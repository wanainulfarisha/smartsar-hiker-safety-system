import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/offline_sync_service.dart';
import '../qr_scanner_page.dart';
import 'completed_page.dart';

class StartJourneyPage extends StatefulWidget {
  const StartJourneyPage({super.key});

  @override
  State<StartJourneyPage> createState() => _StartJourneyPageState();
}

class _StartJourneyPageState extends State<StartJourneyPage> {
  GoogleMapController? mapController;

  final LatLng _initialCenter = const LatLng(5.1475, 100.4945);

  final Map<String, LatLng> checkpointLocations = {
    'Entrance': const LatLng(5.144538, 100.491470),
    'Checkpoint A': const LatLng(5.145877, 100.495890),
    'Checkpoint B': const LatLng(5.149154, 100.497220),
    'Checkpoint C': const LatLng(5.149553, 100.490783),
    'Exit': const LatLng(5.144538, 100.491470),
  };

  final Map<String, String> checkpointDescriptions = {
    'Entrance': 'Starting point of the hiking trail.',
    'Checkpoint A': 'First checkpoint. Confirm user has entered the trail.',
    'Checkpoint B': 'Midpoint checkpoint. Useful for monitoring journey progress.',
    'Checkpoint C': 'Final checkpoint before heading to the exit.',
    'Exit': 'End point of the hiking route.',
  };

  final List<String> checkpointOrder = [
    'Entrance',
    'Checkpoint A',
    'Checkpoint B',
    'Checkpoint C',
    'Exit',
  ];

  final Set<String> scannedCheckpoints = {};
  final Set<String> missedCheckpoints = {};
  String fullName = '';
  String phoneNumber = '';

  @override
  void initState() {
    super.initState();
    _loadUserProgress();
    _loadUserDetails();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<Position?> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location service.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to verify checkpoint.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> _startJourneySession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final journeyRef =
        FirebaseFirestore.instance.collection('journeys').doc(user.uid);

    final doc = await journeyRef.get();

    if (!doc.exists || doc.data()?['start_time'] == null) {
      await journeyRef.set({
        'user_id': user.uid,
        'name': fullName,
        'phone_number': phoneNumber,
        'email': user.email ?? '-',
        'start_time': FieldValue.serverTimestamp(),
        'status': 'active',
        'scanned_count': scannedCheckpoints.length,
        'total_checkpoints': checkpointOrder.length,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _loadUserProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('checkpoint_logs')
        .where('user_id', isEqualTo: user.uid)
        .get();

    final loaded = snapshot.docs
        .map((doc) => doc.data()['checkpoint_name'] as String?)
        .whereType<String>()
        .toSet();

    if (!mounted) return;

    setState(() {
      scannedCheckpoints.addAll(loaded);
    });
  }

  Future<void> _loadUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    fullName = data['full_name'] ?? '';
    phoneNumber = data['phone_number'] ?? '';
  }

  List<String> _getSkippedCheckpoints(String currentCheckpoint) {
    final currentIndex = checkpointOrder.indexOf(currentCheckpoint);

    if (currentIndex == -1) {
      return [];
    }

    final skipped = <String>[];

    for (int i = 0; i < currentIndex; i++) {
      final checkpoint = checkpointOrder[i];

      if (!scannedCheckpoints.contains(checkpoint) &&
          !missedCheckpoints.contains(checkpoint)) {
        skipped.add(checkpoint);
      }
    }

    return skipped;
  }

  Future<void> _logCheckpointToFirestore(
    String name,
    double userLat,
    double userLng,
    double altitude,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userProfile = userDoc.data() ?? {};

    final String hikerName =
        userProfile['full_name'] ??
        user.displayName ??
        user.email ??
        'User';

    final String hikerPhone =
        userProfile['phone_number'] ?? '-';

    final data = {
      'collection': 'checkpoint_logs',
      'user_id': user.uid,
      'name': hikerName,
      'phone_number': hikerPhone,
      'email': user.email ?? '-',
      'checkpoint_name': name,
      'lat': userLat,
      'lng': userLng,
      'altitude': altitude,
      'timestamp': Timestamp.now(),
    };

    try {
      final online = await OfflineSyncService.hasInternet();

      if (online) {
        final firebaseData = Map<String, dynamic>.from(data);
        firebaseData.remove('collection');

        await FirebaseFirestore.instance
            .collection('checkpoint_logs')
            .add(firebaseData);
      } else {
        await OfflineSyncService.saveOfflineData(data);
      }
    } catch (e) {
      await OfflineSyncService.saveOfflineData(data);
    }
  }

  Future<void> _updateJourneyStatus(
    String checkpoint,
    double userLat,
    double userLng,
    double altitude,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool completed = checkpoint == 'Exit';

    await FirebaseFirestore.instance
        .collection('journeys')
        .doc(user.uid)
        .set({
      'user_id': user.uid,
      'name': fullName,
      'phone_number': phoneNumber,
      'email': user.email ?? '-',
      'latest_checkpoint': checkpoint,
      'lat': userLat,
      'lng': userLng,
      'altitude': altitude,
      'scanned_count': scannedCheckpoints.length,
      'missed_checkpoints': missedCheckpoints.toList(),
      'missed_count': missedCheckpoints.length,
      'total_checkpoints': checkpointOrder.length,
      'status': completed ? 'completed' : 'active',
      'last_scan_time': FieldValue.serverTimestamp(),
      if (completed) 'completed_time': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> _getJourneyDurationText() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Duration unavailable';

    final doc = await FirebaseFirestore.instance
        .collection('journeys')
        .doc(user.uid)
        .get();

    final data = doc.data();

    final startTimestamp = data?['start_time'];
    final completedTimestamp = data?['completed_time'];

    if (startTimestamp is! Timestamp || completedTimestamp is! Timestamp) {
      return 'Duration unavailable';
    }

    final startTime = startTimestamp.toDate();
    final completedTime = completedTimestamp.toDate();

    final duration = completedTime.difference(startTime);

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  Future<void> _showCheckpointInfo(String name, double lat, double lng) async {
    final currentIndex = checkpointOrder.indexOf(name);

    final nextCheckpoint = currentIndex + 1 < checkpointOrder.length
        ? checkpointOrder[currentIndex + 1]
        : 'Journey completed';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(name),
        content: Text(
          'Latitude: $lat\n'
          'Longitude: $lng\n\n'
          'Info: ${checkpointDescriptions[name] ?? 'No info available'}\n\n'
          'Next: $nextCheckpoint',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return checkpointLocations.entries.map((entry) {
      final name = entry.key;
      final position = entry.value;
      final isScanned = scannedCheckpoints.contains(name);

      return Marker(
        markerId: MarkerId(name),
        position: position,
        icon: isScanned
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
            : BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: name,
          snippet: isScanned ? 'Completed' : 'Not scanned',
        ),
      );
    }).toSet();
  }

  Future<void> _scanCheckpoint() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );

    if (result == null) return;

    final String name = result['name'];
    final double checkpointLat = result['lat'];
    final double checkpointLng = result['lng'];

    if (scannedCheckpoints.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name already scanned')),
      );
      return;
    }

    final position = await _getCurrentPosition();
    if (position == null) return;

    final double userLat = position.latitude;
    final double userLng = position.longitude;
    final double altitude = position.altitude;
    final skipped = _getSkippedCheckpoints(name);

    final distanceInMeters = Geolocator.distanceBetween(
      userLat,
      userLng,
      checkpointLat,
      checkpointLng,
    );

    if (distanceInMeters > 3000000000000) { //to change distance to scan qr
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are not near $name. Scan rejected. Distance: ${distanceInMeters.toStringAsFixed(1)} m',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      scannedCheckpoints.add(name);
      missedCheckpoints.addAll(skipped);
    });

    setState(() {
      scannedCheckpoints.add(name);
      missedCheckpoints.addAll(skipped);
    });

    if (skipped.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Missed checkpoint(s): ${skipped.join(', ')}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    if (name == 'Entrance') {
      await _startJourneySession();
    }

    await _logCheckpointToFirestore(
      name,
      userLat,
      userLng,
      altitude,
    );

    await _updateJourneyStatus(
      name,
      userLat,
      userLng,
      altitude,
    );

    if (!mounted) return;

    await _showCheckpointInfo(name, checkpointLat, checkpointLng);

    if (name == 'Exit') {
      if (!mounted) return;

      final durationText = await _getJourneyDurationText();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompletedPage(durationText: durationText),
        ),
      );
    }
  }

