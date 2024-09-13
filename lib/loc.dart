
import 'package:location/location.dart';

class NumberGenerator {
  // Function that returns a list of numbers
  Future<List<double?>?> generateNumbers() async {
    Location location = Location();

    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await location.serviceEnabled();

    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return null;
      }
    }


    locationData = await location.getLocation();
    return [locationData.latitude, locationData.longitude];
  }
}