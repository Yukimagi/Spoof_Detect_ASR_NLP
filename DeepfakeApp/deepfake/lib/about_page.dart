import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('關於我們'),
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
                    '什麼是"Deepfake偽造語音"?',
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
                      '是一種通過深度學習技術生成出與人聲極為相似的合成語音\n',
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
                    'Deepfake的威脅！',
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
                      '此技術雖然具有創新潛力，但也造成了威脅！根據美國資安公司統計，每4個人中就有1人曾碰過AI語音詐欺。\n甚至出現AI模仿老闆聲音進行轉帳詐騙的案例，成功騙走近770萬元！\n',
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
                color: const Color.fromARGB(255, 100, 150, 200),
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: const ExpansionTile(
                title: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'DeepFake偽造語音檢測App',
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
                      '因此我們開發了"DeepFake偽造語音檢測"App，以幫助用戶識別偽造語音，保護個人和企業免受這些風險。\n',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
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
