import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:tflite_flutter/tflite_flutter.dart'; //.tflite用
import 'dart:typed_data'; //.tflite用

class TfRecordPage extends StatefulWidget {
  const TfRecordPage({super.key, required this.title});

  final String title;

  @override
  _TfRecordPageState createState() => _TfRecordPageState();
}

class _TfRecordPageState extends State<TfRecordPage> {
  FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  List<double> _waveformData = [];
  StreamSubscription? _recorderSubscription;
  List<String> _predictionResults = [];
  final List<bool> _isFalseSound = []; // 用來存每段是否為假音
  int _segmentCounter = 1; // 段落计数器
  final List<bool> _waveformPrediction = []; // 用來存每段波形是否為假音

  final int _segmentDuration = 4; // 每段持续时间（秒）
  final ScrollController _waveformScrollController =
      ScrollController(); // 用於波形滾動
  final ScrollController _resultScrollController =
      ScrollController(); // 用於預測結果滾動

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _initRecorder();
  }

  Future<void> _initPermissions() async {
    var statuses = await [
      Permission.microphone,
      Permission.phone,
      Permission.storage,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      print("Microphone permission not granted");
    }
    if (statuses[Permission.phone] != PermissionStatus.granted) {
      print("Phone state permission not granted");
    }
    if (statuses[Permission.storage] != PermissionStatus.granted) {
      print("Storage permission not granted");
    }
  }

  void _initRecorder() async {
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 125)); //减少波形数据的采样率或者增加每次绘制的间隔 125
  }

  void _startRecording() async {
    Directory tempDir = await getTemporaryDirectory();
    String filePath = '${tempDir.path}/recording.wav';

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
      audioSource: AudioSource
          .voice_communication, // 將此設置為可能錄製通話的音源(voice_communication)
    );

    setState(() {
      _isRecording = true;
    });

    _recorderSubscription = _recorder.onProgress!.listen((e) {
      setState(() {
        // 正規化音量數據以適合繪圖
        double normalizedValue = (e.decibels ?? 0) / 80;
        _waveformData.add(normalizedValue.clamp(-1.0, 1.0));
        // 滚动到最新的结果
        if (_waveformScrollController.hasClients) {
          _waveformScrollController.animateTo(
            _waveformScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeInOut,
          );
        }
      });
    });

    // 每4秒保存音檔並進行預測
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isRecording) {
        timer.cancel();
      } else {
        await _recorder.stopRecorder(); // 停止錄音以保存音檔
        await _uploadAndPredict(filePath); // 確保在上傳之前檔案已寫入

        // 生成新的文件名以防止覆蓋
        //String newFilePath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _recorder.startRecorder(
          toFile: filePath,
          codec: Codec.pcm16WAV,
        );
      }
    });
  }
