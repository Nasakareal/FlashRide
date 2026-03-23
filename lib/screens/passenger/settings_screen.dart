import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;

  bool _notif = true;
  bool _autoCenter = true;
  bool _shareLocation = true;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _notif = p.getBool('settings_notif') ?? true;
    _autoCenter = p.getBool('settings_autocenter') ?? true;
    _shareLocation = p.getBool('settings_share_location') ?? true;

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 6),
                _sectionTitle('Preferencias'),
                SwitchListTile(
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Avisos de viaje, soporte y seguridad'),
                  value: _notif,
                  onChanged: (v) async {
                    setState(() => _notif = v);
                    await _save('settings_notif', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Auto-centrar mapa'),
                  subtitle: const Text(
                      'Centrar automáticamente tu ubicación al abrir'),
                  value: _autoCenter,
                  onChanged: (v) async {
                    setState(() => _autoCenter = v);
                    await _save('settings_autocenter', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Compartir ubicación durante el viaje'),
                  subtitle: const Text('Para seguimiento y soporte'),
                  value: _shareLocation,
                  onChanged: (v) async {
                    setState(() => _shareLocation = v);
                    await _save('settings_share_location', v);
                  },
                ),
                const Divider(),
                _sectionTitle('Cuenta'),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar contraseña'),
                  subtitle:
                      const Text('Se abrirá desde tu pantalla de Seguridad'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Abre "Seguridad" desde el menú para cambiar contraseña.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Acerca de'),
                  subtitle: const Text('FlashRide'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'FlashRide',
                    applicationVersion: '1.0.0',
                    children: const [
                      Text('Ajustes locales guardados en el teléfono.'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}
