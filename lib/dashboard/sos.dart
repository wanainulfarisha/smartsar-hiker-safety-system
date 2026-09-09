import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/offline_sync_service.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final TextEditingController messageController = TextEditingController();

  Future<String> sendSOS() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return 'Unable to send SOS because no user is logged in.';
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );

  final double latitude = position.latitude;
  final double longitude = position.longitude;
  final double altitude = position.altitude;
  final message = messageController.text.trim();

  String name = user.displayName ?? 'Unknown';
  String phoneNumber = '-';

  try {
    final userDocument = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDocument.exists) {
      final userData = userDocument.data();

      name = userData?['name'] ??
          userData?['username'] ??
          user.displayName ??
          'Unknown';

      phoneNumber = userData?['phone_number'] ??
          userData?['phone'] ??
          '-';
    }
  } catch (e) {
    debugPrint('Unable to load user details: $e');
  }

  final data = {
    'collection': 'sos_alerts',
    'user_id': user.uid,
    'name': name,
    'phone_number': phoneNumber,
    'email': user.email ?? '-',
    'message': message.isEmpty
        ? 'Emergency SOS alert sent'
        : message,
    'lat': latitude,
    'lng': longitude,
    'altitude': altitude,
    'status': 'active',
    'timestamp': Timestamp.now(),
  };

  try {
    final online = await OfflineSyncService.hasInternet();

    if (online) {
      final firebaseData = Map<String, dynamic>.from(data);
      firebaseData.remove('collection');

      await FirebaseFirestore.instance
          .collection('sos_alerts')
          .add(firebaseData);

      messageController.clear();
      return 'SOS alert sent successfully to Firebase.';
    } else {
      await OfflineSyncService.saveOfflineData(data);

      messageController.clear();
      return 'No internet. SOS saved locally and will sync automatically later.';
    }
  } catch (e) {
    await OfflineSyncService.saveOfflineData(data);

    messageController.clear();
    return 'No internet. SOS saved locally and will sync automatically later.';
  }
}

  void confirmSOS() {
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send SOS Alert?'),
        content: const Text(
          'This will notify the park authority that you need emergency assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB85C5C),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              final statusMessage = await sendSOS();

              if (!mounted) return;

              if (!parentContext.mounted) return;

              showDialog(
                context: parentContext,
                builder: (_) => AlertDialog(
                  title: const Text('SOS Status'),
                  content: Text(statusMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(parentContext),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cream = Color(0xFFF6F1E9);
    const Color darkGreen = Color(0xFF355E3B);
    const Color red = Color(0xFFB85C5C);
    const Color brown = Color(0xFFA67C52);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('SOS Emergency'),
        centerTitle: true,
        backgroundColor: cream,
        foregroundColor: darkGreen,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 15),

            const Icon(
              Icons.warning_amber_rounded,
              size: 85,
              color: red,
            ),

            const SizedBox(height: 16),

            const Text(
              'Emergency Help',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Describe your situation and send SOS to the park authority.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: brown,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'SOS Message',
                hintText: 'e.g. I am lost near Checkpoint B',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: darkGreen,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            GestureDetector(
              onTap: confirmSOS,
              child: Container(
                width: 170,
                height: 170,
                margin: const EdgeInsets.symmetric(horizontal: 70),
                decoration: BoxDecoration(
                  color: red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: red.withValues(alpha: 0.35),
                      blurRadius: 25,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: darkGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your SOS alert will be recorded for authority monitoring. If offline, it will sync when internet is available.',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}