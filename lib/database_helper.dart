import 'package:path/path.dart';
import 'gastos_diarios_page.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gastos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria TEXT NOT NULL,
        monto REAL NOT NULL,
        descripcion TEXT,
        fecha TEXT NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'Personal',
        pago TEXT NOT NULL DEFAULT 'Efectivo'
      )
    ''');
    await db.execute('''
      CREATE TABLE gasolina (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sitio TEXT NOT NULL,
        fecha TEXT NOT NULL,
        km REAL NOT NULL,
        total REAL NOT NULL,
        servicio TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ingresos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria TEXT NOT NULL,
        descripcion TEXT,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        tipo TEXT NOT NULL DEFAULT 'Personal',
        cobro TEXT NOT NULL DEFAULT 'Efectivo'
      )
    ''');
    await db.execute('''
      CREATE TABLE gastos_fijos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria TEXT NOT NULL,
        descripcion TEXT,
        monto_mensual REAL NOT NULL,
        deuda_total REAL,
        deuda_pagada REAL NOT NULL DEFAULT 0,
        fecha_limite TEXT NOT NULL,
        urgente INTEGER NOT NULL DEFAULT 0,
        pagado INTEGER NOT NULL DEFAULT 0,
        anclado INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE gastos ADD COLUMN tipo TEXT NOT NULL DEFAULT 'Personal'",
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS gasolina (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sitio TEXT NOT NULL,
          fecha TEXT NOT NULL,
          km REAL NOT NULL,
          total REAL NOT NULL,
          servicio TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE gastos ADD COLUMN pago TEXT NOT NULL DEFAULT 'Efectivo'",
      );
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ingresos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          categoria TEXT NOT NULL,
          descripcion TEXT,
          monto REAL NOT NULL,
          fecha TEXT NOT NULL,
          tipo TEXT NOT NULL DEFAULT 'Personal',
          cobro TEXT NOT NULL DEFAULT 'Efectivo'
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE gastos_fijos ADD COLUMN anclado INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS gastos_fijos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          categoria TEXT NOT NULL,
          descripcion TEXT,
          monto_mensual REAL NOT NULL,
          deuda_total REAL,
          deuda_pagada REAL NOT NULL DEFAULT 0,
          fecha_limite TEXT NOT NULL,
          urgente INTEGER NOT NULL DEFAULT 0,
          pagado INTEGER NOT NULL DEFAULT 0,
          anclado INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }
//INSERTAR
  Future<int> insertarGasto(Gasto gasto) async {
    final db = await database;
    return await db.insert('gastos', {
      'categoria':   gasto.categoria,
      'monto':       gasto.monto,
      'descripcion': gasto.descripcion,
      'fecha':       gasto.fecha.toIso8601String(),
      'tipo':        gasto.tipo,
      'pago':        gasto.pago,
    });
  }
//BASE DE DATOS
  Future<List<Gasto>> obtenerGastos() async {
    final db = await database;
    final maps = await db.query('gastos', orderBy: 'fecha DESC');
    return maps.map((m) => Gasto(
      id:          m['id'] as int?,
      categoria:   m['categoria'] as String,
      monto:       m['monto'] as double,
      descripcion: m['descripcion'] as String? ?? '',
      fecha:       DateTime.parse(m['fecha'] as String),
      tipo:        m['tipo'] as String? ?? 'Personal',
      pago:        m['pago'] as String? ?? 'Efectivo',
    )).toList();
  }

  // ── ACTUALIZAR ────────────────────────────────────────────────────────────
  Future<int> actualizarGasto(Gasto gasto) async {
    final db = await database;
    return await db.update(
      'gastos',
      {
        'categoria':   gasto.categoria,
        'monto':       gasto.monto,
        'descripcion': gasto.descripcion,
        'fecha':       gasto.fecha.toIso8601String(),
        'tipo':        gasto.tipo,
        'pago':        gasto.pago,
      },
      where: 'id = ?',
      whereArgs: [gasto.id],
    );
  }

//
  Future<int> eliminarGasto(int id) async {
    final db = await database;
    return await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
  }

  // ── GASOLINA ───────────────────────────────────────────────────────────────

  Future<int> insertarGasolina(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('gasolina', data);
  }

  Future<List<Map<String, dynamic>>> obtenerGasolina() async {
    final db = await database;
    return await db.query('gasolina', orderBy: 'fecha DESC');
  }

  Future<int> actualizarGasolina(Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'gasolina',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<int> eliminarGasolina(int id) async {
    final db = await database;
    return await db.delete('gasolina', where: 'id = ?', whereArgs: [id]);
  }

  // ── GASTOS FIJOS ───────────────────────────────────────────────────────────

  Future<int> insertarGastoFijo(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('gastos_fijos', data);
  }

  Future<List<Map<String, dynamic>>> obtenerGastosFijos() async {
    final db = await database;
    return await db.query('gastos_fijos', orderBy: 'urgente DESC, fecha_limite ASC');
  }

  Future<int> actualizarGastoFijo(Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'gastos_fijos',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<int> eliminarGastoFijo(int id) async {
    final db = await database;
    return await db.delete('gastos_fijos', where: 'id = ?', whereArgs: [id]);
  }

  // ── INGRESOS ───────────────────────────────────────────────────────────────

  Future<int> insertarIngreso(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('ingresos', data);
  }

  Future<List<Map<String, dynamic>>> obtenerIngresos() async {
    final db = await database;
    return await db.query('ingresos', orderBy: 'fecha DESC');
  }

  Future<int> actualizarIngreso(Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('ingresos', data, where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<int> eliminarIngreso(int id) async {
    final db = await database;
    return await db.delete('ingresos', where: 'id = ?', whereArgs: [id]);
  }
}
