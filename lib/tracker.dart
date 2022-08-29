import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:salesPlus/core/data/data_model/location.dart';
import 'package:salesPlus/core/data/db/app_db.dart';
import 'package:salesPlus/core/globals.dart' as globals;
import 'constant.dart';
import 'package:salesPlus/core/service/tacker/enum.dart';
import 'package:salesPlus/core/service/tacker/geolocator.dart';
import 'package:salesPlus/core/service/tacker/tracker_util.dart';

Future<void> GeolocatorTracker() async {
  if (await checkLocationPermission()) {
    final tracker = FlutterBackgroundService();
    await tracker.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,
        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
    tracker.startService();
  }
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  print('FLUTTER BACKGROUND FETCH');

  return true;
}

void onStart(ServiceInstance service) async {
  AppDB db = await AppDB.initDB();

  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // For flutter prior to version 3.0.0
  // We have to register the plugin manually

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Geolocator.getPositionStream().listen((newLocation) async{
  //   globals.lastLocation = newLocation;
  //   var batteryLevel = await Battery().batteryLevel;
  //
  //   db.locationDao.insert(Location(
  //       timestamp: newLocation.timestamp.toString(),
  //       lat: newLocation.latitude,
  //       lng: newLocation.longitude,
  //       accuracy: newLocation.accuracy,
  //       speed: newLocation.speed,
  //       speedAccuracy: newLocation.speedAccuracy,
  //       heading: newLocation.heading,
  //       altitude: newLocation.altitude,
  //       floor: newLocation.floor,
  //       isMocked: newLocation.isMocked,
  //       batteryLevel: batteryLevel
  //   ));
  //
  //   if (service is AndroidServiceInstance) {
  //     service.setForegroundNotificationInfo(
  //       title: "SalesPlus",
  //       content: "Updated at ${DateTime.now()}",
  //     );
  //   }
  //
  //   /// you can see this log in logcat
  //   debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');
  //
  //   // test using external plugin
  //   final deviceInfo = DeviceInfoPlugin();
  //   String? device;
  //   if (Platform.isAndroid) {
  //     final androidInfo = await deviceInfo.androidInfo;
  //     device = androidInfo.model;
  //   }
  //
  //   if (Platform.isIOS) {
  //     final iosInfo = await deviceInfo.iosInfo;
  //     device = iosInfo.model;
  //   }
  //
  //   service.invoke(
  //     'new_location',
  //     {
  //       'timestamp': newLocation.timestamp?.toIso8601String(),
  //       'lat': newLocation.latitude,
  //       'lng': newLocation.longitude,
  //       'accuracy': newLocation.accuracy,
  //       'speed': newLocation.speed,
  //       'speedAccuracy': newLocation.speedAccuracy,
  //       'heading': newLocation.heading,
  //       'altitude': newLocation.altitude,
  //       'floor': newLocation.floor,
  //       'isMocked': newLocation.isMocked
  //     },
  //   );
  // });

  // bring to foreground
  Timer.periodic(const Duration(seconds: timeIntervalSecond), (timer) async {
    Position newPosition = await determinePosition();

    var batteryLevel = await Battery().batteryLevel;
    final validateResult = validatePosition(newPosition);
    if(validateResult == NewLocationValidEnum.valid){
      globals.lastLocation = Location.fromPosition(newPosition, batteryLevel);
      db.locationDao.insert(globals.lastLocation!);
    }else if(validateResult == NewLocationValidEnum.partiallyValid){
      globals.lastLocation!.lat = newPosition.latitude;
      globals.lastLocation!.lng = newPosition.longitude;
      globals.lastLocation!.accuracy = newPosition.accuracy;
      Location? lastLocation = await db.locationDao.getLastEntry();
      lastLocation!.lat = newPosition.latitude;
      lastLocation.lng = newPosition.longitude;
      lastLocation.accuracy = newPosition.accuracy;
      db.locationDao.insert(lastLocation);
    }

    if(validateResult == NewLocationValidEnum.valid || validateResult == NewLocationValidEnum.partiallyValid){
      service.invoke(
        'new_location',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "SalesPlus",
        content: "Updated at ${DateTime.now()}",
      );
    }

    /// you can see this log in logcat
    debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    // test using external plugin
    final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

  });
}
