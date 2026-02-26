import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_fonts/google_fonts.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
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
      debugShowCheckedModeBanner: false, // 오른쪽 위 DEBUG 띠 여부
      title: 'Wink Page Turner',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        // 앱 전체 텍스트에 백악관 폰트와 비슷한 폰트 (Merriweather) 적용
        textTheme: GoogleFonts.merriweatherTextTheme(), 
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
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, enableTracking: true),
  );

  bool _isDetecting = false;
  String eyeStatus = "AI 인식 중...";
  DateTime _lastTurnTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    fromAsset('assets/sample.pdf', 'sample.pdf').then((f) {
      if (mounted) setState(() => localPath = f.path);
    });
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    CameraDescription? frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});

    _cameraController!.startImageStream((image) {
      if (_isDetecting) return;
      _isDetecting = true;
      _processCameraImage(image, frontCamera);
    });
  }

  Future<void> _processCameraImage(CameraImage image, CameraDescription camera) async {
    try {
      final inputImage = _prepareInputImage(image, camera);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final left = face.leftEyeOpenProbability ?? 1.0;
        final right = face.rightEyeOpenProbability ?? 1.0;

        setState(() {
          eyeStatus = "L: ${(left * 100).toInt()}% | R: ${(right * 100).toInt()}%";
        });

        //  왼쪽 눈 윙크 감지 (쿨타임 1.5초)
        if (left < 0.15 && right > 0.75) {
          if (DateTime.now().difference(_lastTurnTime).inMilliseconds > 1500) {
            _turnPage(true);
            _lastTurnTime = DateTime.now();
          }
        }
      }
    } catch (e) {
      print(e);
    } finally {
      _isDetecting = false;
    }
  }

  void _turnPage(bool next) {
    if (_pdfViewController != null) {
      _pdfViewController!.setPage(next ? currentPage + 1 : currentPage - 1);
    }
  }

  InputImage _prepareInputImage(CameraImage image, CameraDescription camera) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg,
      format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  Future<File> fromAsset(String asset, String filename) async {
    var data = await rootBundle.load(asset);
    var bytes = data.buffer.asUint8List();
    File file = File("${Directory.systemTemp.path}/$filename");
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "AI Wink Page Turner",
          style: GoogleFonts.merriweather(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[100],
      ),
      body: Stack(
        children: [
          // 1. PDF 악보 화면
          Positioned.fill(
            child: localPath != null
                ? PDFView(
                    filePath: localPath,
                    swipeHorizontal: true,
                    onViewCreated: (vc) => _pdfViewController = vc,
                    onPageChanged: (p, t) => setState(() => currentPage = p ?? 0),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          
          // 2. 카메라 미리보기 (오른쪽 위)
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned(
              top: 20, 
              right: 20,
              child: Container(
                width: 90, 
                height: 110,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2), 
                  borderRadius: BorderRadius.circular(10)
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8), 
                  child: CameraPreview(_cameraController!)
                ),
              ),
            ),
            
          // 3. 눈 상태 표시 텍스트 (반투명)
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black45, // 악보가 비치도록 반투명 배경
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                eyeStatus,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      //  수동 넘기기 버튼
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _turnPage(false),
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: () => _turnPage(true),
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}