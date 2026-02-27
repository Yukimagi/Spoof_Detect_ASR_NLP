import 'package:flutter/material.dart';
import 'home_page.dart';
import 'about_page.dart';
import 'issues_page.dart';
import 'record_page.dart';
import 'file_recognition_page.dart';
import 'welcome_page.dart';
import 'tf_file_recognition_page.dart';
import 'tf_record_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepFake',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/home': (context) => const MyHomePage(title: ''),
        '/about': (context) => const AboutPage(),
        '/issues': (context) => const IssuesPage(),
        '/record': (context) => const RecordPage(title: '',),
        '/tfrecord': (context) => const TfRecordPage(title: '',),
        '/fileRecognition': (context) => const FileRecognitionPage(),
        '/tfFileRecognition': (context) => const TfFileRecognitionPage(),
      },
    );
  }
}
