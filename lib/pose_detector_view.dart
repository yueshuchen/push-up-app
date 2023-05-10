import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'camera_app.dart';


class PoseDetectorView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {


  final PoseDetector _poseDetector =
  PoseDetector(options: PoseDetectorOptions());
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  Interpreter? _interpreter1;
  Interpreter? _interpreter2;

  @override
  void initState() {
    super.initState();

    _loadModel1();
    _loadModel2();
  }

  @override
  void dispose() async {
    _canProcess = false;
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameraApp(
      title: 'Pose Detector',
      customPaint: _customPaint,
      text: _text,
      onImage: (inputImage) {
        processImage(inputImage);
      },
    );
  }

  Future<void> _loadModel1() async {
    final interpreterOptions = InterpreterOptions();
    _interpreter1 = await Interpreter.fromAsset('movenet-thunder.tflite', options: interpreterOptions);
  }

  Future<void> _loadModel2() async {
    final interpreterOptions = InterpreterOptions();
    _interpreter2 = await Interpreter.fromAsset('pose-classifier.tflite', options: interpreterOptions);
  }

  Future<void> processImage(Uint8List inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    var output1 = List<double>.filled(51,0).reshape([1,1,17,3]);

    _interpreter1!.run(inputImage, output1);

    debugPrint(output1.toString());

    var output2 = List<double>.filled(2,0).reshape([1,2]);

    _interpreter2?.run(output1, output2);

    debugPrint(output2.toString());

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}