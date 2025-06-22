import 'package:flutter/material.dart';

// Screens generales
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/shared/home.dart';
import 'screens/shared/welcome_screen.dart';

// Pasajero
import 'screens/passenger/request_ride.dart';
import 'screens/passenger/passenger_home_screen.dart';

// Chofer
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/pending_rides.dart';
import 'screens/driver/profile_screen.dart';
import 'screens/driver/past_rides_screen.dart';
import 'screens/driver/ride_details_screen.dart';

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

      // Página inicial
      home: const HomePage(),

      // Rutas definidas
      routes: {
        // Generales
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomePage(),
        '/welcome': (_) => const WelcomeScreen(),

        // Pasajero
        '/ride/request': (_) => const RequestRideScreen(),
        '/passenger_home': (_) => const PassengerHomeScreen(),

        // Chofer
        '/driver_home': (_) => const DriverHomeScreen(),
        '/rides/pending': (_) => const PendingRidesScreen(),
        '/driver/profile': (_) => const ProfileScreen(),
        '/driver/past_rides': (_) => const PastRidesScreen(),

        // Admin
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

      // Ruta por defecto si una no existe
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ruta no encontrada')),
          body: const Center(child: Text('La ruta solicitada no existe')),
        ),
      ),
    );
  }
}
