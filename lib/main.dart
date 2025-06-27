import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/shared/home.dart';
import 'screens/shared/welcome_screen.dart';
import 'screens/passenger/request_ride.dart';
import 'screens/passenger/passenger_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/pending_rides.dart';
import 'screens/driver/profile_screen.dart';
import 'screens/driver/past_rides_screen.dart';
import 'screens/driver/ride_details_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/driver_list_screen.dart';
import 'screens/admin/create_driver_screen.dart';
import 'screens/admin/biometric_driver_screen.dart';
import 'screens/admin/vehicle_list_screen.dart';
import 'screens/admin/create_vehicle_screen.dart';

void main() {
  _setupLogging();
  runApp(const FlashRideApp());
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });
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
        '/home': (_) => const HomePage(),
        '/welcome': (_) => const WelcomeScreen(),
        '/ride/request': (_) => const RequestRideScreen(),
        '/passenger_home': (_) => const PassengerHomeScreen(),
        '/driver_home': (_) => const DriverHomeScreen(),
        '/rides/pending': (_) => const PendingRidesScreen(),
        '/driver/profile': (_) => const ProfileScreen(),
        '/driver/past_rides': (_) => const PastRidesScreen(),
        '/admin_home': (_) => const AdminHomeScreen(),
        '/driver_list': (_) => const DriverListScreen(),
        '/create_driver': (_) => const CreateDriverScreen(),
        '/biometric_module': (_) => const BiometricDriverScreen(
              driverId: 0,
              driverName: '',
            ),
        '/vehicle_list': (_) => const VehicleListScreen(),
        '/create_vehicle': (_) => const CreateVehicleScreen(),
      },
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ruta no encontrada')),
          body: const Center(child: Text('La ruta solicitada no existe')),
        ),
      ),
    );
  }
}
