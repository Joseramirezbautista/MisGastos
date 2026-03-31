import 'package:flutter/material.dart';
import 'error_atm_database.dart';
import 'translation_service.dart';

// ── COLORES POR TIPO DE ERROR ─────────────────────────────────────────────────
Color _colorTipo(String tipo) {
  final t = tipo.toLowerCase();
  if (t.contains('software')) {
    return Colors.blue.shade700;
  } else if (t.contains('cash') || t.contains('bill') || t.contains('note') ||
      t.contains('dispenser') || t.contains('recycl')) {
    return Colors.green.shade700;
  } else if (t.contains('card')) {
    return Colors.purple.shade700;
  } else if (t.contains('printer') || t.contains('receipt') ||
      t.contains('journal')) {
    return Colors.orange.shade700;
  } else if (t.contains('security') || t.contains('encrypt') ||
      t.contains('epp') || t.contains('cimbox') || t.contains('pin')) {
    return Colors.red.shade700;
  } else if (t.contains('serial') || t.contains('tcp') ||
      t.contains('usb') || t.contains('rs2')) {
    return Colors.teal.shade700;
  } else if (t.contains('coin')) {
    return Colors.amber.shade700;
  } else if (t.contains('power') || t.contains('ups') ||
      t.contains('heater')) {
    return Colors.deepOrange.shade700;
  } else if (t.contains('display') || t.contains('screen') ||
      t.contains('vfd') || t.contains('led')) {
    return Colors.indigo.shade700;
  } else if (t.contains('scanner') || t.contains('camera') ||
      t.contains('finger') || t.contains('passport')) {
    return Colors.cyan.shade700;
  }
  return Colors.grey.shade700;
}

// ── PÁGINA CÓDIGOS ────────────────────────────────────────────────────────────
class CodigosPage extends StatefulWidget {
  const CodigosPage({super.key});

  @override
  State<CodigosPage> createState() => _CodigosPageState();
}

class _CodigosPageState extends State<CodigosPage> {
  final TextEditingController _busquedaCtrl = TextEditingController();

  List<CodigoError> _todos = [];
  List<CodigoError> _filtrados = [];
  List<String> _categorias = ['Todas'];
  String _categoriaFiltro = 'Todas';
  String _textoBusqueda = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final datos = await ErrorATMDatabase.instance.obtenerTodos();
    final tipos = datos.map((e) => e.tipoError).toSet().toList()..sort();
    setState(() {
      _todos = datos;
      _categorias = ['Todas', ...tipos];
      _cargando = false;
    });
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    setState(() {
      _filtrados = _todos.where((e) {
        final texto = _textoBusqueda.toLowerCase();
        final coincideTexto = texto.isEmpty ||
            e.codigoEstado.toLowerCase().contains(texto) ||
            e.descripcion.toLowerCase().contains(texto) ||
            e.accionRecomendada.toLowerCase().contains(texto) ||
            e.tipoError.toLowerCase().contains(texto);
        final coincideTipo =
            _categoriaFiltro == 'Todas' || e.tipoError == _categoriaFiltro;
        return coincideTexto && coincideTipo;
      }).toList();
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Códigos de Error ATM'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
              children: [
                // ── Buscador ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _busquedaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por código, descripción o acción...',
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      suffixIcon: _textoBusqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _busquedaCtrl.clear();
                                _textoBusqueda = '';
                                _aplicarFiltros();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.green, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      _textoBusqueda = v;
                      _aplicarFiltros();
                    },
                  ),
                ),

                // ── Filtro por tipo ──────────────────────────────────────────
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categorias.length,
                    itemBuilder: (context, i) {
                      final cat = _categorias[i];
                      final activo = _categoriaFiltro == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat,
                              style: const TextStyle(fontSize: 12)),
                          selected: activo,
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(
                            color: activo
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: activo
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            _categoriaFiltro = cat;
                            _aplicarFiltros();
                          },
                        ),
                      );
                    },
                  ),
                ),

                // ── Contador ─────────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '${_filtrados.length} resultado${_filtrados.length != 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // ── Encabezado de tabla ──────────────────────────────────────
                Container(
                  color: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 8),
                  child: const Row(
                    children: [
                      SizedBox(
                          width: 60,
                          child: Text('Código',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('Descripción',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                      SizedBox(width: 8),
                      SizedBox(
                          width: 110,
                          child: Text('Módulo',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                    ],
                  ),
                ),

                // ── Lista ────────────────────────────────────────────────────
                Expanded(
                  child: _filtrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 60,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'Sin resultados para "$_textoBusqueda"',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtrados.length,
                          itemBuilder: (context, i) {
                            final e = _filtrados[i];
                            final esPar = i % 2 == 0;
                            return InkWell(
                              onTap: () => _mostrarDetalle(context, e),
                              child: Container(
                                color: esPar
                                    ? Colors.white
                                    : Colors.grey.shade50,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Código
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        e.codigoEstado,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Descripción
                                    Expanded(
                                      child: Text(
                                        e.descripcion,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Módulo / tipo
                                    SizedBox(
                                      width: 110,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _colorTipo(e.tipoError)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          e.tipoError,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                _colorTipo(e.tipoError),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ── Modal de detalle ────────────────────────────────────────────────────────
  void _mostrarDetalle(BuildContext context, CodigoError e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        String descripcion = e.descripcion;
        String accion = e.accionRecomendada;
        String tipo = e.tipoError;
        bool traducido = false;
        bool traduciendo = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            maxChildSize: 0.85,
            builder: (_, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Código ${e.codigoEstado}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _colorTipo(tipo).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tipo,
                            style: TextStyle(
                              color: _colorTipo(tipo),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Botón traducir ──────────────────────────────────
                      Tooltip(
                        message: traducido ? 'Ver original' : 'Traducir al español',
                        child: IconButton(
                          icon: traduciendo
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.green),
                                )
                              : Icon(
                                  traducido
                                      ? Icons.language
                                      : Icons.translate,
                                  color: Colors.green,
                                ),
                          onPressed: traduciendo
                              ? null
                              : () async {
                                  if (traducido) {
                                    setModalState(() {
                                      descripcion = e.descripcion;
                                      accion = e.accionRecomendada;
                                      tipo = e.tipoError;
                                      traducido = false;
                                    });
                                    return;
                                  }
                                  setModalState(() => traduciendo = true);
                                  try {
                                    final svc = TranslationService.instance;
                                    await svc.inicializar();
                                    final results = await Future.wait([
                                      svc.traducir(e.descripcion),
                                      svc.traducir(e.accionRecomendada),
                                      svc.traducir(e.tipoError),
                                    ]);
                                    setModalState(() {
                                      descripcion = results[0];
                                      accion = results[1];
                                      tipo = results[2];
                                      traducido = true;
                                      traduciendo = false;
                                    });
                                  } catch (_) {
                                    setModalState(() => traduciendo = false);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Descripción',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(descripcion, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 16),
                  const Text('Acción recomendada',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(accion, style: const TextStyle(fontSize: 15)),
                  if (e.codigoHardware.isNotEmpty &&
                      e.codigoHardware != 'None') ...[
                    const SizedBox(height: 16),
                    const Text('Código de hardware',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(e.codigoHardware,
                        style: const TextStyle(fontSize: 15)),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
