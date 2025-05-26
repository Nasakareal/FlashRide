import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../driver/driver_home_screen.dart';
import '../passenger/passenger_home_screen.dart';
import 'welcome_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.amber,
              ),
            ),
          );
        }

        final role = snapshot.data;

        if (role == 'driver') {
          return const DriverHomeScreen();
        } else if (role == 'passenger') {
          return const PassengerHomeScreen();
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}