/*
  Future<void> _uploadAndPredict(String filePath) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.0.70:8000/predict')); // 替換為你的伺服器IP http://192.168.0.70:8000/predict
    request.files.add(await http.MultipartFile.fromPath('files', filePath));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await http.Response.fromStream(response);
      final result = json.decode(responseData.body);
      setState(() {
        _predictionResults.add(result['results'].join('\n'));
      });
    } else {
      print('Error: ${response.reasonPhrase}');
    }
  }*/

  Future<void> _uploadAndPredict(String filePath) async {
    if (filePath.isEmpty) {
      print('No file selected.');
      return;
    }

    try {
      // 獲取下載目錄的路徑
      final Directory? downloadsDirectory = await getExternalStorageDirectory();
      if (downloadsDirectory == null) {
        print('Could not get downloads directory.');
        return;
      }
      final String saveFilePath =
          '${downloadsDirectory.path}/recorded_audio.wav'; // 將音檔保存到下載目錄

      // 複製音檔到指定位置
      final file = File(filePath);
      await file.copy(saveFilePath);
      print('Audio file saved to: $saveFilePath');

      final interpreter =
          await Interpreter.fromAsset('quantized_Res2Net.tflite');

      // 確認模型的輸入形狀
      final inputShape = interpreter.getInputTensor(0).shape;
      print('Model input shape: $inputShape');

      if (inputShape[0] != 1 || inputShape[1] != 64600 || inputShape[2] != 1) {
        throw Exception('Unexpected model input shape: $inputShape');
      }

      //final file = File(filePath);
      final bytes = await file.readAsBytes();

      // 填充數據
      final paddedAudio = padAudioData(bytes, inputShape[1]);

      // 將數據歸一化至範圍 [0, 1]
      final normalizedAudio = paddedAudio
          .map((value) => (value + 256) / 512.0)
          .toList(); // Normalize to [0, 1]

      // 將數據重塑為 [1, 64600, 1] 的格式
      final input = List.generate(
          1, (_) => List.generate(64600, (i) => [normalizedAudio[i]]));

      // 準備模型的輸出格式，調整為 [1, 2] 的形狀
      List<List<double>> output = List.generate(1, (_) => List.filled(2, 0.0));
      interpreter.run(input, output);

      double p0 = output[0][0]; // 假音
      double p1 = output[0][1]; // 真音

      // 輸出結果
      print('Output p0: $p0, p1: $p1');
      String result = p1 > p0 ? "假音" : "真音"; // Adjusted to compare correctly

      // 计算时间范围
      int startSeconds = (_segmentCounter - 1) * _segmentDuration;
      int endSeconds = startSeconds + _segmentDuration;

      // 將結果包裝成類似於 JSON 結構的格式
      final Map<String, dynamic> resultMap = {
        'results': [result], // 包裝成列表
      };

      setState(() {
        //_predictionResults.add(resultMap['results'].join('\n')); // 與原來相同的呈現方式
        _predictionResults.add(
          '第$startSeconds-$endSeconds秒辨識結果：${resultMap['results'].join('\n')}',
        );

        // 更新真假音标记
        bool hasFalseSound =
            resultMap['results'].any((r) => r == '假音'); // 检查这一段是否包含假音
        _isFalseSound.add(hasFalseSound); // 保存当前段是否为假音
        for (int i = 0; i < _segmentDuration * (1000 / 125); i++) {
          // 计算当前段的波形长度
          _waveformPrediction.add(hasFalseSound); // 如果有假音，将整段标记为假音
        }

        _segmentCounter++; // 更新段落编号
      });

      // 滚动到最新的结果
      if (_resultScrollController.hasClients) {
        _resultScrollController.animateTo(
          _resultScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        print('Error');
      }

      interpreter.close();
    } catch (e) {
      print('Error: $e');
    }
  }

// 填充音頻數據至指定長度（64600）
  List<double> padAudioData(Uint8List audioData, int maxLength) {
    List<double> floatData = audioData.map((byte) => byte.toDouble()).toList();
    if (floatData.length > maxLength) {
      return floatData.sublist(0, maxLength);
    } else {
      return List<double>.filled(maxLength, 0)
        ..setRange(0, floatData.length, floatData);
    }
  }

  //以下是原始的

  void _stopRecording() async {
    await _recorder.stopRecorder();
    _recorderSubscription?.cancel();
    setState(() {
      _isRecording = false;
    });
  }

  void _clearPredictionResult() {
    setState(() {
      _predictionResults.clear();
      _waveformData.clear();
      _segmentCounter = 1; // 重置段落编号
      _isFalseSound.clear(); // 清空真假音的标记
      _waveformPrediction.clear(); // 清空波形真假音标记
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _recorderSubscription?.cancel();
    _waveformScrollController.dispose(); // 清理波形的 ScrollController
    _resultScrollController.dispose(); // 清理結果的 ScrollController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                controller: _waveformScrollController, // 绑定 ScrollController
                scrollDirection: Axis.horizontal, // 啟用水平滾動
                child: CustomPaint(
                  //size: Size(_waveformData.length.toDouble(), 200),
                  size: Size(
                    (_waveformData.length *
                            (WaveformPainter.spaceBetweenWaves +
                                WaveformPainter.xIncrement))
                        .toDouble(), // 动态计算画布宽度
                    200,
                  ),
                  painter: WaveformPainter(_waveformData, _waveformPrediction),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0), // 添加底部内邊距
                child: ListView.builder(
                  controller: _resultScrollController, // 設置 ScrollController
                  itemCount: _predictionResults.length,
                  itemBuilder: (context, index) {
                    // 根据假音标记调整颜色
                    Color textColor =
                        _isFalseSound.isNotEmpty && _isFalseSound[index]
                            ? Colors.red
                            : Colors.black;
                    return ListTile(
                      title: Text(
                        _predictionResults[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor), // 设置文本颜色
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.transparent, // 設置 BottomAppBar 背景顏色
        height: 50.0,
        child: Row(
          children: <Widget>[
            const Spacer(), // 推動按扭到中間
            ElevatedButton(
              onPressed: _clearPredictionResult,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor:
                    const Color.fromARGB(255, 93, 160, 228), // 按鈕顏色
              ),
              child: const Text('清除'),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 0), // 調整錄音按鈕位置
        child: FloatingActionButton(
          onPressed: _isRecording ? _stopRecording : _startRecording,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          tooltip: _isRecording ? '停止录音' : '开始录音',
          // 增加按鈕周圍的 padding
          elevation: 10.0,
          child: Icon(
            _isRecording ? Icons.stop : Icons.mic,
            color: _isRecording ? Colors.red : Colors.blue,
            size: 26, // 增加圖標尺寸
          ),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> data;
  final List<bool> predictions; // 用来接收真假音标记
  static const double threshold = 0.1; // 阈值
  static const double spaceBetweenWaves = 4.0; // 每个波形之间的空隙
  static const double xIncrement = 0.0; // x 坐标增量

  WaveformPainter(this.data, this.predictions);

  @override
  void paint(Canvas canvas, Size size) {
    double x = 0.0;
    double midY = size.height / 2;

    // x 轴
    Paint axisPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axisPaint);

    // y 轴
    Paint axisPaint2 = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint2);

    for (int i = 0; i < data.length; i++) {
      var sample = data[i];
      Paint paint = Paint()
        ..color = (i < predictions.length && predictions[i])
            ? Colors.red
            : Colors.blue
        ..strokeWidth = 1.0;

      if (sample.abs() > threshold) {
        double y = sample * midY;
        canvas.drawLine(Offset(x, midY - y), Offset(x, midY + y), paint);
      }

      x += xIncrement + spaceBetweenWaves; // 更新 x 坐标
    }
    //下面是補上原本的code
    // y 最大值和最小值
    final yLabelStyle = ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      fontSize: 12.0,
    );

    var yTextBuilder = ui.ParagraphBuilder(yLabelStyle)
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText('1.0');
    canvas.drawParagraph(
      yTextBuilder.build()..layout(const ui.ParagraphConstraints(width: 40)),
      const Offset(-30, 0),
    );

    yTextBuilder = ui.ParagraphBuilder(yLabelStyle)
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText('-1.0');
    canvas.drawParagraph(
      yTextBuilder.build()..layout(const ui.ParagraphConstraints(width: 40)),
      Offset(-30, size.height - 12),
    );

    // 0 在开始处
    var timeTextBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      fontSize: 12.0,
    ))
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText('0');
    canvas.drawParagraph(
      timeTextBuilder.build()..layout(const ui.ParagraphConstraints(width: 50)),
      Offset(-36, midY), // 位置
    );

    // 时间戳
    final xLabelStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      fontSize: 12.0,
    );

    int intervalSamples = (4000 / 125).round(); // 采样点数
    //int intervalSamples = (data.length / 4).round(); // 采样点数，每隔 4 秒标记

    for (int i = 0; i < size.width; i += intervalSamples) {
      // 每 intervalSamples 个数据标记
      var timeTextBuilder = ui.ParagraphBuilder(xLabelStyle)
        ..pushStyle(ui.TextStyle(color: Colors.black))
        ..addText('${i ~/ intervalSamples * 4}s'); // 显示秒数

      double xPos = i * xIncrement + spaceBetweenWaves * i;

      canvas.drawParagraph(
        timeTextBuilder.build()
          ..layout(const ui.ParagraphConstraints(width: 50)),
        Offset(xPos - 20, midY + 20), // 调整位置
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
