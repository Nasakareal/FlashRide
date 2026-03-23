import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final rideId = args?['ride_id'];
    final driverId = args?['driver_id'];

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Center(
        child: Text(
          'Chat del viaje $rideId con conductor $driverId',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
