import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

final List<String> imgList = [
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/blast/IMG_0448.jpg?raw=true',
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/blight/IMG_0936.jpg?raw=true',
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/tungro/IMG_0399.jpg?raw=true'
];

Future<File> getImage(String url) async {
  /// Get Image from server
  final Response res = await Dio().get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
    ),
  );

  /// Get App local storage
  final Directory appDir = await getApplicationDocumentsDirectory();

  /// Generate Image Name
  final String imageName = url.split('/').last;

  /// Create Empty File in app dir & fill with new image
  final File file = File(p.join(appDir.path, imageName));

  file.writeAsBytesSync(res.data as List<int>);

  return file;
}

// Reading bytes from a network image
Future<Uint8List> readNetworkImage(String imageUrl) async {
  final ByteData data =
      await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl);
  final Uint8List bytes = data.buffer.asUint8List();
  return bytes;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rice Disease Classifier',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Rice Disease Classifier'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final RoundedLoadingButtonController _btnController =
      RoundedLoadingButtonController();

  String? _resultString;
  Map _resultDict = {
    "label": "None",
    "confidences": [
      {"label": "None", "confidence": 0.0},
      {"label": "None", "confidence": 0.0},
      {"label": "None", "confidence": 0.0}
    ]
  };
  File? imageURI; // Show on image widget on app
  Uint8List? imgBytes; // Store img to be sent for api inference
  bool isClassifying = false;

  String parseResultsIntoString(Map results) {
    return """
    ${results['confidences'][0]['label']} - ${(results['confidences'][0]['confidence'] * 100.0).toStringAsFixed(2)}% \n
    ${results['confidences'][1]['label']} - ${(results['confidences'][1]['confidence'] * 100.0).toStringAsFixed(2)}% \n
    ${results['confidences'][2]['label']} - ${(results['confidences'][2]['confidence'] * 100.0).toStringAsFixed(2)}% """;
  }

  Widget buildPercentIndicator(String className, double classConfidence) {
    return LinearPercentIndicator(
      width: 200.0,
      lineHeight: 18.0,
      percent: classConfidence,
      center: Text(
        "${(classConfidence * 100.0).toStringAsFixed(2)} %",
        style: const TextStyle(fontSize: 12.0),
      ),
      trailing: Text(className),
      leading: const Icon(Icons.arrow_forward_ios),
      linearStrokeCap: LinearStrokeCap.roundAll,
      backgroundColor: Colors.grey,
      progressColor: Colors.blue,
      animation: true,
    );
  }

  Widget buildResultsIndicators(Map resultsDict) {
    return Column(
      children: [
        buildPercentIndicator(resultsDict['confidences'][0]['label'],
            (resultsDict['confidences'][0]['confidence'])),
        buildPercentIndicator(resultsDict['confidences'][1]['label'],
            (resultsDict['confidences'][1]['confidence'])),
        buildPercentIndicator(resultsDict['confidences'][2]['label'],
            (resultsDict['confidences'][2]['confidence']))
      ],
    );
  }

  Future<File> cropImage(XFile pickedFile) async {
    // Crop image here
    final File? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      cropStyle: CropStyle.rectangle,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
        // CropAspectRatioPreset.ratio3x2,
        // CropAspectRatioPreset.original,
        // CropAspectRatioPreset.ratio4x3,
        // CropAspectRatioPreset.ratio16x9
      ],
      androidUiSettings: AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false),
      iosUiSettings: const IOSUiSettings(
        minimumAspectRatio: 1.0,
      ),
    );

    return croppedFile!;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> imageSliders = imgList
        .map((item) => Container(
              margin: const EdgeInsets.all(5.0),
              child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                  child: Stack(
                    children: <Widget>[
                      GestureDetector(
                          onTap: () async {
                            context.loaderOverlay.show();

                            String imgUrl = imgList[imgList.indexOf(item)];

                            final imgFile = await getImage(imgUrl);
                            setState(() {
                              imageURI = imgFile;
                              _btnController.reset();
                            });

                            context.loaderOverlay.hide();

                            print("Tapped on image ${imgList.indexOf(item)}");
                          },
                          child: CachedNetworkImage(
                            imageUrl: item,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          )),
                      // child: Image.network(item, fit: BoxFit.cover)),
                      Positioned(
                        bottom: 0.0,
                        left: 0.0,
                        right: 0.0,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(200, 0, 0, 0),
                                Color.fromARGB(0, 0, 0, 0)
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10.0, horizontal: 20.0),
                          child: Text(
                            'GT: ${imgList[imgList.indexOf(item)].split('/').reversed.elementAt(1)}', // get the class name from url
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
            ))
        .toList();

    return LoaderOverlay(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                imageURI == null
                    ? const Text(
                        'Select an image by pressing the camera icon and I will tell you my',
                        textAlign: TextAlign.center,
                      )
                    : Image.file(imageURI!, height: 300, fit: BoxFit.cover),
                const SizedBox(
                  height: 10,
                ),
                Text("Top 3 predictions",
                    style: Theme.of(context).textTheme.headline6),
                const SizedBox(height: 20),
                buildResultsIndicators(_resultDict),
                const SizedBox(
                  height: 10,
                ),
                RoundedLoadingButton(
                  width: MediaQuery.of(context).size.width,
                  successColor: Colors.green,
                  resetAfterDuration: true,
                  resetDuration: const Duration(seconds: 10),
                  child: const Text('Classify!',
                      style: TextStyle(color: Colors.white)),
                  controller: _btnController,
                  onPressed: isClassifying || imageURI == null
                      ? null // null value disables the button
                      : () async {
                          setState(() {
                            isClassifying = true;
                          });

                          imgBytes = imageURI!.readAsBytesSync();
                          String base64Image = "data:image/png;base64," +
                              base64Encode(imgBytes!);

                          try {
                            final result = await classifyRiceImage(base64Image);

                            setState(() {
                              _resultString = parseResultsIntoString(result);
                              _resultDict = result;
                            });
                            _btnController.success();
                          } catch (e) {
                            _btnController.error();
                          }
                          isClassifying = false;
                        },
                ),
                CarouselSlider(
                  options: CarouselOptions(
                    // height: 400,
                    autoPlay: true,
                    aspectRatio: 2.5,
                    viewportFraction: 0.45,
                    enlargeCenterPage: true,
                    enlargeStrategy: CenterPageEnlargeStrategy.height,
                  ),
                  items: imageSliders,
                )
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet<void>(
                context: context,
                builder: (BuildContext context) {
                  return Container(
                      height: 120,
                      child: ListView(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera),
                            title: const Text("Camera"),
                            onTap: () async {
                              final XFile? pickedFile = await ImagePicker()
                                  .pickImage(source: ImageSource.camera);

                              if (pickedFile != null) {
                                // Clear result of previous inference as soon as new image is selected
                                setState(() {
                                  _resultString = "";
                                  _resultDict = {
                                    "label": "None",
                                    "confidences": [
                                      {"label": "None", "confidence": 0.0},
                                      {"label": "None", "confidence": 0.0},
                                      {"label": "None", "confidence": 0.0}
                                    ]
                                  };
                                });

                                File croppedFile = await cropImage(pickedFile);

                                final imgFile = File(croppedFile.path);

                                setState(() {
                                  imageURI = imgFile;
                                  _btnController.reset();
                                  isClassifying = false;
                                });
                                Navigator.pop(context);
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.image),
                            title: const Text("Gallery"),
                            onTap: () async {
                              final XFile? pickedFile = await ImagePicker()
                                  .pickImage(source: ImageSource.gallery);

                              if (pickedFile != null) {
                                // Clear result of previous inference as soon as new image is selected
                                setState(() {
                                  _resultString = "";
                                  _resultDict = {
                                    "label": "None",
                                    "confidences": [
                                      {"label": "None", "confidence": 0.0},
                                      {"label": "None", "confidence": 0.0},
                                      {"label": "None", "confidence": 0.0}
                                    ]
                                  };
                                });

                                File croppedFile = await cropImage(pickedFile);
                                final imgFile = File(croppedFile.path);

                                setState(() {
                                  imageURI = imgFile;
                                  _btnController.reset();
                                  isClassifying = false;
                                });
                                Navigator.pop(context);
                              }
                            },
                          )
                        ],
                      ));
                });
          },
          child: const Icon(Icons.camera),
        ),
      ),
    );
  }
}
