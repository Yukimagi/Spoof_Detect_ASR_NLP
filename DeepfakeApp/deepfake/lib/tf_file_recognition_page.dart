import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import 'package:tflite_flutter/tflite_flutter.dart'; // .tflite用
import 'dart:typed_data'; // .tflite用

class TfFileRecognitionPage extends StatefulWidget {
  const TfFileRecognitionPage({super.key});

  @override
  _TfFileRecognitionPage createState() => _TfFileRecognitionPage();
}

class _TfFileRecognitionPage extends State<TfFileRecognitionPage> {
  List<String>? _filePaths;
  List<String> _fileNames = []; // 儲存檔案名稱
  final Map<String, String> _predictionResults = {}; // 儲存檔案名稱對應的辨識結果
  bool _isLoading = false; // 整體辨識狀態
  String? _errorMessage; // 用於存儲錯誤訊息

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'flac'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _filePaths = result.paths.cast<String>();
        _fileNames = _filePaths!.map((path) => File(path).uri.pathSegments.last).toList();
        _predictionResults.clear();
      });
    } else {
      print('No files selected.');
    }
  }

  Future<void> _uploadAndPredict() async {
    if (_filePaths == null || _filePaths!.isEmpty) {
      print('No files selected.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final interpreter = await Interpreter.fromAsset('quantized_Res2Net.tflite');
      final inputShape = interpreter.getInputTensor(0).shape;

      if (inputShape[0] != 1 || inputShape[1] != 64600 || inputShape[2] != 1) {
        throw Exception('Unexpected model input shape: $inputShape');
      }

      List<String> results = [];
      for (String? path in _filePaths!) {
        if (path == null) continue;

        final file = File(path);
        final bytes = await file.readAsBytes();
        // 填充數據
        final paddedAudio = padAudioData(bytes, inputShape[1]);
        // 將數據歸一化至範圍 [0, 1]
        final normalizedAudio = paddedAudio.map((value) => (value + 256) / 512.0).toList();
        // 將數據重塑為 [1, 64600, 1] 的格式
        final input = List.generate(1, (_) => List.generate(64600, (i) => [normalizedAudio[i]]));
        // 準備模型的輸出格式，調整為 [1, 2] 的形狀
        List<List<double>> output = List.generate(1, (_) => List.filled(2, 0.0));
        interpreter.run(input, output);

        double p0 = output[0][0]; // 假音
        double p1 = output[0][1]; // 真音

        // 輸出結果
        String result = p1 > p0 ? "假音" : "真音";
        results.add(result);
      }

      setState(() {
        _isLoading = false; // 辨識完成後設置為 false
        if (results.isNotEmpty) {
          for (int i = 0; i < _fileNames.length; i++) {
            _predictionResults[_fileNames[i]] = results[i]; // 將辨識結果與檔案名稱配對
          }
        }
      });

      interpreter.close();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '辨識過程出錯: $e';
      });
    }
  }

  // 填充音頻數據至指定長度（64600）
  List<double> padAudioData(Uint8List audioData, int maxLength) {
    List<double> floatData = audioData.map((byte) => byte.toDouble()).toList();
    if (floatData.length > maxLength) {
      return floatData.sublist(0, maxLength);
    } else {
      return List<double>.filled(maxLength, 0)..setRange(0, floatData.length, floatData);
    }
  }

  List<Widget> _buildFileNameListWithResults() {
    return _fileNames.map((fileName) {
      String? prediction = _predictionResults[fileName];
      bool isFalseSound = prediction != null && prediction.contains('假音');

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              fileName,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(width: 10),
            if (_isLoading && prediction == null)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            if (!_isLoading && prediction == null)
              const Text(
                '尚未辨識',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            if (prediction != null)
              Text(
                prediction,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isFalseSound ? Colors.red : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('辨識結果'),
      ),
      body: Column(
        children: <Widget>[
          if (_errorMessage != null) // 如果有錯誤訊息則顯示
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (_filePaths != null && _filePaths!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Align(
                          alignment: Alignment(-0.3, 0), // 調整這裡使 "已選擇檔案" 向左一點
                          child: Padding(
                            padding: EdgeInsets.only(left: 20.0, top: 0.0, bottom: 5.0), // 向上移動
                            child: Text(
                              '已選擇檔案:',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                        ..._buildFileNameListWithResults(),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _pickFiles,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromARGB(255, 20, 52, 112),
                    ),
                    child: const Text(
                      '選擇檔案',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _uploadAndPredict,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromARGB(255, 100, 150, 200),
                    ),
                    child: const Text(
                      '辨識',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
