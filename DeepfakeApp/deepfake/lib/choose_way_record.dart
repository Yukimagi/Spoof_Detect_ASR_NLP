import 'package:flutter/material.dart';

class ChooseWayRecord extends StatelessWidget {
  const ChooseWayRecord({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 定義統一按鈕樣式
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      foregroundColor: Colors.white,
      fixedSize: const Size(250, 60), // 固定按鈕大小
      textStyle: const TextStyle(fontSize: 20),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇辨識方式'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 添加說明文字，位於標題下方
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0), // 讓文字左右有點邊距
              child: Text(
                '\nserver辨識：\n 需連接server，效果較好\n\n本機Tflite辨識：\n  本機即可辨識，但效果稍差一些',
                style: TextStyle(fontSize: 18), // 說明文字的字體大小
                // textAlign: TextAlign.center, // 文字居中對齊
              ),
            ),
            // const SizedBox(height: 0), // 說明文字和按鈕之間的間距

            // 使用 Expanded 讓按鈕置中
            Expanded(
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Server 辨識按鈕
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/record'); // 跳轉到 record_page.dart
                    },
                    style: buttonStyle.copyWith(
                      backgroundColor: const WidgetStatePropertyAll<Color>(
                        Color.fromARGB(255, 20, 52, 112),
                      ),
                    ),
                    child: const Text('Server 辨識'),
                  ),
                  const SizedBox(height: 20), // 按鈕之間的間距
                  // 本機 TFLite 辨識按鈕
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/tfrecord'); // 跳轉到 tf_record_page.dart
                    },
                    style: buttonStyle.copyWith(
                      backgroundColor: const WidgetStatePropertyAll<Color>(
                        Color.fromARGB(255, 100, 150, 200), // 按鈕顏色
                      ),
                    ),
                    child: const Text('本機 TFLite 辨識'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
