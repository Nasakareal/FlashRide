import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/passenger/request_ride.dart';
import 'screens/driver/pending_rides.dart';
import 'screens/shared/home.dart';

void main() {
  runApp(const FlashRideApp());
}

class FlashRideApp extends StatelessWidget {
  const FlashRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlashRide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/ride/request': (_) => const RequestRideScreen(),
        '/rides/pending': (_) => const PendingRidesScreen(),
      },
    );
  }
}
