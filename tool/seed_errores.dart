import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = p.join(Directory.current.path, 'codigo_errores.db');
  final db = await databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS codigos_errores (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            codigo   TEXT NOT NULL,
            tipo     TEXT NOT NULL,
            mensaje  TEXT NOT NULL,
            modulo   TEXT NOT NULL,
            activo   INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    ),
  );

  final errores = [
    {'codigo': 'ERR-001', 'tipo': 'VALIDACION',  'mensaje': 'El campo monto no puede ser negativo.',           'modulo': 'GastosDiarios', 'activo': 1},
    {'codigo': 'ERR-002', 'tipo': 'VALIDACION',  'mensaje': 'La fecha ingresada no es válida.',                'modulo': 'GastosDiarios', 'activo': 1},
    {'codigo': 'ERR-003', 'tipo': 'VALIDACION',  'mensaje': 'La descripción excede 200 caracteres.',           'modulo': 'GastosDiarios', 'activo': 1},
    {'codigo': 'ERR-004', 'tipo': 'VALIDACION',  'mensaje': 'La categoría seleccionada no existe.',            'modulo': 'GastosDiarios', 'activo': 1},
    {'codigo': 'ERR-005', 'tipo': 'BASE_DATOS',  'mensaje': 'No se pudo abrir la base de datos.',             'modulo': 'DatabaseHelper', 'activo': 1},
    {'codigo': 'ERR-006', 'tipo': 'BASE_DATOS',  'mensaje': 'Error al insertar el gasto.',                    'modulo': 'DatabaseHelper', 'activo': 1},
    {'codigo': 'ERR-007', 'tipo': 'BASE_DATOS',  'mensaje': 'Error al actualizar el gasto.',                  'modulo': 'DatabaseHelper', 'activo': 1},
    {'codigo': 'ERR-008', 'tipo': 'BASE_DATOS',  'mensaje': 'Error al eliminar el gasto.',                    'modulo': 'DatabaseHelper', 'activo': 1},
    {'codigo': 'ERR-009', 'tipo': 'BASE_DATOS',  'mensaje': 'No se encontró el registro solicitado.',         'modulo': 'DatabaseHelper', 'activo': 1},
    {'codigo': 'ERR-010', 'tipo': 'REPORTE',     'mensaje': 'No hay datos para el período seleccionado.',     'modulo': 'ReportesPage',   'activo': 1},
    {'codigo': 'ERR-011', 'tipo': 'REPORTE',     'mensaje': 'Error al generar la gráfica de pastel.',         'modulo': 'ReportesPage',   'activo': 1},
    {'codigo': 'ERR-012', 'tipo': 'NAVEGACION',  'mensaje': 'Pestaña no disponible todavía.',                 'modulo': 'MyHomePage',     'activo': 1},
    {'codigo': 'ERR-013', 'tipo': 'SISTEMA',     'mensaje': 'Error al inicializar el locale es_MX.',          'modulo': 'Main',           'activo': 1},
    {'codigo': 'ERR-014', 'tipo': 'SISTEMA',     'mensaje': 'Permisos de almacenamiento denegados.',          'modulo': 'Main',           'activo': 1},
    {'codigo': 'ERR-015', 'tipo': 'VALIDACION',  'mensaje': 'El monto debe ser un número válido.',            'modulo': 'GastosDiarios', 'activo': 1},
  ];

  for (final error in errores) {
    await db.insert('codigos_errores', error);
  }

  await db.close();
  print('✅ Base de datos poblada con ${errores.length} códigos de error en:\n   $dbPath');
}
