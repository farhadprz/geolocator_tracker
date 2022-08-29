
import 'package:app_settings/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../geolocator_tracker/lib/constant.dart';
import 'package:salesPlus/core/service/tacker/enum.dart';
import 'package:salesPlus/core/globals.dart' as globals;

Future<bool> checkLocationPermission() async {
  final access = await Geolocator.checkPermission();
  switch (access) {
    case LocationPermission.denied:
    case LocationPermission.deniedForever:
    case LocationPermission.unableToDetermine:
      final permissionStatus = await Geolocator.requestPermission();
      if (permissionStatus == LocationPermission.whileInUse) {
        AppSettings.openAppSettings();
        return true;
      } else if (permissionStatus == LocationPermission.always) {
        return true;
      } else {
        return false;
      }
    case LocationPermission.whileInUse:
      AppSettings.openAppSettings();
      return true;
    case LocationPermission.always:
      return true;
    default:
      return false;
  }
}

NewLocationValidEnum validatePosition(Position newPosition) {
  if (newPosition.accuracy > maximumAccuracy) {
    return NewLocationValidEnum.invalid;
  }
  if (globals.lastLocation != null) {
    double distance = Geolocator.distanceBetween(
      globals.lastLocation!.lat ?? 0.0,
      globals.lastLocation!.lng ?? 0.0,
      newPosition.latitude,
      newPosition.longitude,
    );
    if (distance > validDistanceThreshold) {
      return NewLocationValidEnum.valid;
    } else {
      if (newPosition.accuracy < (globals.lastLocation!.accuracy ?? 0.0)) {//newLocation.speed < speedThreshold &&
        NewLocationValidEnum.partiallyValid;
      }else {
        return NewLocationValidEnum.invalid;
      }
    }
  }

  return NewLocationValidEnum.valid;
}
