import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';  // Import the AnnotationData class from your previous code

class AnnotationsPage extends StatefulWidget {
  @override
  State<AnnotationsPage> createState() => _AnnotationsPageState();
}

class _AnnotationsPageState extends State<AnnotationsPage> {
  bool _ascendingOrder = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Annotations'),
        actions: [
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: () {
              setState(() {
                _ascendingOrder = !_ascendingOrder;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<AnnotationData>>(
        future: _loadAnnotations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('An error occurred'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No annotations available.'));
          } else {
            final annotations = snapshot.data!;
            final sortedAnnotations = List.from(annotations);

            sortedAnnotations.sort((a, b) {
              if (_ascendingOrder) {
                return a.pageNumber.compareTo(b.pageNumber);
              } else {
                return b.pageNumber.compareTo(a.pageNumber);
              }
            });

            if (!_ascendingOrder) {
              sortedAnnotations.sort((a, b) => b.pageNumber.compareTo(a.pageNumber));
            }
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final annotation = _ascendingOrder
                    ? sortedAnnotations[index]
                    : sortedAnnotations.reversed.toList()[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Page ${annotation.pageNumber}, Line ${annotation.lineNumber}', style: TextStyle(fontWeight: FontWeight.bold)),
                            Spacer(),
                            InkWell(
                                onTap: () {
                                  _deleteAnnotation(context, annotation);
                                },
                                child: Icon(Icons.delete)),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Row(
                          children: [
                            Text('Text: '),
                            Container(
                              color: Colors.yellow,
                                child: Text(' ${annotation.selectedText} ',style: TextStyle(fontWeight: FontWeight.bold),)),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Text('Annotation: ${annotation.annotationType}'),
                        SizedBox(height: 8.0),
                        Row(
                          children: [
                            Text('X Axis: ${annotation.startX.toStringAsFixed(2)}'),
                            SizedBox(width: 16.0),
                            Text('Y Axis: ${annotation.startY.toStringAsFixed(2)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteAnnotation(BuildContext context, AnnotationData annotation) async {
    final prefs = await SharedPreferences.getInstance();
    final annotationList = prefs.getStringList('annotations') ?? [];

    // Remove the selected annotation from the list
    annotationList.removeWhere((json) {
      final Map<String, dynamic> jsonData = jsonDecode(json);
      final savedAnnotation = AnnotationData.fromJson(jsonData);
      return savedAnnotation.pageNumber == annotation.pageNumber &&
          savedAnnotation.lineNumber == annotation.lineNumber &&
          savedAnnotation.startX == annotation.startX &&
          savedAnnotation.startY == annotation.startY &&
          savedAnnotation.endX == annotation.endX &&
          savedAnnotation.endY == annotation.endY &&
          savedAnnotation.annotationType == annotation.annotationType;
    });

    // Save the updated annotation list
    await prefs.setStringList('annotations', annotationList);

    // Reload the AnnotationsPage to reflect the updated list
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AnnotationsPage()),
    );
  }

  Future<List<AnnotationData>> _loadAnnotations() async {
    final prefs = await SharedPreferences.getInstance();
    final annotationList = prefs.getStringList('annotations') ?? [];
    return annotationList.map((json) {
      final Map<String, dynamic> jsonData = jsonDecode(json);
      return AnnotationData.fromJson(jsonData);
    }).toList();
  }
}
