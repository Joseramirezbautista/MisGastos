
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reportes_page.dart';
import 'gastos_diarios_page.dart';
import 'codigos_page.dart';
import 'gastos_fijos.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_config.dart';

import 'services/update_service.dart';
import 'services/update_dialog.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.cargar();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('es_MX', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MisGastos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const SplashScreen(), // 👈 inicia en el Splash
    );
  }
}

// ── SPLASH SCREEN ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(
          version: update['version'],
          downloadUrl: update['download_url'],
        ),
      );
    }


    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    // Espera 3 segundos y navega a la pantalla principal
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const MyHomePage(title: 'MisGastos'),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono / logo
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_money_rounded,
                    size: 70,
                    color: Colors.green,
                  ),
                ),

                const SizedBox(height: 24),

                // Nombre de la app
                const Text(
                  'MisGastos',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                // Slogan
                const Text(
                  ' Desarrollado por mrx',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),

                const SizedBox(height: 60),

                // Indicador de carga
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ── PANTALLA PRINCIPAL ────────────────────────────────────────────────────────
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ReportesPageState> _reportesKey = GlobalKey();
  final GlobalKey<GastosDiariosPageState> _gastosDiariosKey = GlobalKey();
  final GlobalKey<GastosFijosPageState> _gastosFijosKey = GlobalKey();

  // ── Índices de página: 0=Inicio 1=Gastos 2=Códigos 3=Deudas ──────────────
  // Básico y Premium: Inicio, Gastos, Deudas
  // Admin: Inicio, Gastos, Códigos, Deudas
  List<int> get _indicesActivos {
    if (AppConfig.puedeVerCodigos) return [0, 1, 2, 3];
    return [0, 1, 3];
  }

  // Página real que se muestra según el tab seleccionado
  int get _paginaActual => _indicesActivos[_selectedIndex];

  static const List<BottomNavigationBarItem> _todosLosItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.list_alt_outlined),
      activeIcon: Icon(Icons.list_alt),
      label: 'Gastos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.code_outlined),
      activeIcon: Icon(Icons.code),
      label: 'Códigos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined),
      activeIcon: Icon(Icons.receipt_long),
      label: 'Deudas',
    ),
  ];

  List<BottomNavigationBarItem> get _itemsActivos =>
      _indicesActivos.map((i) => _todosLosItems[i]).toList();

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    final pagina = _indicesActivos[index];
    // Al volver a Inicio, recargar reportes
    if (pagina == 0) {
      _reportesKey.currentState?.recargar();
    }
    // Al volver a Gastos, recargar gastos fijos para reflejar pagos inmediatos
    if (pagina == 1) {
      _gastosDiariosKey.currentState?.recargarFijos();
    }
  }

  void _mostrarActivacion(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plan: ${AppConfig.planActual}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Código de activación',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final ok = await AppConfig.activar(controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Plan cambiado a: ${AppConfig.planActual}'
                      : 'Código inválido'),
                ),
              );
              if (ok) setState(() => _selectedIndex = 0);
            },
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }

  void _mostrarContacto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.green, Color(0xFF1B5E20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 14),

            // Nombre
            const Text(
              'Jose Bautista',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Desarrollador · MisGastos',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),

            // Tarjeta de datos
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _contactoItem(
                    Icons.email_outlined,
                    'Correo',
                    'Yairg0913@gmail.com',
                    Colors.blue,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _contactoItem(
                    Icons.phone_outlined,
                    'Teléfono',
                    '+52 4426670736',
                    Colors.green,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _contactoItem(
                    Icons.link,
                    'GitHub',
                    'github.com/josebautista',
                    Colors.purple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Versión + botón cambiar plan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'v1.0  •  Plan: ${AppConfig.planActual}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _mostrarActivacion(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Cambiar plan',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactoItem(IconData icono, String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _mostrarContacto(context),
          ),
        ],
      ),

      // IndexedStack preserva el estado de cada página al cambiar de tab
      body: IndexedStack(
        index: _paginaActual,
        children: [
          ReportesPage(
            key: _reportesKey,
            onIrADeudas: () {
              final idxDeudas = _indicesActivos.indexOf(3);
              if (idxDeudas != -1) setState(() => _selectedIndex = idxDeudas);
            },
            onIrAIngresos: () {
              final idxDeudas = _indicesActivos.indexOf(3);
              if (idxDeudas != -1) {
                setState(() => _selectedIndex = idxDeudas);
                _gastosFijosKey.currentState?.irAIngresos();
              }
            },
          ),
          GastosDiariosPage(key: _gastosDiariosKey),
          const CodigosPage(),
          GastosFijosPage(key: _gastosFijosKey),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: _itemsActivos,
      ),

      floatingActionButton: _paginaActual == 1
          ? FloatingActionButton(
              heroTag: 'agregar_gasto',
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              onPressed: () =>
                  _gastosDiariosKey.currentState?.mostrarFormularioActual(),
              child: const Icon(Icons.add),
            )
          : _paginaActual == 3
          ? FloatingActionButton(
              heroTag: 'agregar_fijo',
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              onPressed: () =>
                  _gastosFijosKey.currentState?.mostrarFormularioActual(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
