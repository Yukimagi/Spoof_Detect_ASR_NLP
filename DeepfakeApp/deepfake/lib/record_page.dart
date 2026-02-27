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

class RecordPage extends StatefulWidget {
  const RecordPage({super.key, required this.title});

  final String title;

  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  final List<double> _waveformData = [];
  StreamSubscription? _recorderSubscription;
  final List<String> _predictionResults = [];
  final List<bool> _isFalseSound = []; // 用來存每段是否為假音
  int _segmentCounter = 1; // 段落计数器
  final List<bool> _waveformPrediction = []; // 用來存每段波形是否為假音

  final int _segmentDuration = 4; // 每段持续时间（秒）
  //final ScrollController _scrollController =ScrollController(); // 添加 ScrollController

  final ScrollController _waveformScrollController =
      ScrollController(); // 用於波形滾動
  final ScrollController _resultScrollController =
      ScrollController(); // 用於預測結果滾動

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _initRecorder();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showUsageInstructions(); // 在第一幀渲染完成後顯示對話框
    });
  }

  Future<void> _showUsageInstructions() async {
    //SharedPreferences prefs = await SharedPreferences.getInstance();
    //bool? hasSeenInstructions = prefs.getBool('hasSeenInstructions') ?? false;

    //if (!hasSeenInstructions) {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('使用說明'),
          content: const Text(
            '1. 點擊下方 "錄音" 按鈕來錄音即可即時辨識並顯示辨識結果',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('了解'),
              onPressed: () {
                //prefs.setBool('hasSeenInstructions', true); // 設置標誌為 true
                Navigator.of(context).pop(); // 關閉對話框
              },
            ),
          ],
        );
      },
    );
  }
  //}

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
        const Duration(milliseconds: 125)); //减少波形数据的采样率或者增加每次绘制的间隔
  }

  void _startRecording() async {
    Directory tempDir = await getTemporaryDirectory();
    String filePath = '${tempDir.path}/recording.wav';

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
      audioSource: AudioSource.voice_communication, // 將此設置為可能錄製通話的音源
    );

    setState(() {
      _isRecording = true;
    });

    _recorderSubscription = _recorder.onProgress!.listen((e) {
      print("Decibels: ${e.decibels}"); // 打印分贝值
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

    // 每4秒保存音档并进行预测
    Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!_isRecording) {
        timer.cancel();
      } else {
        await _recorder.stopRecorder(); // 停止录音以保存音档
        await _uploadAndPredict(filePath);

        // 生成新的文件名以防止覆盖
        // String newFilePath =
        //     '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _recorder.startRecorder(
          toFile: filePath,
          codec: Codec.pcm16WAV,
        );
      }
    });
  }

  Future<void> _uploadAndPredict(String filePath) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse('http://172.20.10.3:8000/predict')); // 替换为你的服务器IP

    request.files.add(await http.MultipartFile.fromPath('files', filePath));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await http.Response.fromStream(response);
      final result = json.decode(responseData.body);

      // 计算时间范围
      int startSeconds = (_segmentCounter - 1) * _segmentDuration;
      int endSeconds = startSeconds + _segmentDuration;

      setState(() {
        _predictionResults.add(
          '第$startSeconds-$endSeconds秒辨識結果：${result['results'].join('\n')}',
        );

        // 更新真假音标记
        bool hasFalseSound =
            result['results'].any((r) => r == '假音'); // 检查这一段是否包含假音
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
      }
    } else {
      print('Error: ${response.reasonPhrase}');
    }
  }

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
