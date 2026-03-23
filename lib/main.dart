import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/shared/home.dart';
import 'screens/shared/welcome_screen.dart';

import 'screens/passenger/request_ride.dart';
import 'screens/passenger/passenger_home_screen.dart';
import 'screens/passenger/transit/route_list_screen.dart';

import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/pending_rides.dart';
import 'screens/driver/profile_screen.dart';
import 'screens/driver/past_rides_screen.dart';
import 'screens/driver/support_screen.dart';

import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/driver_list_screen.dart';
import 'screens/admin/create_driver_screen.dart';
import 'screens/admin/biometric_driver_screen.dart';
import 'screens/admin/vehicle_list_screen.dart';
import 'screens/admin/create_vehicle_screen.dart';

import 'screens/shared/chat_screen.dart';
import 'screens/passenger/driver_profile_view_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  if (!kReleaseMode) {
    HttpOverrides.global = MyHttpOverrides();
  }
  _setupLogging();
  runApp(const FlashRideApp());
}

void _setupLogging() {
  Logger.root.level = Level.ALL;

  Logger.root.onRecord.listen((record) {
    debugPrint(
      '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}',
    );
  });

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);

    Logger('FlutterError').severe(
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };
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
        '/transit/routes': (_) => const TransitRouteListScreen(),
        '/driver_home': (_) => const DriverHomeScreen(),
        '/rides/pending': (_) => const PendingRidesScreen(),
        '/driver/profile': (_) => const ProfileScreen(),
        '/driver/past_rides': (_) => const PastRidesScreen(),
        '/driver/support': (_) => const DriverSupportScreen(),
        '/admin_home': (_) => const AdminHomeScreen(),
        '/driver_list': (_) => const DriverListScreen(),
        '/create_driver': (_) => const CreateDriverScreen(),
        '/biometric_module': (_) =>
            const BiometricDriverScreen(driverId: 0, driverName: ''),
        '/vehicle_list': (_) => const VehicleListScreen(),
        '/create_vehicle': (_) => const CreateVehicleScreen(),
        '/chat': (_) => const ChatScreen(),
        '/driver_profile_view': (_) => const DriverProfileViewScreen(),
      },
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ruta no encontrada')),
          body: const Center(
            child: Text('La ruta solicitada no existe'),
          ),
        ),
      ),
    );
  }
}
