import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'camera_app.dart';
import 'pose_painter.dart';
import 'dart:developer';

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

    // Convert the InputImage object to a Uint8List.


    Tensor _input = _interpreter1!.getInputTensor(0);



    Tensor _outputTensor1 = _interpreter1!.getOutputTensor(0);
    debugPrint('========================');
    debugPrint(inputImage.toString());
    debugPrint(_input.getInputShapeIfDifferent(inputImage).toString());


    _interpreter1!.run(inputImage, _outputTensor1.data);

    Tensor _outputTensor2 = _interpreter2!.getOutputTensor(0);
    _interpreter2?.run(_outputTensor1.data, _outputTensor2.data);












    // final poses = await _poseDetector.processImage(inputImage);
    // if (inputImage.inputImageData?.size != null &&
    //     inputImage.inputImageData?.imageRotation != null) {
    //   final painter = PosePainter(poses, inputImage.inputImageData!.size,
    //       inputImage.inputImageData!.imageRotation);
    //   _customPaint = CustomPaint(painter: painter);
    // } else {
    //   _text = 'Poses found: ${poses.length}\n\n';
    //   _customPaint = null;
    // }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}