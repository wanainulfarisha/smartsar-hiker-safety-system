import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncService {
  static const String offlineKey = 'offline_pending_data';

  // SAVE DATA LOCALLY
  static Future<void> saveOfflineData(
      Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> existing =
        prefs.getStringList(offlineKey) ?? [];

    existing.add(jsonEncode(data));

    await prefs.setStringList(offlineKey, existing);
  }

  // CHECK INTERNET
  static Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // SYNC TO FIREBASE
  static Future<void> syncPendingData() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> existing =
        prefs.getStringList(offlineKey) ?? [];

    if (existing.isEmpty) return;

    final hasConnection = await hasInternet();

    if (!hasConnection) return;

    for (String item in existing) {
      final Map<String, dynamic> data =
          jsonDecode(item);

      final String collection = data['collection'];

      data.remove('collection');

      await FirebaseFirestore.instance
          .collection(collection)
          .add(data);
    }

    await prefs.remove(offlineKey);
  }
}