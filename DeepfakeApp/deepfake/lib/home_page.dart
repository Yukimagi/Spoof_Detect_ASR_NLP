import 'package:flutter/material.dart';
import 'choose_way_file.dart';
import 'choose_way_record.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: '首頁'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ChooseWayFile(),
    const ChooseWayRecord(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(253, 252, 248, 255),
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 20, 52, 112),
              ),
              child: Text(
                '更多',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('關於我們'),
              onTap: () {
                Navigator.pushNamed(context, '/about');
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_answer),
              title: const Text('如何使用'),
              onTap: () {
                Navigator.pushNamed(context, '/issues');
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex], // 根據選中的索引顯示對應的頁面
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.file_upload),
            label: '檔案辨識',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: '錄音辨識',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        // backgroundColor: Color.fromARGB(255, 248, 187, 207),
        // selectedItemColor: const Color.fromARGB(255, 255, 255, 255),
        backgroundColor: const Color.fromARGB(253, 252, 248, 255),
        elevation: 0, // 移除阴影
        onTap: _onItemTapped,
      ),
    );
  }
}
