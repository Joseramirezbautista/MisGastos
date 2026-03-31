import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String _plan = 'admin';

  static String get plan => _plan;

  static bool get puedeVerGasolina => _plan == 'premium' || _plan == 'admin';
  static bool get puedeVerCodigos => _plan == 'admin';
  static bool get puedeVerReportes => true;

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();

    // Primera vez que corre esta versión
    if (!prefs.containsKey('plan')) {
      // Si ya tiene datos guardados = usuario existente → admin
      // Si no tiene datos = usuario nuevo → basico
      final tieneGastos = prefs.containsKey('gastos') ||
                          prefs.containsKey('ultimo_gasto');

      if (tieneGastos) {
        _plan = 'admin'; // usuario existente, no pierde nada
      } else {
        _plan = 'basico'; // usuario nuevo
      }
      await prefs.setString('plan', _plan);
    } else {
      _plan = prefs.getString('plan')!;
    }
  }

  // Tú les das el código para subir o bajar nivel
  static Future<bool> activar(String codigo) async {
    final prefs = await SharedPreferences.getInstance();

    final codigos = {
      'BAS2026': 'basico',
      'PRE2026': 'premium',
      'ADM2026': 'admin',
    };

    if (codigos.containsKey(codigo.toUpperCase())) {
      _plan = codigos[codigo.toUpperCase()]!;
      await prefs.setString('plan', _plan);
      return true;
    }
    return false;
  }

  // Ver qué plan tiene
  static String get planActual {
    switch (_plan) {
      case 'admin': return 'Administrador';
      case 'premium': return 'Premium';
      default: return 'Básico';
    }
  }
}
