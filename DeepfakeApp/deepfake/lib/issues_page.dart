import 'package:flutter/material.dart';

class IssuesPage extends StatelessWidget {
  const IssuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用說明'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: [
            // 第一個標題
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0), // 調整上下邊距
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 100, 150, 200), // 設置背景顏色
                borderRadius: BorderRadius.circular(15.0), // 設置圓角
              ),
              child: const ExpansionTile(
                title: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    '檔案辨識',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // 設置文字顏色
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      '點擊下方"檔案辨識"後，點擊"選擇檔案"上傳欲檢測的音訊檔案。\n\n支持多種格式（mp3, wav, aac, flac），並且可以一次上傳多個檔案。\n\n點擊"辨識"，App將自動分析音檔，並顯示辨識結果(真音或假音)。\n',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 第二個標題
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 100, 150, 200),
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: const ExpansionTile(
                title: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    '語音辨識',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      '點擊下方"語音辨識"後，即可及時錄製音訊並分析音訊，顯示辨識結果(真音或假音)。\n',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 第三個標題
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 252, 199, 216),
                borderRadius: BorderRadius.circular(15.0),
              ),
              // child: const ExpansionTile(
              //   title: Padding(
              //     padding: EdgeInsets.all(8.0),
              //     child: Text(
              //       '3. 簡單直觀的操作：',
              //       style: TextStyle(
              //         fontSize: 18,
              //         fontWeight: FontWeight.bold,
              //         color: Colors.white,
              //       ),
              //     ),
              //   ),
              //   children: [
              //     Padding(
              //       padding: EdgeInsets.symmetric(horizontal: 16.0),
              //       child: Text(
              //         '我們的App簡單直觀，讓使用者能輕鬆上手，保護自己免受偽造語音的欺騙。\n',
              //         style: TextStyle(fontSize: 18),
              //       ),
              //     ),
              //   ],
              // ),
            ),
          ],
        ),
      ),
    );
  }
}
