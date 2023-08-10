import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfviewer/secondpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() => runApp(MaterialApp(
  title: 'Syncfusion PDF Viewer Demo',
  home: HomePage(),
));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _documentBytes;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;


  @override
  void initState() {
    _pdfViewerController = PdfViewerController();
    getPdfBytes();
    _loadSavedAnnotations();
    super.initState();
  }

  Future<void> _loadSavedAnnotations() async {
    final annotations = await _loadAnnotations();
    print('Loaded ${annotations.length} saved annotations.');

    annotations.forEach((annotation) {
      print('Applying annotation: ${annotation.annotationType}');
      final annotationJson = annotation.toJson();
      print('Annotation JSON: $annotationJson');
      // Apply the annotation
      addAnnotation(annotation);
     // _drawAnnotation(annotation.annotationType, annotation.selectedText);
    });
  }


  void addAnnotation(AnnotationData annotation) {

    print('Annotation added: ${annotation.annotationType}');
  }

  Future<List> _loadAnnotations() async {
    final prefs = await SharedPreferences.getInstance();
    final annotationList = prefs.getStringList('annotations') ?? [];
    return annotationList.map((json) {
      final Map<String, dynamic> jsonData = jsonDecode(json);
      return AnnotationData.fromJson(jsonData);
    }).toList();
  }

  Future<int> _getLineNumber(PdfPage page, String selectedText) async {
    final document = PdfDocument(inputBytes: _documentBytes);
    final extractor = PdfTextExtractor(document);
    final text = await extractor.extractText();
    final lines = text.split('\n');
    for (int j = 0; j < lines.length; j++) {
      if (lines[j].contains(selectedText)) {
        return j + 1;
      }
    }
    return -1;
  }
  void getPdfBytes() async {
    _documentBytes = await http.readBytes(Uri.parse(
        'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf'));
    setState(() {});
  }

  Widget _addAnnotation(String? annotationType, String? selectedText) {
    return Container(
      height: 30,
      width: 100,
      color: Colors.white,
      child: RawMaterialButton(
        onPressed: () async {
          _checkAndCloseContextMenu();
          await Clipboard.setData(ClipboardData(text: selectedText!));
          _drawAnnotation(annotationType,selectedText);
        },
        child: Text(
          annotationType!,
          style: TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  OverlayEntry? _overlayEntry;
  Color _contextMenuColor = Colors.white;

  void _showContextMenu(
      BuildContext context, PdfTextSelectionChangedDetails? details) {
    final RenderBox? renderBoxContainer =
    context.findRenderObject()! as RenderBox;
    if (renderBoxContainer != null) {
      final double _kContextMenuHeight = 90;
      final double _kContextMenuWidth = 100;
      final double _kHeight = 18;

      //find constraints X AND Y
      final Offset containerOffset =
      renderBoxContainer.localToGlobal(renderBoxContainer.paintBounds.topLeft);
      if (details != null &&
          containerOffset.dy < details.globalSelectedRegion!.topLeft.dy ||
          (containerOffset.dy <
              details!.globalSelectedRegion!.center.dy -
                  (_kContextMenuHeight / 2) &&
              details.globalSelectedRegion!.height > _kContextMenuWidth)) {
        double top = 0.0;
        double left = 0.0;
        final Rect globalSelectedRect = details.globalSelectedRegion!;
        if ((globalSelectedRect.top) >
            MediaQuery.of(context).size.height / 2) {
          top = globalSelectedRect.topLeft.dy +
              details.globalSelectedRegion!.height +
              _kHeight;
          left = globalSelectedRect.bottomLeft.dx;
        } else {
          top = globalSelectedRect.height > _kContextMenuWidth
              ? globalSelectedRect.center.dy - (_kContextMenuHeight / 2)
              : globalSelectedRect.topLeft.dy +
              details.globalSelectedRegion!.height +
              _kHeight;
          left = globalSelectedRect.height > _kContextMenuWidth
              ? globalSelectedRect.center.dx - (_kContextMenuWidth / 2)
              : globalSelectedRect.bottomLeft.dx;
        }

        final Offset textStartOffset = details.globalSelectedRegion!.topLeft;
        final Offset textEndOffset = details.globalSelectedRegion!.bottomRight;

        //print X AND Y Coordinates
        print('Selected Text Coordinates:');
        print('Start X: ${textStartOffset.dx}, Y: ${textStartOffset.dy}');
        print('End X: ${textEndOffset.dx}, Y: ${textEndOffset.dy}');

        final OverlayState? _overlayState =
        Overlay.of(context, rootOverlay: true);
        _overlayEntry = OverlayEntry(
          builder: (context) => Positioned(
            top: top,
            left: left,
            child: Container(
              decoration: BoxDecoration(
                color: _contextMenuColor,
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.14),
                    blurRadius: 2,
                    offset: Offset(0, 0),
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.12),
                    blurRadius: 2,
                    offset: Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.2),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              constraints: BoxConstraints.tightFor(
                  width: _kContextMenuWidth, height: _kContextMenuHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _addAnnotation('Highlight', details.selectedText),
                  _addAnnotation('Underline', details.selectedText),
                  _addAnnotation('Strikethrough', details.selectedText),
                ],
              ),
            ),
          ),
        );
        _overlayState?.insert(_overlayEntry!);
      }
    }
  }


  void _checkAndCloseContextMenu() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  void _drawAnnotation(String? annotationType, String selectedText) async {
    print("Drawing annotation of type: $annotationType");
    if (annotationType == null) {
      return;
    }
    final PdfDocument document = PdfDocument(inputBytes: _documentBytes);
    switch (annotationType) {
      case 'Highlight':
        {
          final List<PdfTextLine> selectedTextLines =
          _pdfViewerKey.currentState!.getSelectedTextLines();
          final String text = selectedTextLines
              .map((line) => line.text)
              .join(' ');
          final int selectedPageNumber = selectedTextLines.first.pageNumber + 1;
          final int selectedLineNumber =
          await _getLineNumber(document.pages[selectedPageNumber - 1], text);

          print('Selected Text: $selectedText');
          print('Page Number: $selectedPageNumber');
          print('Line Number: $selectedLineNumber');

          selectedTextLines.forEach((pdfTextLine) {
            final PdfPage _page = document.pages[pdfTextLine.pageNumber];
            final PdfRectangleAnnotation rectangleAnnotation =
            PdfRectangleAnnotation(
              pdfTextLine.bounds,
              'Highlight Annotation',
              author: 'Syncfusion',
              color: PdfColor.fromCMYK(0, 0, 255, 0),
              innerColor: PdfColor.fromCMYK(0, 0, 255, 0),
              opacity: 0.3,
            );
            _page.annotations.add(rectangleAnnotation);
            _page.annotations.flattenAllAnnotations();
          });

          final annotationData = AnnotationData(
            startX: selectedTextLines.first.bounds.left,
            startY: selectedTextLines.first.bounds.top,
            endX: selectedTextLines.last.bounds.right,
            endY: selectedTextLines.last.bounds.bottom,
            pageNumber: selectedPageNumber,
            lineNumber: selectedLineNumber,
            selectedText: selectedText,
            annotationType: annotationType,
          );

          final annotationJson = annotationData.toJson();
          print('Annotation JSON: $annotationJson');
          final prefs = await SharedPreferences.getInstance();
          final annotationList = prefs.getStringList('annotations') ?? [];

          // Check if an annotation with the same properties already exists
          final annotationExists = annotationList.any((json) {
            final Map<String, dynamic> jsonData = jsonDecode(json);
            final existingAnnotation = AnnotationData.fromJson(jsonData);
            return existingAnnotation.pageNumber == annotationData.pageNumber &&
                existingAnnotation.lineNumber == annotationData.lineNumber &&
                existingAnnotation.startX == annotationData.startX &&
                existingAnnotation.startY == annotationData.startY &&
                existingAnnotation.endX == annotationData.endX &&
                existingAnnotation.endY == annotationData.endY;
          });
          // Only add the annotation if it doesn't already exist
          if (annotationExists) {
            print('Annotation already exists at the specified coordinates.');
          } else {
            annotationList.add(jsonEncode(annotationData.toJson()));
            await prefs.setStringList('annotations', annotationList);
          }
        }
        break;
      case 'Underline':
        {
          _pdfViewerKey.currentState!
              .getSelectedTextLines()
              .forEach((pdfTextLine) {
            final PdfPage _page = document.pages[pdfTextLine.pageNumber];
            final PdfLineAnnotation lineAnnotation = PdfLineAnnotation(
              [
                pdfTextLine.bounds.left.toInt(),
                (document.pages[pdfTextLine.pageNumber].size.height -
                    pdfTextLine.bounds.bottom)
                    .toInt(),
                pdfTextLine.bounds.right.toInt(),
                (document.pages[pdfTextLine.pageNumber].size.height -
                    pdfTextLine.bounds.bottom)
                    .toInt(),
              ],
              'Underline Annotation',
              author: 'Syncfusion',
              innerColor: PdfColor(0, 255, 0),
              color: PdfColor(8, 0, 5),
            );
            _page.annotations.add(lineAnnotation);
            _page.annotations.flattenAllAnnotations();
          });
        }
        break;
      case 'Strikethrough':
        {
          _pdfViewerKey.currentState!
              .getSelectedTextLines()
              .forEach((pdfTextLine) {
            final PdfPage _page = document.pages[pdfTextLine.pageNumber];
            final PdfLineAnnotation lineAnnotation = PdfLineAnnotation(
              [
                pdfTextLine.bounds.left.toInt(),
                (document.pages[pdfTextLine.pageNumber].size.height -
                    pdfTextLine.bounds.bottom +
                    pdfTextLine.bounds.height / 2)
                    .toInt(),
                pdfTextLine.bounds.right.toInt(),
                (document.pages[pdfTextLine.pageNumber].size.height -
                    pdfTextLine.bounds.bottom +
                    pdfTextLine.bounds.height / 2)
                    .toInt(),
              ],
              'Strikethrough Annotation',
              author: 'Syncfusion',
              innerColor: PdfColor(255, 0, 0),
              color: PdfColor(255, 0, 0),

            );
            _page.annotations.add(lineAnnotation);
            _page.annotations.flattenAllAnnotations();
          });
        }
        break;
    }

    final List<int> bytes = await document.save();
    setState(() {
      _documentBytes = Uint8List.fromList(bytes);
      _pdfViewerController = PdfViewerController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Viewer Demo'),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AnnotationsPage()),
              );
            },
          ),
        ],
      ),
      body: _documentBytes != null
          ? SfPdfViewer.memory(
        _documentBytes!,
        key: _pdfViewerKey,
        controller: _pdfViewerController,
        onTextSelectionChanged:
            (PdfTextSelectionChangedDetails details) {
          if (details.selectedText == null && _overlayEntry != null) {
            _checkAndCloseContextMenu();
          } else if (details.selectedText != null &&
              _overlayEntry == null) {
            _showContextMenu(context, details);
          }
        },
      )
          : Container(),
    );
  }

}
class AnnotationData {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final int pageNumber;
  final int lineNumber;
  final String selectedText;
  final String annotationType;

  AnnotationData({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.pageNumber,
    required this.lineNumber,
    required this.selectedText,
    required this.annotationType,
  });

  Map<String, dynamic> toJson() {
    return {
      'startX': startX,
      'startY': startY,
      'endX': endX,
      'endY': endY,
      'pageNumber': pageNumber,
      'lineNumber': lineNumber,
      'selectedText': selectedText,
      'annotationType': annotationType,
    };
  }

  factory AnnotationData.fromJson(Map<String, dynamic> json) {
    return AnnotationData(
      startX: json['startX'],
      startY: json['startY'],
      endX: json['endX'],
      endY: json['endY'],
      pageNumber: json['pageNumber'],
      lineNumber: json['lineNumber'],
      selectedText: json['selectedText'],
      annotationType: json['annotationType'],
    );
  }
}
