import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_config.dart';
import 'screens/map_screen.dart';
import 'services/location_service.dart';
import 'services/parking_logic_service.dart';
import 'services/local_storage_service.dart';
import 'services/osm_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const SmartParkApp());
}

class SmartParkApp extends StatelessWidget {
  const SmartParkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locationService = LocationService();
    final storageService = LocalStorageService();
    final osmService = OsmService();
    final parkingLogic = ParkingLogicService(
      storage: storageService,
      osm: osmService,
    );

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppConfig.colorAccent,
        scaffoldBackgroundColor: AppConfig.colorBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConfig.colorSurface,
          foregroundColor: AppConfig.colorText,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          foregroundColor: Colors.white,
        ),
      ),
      home: MapScreen(
        locationService: locationService,
        parkingLogic: parkingLogic,
        storageService: storageService,
        osmService: osmService,
      ),
    );
  }
}