  Widget buildJourneyTimeText(Color darkGreen) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Text(
        'Elapsed time: 0 min',
        style: TextStyle(color: darkGreen, fontSize: 13),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('journeys')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text(
            'Elapsed time: 0 min',
            style: TextStyle(color: darkGreen, fontSize: 13),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        final startTimestamp = data?['start_time'];
        final completedTimestamp = data?['completed_time'];

        if (startTimestamp is! Timestamp) {
          return Text(
            'Elapsed time: 0 min',
            style: TextStyle(color: darkGreen, fontSize: 13),
          );
        }

        final startTime = startTimestamp.toDate();

        final DateTime endTime = completedTimestamp is Timestamp
            ? completedTimestamp.toDate()
            : DateTime.now();

        final duration = endTime.difference(startTime);
        final minutes = duration.inMinutes;

        return Text(
          completedTimestamp is Timestamp
              ? 'Completed in: $minutes min'
              : 'Elapsed time: $minutes min',
          style: TextStyle(color: darkGreen, fontSize: 13),
        );
      },
    );
  }

  Future<void> _resetJourney() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Journey'),
        content: const Text(
          'Are you sure you want to reset your journey? All progress will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final logs = await FirebaseFirestore.instance
          .collection('checkpoint_logs')
          .where('user_id', isEqualTo: user.uid)
          .get();

      for (final doc in logs.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('journeys')
          .doc(user.uid)
          .delete();

      if (!mounted) return;

      setState(() {
        scannedCheckpoints.clear();
        missedCheckpoints.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journey has been reset successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color cream = Color(0xFFF6F1E9);
    const Color darkGreen = Color(0xFF355E3B);

    final int processedCount =
        scannedCheckpoints.length + missedCheckpoints.length;

    final double progress =
        processedCount / checkpointOrder.length;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Start Journey'),
        centerTitle: true,
        backgroundColor: cream,
        foregroundColor: darkGreen,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _resetJourney,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            padding: const EdgeInsets.only(bottom: 80),
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialCenter,
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _buildMarkers(),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    'Journey Progress: $processedCount/${checkpointOrder.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  buildJourneyTimeText(darkGreen),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(darkGreen),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 70,
              decoration: const BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -25),
                  child: GestureDetector(
                    onTap: _scanCheckpoint,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: darkGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cream,
                          width: 6,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}