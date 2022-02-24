import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets.dart';
import 'utils.dart';

final List<String> imgList = [
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/blast/IMG_0448.jpg?raw=true',
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/blast/IMG_0546.jpg?raw=true',
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/blight/IMG_0936.jpg?raw=true',
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/blight/IMG_0834.jpg?raw=true',
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/tungro/IMG_0399.jpg?raw=true',
  'https://github.com/dnth/paddy_disease_detection/blob/main/classification_dataset/training/tungro/IMG_0823.jpg?raw=true',
];

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
  File? imageFile; // A variable to show image widget on app
  Uint8List? imgBytes; // A variable to store img to be sent for api inference

  Map _resultDict = {
    "label": "None",
    "confidences": [
      {"label": "None", "confidence": 0.0},
      {"label": "None", "confidence": 0.0},
      {"label": "None", "confidence": 0.0}
    ]
  };

  final RoundedLoadingButtonController _btnController =
      RoundedLoadingButtonController();

  clearInferenceResults() {
    _resultDict = {
      "label": "None",
      "confidences": [
        {"label": "None", "confidence": 0.0},
        {"label": "None", "confidence": 0.0},
        {"label": "None", "confidence": 0.0}
      ]
    };
  }

  ListTile btmSheetListTile(String text, IconData icon) {
    XFile? pickedFile;
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: () async {
        if (icon == Icons.camera) {
          pickedFile =
              await ImagePicker().pickImage(source: ImageSource.camera);
        } else {
          pickedFile =
              await ImagePicker().pickImage(source: ImageSource.gallery);
        }

        if (pickedFile != null) {
          // Clear result of previous inference as soon as new image is selected
          setState(() {
            clearInferenceResults();
          });

          File croppedFile = await cropImage(pickedFile!);
          final imgFile = File(croppedFile.path);

          setState(() {
            imageFile = imgFile;
            _btnController.stop();
          });
          Navigator.pop(context);
        }
      },
    );
  }

  Widget buildModalBtmSheetItems() {
    return SizedBox(
      height: 120,
      child: ListView(
        children: [
          btmSheetListTile("Camera", Icons.camera),
          btmSheetListTile("Gallery", Icons.image),
        ],
      ),
    );
  }

  Widget buildCarouselItems(item) {
    return Container(
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
                  imageFile = imgFile;
                  _btnController.stop();
                  clearInferenceResults();
                });
                context.loaderOverlay.hide();
              },
              child: CachedNetworkImage(
                imageUrl: item,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> imageSliders =
        imgList.map((item) => buildCarouselItems(item)).toList();

    return LoaderOverlay(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              imageFile == null
                  ? buildEmptyWidget()
                  : Image.file(imageFile!, height: 200, fit: BoxFit.cover),
              buildTextHeading("Top 3 predictions", context),
              buildResultsIndicators(_resultDict),
              buildTextHeading("Samples", context),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CarouselSlider(
                  options: CarouselOptions(
                    height: 200,
                    autoPlay: true,
                    // aspectRatio: 2.5,
                    viewportFraction: 0.35,
                    enlargeCenterPage: true,
                    enlargeStrategy: CenterPageEnlargeStrategy.height,
                  ),
                  items: imageSliders,
                ),
              ),
              RoundedLoadingButton(
                width: MediaQuery.of(context).size.width * 0.5,
                color: Colors.blue,
                successColor: Colors.green,
                child: const Text('Classify!',
                    style: TextStyle(color: Colors.white)),
                controller: _btnController,
                onPressed: imageFile == null
                    ? null // null value disables the button
                    : () async {
                        imgBytes = imageFile!.readAsBytesSync();
                        String base64Image =
                            "data:image/png;base64," + base64Encode(imgBytes!);
                        try {
                          final result = await classifyRiceImage(base64Image);
                          setState(() {
                            _resultDict = result;
                          });
                          _btnController.success();
                        } catch (e) {
                          _btnController.error();
                        }
                      },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.camera),
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              builder: (BuildContext context) {
                return buildModalBtmSheetItems();
              },
            );
          },
        ),
      ),
    );
  }
}
