import 'package:flutter/material.dart';

class RequestRideButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;

  const RequestRideButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF1B8F),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Text(
            'Solicitar viaje aquí',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
