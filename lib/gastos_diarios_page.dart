import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import 'gasolina_page.dart';
import 'gastos_fijos.dart';

// ── MODELO ────────────────────────────────────────────────────────────────────
class Gasto {
  final int? id;
  final String categoria;
  final double monto;
  final String descripcion;
  final DateTime fecha;
  final String tipo;  // 'Personal' o 'Empresa'
  final String pago;  // 'Efectivo' o 'Tarjeta'

  Gasto({
    this.id,
    required this.categoria,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    this.tipo = 'Personal',
    this.pago = 'Efectivo',
  });
}

// ── PÁGINA GASTOS DIARIOS ─────────────────────────────────────────────────────
class GastosDiariosPage extends StatefulWidget {
  const GastosDiariosPage({super.key});

  @override
  State<GastosDiariosPage> createState() => GastosDiariosPageState();
}

class GastosDiariosPageState extends State<GastosDiariosPage> {
  List<Gasto> _gastos = [];
  List<GastoFijo> _gastosFijos = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String _filtroTipo  = 'Todos'; // 'Todos', 'Personal', 'Empresa'
  String _filtroPago  = 'Todos'; // 'Todos', 'Efectivo', 'Tarjeta'
  String _vistaFecha  = 'Dia';   // 'Dia' o 'Mes'
  String _vistaActual = 'Gastos'; // 'Gastos' o 'Gasolina'
  final GlobalKey<GasolinaPageState> _gasolinaKey = GlobalKey();

  static const List<String> _categorias = [
    'Comida', 'Transporte', 'Entretenimiento',
    'Servicios', 'Salud', 'Ropa', 'Otros',
  ];

  static const Map<String, IconData> _iconos = {
    'Comida':           Icons.restaurant,
    'Transporte':       Icons.directions_car,
    'Entretenimiento':  Icons.movie,
    'Servicios':        Icons.receipt_long,
    'Salud':            Icons.favorite,
    'Ropa':             Icons.checkroom,
    'Otros':            Icons.category,
  };

  static const Map<String, Color> _colores = {
    'Comida':           Colors.orange,
    'Transporte':       Colors.blue,
    'Entretenimiento':  Colors.purple,
    'Servicios':        Colors.teal,
    'Salud':            Colors.red,
    'Ropa':             Colors.pink,
    'Otros':            Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _cargarGastos();
    _cargarGastosFijos();
  }

  Future<void> _cargarGastos() async {
    final gastos = await DatabaseHelper.instance.obtenerGastos();
    setState(() => _gastos = gastos);
  }

  Future<void> _cargarGastosFijos() async {
    final maps = await DatabaseHelper.instance.obtenerGastosFijos();
    setState(() => _gastosFijos = maps.map(GastoFijo.fromMap).toList());
  }

  void recargarFijos() => _cargarGastosFijos();

  // ── MÉTODOS HELPER ────────────────────────────────────────────────────────

  List<Gasto> get _gastosFiltrados => _gastos.where((g) {
    final coincideFecha = _vistaFecha == 'Mes'
        ? g.fecha.month == _focusedDay.month && g.fecha.year == _focusedDay.year
        : g.fecha.day == _selectedDay.day &&
          g.fecha.month == _selectedDay.month &&
          g.fecha.year == _selectedDay.year;
    final mismoTipo = _filtroTipo == 'Todos' || g.tipo == _filtroTipo;
    final mismoPago = _filtroPago == 'Todos' || g.pago == _filtroPago;
    return coincideFecha && mismoTipo && mismoPago;
  }).toList();

