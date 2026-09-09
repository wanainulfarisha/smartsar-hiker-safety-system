import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/login_page.dart';

class AuthorityPage extends StatefulWidget {
  const AuthorityPage({super.key});

  @override
  State<AuthorityPage> createState() => _AuthorityPageState();
}

class _AuthorityPageState extends State<AuthorityPage> {
  final TextEditingController searchController = TextEditingController();

  StreamSubscription? sosSubscription;
  Timer? warningTimer;
  final Set<String> alertedSosIds = {};

  @override
  void initState() {
    super.initState();

    _listenForSosAlerts();

    warningTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    sosSubscription?.cancel();
    warningTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  String formatTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} '
          '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'No timestamp';
  }

  bool isHikerWarning(dynamic timestamp) {
    if (timestamp is! Timestamp) return false;

    final lastScan = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastScan);

    return difference.inMinutes >= 10; // Change warning delay time here
  }

  void _listenForSosAlerts() {
    sosSubscription = FirebaseFirestore.instance
        .collection('sos_alerts')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        if (!alertedSosIds.contains(doc.id)) {
          alertedSosIds.add(doc.id);

          final data = doc.data();

          _showAdminAlert(
            title: '🚨 SOS ALERT',
            message:
                'Name: ${data['name'] ?? '-'}\n'
                'Phone: ${data['phone_number'] ?? '-'}\n'
                'Message: ${data['message'] ?? '-'}\n'
                'Lat: ${data['lat']?.toStringAsFixed(6) ?? '-'}\n'
                'Lng: ${data['lng']?.toStringAsFixed(6) ?? '-'}\n'
                'Altitude: ${data['altitude']?.toStringAsFixed(2) ?? '-'} m',
          );

          break;
        }
      }
    });
  }

  void _showAdminAlert({
    required String title,
    required String message,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> filterDocs(List<QueryDocumentSnapshot> docs) {
    final searchText = searchController.text.toLowerCase().trim();

    if (searchText.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final combined = data.values.join(' ').toLowerCase();
      return combined.contains(searchText);
    }).toList();
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              title: 'Active SOS',
              icon: Icons.sos,
              color: Colors.red,
              collection: 'sos_alerts',
              field: 'status',
              value: 'active',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('journeys').snapshots(),
              builder: (context, snapshot) {
                int warningCount = 0;

                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    final status = data['status'] ?? 'active';

                    if (status != 'completed' &&
                        isHikerWarning(data['last_scan_time'])) {
                      warningCount++;
                    }
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$warningCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text(
                        'Warnings',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              title: 'Active',
              icon: Icons.hiking_rounded,
              color: Colors.brown,
              collection: 'journeys',
              field: 'status',
              value: 'active',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required IconData icon,
    required Color color,
    required String collection,
    required String field,
    required String value,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(field, isEqualTo: value)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: searchController,
        onChanged: (_) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Search email, username, status, checkpoint...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cream = Color(0xFFF6F1E9);
    const Color darkGreen = Color(0xFF355E3B);
    const Color red = Color(0xFFB85C5C);
    const Color brown = Color(0xFFA67C52);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: cream,
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          centerTitle: true,
          backgroundColor: cream,
          foregroundColor: darkGreen,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();

                if (!context.mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: darkGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: darkGreen,
            tabs: [
              Tab(text: 'SOS'),
              Tab(text: 'Journeys'),
              Tab(text: 'Logs'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSummaryCards(),
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sos_alerts')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Error loading SOS alerts'),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = filterDocs(snapshot.data!.docs);

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No matching SOS alerts'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: red,
                                child: Icon(
                                  Icons.sos,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                data['message'] ?? 'SOS Alert',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Name: ${data['name'] ?? '-'}\n'
                                'Phone: ${data['phone_number'] ?? '-'}\n'
                                'Status: ${data['status'] ?? 'active'}\n'
                                'Lat: ${data['lat']?.toStringAsFixed(6) ?? '-'}\n'
                                'Lng: ${data['lng']?.toStringAsFixed(6) ?? '-'}\n'
                                'Altitude: ${data['altitude']?.toStringAsFixed(2) ?? '-'} m\n'
                                'Time: ${formatTime(data['timestamp'])}',
                              ),
                              trailing: TextButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('sos_alerts')
                                      .doc(doc.id)
                                      .update({
                                    'status': 'resolved',
                                  });
                                },
                                child: const Text('Resolve'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('journeys')
                        .orderBy(
                          'last_scan_time',
                          descending: true,
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Error loading journeys'),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = filterDocs(snapshot.data!.docs);

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No matching journeys'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;

                          final status = data['status'] ?? 'active';

                          final int scanned = data['scanned_count'] ?? 0;
                          final int missed = data['missed_count'] ?? 0;
                          final int total = data['total_checkpoints'] ?? 5;
                          final int processed = scanned + missed;

                          final warning = status != 'completed' &&
                              isHikerWarning(data['last_scan_time']);

                          final Color statusColor = warning
                              ? red
                              : status == 'completed'
                                  ? darkGreen
                                  : brown;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: statusColor,
                                child: const Icon(
                                  Icons.hiking_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                data['name'] ?? data['email'] ?? 'Unknown hiker',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Phone: ${data['phone_number'] ?? '-'}\n'
                                'Latest checkpoint: ${data['latest_checkpoint'] ?? '-'}\n'
                                'Progress: $processed/$total\n'
                                'Scanned: $scanned\n'
                                'Missed: $missed\n'
                                'Status: ${warning ? 'WARNING' : status}\n'
                                'Lat: ${data['lat']?.toStringAsFixed(6) ?? '-'}\n'
                                'Lng: ${data['lng']?.toStringAsFixed(6) ?? '-'}\n'
                                'Altitude: ${data['altitude']?.toStringAsFixed(2) ?? '-'} m\n'
                                'Last scan: ${formatTime(data['last_scan_time'])}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('checkpoint_logs')
                        .orderBy(
                          'timestamp',
                          descending: true,
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Error loading checkpoint logs'),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = filterDocs(snapshot.data!.docs);

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No matching checkpoint logs'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: darkGreen,
                                child: Icon(
                                  Icons.qr_code,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                data['checkpoint_name'] ??
                                    'Unknown checkpoint',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Name: ${data['name'] ?? '-'}\n'
                                'Phone: ${data['phone_number'] ?? '-'}\n'
                                'Lat: ${data['lat']?.toStringAsFixed(6) ?? '-'}\n'
                                'Lng: ${data['lng']?.toStringAsFixed(6) ?? '-'}\n'
                                'Altitude: ${data['altitude']?.toStringAsFixed(2) ?? '-'} m\n'
                                'Time: ${formatTime(data['timestamp'])}',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}