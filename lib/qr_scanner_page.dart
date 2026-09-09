import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool isProcessing = false;
  String lastScanned = "No QR detected yet";

  bool _isValidCheckpointData(dynamic data) {
    return data is Map &&
        data['name'] != null &&
        data['lat'] != null &&
        data['lng'] != null;
  }

  void _handleScan(String rawValue) {
    if (isProcessing) return;

    final cleanedValue = rawValue
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();

    setState(() {
      lastScanned = cleanedValue;
    });

    try {
      final data = jsonDecode(cleanedValue);

      if (!_isValidCheckpointData(data)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR detected, but format is incomplete')),
        );
        return;
      }

      isProcessing = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scanned: ${data['name']}")),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pop(context, data);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR JSON format')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Checkpoint'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? rawValue = barcodes.first.rawValue;
                  if (rawValue != null && rawValue.isNotEmpty) {
                    _handleScan(rawValue);
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black12,
              child: SingleChildScrollView(
                child: Text(
                  "Last scanned:\n$lastScanned",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}