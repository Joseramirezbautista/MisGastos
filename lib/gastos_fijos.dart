import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'ingreso_page.dart';

// ── MODELO ────────────────────────────────────────────────────────────────────
class GastoFijo {
  final int? id;
  final String categoria;
  final String descripcion;
  final double montoMensual;
  final double? deudaTotal;   // solo TC y Préstamos
  final double deudaPagada;   // acumulado de pagos
  final DateTime fechaLimite;
  final bool urgente;
  final bool pagado;
  final bool anclado;

  const GastoFijo({
    this.id,
    required this.categoria,
    required this.descripcion,
    required this.montoMensual,
    this.deudaTotal,
    this.deudaPagada = 0,
    required this.fechaLimite,
    this.urgente = false,
    this.pagado = false,
    this.anclado = false,
  });

  bool get tieneDeuda => categoria == 'TC' || categoria == 'Préstamos';

  double get saldoPendiente =>
      ((deudaTotal ?? 0) - deudaPagada).clamp(0, double.infinity);

  factory GastoFijo.fromMap(Map<String, dynamic> m) => GastoFijo(
        id: m['id'] as int?,
        categoria: m['categoria'] as String,
        descripcion: m['descripcion'] as String? ?? '',
        montoMensual: (m['monto_mensual'] as num).toDouble(),
        deudaTotal:
            m['deuda_total'] != null ? (m['deuda_total'] as num).toDouble() : null,
        deudaPagada: (m['deuda_pagada'] as num? ?? 0).toDouble(),
        fechaLimite: DateTime.parse(m['fecha_limite'] as String),
        urgente: (m['urgente'] as int? ?? 0) == 1,
        pagado: (m['pagado'] as int? ?? 0) == 1,
        anclado: (m['anclado'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'categoria': categoria,
        'descripcion': descripcion,
        'monto_mensual': montoMensual,
        'deuda_total': deudaTotal,
        'deuda_pagada': deudaPagada,
        'fecha_limite': fechaLimite.toIso8601String(),
        'urgente': urgente ? 1 : 0,
        'pagado': pagado ? 1 : 0,
        'anclado': anclado ? 1 : 0,
      };

  GastoFijo copyWith({
    bool? pagado,
    bool? anclado,
    double? deudaPagada,
    DateTime? fechaLimite,
  }) =>
      GastoFijo(
        id: id,
        categoria: categoria,
        descripcion: descripcion,
        montoMensual: montoMensual,
        deudaTotal: deudaTotal,
        deudaPagada: deudaPagada ?? this.deudaPagada,
        fechaLimite: fechaLimite ?? this.fechaLimite,
        urgente: urgente,
        pagado: pagado ?? this.pagado,
        anclado: anclado ?? this.anclado,
      );
}

// ── PÁGINA ────────────────────────────────────────────────────────────────────
class GastosFijosPage extends StatefulWidget {
  const GastosFijosPage({super.key});

  @override
  State<GastosFijosPage> createState() => GastosFijosPageState();
}

class GastosFijosPageState extends State<GastosFijosPage> {
  List<GastoFijo> _items = [];
  String _vista          = 'Deudas';  // 'Deudas' | 'Ingresos'
  String _filtroEstado   = 'Todos';   // 'Todos' | 'Pendiente' | 'Pagado'
  String _filtroCategoria = 'Todas';  // 'Todas' | categoría
  final GlobalKey<IngresosPageState> _ingresosKey = GlobalKey();

  static const List<String> _categorias = ['Servicios', 'TC', 'Préstamos', 'Renta'];

  static const Map<String, IconData> _iconos = {
    'Servicios': Icons.receipt_long,
    'TC': Icons.credit_card,
    'Préstamos': Icons.account_balance,
    'Renta': Icons.home,
  };

  static const Map<String, Color> _colores = {
    'Servicios': Colors.teal,
    'TC': Colors.indigo,
    'Préstamos': Colors.orange,
    'Renta': Colors.brown,
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final maps = await DatabaseHelper.instance.obtenerGastosFijos();
    setState(() => _items = maps.map(GastoFijo.fromMap).toList());
  }

  // ── Totales resumen ───────────────────────────────────────────────────────

  // ── Filtrado ──────────────────────────────────────────────────────────────

  List<GastoFijo> get _itemsFiltrados {
    return _items.where((g) {
      // Filtro estado
      if (_filtroEstado == 'Pendiente' && g.pagado) return false;
      if (_filtroEstado == 'Pagado' && !g.pagado) return false;
      // Filtro categoría
      if (_filtroCategoria != 'Todas' && g.categoria != _filtroCategoria) return false;
      return true;
    }).toList();
  }

  double get _totalMensual => _items.fold(0, (s, g) => s + g.montoMensual);

  double get _totalDeudaPendiente => _items
      .where((g) => g.tieneDeuda)
      .fold(0, (s, g) => s + g.saldoPendiente);

  // ── Toggle anclado ────────────────────────────────────────────────────────

  Future<void> _toggleAnclado(GastoFijo g) async {
    final actualizado = g.copyWith(anclado: !g.anclado);
    await DatabaseHelper.instance.actualizarGastoFijo(actualizado.toMap());
    await _cargar();
  }

  // ── Toggle pagado / mensualidad ───────────────────────────────────────────

  // Calcula el mismo día en el mes siguiente (respeta meses cortos)
  DateTime _siguienteMes(DateTime fecha) {
    int anio = fecha.year;
    int mes = fecha.month + 1;
    if (mes > 12) { mes = 1; anio++; }
    final ultimoDia = DateTime(anio, mes + 1, 0).day;
    return DateTime(anio, mes, fecha.day.clamp(1, ultimoDia));
  }

  DateTime _mesAnterior(DateTime fecha) {
    int anio = fecha.year;
    int mes = fecha.month - 1;
    if (mes < 1) { mes = 12; anio--; }
    final ultimoDia = DateTime(anio, mes + 1, 0).day;
    return DateTime(anio, mes, fecha.day.clamp(1, ultimoDia));
  }

  Future<void> _togglePagado(GastoFijo g) async {
    final nuevoPagado = !g.pagado;
    double nuevaDeudaPagada = g.deudaPagada;

    if (g.tieneDeuda) {
      if (nuevoPagado) {
        nuevaDeudaPagada = (g.deudaPagada + g.montoMensual)
            .clamp(0, g.deudaTotal ?? double.infinity);
      } else {
        nuevaDeudaPagada =
            (g.deudaPagada - g.montoMensual).clamp(0, double.infinity);
      }
    }

    // Avanzar fecha al mes siguiente al pagar; retroceder si se desmarca
    final nuevaFecha =
        nuevoPagado ? _siguienteMes(g.fechaLimite) : _mesAnterior(g.fechaLimite);

    final actualizado = g.copyWith(
      pagado: nuevoPagado,
      deudaPagada: nuevaDeudaPagada,
      fechaLimite: nuevaFecha,
    );
    await DatabaseHelper.instance.actualizarGastoFijo(actualizado.toMap());
    await _cargar();
  }

  // ── Abono ─────────────────────────────────────────────────────────────────

  void _mostrarAbono(GastoFijo g) {
    final abonoCtrl = TextEditingController();
    bool esQuitar = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final double? monto = double.tryParse(abonoCtrl.text);
          final bool montoValido = monto != null && monto >= 100;

          // Vista previa del saldo resultante
          double? saldoResultante;
          if (montoValido) {
            if (esQuitar) {
              saldoResultante =
                  (g.deudaPagada - monto).clamp(0.0, double.infinity);
            } else {
              saldoResultante = (g.deudaPagada + monto)
                  .clamp(0.0, g.deudaTotal ?? double.infinity);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Movimiento de deuda',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Saldo actual ────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pagado',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                          Text('\$${g.deudaPagada.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Pendiente',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                          Text('\$${g.saldoPendiente.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Toggle Abonar / Quitar ───────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialog(() { esQuitar = false; abonoCtrl.clear(); });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !esQuitar ? Colors.green : Colors.grey.shade100,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(10)),
                            border: Border.all(
                                color: !esQuitar
                                    ? Colors.green
                                    : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline,
                                  size: 16,
                                  color: !esQuitar
                                      ? Colors.white
                                      : Colors.grey),
                              const SizedBox(width: 6),
                              Text('Abonar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !esQuitar
                                          ? Colors.white
                                          : Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialog(() { esQuitar = true; abonoCtrl.clear(); });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: esQuitar ? Colors.red : Colors.grey.shade100,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(10)),
                            border: Border.all(
                                color: esQuitar
                                    ? Colors.red
                                    : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.remove_circle_outline,
                                  size: 16,
                                  color:
                                      esQuitar ? Colors.white : Colors.grey),
                              const SizedBox(width: 6),
                              Text('Quitar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: esQuitar
                                          ? Colors.white
                                          : Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Campo monto ──────────────────────────────────
                TextField(
                  controller: abonoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setDialog(() {}),
                  decoration: InputDecoration(
                    labelText: esQuitar
                        ? 'Monto a quitar (mín. \$100)'
                        : 'Monto del abono (mín. \$100)',
                    prefixIcon: Icon(
                        esQuitar
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        color: esQuitar ? Colors.red : Colors.green),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: esQuitar ? Colors.red : Colors.green,
                          width: 2),
                    ),
                  ),
                ),

                // ── Vista previa ─────────────────────────────────
                if (montoValido && saldoResultante != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        esQuitar
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 14,
                        color: esQuitar ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        esQuitar
                            ? 'Pagado quedará: \$${saldoResultante.toStringAsFixed(2)}'
                            : 'Pendiente quedará: \$${(g.saldoPendiente - monto!).clamp(0, double.infinity).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: esQuitar ? Colors.red : Colors.green),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: esQuitar ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: montoValido
                    ? () async {
                        final nuevaDeudaPagada = esQuitar
                            ? (g.deudaPagada - monto!)
                                .clamp(0.0, double.infinity)
                                .toDouble()
                            : (g.deudaPagada + monto!)
                                .clamp(0.0, g.deudaTotal ?? double.infinity)
                                .toDouble();
                        final actualizado =
                            g.copyWith(deudaPagada: nuevaDeudaPagada);
                        await DatabaseHelper.instance
                            .actualizarGastoFijo(actualizado.toMap());
                        await _cargar();
                        Navigator.pop(ctx);
                      }
                    : null,
                child: Text(esQuitar ? 'Quitar abono' : 'Abonar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Navega directo a la vista Ingresos
  void irAIngresos() => setState(() => _vista = 'Ingresos');

  // Despacha el FAB a la vista activa
  void mostrarFormularioActual() {
    if (_vista == 'Ingresos') {
      _ingresosKey.currentState?.mostrarFormulario();
    } else {
      mostrarFormulario();
    }
  }

  // ── Formulario ────────────────────────────────────────────────────────────

  void mostrarFormulario({GastoFijo? editar}) {
    final esEdicion = editar != null;
    String categoria = editar?.categoria ?? 'Servicios';
    final descCtrl =
        TextEditingController(text: editar?.descripcion ?? '');
    final montoCtrl = TextEditingController(
        text: editar != null ? editar.montoMensual.toString() : '');
    final deudaCtrl = TextEditingController(
        text: editar?.deudaTotal != null ? editar!.deudaTotal.toString() : '');
    DateTime fechaLimite = editar?.fechaLimite ?? DateTime.now();
    bool urgente = editar?.urgente ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final tieneDeuda = categoria == 'TC' || categoria == 'Préstamos';
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Encabezado ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        esEdicion ? 'Editar gasto fijo' : 'Nuevo gasto fijo',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (esEdicion)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance
                                .eliminarGastoFijo(editar.id!);
                            await _cargar();
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Categoría ───────────────────────────────────
                  const Text('Categoría',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _categorias.map((cat) {
                      final activo = categoria == cat;
                      final color = _colores[cat]!;
                      return GestureDetector(
                        onTap: () => setModal(() => categoria = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: activo ? color : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: activo ? color : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconos[cat],
                                  size: 14,
                                  color: activo ? Colors.white : color),
                              const SizedBox(width: 6),
                              Text(cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: activo
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Descripción ─────────────────────────────────
                  TextField(
                    controller: descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon:
                          const Icon(Icons.notes, color: Colors.green),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Monto mensual ───────────────────────────────
                  TextField(
                    controller: montoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tieneDeuda ? 'Mensualidad' : 'Monto mensual',
                      prefixIcon: const Icon(Icons.attach_money,
                          color: Colors.green),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Deuda total (TC / Préstamos) ─────────────────
                  if (tieneDeuda) ...[
                    TextField(
                      controller: deudaCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Deuda total',
                        prefixIcon: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.orange),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Fecha límite ─────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: Colors.green),
                    title: Text(
                      'Vence: ${fechaLimite.day}/${fechaLimite.month}/${fechaLimite.year}',
                    ),
                    trailing: TextButton(
                      child: const Text('Cambiar'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: fechaLimite,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setModal(() => fechaLimite = d);
                      },
                    ),
                  ),

                  // ── Urgente ─────────────────────────────────────
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Urgente',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Marcar como pago prioritario'),
                    value: urgente,
                    activeColor: Colors.red,
                    onChanged: (v) => setModal(() => urgente = v),
                  ),
                  const SizedBox(height: 16),

                  // ── Guardar ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final monto = double.tryParse(montoCtrl.text);
                        if (monto == null ||
                            monto <= 0 ||
                            descCtrl.text.trim().isEmpty) return;
                        final deuda = tieneDeuda
                            ? double.tryParse(deudaCtrl.text)
                            : null;

                        final item = GastoFijo(
                          id: editar?.id,
                          categoria: categoria,
                          descripcion: descCtrl.text.trim(),
                          montoMensual: monto,
                          deudaTotal: deuda,
                          deudaPagada: editar?.deudaPagada ?? 0,
                          fechaLimite: fechaLimite,
                          urgente: urgente,
                          pagado: editar?.pagado ?? false,
                        );

                        if (esEdicion) {
                          await DatabaseHelper.instance
                              .actualizarGastoFijo(item.toMap());
                        } else {
                          await DatabaseHelper.instance
                              .insertarGastoFijo(item.toMap());
                        }
                        await _cargar();
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        esEdicion ? 'Actualizar' : 'Guardar',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtrados = _itemsFiltrados;
    final anclados = filtrados.where((g) => g.anclado).toList();
    final urgentes = filtrados.where((g) => !g.anclado && g.urgente && !g.pagado).toList();
    final resto    = filtrados.where((g) => !g.anclado && (!g.urgente || g.pagado)).toList();
    final ordenados = [...anclados, ...urgentes, ...resto];

    return Column(
      children: [
        // ── Toggle Deudas / Ingresos ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: ['Deudas', 'Ingresos'].map((v) {
              final activo = _vista == v;
              final color  = v == 'Ingresos' ? Colors.green : Colors.orange;
              final icono  = v == 'Ingresos' ? Icons.trending_up : Icons.receipt_long;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _vista = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: activo ? color : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: activo ? color : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icono, size: 16,
                            color: activo ? Colors.white : color),
                        const SizedBox(width: 6),
                        Text(v,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: activo ? Colors.white : Colors.grey.shade700,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Contenido según vista ─────────────────────────────────
        if (_vista == 'Ingresos')
          Expanded(child: IngresosPage(key: _ingresosKey)),

        if (_vista == 'Deudas') ...[
        // ── Filtros ──────────────────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // Grupo estado
              ...['Todos', 'Pendiente', 'Pagado'].map((op) {
                final activo = _filtroEstado == op;
                final color = op == 'Pagado'
                    ? Colors.green
                    : op == 'Pendiente'
                        ? Colors.orange
                        : Colors.grey.shade700;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(op),
                    selected: activo,
                    onSelected: (_) => setState(() => _filtroEstado = op),
                    selectedColor: color.withOpacity(0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: activo ? color : Colors.grey.shade600,
                      fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                        color: activo ? color : Colors.grey.shade300),
                    backgroundColor: Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }),
              // Separador
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: VerticalDivider(
                    color: Colors.grey.shade300, thickness: 1, width: 1),
              ),
              // Grupo categoría
              ...['Todas', ..._categorias].map((cat) {
                final activo = _filtroCategoria == cat;
                final color = cat == 'Todas'
                    ? Colors.grey.shade700
                    : _colores[cat]!;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: cat != 'Todas'
                        ? Icon(_iconos[cat], size: 13, color: activo ? color : Colors.grey)
                        : null,
                    label: Text(cat),
                    selected: activo,
                    onSelected: (_) => setState(() => _filtroCategoria = cat),
                    selectedColor: color.withOpacity(0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: activo ? color : Colors.grey.shade600,
                      fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                        color: activo ? color : Colors.grey.shade300),
                    backgroundColor: Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // ── Resumen ──────────────────────────────────────────────
        if (_items.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _resumenTile(
                    'Mensual total',
                    '\$${_totalMensual.toStringAsFixed(2)}',
                    Icons.calendar_month,
                    Colors.green,
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.green.withOpacity(0.2)),
                Expanded(
                  child: _resumenTile(
                    'Deuda pendiente',
                    '\$${_totalDeudaPendiente.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),

        // ── Lista ────────────────────────────────────────────────
        Expanded(
          child: ordenados.isEmpty
              ? const Center(
                  child: Text(
                    'Sin gastos fijos registrados',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: ordenados.length,
                  itemBuilder: (ctx, i) => _buildCard(ordenados[i]),
                ),
        ),
        ], // fin if Deudas
      ],
    );
  }

  Widget _resumenTile(
      String label, String valor, IconData icono, Color color) {
    return Column(
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(height: 4),
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _buildCard(GastoFijo g) {
    final color = _colores[g.categoria]!;
    final icono = _iconos[g.categoria]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: g.anclado ? 4 : (g.urgente && !g.pagado ? 3 : 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: g.anclado
            ? BorderSide(color: Colors.amber.shade600, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          // ── Cabecera ──────────────────────────────────────────
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icono, color: color),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(g.descripcion,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (g.urgente && !g.pagado) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('URGENTE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(g.categoria,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.event, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(
                    'Vence ${g.fechaLimite.day}/${g.fechaLimite.month}/${g.fechaLimite.year}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleAnclado(g),
                  child: Tooltip(
                    message: g.anclado ? 'Desanclar' : 'Anclar',
                    child: Icon(
                      g.anclado ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 20,
                      color: g.anclado ? Colors.amber.shade700 : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.grey, size: 20),
                  onPressed: () => mostrarFormulario(editar: g),
                ),
              ],
            ),
          ),

          // ── Deuda (TC / Préstamos) ────────────────────────────
          if (g.tieneDeuda && g.deudaTotal != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.deudaTotal! > 0
                          ? (g.deudaPagada / g.deudaTotal!).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: \$${g.deudaTotal!.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                      Text(
                        'Pagado: \$${g.deudaPagada.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                      Text(
                        'Resta: \$${g.saldoPendiente.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: g.saldoPendiente > 0 ? color : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Registrar abono',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: g.saldoPendiente > 0
                          ? () => _mostrarAbono(g)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Footer: monto mensual + toggle pagado ─────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${g.montoMensual.toStringAsFixed(2)}/mes',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green),
                ),
                Row(
                  children: [
                    Text(
                      g.pagado ? 'Pagado' : 'Pendiente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color:
                            g.pagado ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: g.pagado,
                      activeColor: Colors.green,
                      onChanged: (_) => _togglePagado(g),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
