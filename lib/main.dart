import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:camera/camera.dart'; // 🌟 1. 카메라 기능 불러오기

// 🌟 2. 내 폰에 있는 카메라 목록을 저장할 빈 바구니
List<CameraDescription> cameras = [];

// 🌟 3. 앱 시작 전에 카메라를 먼저 찾도록 main() 함수 수정
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras(); // 폰의 모든 카메라(전면, 후면) 정보 가져오기
  } catch (e) {
    print('카메라 에러: $e');
  }
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
  PDFViewController? _pdfViewController;
  int currentPage = 0;

  // 🌟 4. 카메라를 조종할 리모컨 변수 추가
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    // PDF 준비하기
    fromAsset('assets/sample.pdf', 'sample.pdf').then((f) {
      setState(() {
        localPath = f.path;
      });
    });

    // 🌟 5. 전면 카메라 켜기 함수 실행
    _initCamera();
  }

  // 🌟 전면 카메라를 찾아서 세팅하는 함수
  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;

    CameraDescription? frontCamera;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera; // 셀카용 전면 카메라 찾기
        break;
      }
    }

    if (frontCamera != null) {
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // 얼굴 인식용이라 저화질(low)로 설정하여 속도 높이기
        enableAudio: false,   // 소리 녹음은 안 함
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {}); // 화면 새로고침해서 카메라 보여주기
      }
    }
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
  void dispose() {
    // 🌟 6. 앱을 끌 때 카메라도 안전하게 꺼주기
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("나의 악보"),
        backgroundColor: Colors.blue[100],
      ),
      // 🌟 7. 화면을 겹치기 위해 Stack 사용 (바닥엔 PDF, 그 위엔 카메라)
      body: Stack(
        children: [
          // [1층] 바닥: PDF 뷰어
          Positioned.fill(
            child: localPath != null
                ? PDFView(
                    filePath: localPath,
                    enableSwipe: true,
                    swipeHorizontal: true,
                    autoSpacing: false,
                    pageFling: true,
                    backgroundColor: Colors.grey,
                    onViewCreated: (PDFViewController vc) {
                      _pdfViewController = vc;
                    },
                    onPageChanged: (int? page, int? total) {
                      setState(() {
                        currentPage = page ?? 0;
                      });
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // [2층] 공중: 카메라 화면 (오른쪽 위에 작게 띄우기)
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 100,
                height: 130,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CameraPreview(_cameraController!), // 카메라 영상이 나오는 곳
                ),
              ),
            ),
        ],
      ),
      // 수동 넘기기 버튼 (유지)
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              if (_pdfViewController != null && currentPage > 0) {
                _pdfViewController!.setPage(currentPage - 1);
              }
            },
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: () {
              if (_pdfViewController != null) {
                _pdfViewController!.setPage(currentPage + 1);
              }
            },
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}