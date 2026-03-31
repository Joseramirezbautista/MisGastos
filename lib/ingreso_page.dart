import 'package:flutter/material.dart';
import 'database_helper.dart';

// ── MODELO ────────────────────────────────────────────────────────────────────
class Ingreso {
  final int? id;
  final String categoria;
  final String descripcion;
  final double monto;
  final DateTime fecha;
  final String tipo;  // 'Personal' | 'Empresa'
  final String cobro; // 'Efectivo' | 'Transferencia' | 'Tarjeta'

  Ingreso({
    this.id,
    required this.categoria,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    this.tipo  = 'Personal',
    this.cobro = 'Efectivo',
  });

  factory Ingreso.fromMap(Map<String, dynamic> m) => Ingreso(
        id:          m['id'] as int?,
        categoria:   m['categoria'] as String,
        descripcion: m['descripcion'] as String? ?? '',
        monto:       (m['monto'] as num).toDouble(),
        fecha:       DateTime.parse(m['fecha'] as String),
        tipo:        m['tipo']  as String? ?? 'Personal',
        cobro:       m['cobro'] as String? ?? 'Efectivo',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'categoria':   categoria,
        'descripcion': descripcion,
        'monto':       monto,
        'fecha':       fecha.toIso8601String(),
        'tipo':        tipo,
        'cobro':       cobro,
      };
}

// ── PÁGINA INGRESOS ───────────────────────────────────────────────────────────
class IngresosPage extends StatefulWidget {
  const IngresosPage({super.key});

  @override
  State<IngresosPage> createState() => IngresosPageState();
}

class IngresosPageState extends State<IngresosPage> {
  List<Ingreso> _ingresos = [];

  static const List<String> _categorias = [
    'Sueldo', 'Freelance', 'Venta', 'Otro',
  ];

  static const Map<String, IconData> _iconos = {
    'Sueldo':    Icons.work_outline,
    'Freelance': Icons.computer,
    'Venta':     Icons.sell_outlined,
    'Otro':      Icons.category_outlined,
  };

  static const Map<String, Color> _colores = {
    'Sueldo':    Colors.green,
    'Freelance': Colors.blue,
    'Venta':     Colors.orange,
    'Otro':      Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final maps = await DatabaseHelper.instance.obtenerIngresos();
    setState(() => _ingresos = maps.map(Ingreso.fromMap).toList());
  }

  double get _totalMes {
    final ahora = DateTime.now();
    return _ingresos
        .where((i) => i.fecha.month == ahora.month && i.fecha.year == ahora.year)
        .fold(0, (s, i) => s + i.monto);
  }

  double get _totalGeneral => _ingresos.fold(0, (s, i) => s + i.monto);

  // ── Formulario ────────────────────────────────────────────────────────────

  void mostrarFormulario({Ingreso? editar}) {
    final esEdicion = editar != null;
    String categoria  = editar?.categoria ?? 'Sueldo';
    String tipo       = editar?.tipo       ?? 'Personal';
    String cobro      = editar?.cobro      ?? 'Efectivo';
    final montoCtrl   = TextEditingController(text: editar != null ? editar.monto.toString() : '');
    final descCtrl    = TextEditingController(text: editar?.descripcion ?? '');
    DateTime fecha    = editar?.fecha ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
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
                        esEdicion ? 'Editar ingreso' : 'Nuevo ingreso',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (esEdicion)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance.eliminarIngreso(editar.id!);
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
                      final color  = _colores[cat]!;
                      return GestureDetector(
                        onTap: () => setModal(() => categoria = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: activo ? color : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: activo ? color : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconos[cat], size: 14,
                                  color: activo ? Colors.white : color),
                              const SizedBox(width: 6),
                              Text(cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: activo ? Colors.white : Colors.grey.shade700,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Tipo Personal / Empresa ──────────────────────
                  const Text('Tipo', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Personal', 'Empresa'].map((t) {
                      final activo = tipo == t;
                      final color  = t == 'Empresa' ? Colors.blue : Colors.green;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModal(() => tipo = t),
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
                            child: Text(t,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: activo ? Colors.white : Colors.grey.shade600,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Forma de cobro ───────────────────────────────
                  const Text('Cobro', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ('Efectivo',     Colors.teal,   Icons.payments_outlined),
                      ('Transferencia',Colors.purple, Icons.swap_horiz),
                      ('Tarjeta',      Colors.indigo, Icons.credit_card_outlined),
                    ].map((e) {
                      final activo = cobro == e.$1;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModal(() => cobro = e.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: activo ? e.$2 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: activo ? e.$2 : Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Icon(e.$3, size: 16,
                                    color: activo ? Colors.white : e.$2),
                                const SizedBox(height: 2),
                                Text(e.$1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: activo ? Colors.white : Colors.grey.shade600,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Monto ────────────────────────────────────────
                  TextField(
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Descripción ──────────────────────────────────
                  TextField(
                    controller: descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      prefixIcon: const Icon(Icons.notes, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Fecha ────────────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: Colors.green),
                    title: Text('Fecha: ${fecha.day}/${fecha.month}/${fecha.year}'),
                    trailing: TextButton(
                      child: const Text('Cambiar'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setModal(() => fecha = d);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Guardar ──────────────────────────────────────
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
                        if (monto == null || monto <= 0) return;
                        final item = Ingreso(
                          id:          editar?.id,
                          categoria:   categoria,
                          descripcion: descCtrl.text.trim(),
                          monto:       monto,
                          fecha:       fecha,
                          tipo:        tipo,
                          cobro:       cobro,
                        );
                        if (esEdicion) {
                          await DatabaseHelper.instance.actualizarIngreso(item.toMap());
                        } else {
                          await DatabaseHelper.instance.insertarIngreso(item.toMap());
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
    final ahora = DateTime.now();
    final estesMes = _ingresos
        .where((i) => i.fecha.month == ahora.month && i.fecha.year == ahora.year)
        .toList();

    return Column(
      children: [
        // ── Resumen ──────────────────────────────────────────────
        if (_ingresos.isNotEmpty)
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
                Expanded(child: _resumenTile(
                  'Este mes',
                  '\$${_totalMes.toStringAsFixed(2)}',
                  Icons.calendar_month,
                  Colors.green,
                )),
                Container(width: 1, height: 40, color: Colors.green.withOpacity(0.2)),
                Expanded(child: _resumenTile(
                  'Total general',
                  '\$${_totalGeneral.toStringAsFixed(2)}',
                  Icons.account_balance_wallet,
                  Colors.blue,
                )),
              ],
            ),
          ),

        // ── Lista ────────────────────────────────────────────────
        Expanded(
          child: estesMes.isEmpty
              ? const Center(
                  child: Text('Sin ingresos este mes',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: estesMes.length,
                  itemBuilder: (ctx, i) => _buildCard(estesMes[i]),
                ),
        ),
      ],
    );
  }

  Widget _resumenTile(String label, String valor, IconData icono, Color color) {
    return Column(
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(height: 4),
        Text(valor,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _buildCard(Ingreso i) {
    final color = _colores[i.categoria]!;
    final icono = _iconos[i.categoria]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icono, color: color),
        ),
        title: Text(
          i.descripcion.isNotEmpty ? i.descripcion : i.categoria,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip(i.categoria, color),
              _chip(i.tipo, i.tipo == 'Empresa' ? Colors.blue : Colors.green),
              _chip(i.cobro, Colors.teal),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${i.monto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                Text(
                  '${i.fecha.day}/${i.fecha.month}/${i.fecha.year}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => mostrarFormulario(editar: i),
              child: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
