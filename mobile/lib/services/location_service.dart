import 'package:geolocator/geolocator.dart';

class LocationDeniedException implements Exception {
  final String message;
  LocationDeniedException(this.message);

  @override
  String toString() => 'LocationDeniedException: $message';
}

class LocationService {
  Future<Position> current() async {
    // 1. ¿El servicio de ubicación está encendido en el sistema?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationDeniedException(
        'Activa la ubicación en tu sistema para ver tu posición.',
      );
    }

    // 2. Estado del permiso
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationDeniedException(
          'Sin permiso de ubicación no podemos centrar el mapa en ti.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationDeniedException(
        'Has bloqueado la ubicación permanentemente. '
        'Actívala desde los ajustes del navegador.',
      );
    }

    // 3. Todo ok: pedir la posición
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }
}