  // Fecha real de pago = mes anterior a fechaLimite (porque al pagar avanza al siguiente)
  DateTime _fechaPago(GastoFijo f) {
    int year  = f.fechaLimite.year;
    int month = f.fechaLimite.month - 1;
    if (month < 1) { month = 12; year--; }
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, f.fechaLimite.day.clamp(1, lastDay));
  }

  // Gastos fijos visibles según la vista y fecha activa
  List<GastoFijo> get _gastosFijosVisibles => _gastosFijos.where((f) {
    if (!f.pagado) return false;
    final pago = _fechaPago(f);
    if (_vistaFecha == 'Mes') {
      return pago.month == _focusedDay.month && pago.year == _focusedDay.year;
    } else {
      return pago.day   == _selectedDay.day  &&
             pago.month == _selectedDay.month &&
             pago.year  == _selectedDay.year;
    }
  }).toList();

  double get _totalDiaSeleccionado {
    final totalGastos = _gastosFiltrados.fold<double>(0, (sum, g) => sum + g.monto);
    final totalFijos  = _gastosFijosVisibles.fold<double>(0, (sum, f) => sum + f.montoMensual);
    return totalGastos + totalFijos;
  }

  double? _getTotalPorDia(DateTime dia) {
    final gastosDia = _gastos.where((g) =>
    g.fecha.day == dia.day &&
        g.fecha.month == dia.month &&
        g.fecha.year == dia.year);
    if (gastosDia.isEmpty) return null;
    return gastosDia.fold(0, (sum, g) => sum! + g.monto);
  }

  String _nombreMes(DateTime fecha) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${meses[fecha.month]} ${fecha.year}';
  }

  Widget _buildDiaCell(DateTime day, double? total, bool seleccionado, bool esHoy) {
    Color fondo = Colors.transparent;
    Color textoColor = Colors.black;

    if (seleccionado) {
      fondo = Colors.green;
      textoColor = Colors.white;
    } else if (esHoy) {
      fondo = Colors.green.withOpacity(0.25);
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: textoColor,
              fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          if (total != null)
            Text(
              '\$${total >= 1000 ? '${(total / 1000).toStringAsFixed(1)}k' : total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 9,
                color: seleccionado ? Colors.white : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  // ── FORMULARIO ────────────────────────────────────────────────────────────

  void mostrarFormulario({Gasto? gastoEditar}) {
    final esEdicion = gastoEditar != null;
    final montoCtrl = TextEditingController(
        text: esEdicion ? gastoEditar.monto.toString() : '');
    final descCtrl = TextEditingController(
        text: esEdicion ? gastoEditar.descripcion : '');
    String categoriaSeleccionada =
    esEdicion ? gastoEditar.categoria : _categorias[0];
    String tipoSeleccionado =
    esEdicion ? gastoEditar.tipo : 'Personal';
    String pagoSeleccionado =
    esEdicion ? gastoEditar.pago : 'Efectivo';
    DateTime fechaSeleccionada =
    esEdicion ? gastoEditar.fecha : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        esEdicion ? 'Editar Gasto' : 'Agregar Gasto',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (esEdicion)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance
                                .eliminarGasto(gastoEditar.id!);
                            await _cargarGastos();
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Selector Personal / Empresa ────────────────────
                  Row(
                    children: ['Personal', 'Empresa'].map((tipo) {
                      final seleccionado = tipoSeleccionado == tipo;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => tipoSeleccionado = tipo),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: seleccionado ? Colors.green : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: seleccionado ? Colors.green : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  tipo == 'Personal' ? Icons.person : Icons.business,
                                  color: seleccionado ? Colors.white : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tipo,
                                  style: TextStyle(
                                    color: seleccionado ? Colors.white : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // ── Selector Efectivo / Tarjeta ────────────────────
                  Row(
                    children: ['Efectivo', 'Tarjeta'].map((metodo) {
                      final seleccionado = pagoSeleccionado == metodo;
                      final color = metodo == 'Tarjeta' ? Colors.indigo : Colors.teal;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => pagoSeleccionado = metodo),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: seleccionado ? color : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: seleccionado ? color : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  metodo == 'Efectivo'
                                      ? Icons.payments_outlined
                                      : Icons.credit_card,
                                  color: seleccionado ? Colors.white : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  metodo,
                                  style: TextStyle(
                                    color: seleccionado ? Colors.white : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      prefixIcon:
                      const Icon(Icons.attach_money, color: Colors.green),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon:
                      const Icon(Icons.category, color: Colors.green),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categorias
                        .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => categoriaSeleccionada = val!),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Descripción / Nota',
                      prefixIcon:
                      const Icon(Icons.notes, color: Colors.green),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today,
                        color: Colors.green),
                    title: Text(
                      '${fechaSeleccionada.day}/${fechaSeleccionada.month}/${fechaSeleccionada.year}  '
                          '${fechaSeleccionada.hour.toString().padLeft(2, '0')}:${fechaSeleccionada.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: TextButton(
                      child: const Text('Cambiar'),
                      onPressed: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (fecha != null) {
                          final hora = await showTimePicker(
                            context: context,
                            initialTime:
                            TimeOfDay.fromDateTime(fechaSeleccionada),
                          );
                          if (hora != null) {
                            setModalState(() {
                              fechaSeleccionada = DateTime(
                                fecha.year, fecha.month, fecha.day,
                                hora.hour, hora.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

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

                        final gasto = Gasto(
                          id:          esEdicion ? gastoEditar.id : null,
                          categoria:   categoriaSeleccionada,
                          monto:       monto,
                          descripcion: descCtrl.text,
                          fecha:       fechaSeleccionada,
                          tipo:        tipoSeleccionado,
                          pago:        pagoSeleccionado,
                        );

                        if (esEdicion) {
                          await DatabaseHelper.instance.actualizarGasto(gasto);
                        } else {
                          await DatabaseHelper.instance.insertarGasto(gasto);
                        }
                        await _cargarGastos();
                        Navigator.pop(context);
                      },
                      child: Text(
                        esEdicion ? 'Actualizar Gasto' : 'Guardar Gasto',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void mostrarFormularioActual() {
    if (_vistaActual == 'Gastos') {
      mostrarFormulario();
    } else {
      _gasolinaKey.currentState?.mostrarFormulario();
    }
  }

  Future<void> _eliminarGasto(Gasto gasto) async {
    if (gasto.id != null) {
      await DatabaseHelper.instance.eliminarGasto(gasto.id!);
      await _cargarGastos();
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  Widget _buildToggleVista() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: ['Gastos', 'Gasolina'].map((vista) {
          final activo = _vistaActual == vista;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _vistaActual = vista),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: activo ? Colors.green : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activo ? Colors.green : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      vista == 'Gastos'
                          ? Icons.list_alt
                          : Icons.local_gas_station,
                      color: activo ? Colors.white : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vista,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: activo ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Botones de vista ────────────────────────────────────
        _buildToggleVista(),
        const SizedBox(height: 4),

        // ── Contenido según vista ───────────────────────────────
        Expanded(
          child: _vistaActual == 'Gastos'
              ? _buildGastosView()
              : GasolinaPage(key: _gasolinaKey),
        ),
      ],
    );
  }

  Widget _buildGastosView() {
    return Column(
      children: [
        // ── Calendario ──────────────────────────────────────────
        TableCalendar(
          locale: 'es_MX', // 👈 agrega esta línea
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {CalendarFormat.week: 'Semana'},
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            selectedDecoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final total = _getTotalPorDia(DateTime(day.year, day.month, day.day));
              return _buildDiaCell(day, total, false, false);
            },
            selectedBuilder: (context, day, focusedDay) {
              final total = _getTotalPorDia(DateTime(day.year, day.month, day.day));
              return _buildDiaCell(day, total, true, false);
            },
            todayBuilder: (context, day, focusedDay) {
              final total = _getTotalPorDia(DateTime(day.year, day.month, day.day));
              return _buildDiaCell(day, total, false, true);
            },
          ),
        ),

        const Divider(),

        // ── Barra: fecha/mes + toggle Día|Mes + total ────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              // Etiqueta de fecha o mes
              Expanded(
                child: Text(
                  _vistaFecha == 'Mes'
                      ? _nombreMes(_focusedDay)
                      : '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              // Toggle Día / Mes
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['Dia', 'Mes'].map((v) {
                    final activo = _vistaFecha == v;
                    return GestureDetector(
                      onTap: () => setState(() => _vistaFecha = v),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: activo ? Colors.green : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          v,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: activo ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 10),
              // Total
              Text(
                '\$${_totalDiaSeleccionado.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
              ),
            ],
          ),
        ),

        // ── Filtros en chips deslizables ─────────────────────────
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // Tipo
              ...[
                ('Todos',    Colors.green,  null),
                ('Personal', Colors.green,  Icons.person_outline),
                ('Empresa',  Colors.blue,   Icons.business_outlined),
              ].map((e) {
                final activo = _filtroTipo == e.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: e.$3 != null ? Icon(e.$3, size: 15,
                        color: activo ? Colors.white : e.$2) : null,
                    label: Text(e.$1),
                    selected: activo,
                    onSelected: (_) => setState(() => _filtroTipo = e.$1),
                    selectedColor: e.$2,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: activo ? Colors.white : Colors.grey.shade700,
                    ),
                    side: BorderSide(
                      color: activo ? e.$2 : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    showCheckmark: false,
                  ),
                );
              }),

              // Separador
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: VerticalDivider(width: 1, color: Colors.grey.shade300),
              ),

              // Pago
              ...[
                ('Todos',    Colors.green,   null),
                ('Efectivo', Colors.teal,    Icons.payments_outlined),
                ('Tarjeta',  Colors.indigo,  Icons.credit_card_outlined),
              ].map((e) {
                final activo = _filtroPago == e.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: e.$3 != null ? Icon(e.$3, size: 15,
                        color: activo ? Colors.white : e.$2) : null,
                    label: Text(e.$1),
                    selected: activo,
                    onSelected: (_) => setState(() => _filtroPago = e.$1),
                    selectedColor: e.$2,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: activo ? Colors.white : Colors.grey.shade700,
                    ),
                    side: BorderSide(
                      color: activo ? e.$2 : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    showCheckmark: false,
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // ── Lista ────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            children: [
              if (_gastosFiltrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Sin gastos este día',
                        style: TextStyle(color: Colors.grey, fontSize: 15)),
                  ),
                ),
              ...List.generate(_gastosFiltrados.length, (index) {
                final g = _gastosFiltrados[index];
                return Dismissible(
                key: ValueKey(g.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _eliminarGasto(g),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      _colores[g.categoria]?.withOpacity(0.15),
                      child: Icon(_iconos[g.categoria],
                          color: _colores[g.categoria]),
                    ),
                    title: Text(g.categoria,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          g.descripcion.isNotEmpty ? g.descripcion : 'Sin nota',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: g.tipo == 'Empresa'
                                    ? Colors.blue.withOpacity(0.12)
                                    : Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                g.tipo,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: g.tipo == 'Empresa' ? Colors.blue : Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: g.pago == 'Tarjeta'
                                    ? Colors.indigo.withOpacity(0.12)
                                    : Colors.teal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    g.pago == 'Tarjeta'
                                        ? Icons.credit_card
                                        : Icons.payments_outlined,
                                    size: 10,
                                    color: g.pago == 'Tarjeta'
                                        ? Colors.indigo
                                        : Colors.teal,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    g.pago,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: g.pago == 'Tarjeta'
                                          ? Colors.indigo
                                          : Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${g.monto.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              _vistaFecha == 'Mes'
                                  ? '${g.fecha.day}/${g.fecha.month} · ${g.fecha.hour.toString().padLeft(2, '0')}:${g.fecha.minute.toString().padLeft(2, '0')}'
                                  : '${g.fecha.hour.toString().padLeft(2, '0')}:${g.fecha.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              mostrarFormulario(gastoEditar: g),
                          child: const Icon(Icons.edit,
                              color: Colors.grey, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              }),

              // ── Gastos Fijos ──────────────────────────────────
              if (_gastosFijosVisibles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Gastos fijos',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                ..._gastosFijosVisibles.map((f) => _buildCardFijo(f)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardFijo(GastoFijo f) {
    const iconos = {
      'Servicios': Icons.receipt_long,
      'TC':        Icons.credit_card,
      'Préstamos': Icons.account_balance,
      'Renta':     Icons.home,
    };
    const colores = {
      'Servicios': Colors.teal,
      'TC':        Colors.indigo,
      'Préstamos': Colors.orange,
      'Renta':     Colors.brown,
    };
    final color = colores[f.categoria] ?? Colors.grey;
    final icono = iconos[f.categoria] ?? Icons.category;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icono, color: color, size: 20),
        ),
        title: Text(f.descripcion.isNotEmpty ? f.descripcion : f.categoria,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Wrap(
          spacing: 6,
          children: [
            _chipFijo(f.categoria, color),
            _chipFijo(
              'Vence ${f.fechaLimite.day}/${f.fechaLimite.month}',
              Colors.grey,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${f.montoMensual.toStringAsFixed(2)}/mes',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: f.pagado ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                f.pagado ? 'Pagado' : 'Pendiente',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: f.pagado ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipFijo(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}