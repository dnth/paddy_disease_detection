import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:empty_widget/empty_widget.dart';

Widget buildPercentIndicator(String className, double classConfidence) {
  return LinearPercentIndicator(
    width: 300.0,
    lineHeight: 18.0,
    percent: classConfidence,
    center: Text(
      "${(classConfidence * 100.0).toStringAsFixed(2)} %",
      style: const TextStyle(fontSize: 12.0),
    ),
    trailing: Text(className),
    leading: const Icon(Icons.arrow_forward_ios),
    // linearStrokeCap: LinearStrokeCap.roundAll,
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

Widget buildEmptyWidget() {
  return SizedBox(
    height: 200,
    child: EmptyWidget(
      image: null,
      packageImage: PackageImage.Image_3,
      title: 'No image',
      // subTitle: 'Select an image or upload your own',
      titleTextStyle: const TextStyle(
        fontSize: 15,
        color: Color(0xff9da9c7),
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xffabb8d6),
      ),
    ),
  );
}

Widget buildTextHeading(String text, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(text, style: Theme.of(context).textTheme.headline6),
  );
}
