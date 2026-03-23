import 'package:flutter/material.dart';
import '../../../services/transit_service.dart';

class TransitSuggestionsPanel extends StatelessWidget {
  final bool loading;
  final bool hasChecked;
  final List<TransitRouteSuggestion> suggestions;
  final ValueChanged<TransitRouteSuggestion> onOpenRoute;

  const TransitSuggestionsPanel({
    super.key,
    required this.loading,
    required this.hasChecked,
    required this.suggestions,
    required this.onOpenRoute,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading && !hasChecked && suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_bus, color: Color(0xFF0B57D0)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rutas de transporte cercanas al destino',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ] else if (suggestions.isEmpty && hasChecked) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No encontramos rutas de transporte que pasen lo suficientemente cerca de este destino.',
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...suggestions.map(
              (suggestion) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _colorFromHex(
                      suggestion.colorHex,
                    ).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _colorFromHex(suggestion.colorHex),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (suggestion.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              suggestion.subtitle,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            _distanceLabel(suggestion.distanceMeters),
                            style: const TextStyle(
                              color: Color(0xFF0B57D0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => onOpenRoute(suggestion),
                      child: const Text('Ver ruta'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _distanceLabel(double distanceMeters) {
    final rounded = distanceMeters.round();
    if (rounded <= 120) {
      return 'Muy cerca del destino: $rounded m';
    }
    if (rounded < 1000) {
      return 'Pasa cerca del destino: $rounded m';
    }
    return 'Pasa a ${(distanceMeters / 1000).toStringAsFixed(1)} km del destino';
  }

  Color _colorFromHex(String hex) {
    final normalized = hex.trim().replaceAll('#', '');
    final candidate = normalized.length == 6 ? 'FF$normalized' : normalized;
    try {
      return Color(int.parse(candidate, radix: 16));
    } catch (_) {
      return const Color(0xFF0B57D0);
    }
  }
}
