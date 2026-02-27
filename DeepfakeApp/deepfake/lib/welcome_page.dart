import 'package:flutter/material.dart';
import 'home_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 延遲兩秒後跳轉到 MyHomePage
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: 'DeepFake'),
        ),
      );
    });

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // 全螢幕圖片
          Positioned.fill(
            child: Image.asset(
              'assets/Deepfake.png',  // 確保這個路徑與你配置的資源路徑一致
              fit: BoxFit.cover,  // 使用 BoxFit.cover 來保持比例並填滿螢幕
            ),
          ),
          // 你可以在圖片上添加其他小部件
          // Positioned(
          //   bottom: 50,  // 這裡可以調整位置
          //   left: 20,
          //   child: const Text(
          //     '歡迎使用DeepFake！',
          //     style: TextStyle(
          //       fontSize: 24,
          //       color: Colors.white,
          //       fontWeight: FontWeight.bold,
          //     ),
            // ),
          // ),
        ],
      ),
    );
  }
}
