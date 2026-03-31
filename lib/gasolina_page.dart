import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'database_helper.dart';

// ── MODELO ────────────────────────────────────────────────────────────────────
class RegistroGasolina {
  final int? id;
  final String sitio;
  final DateTime fecha;
  final double km;
  final double total; // km × 3.1
  final String servicio; // 'Ticket' o 'Paquetería'

  RegistroGasolina({
    this.id,
    required this.sitio,
    required this.fecha,
    required this.km,
    required this.total,
    required this.servicio,
  });

  factory RegistroGasolina.fromMap(Map<String, dynamic> m) => RegistroGasolina(
        id:       m['id'] as int?,
        sitio:    m['sitio'] as String,
        fecha:    DateTime.parse(m['fecha'] as String),
        km:       (m['km'] as num).toDouble(),
        total:    (m['total'] as num).toDouble(),
        servicio: m['servicio'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sitio':    sitio,
        'fecha':    fecha.toIso8601String(),
        'km':       km,
        'total':    total,
        'servicio': servicio,
      };
}

// ── PÁGINA GASOLINA ───────────────────────────────────────────────────────────
class GasolinaPage extends StatefulWidget {
  const GasolinaPage({super.key});

  @override
  State<GasolinaPage> createState() => GasolinaPageState();
}

class GasolinaPageState extends State<GasolinaPage> {
  List<RegistroGasolina> _registros = [];
  DateTime _focusedDay  = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool get _usandoRango => _fechaInicio != null && _fechaFin != null;

  static const double _factor = 3.1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final maps = await DatabaseHelper.instance.obtenerGasolina();
    setState(() => _registros = maps.map(RegistroGasolina.fromMap).toList());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<RegistroGasolina> get _filtrados {
    if (_usandoRango) {
      final inicio = DateTime(_fechaInicio!.year, _fechaInicio!.month, _fechaInicio!.day);
      final fin    = DateTime(_fechaFin!.year,    _fechaFin!.month,    _fechaFin!.day, 23, 59, 59);
      return _registros.where((r) =>
          !r.fecha.isBefore(inicio) && !r.fecha.isAfter(fin)).toList();
    }
    return _registros.where((r) =>
        r.fecha.year  == _selectedDay.year  &&
        r.fecha.month == _selectedDay.month &&
        r.fecha.day   == _selectedDay.day).toList();
  }

  double get _totalDia => _filtrados.fold(0, (s, r) => s + r.total);

  double? _totalPorDia(DateTime dia) {
    final lista = _registros.where((r) =>
        r.fecha.year == dia.year &&
        r.fecha.month == dia.month &&
        r.fecha.day == dia.day);
    if (lista.isEmpty) return null;
    return lista.fold(0, (s, r) => s! + r.total);
  }

