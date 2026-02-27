import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart'; // 添加此行

class FileRecognitionPage extends StatefulWidget {
  const FileRecognitionPage({super.key});

  @override
  _FileRecognitionPageState createState() => _FileRecognitionPageState();
}

class _FileRecognitionPageState extends State<FileRecognitionPage> {
  List<String>? _filePaths;
  List<String> _fileNames = []; // 儲存檔案名稱
  final Map<String, String> _predictionResults = {}; // 儲存檔案名稱對應的辨識結果
  bool _isLoading = false; // 整體辨識狀態

  @override
  void initState() {
    super.initState();
    
    // 在第一幀渲染完成後顯示對話框
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showUsageInstructions(); 
    });
  }

  // 顯示使用說明的對話框
  Future<void> _showUsageInstructions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? hasSeenInstructions = prefs.getBool('hasSeenInstructions') ?? false;

    // if (!hasSeenInstructions) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('使用說明'),
            content: const Text(
              '1. 點擊 "選擇檔案" 按鈕來上傳音訊檔案（支援 MP3、WAV、AAC、FLAC）。\n'
              '2. 檔案選擇後，點擊 "辨識" 按鈕來進行辨識。\n'
              '3. 辨識完成後，結果將顯示在檔案名稱旁邊。',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('了解'),
                onPressed: () {
                  prefs.setBool('hasSeenInstructions', true); // 設置標誌為 true
                  Navigator.of(context).pop(); // 關閉對話框
                },
              ),
            ],
          );
        },
      );
    // }
  }

  // 選擇檔案
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
        _predictionResults.clear(); // 清除之前的辨識結果
      });
    } else {
      print('No file selected.');
    }
  }

  // 上傳檔案並進行辨識
  Future<void> _uploadAndPredict() async {
    if (_filePaths == null || _filePaths!.isEmpty) {
      print('No files selected.');
      return;
    }

    setState(() {
      _isLoading = true; // 開始辨識時設置為 true
    });

    final request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.1.118:8000/predict'));

    for (String? path in _filePaths!) {
      if (path != null) {
        request.files.add(await http.MultipartFile.fromPath('files', path));
      }
    }

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await http.Response.fromStream(response);
      final result = json.decode(responseData.body);
      setState(() {
        _isLoading = false; // 辨識完成後設置為 false
        if (result['results'] != null && result['results'] is List) {
          for (int i = 0; i < _fileNames.length; i++) {
            _predictionResults[_fileNames[i]] = result['results'][i]; // 將辨識結果與檔案名稱配對
          }
        }
      });
    } else {
      setState(() {
        _isLoading = false; // 辨識失敗後設置為 false
      });
      print('Error: ${response.reasonPhrase}');
    }
  }

  // 建立檔案名稱及辨識結果的列表
  List<Widget> _buildFileNameListWithResults() {
    return _fileNames.map((fileName) {
      String? prediction = _predictionResults[fileName];
      
      // 假音標記
      bool isFalseSound = prediction != null && prediction.contains('假音');

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // 水平置中
          children: [
            Text(
              fileName,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(width: 10), // 用來控制檔案名稱和辨識結果之間的距離
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
                  color: isFalseSound ? Colors.red : Colors.black, // 根據假音決定顏色
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
        title: const Text(''),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // 水平置中
                children: <Widget>[
                  if (_filePaths != null && _filePaths!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center, // 水平置中
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
                        ..._buildFileNameListWithResults(), // 顯示檔案名稱和辨識結果
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25), // 添加與按鈕之間的距離
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0), // 控制按鈕距離底部的間距
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 按鈕之間均勻分布
              children: [
                SizedBox(
                  width: 150, // 設定按鈕的寬度
                  height: 50, // 設定按鈕的高度
                  child: ElevatedButton(
                    onPressed: _pickFiles,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromARGB(255, 20, 52, 112), // 按鈕顏色
                    ),
                    child: const Text(
                      '選擇檔案',
                      style: TextStyle(
                        fontSize: 15, // 設定文字大小為 15
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150, // 設定按鈕的寬度
                  height: 50, // 設定按鈕的高度
                  child: ElevatedButton(
                    onPressed: _uploadAndPredict,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromARGB(255, 100, 150, 200), // 按鈕顏色
                    ),
                    child: const Text(
                      '辨識',
                      style: TextStyle(
                        fontSize: 15, // 設定文字大小為 15
                      )
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
