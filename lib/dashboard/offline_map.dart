import 'package:flutter/material.dart';

class OfflineMapPage extends StatelessWidget {
  const OfflineMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color cream = Color(0xFFF6F1E9);
    const Color darkGreen = Color(0xFF355E3B);
    const Color brown = Color(0xFFA67C52);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Offline Map'),
        centerTitle: true,
        backgroundColor: cream,
        foregroundColor: darkGreen,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt_rounded, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Offline map is available without internet connection.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.asset(
                    'assets/images/offline_map.png',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: darkGreen),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use pinch gestures to zoom and drag to move around the offline map.',
                    style: TextStyle(
                      color: brown,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}