import 'package:flutter/material.dart';
import '../../../services/transit_service.dart';
import 'route_map_screen.dart';

class TransitRouteListScreen extends StatefulWidget {
  const TransitRouteListScreen({super.key});

  @override
  State<TransitRouteListScreen> createState() => _TransitRouteListScreenState();
}

class _TransitRouteListScreenState extends State<TransitRouteListScreen> {
  final _svc = TransitService();
  bool _loading = true;
  List _routes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _svc.fetchRoutes();
      setState(() {
        _routes = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error cargando rutas: ${transitFriendlyError(e)}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rutas de transporte'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Aunque esté cargando, simplemente no hará nada útil
              },
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas de transporte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await showSearch(
                context: context,
                delegate: TransitRouteSearchDelegate(
                  routes: _routes,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _routes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = _routes[i];
          final short = (r['short_name'] ?? '').toString();
          final long = (r['long_name'] ?? '').toString();
          final vt = (r['vehicle_type'] ?? '').toString();
          return ListTile(
            leading: CircleAvatar(child: Text(short.isEmpty ? '?' : short)),
            title: Text('$short  $long'),
            subtitle: Text(vt),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransitRouteMapScreen(
                    routeId: r['id'] as int,
                    title: short.isEmpty ? 'Ruta' : 'Ruta $short',
                    initialRouteData: Map<String, dynamic>.from(r as Map),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Delegate para la búsqueda de rutas
class TransitRouteSearchDelegate extends SearchDelegate {
  final List routes;

  TransitRouteSearchDelegate({required this.routes});

  @override
  String get searchFieldLabel => 'Buscar ruta (color, nombre, etc.)';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  List _filteredRoutes() {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return routes;

    return routes.where((r) {
      final short = (r['short_name'] ?? '').toString().toLowerCase();
      final long = (r['long_name'] ?? '').toString().toLowerCase();
      final vt = (r['vehicle_type'] ?? '').toString().toLowerCase();
      final color = (r['color'] ?? '').toString().toLowerCase();
      final desc = (r['description'] ?? '').toString().toLowerCase();

      return short.contains(q) ||
          long.contains(q) ||
          vt.contains(q) ||
          color.contains(q) ||
          desc.contains(q);
    }).toList();
  }

  @override
  Widget buildResults(BuildContext context) {
    final list = _filteredRoutes();

    if (list.isEmpty) {
      return const Center(
        child: Text('No se encontraron rutas que coincidan'),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = list[i];
        final short = (r['short_name'] ?? '').toString();
        final long = (r['long_name'] ?? '').toString();
        final vt = (r['vehicle_type'] ?? '').toString();
        return ListTile(
          leading: CircleAvatar(child: Text(short.isEmpty ? '?' : short)),
          title: Text('$short  $long'),
          subtitle: Text(vt),
          onTap: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransitRouteMapScreen(
                  routeId: r['id'] as int,
                  title: short.isEmpty ? 'Ruta' : 'Ruta $short',
                  initialRouteData: Map<String, dynamic>.from(r as Map),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Mientras escribe, usamos el mismo filtrado que en los resultados
    final list = _filteredRoutes();

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = list[i];
        final short = (r['short_name'] ?? '').toString();
        final long = (r['long_name'] ?? '').toString();
        final vt = (r['vehicle_type'] ?? '').toString();
        return ListTile(
          leading: CircleAvatar(child: Text(short.isEmpty ? '?' : short)),
          title: Text('$short  $long'),
          subtitle: Text(vt),
          onTap: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransitRouteMapScreen(
                  routeId: r['id'] as int,
                  title: short.isEmpty ? 'Ruta' : 'Ruta $short',
                  initialRouteData: Map<String, dynamic>.from(r as Map),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
