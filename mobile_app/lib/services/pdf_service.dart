import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  Future<void> generateProductCertificate(Map<String, dynamic> productData) async {
    final pdf = pw.Document();
    
    // Extract Data
    final productId = productData['productId'] ?? 'Unknown';
    final manufacturer = productData['manufacturerName'] ?? 'Unknown Manufacturer';
    final hops = productData['hops'] as List<dynamic>;
    
    // Load Fonts or Images if needed (using default for now)
    // final font = await PdfGoogleFonts.nunitoExtraLight();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Digital Product Passport", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.PdfLogo(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Product Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildField("Product ID", productId),
                          _buildField("Manufacturer", manufacturer),
                          _buildField("Current Status", hops.last['role'] == "Manufacturer" ? "Minted" : "In Supply Chain"),
                          _buildField("Verification Date", DateFormat('yyyy-MM-dd').format(DateTime.now())),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // QR Code
                    pw.Container(
                      height: 100,
                      width: 100,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: productId,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Timeline Title
              pw.Text("Supply Chain Journey", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              // Timeline Table
              pw.Table.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                },
                headers: <String>['Date', 'Actor', 'Event', 'Location'],
                data: hops.map((hop) {
                  final timestamp = DateTime.fromMillisecondsSinceEpoch(hop['timestamp'] * 1000);
                  final date = DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
                  final role = hop['role'].toString();
                  final actorName = hop['actorName'] ?? "Unknown";
                  final location = hop['location'].toString();
                  
                  return [date, actorName, role == "Manufacturer" ? "Minted" : "Scanned", location];
                }).toList(),
              ),

              pw.Spacer(),

              // Footer
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.only(top: 20),
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey, width: 0.5))),
                child: pw.Text(
                  "Secured by Ethereum Blockchain • Verified by ProductTrace",
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Open Share/Print Dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Passport-$productId.pdf',
    );
  }

  pw.Widget _buildField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: "$label: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
