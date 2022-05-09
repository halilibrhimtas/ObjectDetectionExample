import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

List<CameraDescription>? cameras = [];

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool busy = false;
  ImagePicker imagePicker = ImagePicker();
  List _recognitions = [];
  double _imageHeight = 0.0;
  double _imageWidth = 0.0;
  File _image = File("");

  getImagePicker () async {
    var Ximage = await imagePicker.pickImage(source: ImageSource.gallery);
    if(Ximage == null) {
      return;
  } else {
      _image = File(Ximage.path);
    setState(() {
      busy = true;
    });
    predictImage(_image);
  }
  }
  predictImage (File image) async {
    if(image == null){
      return;
    }else{
      var recognitions = await Tflite.detectObjectOnImage(path: image.path, numResultsPerClass: 1);
      if(recognitions == null){
        return;
      } else{
        setState(() {
          _recognitions = recognitions;
        });
      }
      FileImage(image).resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((ImageInfo info, bool _){
        setState(() {
          _imageHeight = info.image.height.toDouble();
          _imageWidth = info.image.width.toDouble();
        });
      }));
      setState(() {
        _image = image;
        busy = false;
      });
    }
  }

  loadModel() async {
    await Tflite.loadModel(
        model: "asset/models/ssd_mobilenet.tflite",
        labels: "asset/models/label.txt",
        numThreads: 1,
        isAsset: true,
        useGpuDelegate: false);
  }
  @override
  void initState() {
    super.initState();

    busy = true;

    loadModel().then((val) {
      setState(() {
        busy = false;
      });
    });
  }

  List<Widget> renderBoxes(Size size){
    double factorX = size.width;
    double factorY = _imageHeight / _imageWidth*size.width;
    Color green = Colors.green;
    return _recognitions.map((e){
      return Positioned(
        left: e["rect"]["x"]*factorX,
        top: e["rect"]["y"]*factorY,
        width: e["rect"]["w"]*factorX,
        height: e["rect"]["h"]*factorY,
        child: e["confidenceInClass"] > 0.5 ? Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            border: Border.all(
              color: green,
              width: 2
            )
          ),
          child: e["confidenceInClass"] > 0.5 ? Text(
            "${e["detectedClass"]} ${(e["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = green,
              color: Colors.white,
              fontSize: 12.0
            ),
          ): Container(),
        ) : Container(),
      );
    }).toList();
  }

  @override
  Future<void> dispose() async {
    // TODO: implement dispose
    super.dispose();
    await Tflite.close();
  }
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];
      stackChildren.add(
          Positioned(
            child: Image.file(_image),
          ));


    stackChildren.addAll(renderBoxes(size));

    if (busy) {
      stackChildren.add(const Opacity(
        child: ModalBarrier(dismissible: false, color: Colors.grey),
        opacity: 0.3,
      ));
      stackChildren.add(const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
        appBar: AppBar(
          title:  const Text("tflite example"),
        ),
        body: Stack(
          children: stackChildren,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            getImagePicker();
          },
          tooltip: "Pick Image",
          child:  const Icon(Icons.image),
        ),
      );

  }
}





