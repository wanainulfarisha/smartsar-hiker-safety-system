import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/login_page.dart';
import 'offline_map.dart';
import 'sos.dart';
import 'start_journey.dart';
import 'authority_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> logout(BuildContext context) async {
      await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? 'User';
    final bool isAuthority = [
      'authority@gmail.com',
      'parkadmin@gmail.com',
    ].contains(user?.email);

    const Color backgroundColor = Color(0xFFFFF5E8);
    const Color darkGreen = Color(0xFF355E3B);
    const Color mediumGreen = Color(0xFF6B8E6E);
    const Color beige = Color(0xFFD9C3A5);
    const Color red = Color(0xFFB85C5C);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Hiker Dashboard',
          style: TextStyle(
            color: darkGreen,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: darkGreen),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready for your hike?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hello, $username 👋',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Track checkpoints, use offline map, and send SOS instantly when needed.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _dashboardCard(
            context: context,
            title: 'Start Journey',
            subtitle: 'Open live map and checkpoints',
            icon: Icons.map_rounded,
            color: mediumGreen,
            textColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StartJourneyPage()),
              );
            },
          ),

          const SizedBox(height: 18),

          _dashboardCard(
            context: context,
            title: 'Offline Mode',
            subtitle: 'View map without internet',
            icon: Icons.explore_off_rounded,
            color: beige,
            textColor: Colors.black87,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflineMapPage()),
              );
            },
          ),

          const SizedBox(height: 18),

          _dashboardCard(
            context: context,
            title: 'SOS',
            subtitle: 'Alert authority for emergency help',
            icon: Icons.sos_rounded,
            color: red,
            textColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SosPage()),
              );
            },
          ),

          const SizedBox(height: 18),

          //_dashboardCard(
            //context: context,
            //title: 'Scan History',
            //subtitle: 'View completed checkpoint logs',
            //icon: Icons.history_rounded,
            //color: brown,
            //textColor: Colors.white,
            //onTap: () {
              //Navigator.push(
                //context,
                //MaterialPageRoute(builder: (_) => const HistoryPage()),
              //);
            //},
          //),

if (isAuthority) ...[
  const SizedBox(height: 18),
  _dashboardCard(
    context: context,
    title: 'Authority',
    subtitle: 'Monitor SOS alerts and checkpoint logs',
    icon: Icons.admin_panel_settings_rounded,
    color: const Color(0xFF4F6F52),
    textColor: Colors.white,
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthorityPage()),
      );
    },
  ),
],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
    //    height: 130,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              child: Icon(
                icon,
                color: textColor,
                size: 36,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textColor,
              size: 42,
            ),
          ],
        ),
      ),
    );
  }
}