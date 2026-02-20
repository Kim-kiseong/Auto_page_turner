import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_pdfview/flutter_pdfview.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Turner',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const PdfViewerPage(),
    );
  }
}

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  String? localPath;
  
  // 🌟 [추가된 부분 1] PDF 컨트롤러(리모컨)와 현재 페이지 번호를 저장할 공간
  PDFViewController? _pdfViewController;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    fromAsset('assets/sample.pdf', 'sample.pdf').then((f) {
      setState(() {
        localPath = f.path;
      });
    });
  }

  Future<File> fromAsset(String asset, String filename) async {
    try {
      var data = await rootBundle.load(asset);
      var bytes = data.buffer.asUint8List();
      var dir = Directory.systemTemp; 
      File file = File("${dir.path}/$filename");

      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      throw Exception("파일을 처리하는 중 오류가 났어요: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("나의 악보"),
        backgroundColor: Colors.blue[100],
      ),
      body: localPath != null
          ? PDFView(
              filePath: localPath,
              enableSwipe: true, 
              swipeHorizontal: true, 
              autoSpacing: false,
              pageFling: true,
              backgroundColor: Colors.grey,
              
              // 🌟 [추가된 부분 2] PDF가 화면에 뜨면 컨트롤러(리모컨)를 연결합니다.
              onViewCreated: (PDFViewController vc) {
                _pdfViewController = vc;
              },
              
              // 🌟 [추가된 부분 3] 스와이프해서 넘길 때마다 현재 몇 페이지인지 기억합니다.
              onPageChanged: (int? page, int? total) {
                setState(() {
                  currentPage = page ?? 0;
                });
              },
            )
          : const Center(child: CircularProgressIndicator()), 
          
      // 🌟 [추가된 부분 4] 화면 오른쪽 아래에 떠 있는 버튼(화살표) 2개 만들기
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              // 이전 페이지로 가기 로직
              if (_pdfViewController != null && currentPage > 0) {
                _pdfViewController!.setPage(currentPage - 1);
              }
            },
            child: const Icon(Icons.arrow_back), // 왼쪽 화살표
          ),
          const SizedBox(width: 10), // 두 버튼 사이의 간격
          FloatingActionButton(
            onPressed: () {
              // 다음 페이지로 가기 로직
              if (_pdfViewController != null) {
                _pdfViewController!.setPage(currentPage + 1);
              }
            },
            child: const Icon(Icons.arrow_forward), // 오른쪽 화살표
          ),
        ],
      ),
    );
  }
}