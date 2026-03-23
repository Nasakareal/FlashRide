import 'package:flutter/material.dart';

class PassengerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;

  /// Puede venir _Sug, PlaceSug, Map, etc.
  final List<dynamic> sugs;

  final void Function(String) onChanged;

  /// Recibe el objeto sugerencia completo (lo resuelves en el Home)
  final void Function(dynamic) onPick;

  const PassengerSearchBar({
    super.key,
    required this.controller,
    required this.loading,
    required this.sugs,
    required this.onChanged,
    required this.onPick,
  });

  String _descOf(dynamic s) {
    if (s == null) return '';

    // Soporta _Sug / PlaceSug (con propiedad desc)
    try {
      final d = (s as dynamic).desc;
      if (d != null) return d.toString();
    } catch (_) {}

    // Soporta Map {description: "..."} o {desc: "..."}
    if (s is Map) {
      final d = s['desc'] ?? s['description'];
      if (d != null) return d.toString();
    }

    // fallback
    return s.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar dirección…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: onChanged,
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          ...sugs.map((s) {
            final desc = _descOf(s);
            if (desc.trim().isEmpty) return const SizedBox.shrink();

            return ListTile(
              dense: true,
              title: Text(
                desc,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onPick(s),
            );
          }),
        ],
      ),
    );
  }
}