  Widget _buildDiaCell(DateTime day, double? total, bool sel, bool hoy) {
    Color fondo = Colors.transparent;
    Color texto = Colors.black;
    if (sel) { fondo = Colors.green; texto = Colors.white; }
    else if (hoy) { fondo = Colors.green.withOpacity(0.25); }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}',
              style: TextStyle(
                  color: texto,
                  fontWeight: hoy ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14)),
          if (total != null)
            Text(
              '\$${total >= 1000 ? '${(total / 1000).toStringAsFixed(1)}k' : total.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 9,
                  color: sel ? Colors.white : Colors.green,
                  fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  // ── Formulario ────────────────────────────────────────────────────────────

  void mostrarFormulario({RegistroGasolina? editar}) {
    final esEdicion = editar != null;
    final sitioCtrl = TextEditingController(text: esEdicion ? editar.sitio : '');
    final kmCtrl    = TextEditingController(text: esEdicion ? editar.km.toString() : '');
    String servicio = esEdicion ? editar.servicio : 'Ticket';
    DateTime fecha  = esEdicion ? editar.fecha : DateTime.now();
    double totalPreview = esEdicion ? editar.total : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) {
          void recalcular() {
            final km = double.tryParse(kmCtrl.text) ?? 0;
            setModal(() => totalPreview = km * _factor);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                        esEdicion ? 'Editar registro' : 'Nuevo registro',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (esEdicion)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance.eliminarGasolina(editar.id!);
                            await _cargar();
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Sitio ────────────────────────────────────────
                  TextField(
                    controller: sitioCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Sitio',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Fecha ────────────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.green),
                    title: Text(
                      '${fecha.day}/${fecha.month}/${fecha.year}  '
                      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: TextButton(
                      child: const Text('Cambiar'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(fecha),
                          );
                          if (t != null) {
                            setModal(() => fecha = DateTime(
                                d.year, d.month, d.day, t.hour, t.minute));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── KM ───────────────────────────────────────────
                  TextField(
                    controller: kmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => recalcular(),
                    decoration: InputDecoration(
                      labelText: 'Kilómetros',
                      prefixIcon: const Icon(Icons.speed, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Total calculado ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calculate_outlined, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Total (km × $_factor):  ',
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        Text(
                          '\$${totalPreview.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Servicio ─────────────────────────────────────
                  const Text('Servicio',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Ticket', 'Pack'].map((s) {
                      final activo = servicio == s;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModal(() => servicio = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                            decoration: BoxDecoration(
                              color: activo ? Colors.green : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: activo ? Colors.green : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    s == 'Ticket'
                                        ? Icons.receipt_long
                                        : Icons.inventory_2_outlined,
                                    color: activo ? Colors.white : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      s,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: activo ? Colors.white : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

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
                        final km = double.tryParse(kmCtrl.text);
                        if (km == null || km <= 0 || sitioCtrl.text.trim().isEmpty) return;

                        final registro = RegistroGasolina(
                          id:       esEdicion ? editar.id : null,
                          sitio:    sitioCtrl.text.trim(),
                          fecha:    fecha,
                          km:       km,
                          total:    km * _factor,
                          servicio: servicio,
                        );

                        if (esEdicion) {
                          await DatabaseHelper.instance.actualizarGasolina(registro.toMap());
                        } else {
                          await DatabaseHelper.instance.insertarGasolina(registro.toMap());
                        }
                        await _cargar();
                        Navigator.pop(context);
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

  Future<void> _eliminar(RegistroGasolina r) async {
    if (r.id != null) {
      await DatabaseHelper.instance.eliminarGasolina(r.id!);
      await _cargar();
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Calendario ────────────────────────────────────────────
        TableCalendar(
          locale: 'es_MX',
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (sel, foc) =>
              setState(() { _selectedDay = sel; _focusedDay = foc; }),
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(
              formatButtonVisible: false, titleCentered: true),
          calendarStyle: CalendarStyle(
            selectedDecoration: const BoxDecoration(
                color: Colors.green, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3), shape: BoxShape.circle),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (ctx, day, _) =>
                _buildDiaCell(day, _totalPorDia(day), false, false),
            selectedBuilder: (ctx, day, _) =>
                _buildDiaCell(day, _totalPorDia(day), true, false),
            todayBuilder: (ctx, day, _) =>
                _buildDiaCell(day, _totalPorDia(day), false, true),
          ),
        ),

        const Divider(),

        // ── Filtro por rango de fechas ─────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              // De:
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 15, color: Colors.green),
                  label: Text(
                    _fechaInicio != null
                        ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                        : 'Desde',
                    style: TextStyle(
                      fontSize: 13,
                      color: _fechaInicio != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: _fechaInicio != null ? Colors.green : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaInicio ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _fechaInicio = d);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('→', style: TextStyle(color: Colors.grey)),
              ),
              // Hasta:
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 15, color: Colors.green),
                  label: Text(
                    _fechaFin != null
                        ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                        : 'Hasta',
                    style: TextStyle(
                      fontSize: 13,
                      color: _fechaFin != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: _fechaFin != null ? Colors.green : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaFin ?? _fechaInicio ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _fechaFin = d);
                  },
                ),
              ),
              // Limpiar rango
              if (_usandoRango)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  tooltip: 'Limpiar filtro',
                  onPressed: () => setState(() { _fechaInicio = null; _fechaFin = null; }),
                ),
            ],
          ),
        ),

        // ── Total del período ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _usandoRango
                    ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}  –  '
                      '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                    : '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Total: \$${_totalDia.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
              ),
            ],
          ),
        ),

        // ── Lista ─────────────────────────────────────────────────
        Expanded(
          child: _filtrados.isEmpty
              ? const Center(
                  child: Text('Sin registros este día',
                      style: TextStyle(color: Colors.grey, fontSize: 15)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtrados.length,
                  itemBuilder: (ctx, i) {
                    final r = _filtrados[i];
                    return Dismissible(
                      key: ValueKey(r.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _eliminar(r),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(0.12),
                            child: const Icon(Icons.local_gas_station,
                                color: Colors.green),
                          ),
                          title: Text(r.sitio,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: r.servicio == 'Ticket'
                                      ? Colors.orange.withOpacity(0.12)
                                      : Colors.purple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r.servicio,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: r.servicio == 'Ticket'
                                        ? Colors.orange
                                        : Colors.purple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${r.km.toStringAsFixed(1)} km  •  '
                                '${r.fecha.hour.toString().padLeft(2, '0')}:${r.fecha.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${r.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => mostrarFormulario(editar: r),
                                child: const Icon(Icons.edit,
                                    color: Colors.grey, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
