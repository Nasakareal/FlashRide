import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/passenger/request_ride.dart';
import 'screens/driver/pending_rides.dart';
import 'screens/shared/home.dart';
import 'screens/admin/admin_home_screen.dart';

// Admin
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/driver_list_screen.dart';
import 'screens/admin/create_driver_screen.dart';
import 'screens/admin/biometric_driver_screen.dart';
import 'screens/admin/vehicle_list_screen.dart';
import 'screens/admin/create_vehicle_screen.dart';

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
        // Admin:
        '/admin_home': (_) => const AdminHomeScreen(),
        '/driver_list': (_) => const DriverListScreen(),
        '/create_driver': (_) => const CreateDriverScreen(),
        '/biometric_module': (_) => const BiometricDriverScreen(
              driverId: 0,
              driverName: '',
            ), // Solo para inicializar; en uso real se pasa desde driver_list
        '/vehicle_list': (_) => const VehicleListScreen(),
        '/create_vehicle': (_) => const CreateVehicleScreen(),
      },
    );
  }
}
