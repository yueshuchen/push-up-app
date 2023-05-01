import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'dart:async';

import './main.dart';

import 'dart:io';

class CameraApp extends StatefulWidget {
  CameraApp(
      {Key? key,
        required this.title,
        required this.customPaint,
        this.text,
        required this.onImage,
        this.initialDirection = CameraLensDirection.back})
      : super(key: key);

  final String title;
  final CustomPaint? customPaint;
  final String? text;
  final Function(Uint8List inputImage) onImage;
  final CameraLensDirection initialDirection;

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController? _controller;
  int _cameraIndex = -1;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  bool _changingCameraLens = false;

  @override
  void initState() {
    super.initState();

    if (cameras.any(
          (element) =>
      element.lensDirection == widget.initialDirection &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere((element) =>
        element.lensDirection == widget.initialDirection &&
            element.sensorOrientation == 90),
      );
    } else {
      for (var i = 0; i < cameras.length; i++) {
        if (cameras[i].lensDirection == widget.initialDirection) {
          _cameraIndex = i;
          break;
        }
      }
    }

    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _body(),
      floatingActionButton: _floatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget? _floatingActionButton() {
    if (cameras.length == 1) return null;
    return SizedBox(
        height: 70.0,
        width: 70.0,
        child: FloatingActionButton(
          onPressed: _switchLiveCamera,
          child: Icon(
            Platform.isIOS
                ? Icons.flip_camera_ios_outlined
                : Icons.flip_camera_android_outlined,
            size: 40,
          ),
        ));
  }

  Widget _body() {
    Widget body = _liveFeedBody();

    return body;
  }

  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }

    final size = MediaQuery.of(context).size;
    // calculate scale depending on screen and camera ratios
    // this is actually size.aspectRatio / (1 / camera.aspectRatio)
    // because camera preview size is received as landscape
    // but we're calculating for portrait orientation
    var scale = size.aspectRatio * _controller!.value.aspectRatio;

    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: Center(
              child: _changingCameraLens
                  ? const Center(
                child: Text('Changing camera lens'),
              )
                  : CameraPreview(_controller!),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
          Text(widget.text!,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold)),
          Positioned(
            bottom: 100,
            left: 50,
            right: 50,
            child: Slider(
              value: zoomLevel,
              min: minZoomLevel,
              max: maxZoomLevel,
              onChanged: (newSliderValue) {
                setState(() {
                  zoomLevel = newSliderValue;
                  _controller!.setZoomLevel(zoomLevel);
                });
              },
              divisions: (maxZoomLevel - 1).toInt() < 1
                  ? null
                  : (maxZoomLevel - 1).toInt(),
            ),
          )
        ],
      ),
    );
  }

  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _controller?.startImageStream(_extractChannels);
      setState(() {});
    });
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  Future<void> _extractChannels(CameraImage image) async {
    final width = image.width;
    final height = image.height;

    final channels = <int>[];
    final bgraData = image.planes[0].bytes;
    for (int i = 0; i < bgraData.lengthInBytes; i += 4) {
      // Get the blue, green, and red channels for the current pixel
      final blue = bgraData[i];
      final green = bgraData[i + 1];
      final red = bgraData[i + 2];

      // Add the channels to the output list
      channels.add(blue);
      channels.add(green);
      channels.add(red);
    }

    // Create an image from the extracted channels
    final imageBytes = Uint8List.fromList(channels);
    final resizedImage = img.copyResize(
      img.Image.fromBytes(width, height, imageBytes),
      width: 256,
      height: 256,
    );

    // Convert the resized image back to a Uint8List
    final resizedBytes = Uint8List.fromList(img.encodePng(resizedImage));

    // Create a ui.Image from the resized image
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      resizedBytes.buffer.asUint8List(),
      resizedImage.width,
      resizedImage.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final uiImage = await completer.future;

    // Convert the ui.Image to a ByteData object
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

    widget.onImage(byteData!.buffer.asUint8List());
  }




  // Future _processCameraImage(CameraImage image) async {
  //   final WriteBuffer allBytes = WriteBuffer();
  //
  //   for (final Plane plane in image.planes) {
  //     allBytes.putUint8List(plane.bytes);
  //   }
  //   final obytes = allBytes.done().buffer.asUint8List();
  //
  //
  //   final bytes = Uint8List.fromList(obytes);
  //
  //
  //   final Size imageSize =
  //   Size(image.width.toDouble(), image.height.toDouble());
  //
  //   final camera = cameras[_cameraIndex];
  //   final imageRotation =
  //   InputImageRotationValue.fromRawValue(camera.sensorOrientation);
  //
  //   if (imageRotation == null) return;
  //
  //   final inputImageFormat =
  //   InputImageFormatValue.fromRawValue(image.format.raw);
  //   if (inputImageFormat == null) return;
  //
  //
  //   final planeData = image.planes.map(
  //         (Plane plane) {
  //       return InputImagePlaneMetadata(
  //         bytesPerRow: plane.bytesPerRow,
  //         height: plane.height,
  //         width: plane.width,
  //       );
  //     },
  //   ).toList();
  //
  //   final inputImageData = InputImageData(
  //     size: imageSize,
  //     imageRotation: imageRotation,
  //     inputImageFormat: inputImageFormat,
  //     planeData: planeData,
  //   );
  //
  //   final inputImage =
  //   InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
  //
  //
  //   //
  //   // widget.onImage(inputImage);
  // }
}