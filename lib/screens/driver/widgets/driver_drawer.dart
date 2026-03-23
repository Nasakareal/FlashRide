import 'package:flutter/material.dart';

import '../profile_screen.dart';
import '../past_rides_screen.dart';

class DriverDrawer extends StatelessWidget {
  final Color brandColor;
  final Map<String, dynamic>? profileData;
  final VoidCallback onLogout;

  const DriverDrawer({
    super.key,
    required this.brandColor,
    required this.profileData,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final name = profileData != null ? '${profileData!['name']}' : null;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: brandColor),
            child: Text(
              name != null ? 'Bienvenido, $name' : 'Menú Conductor',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Mi perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Viajes pendientes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/rides/pending');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Viajes pasados'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PastRidesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Soporte'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver/support');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
