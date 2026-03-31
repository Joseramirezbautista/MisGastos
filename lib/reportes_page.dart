import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'gastos_fijos.dart';
import 'ingreso_page.dart';

// Modelo local para la gráfica
class GastoGrafica {
  final String categoria;
  final double monto;
  final Color color;

  GastoGrafica({required this.categoria, required this.monto, required this.color});
}

// ── PANTALLA DE REPORTES ──────────────────────────────────────────────────────
class ReportesPage extends StatefulWidget {
  final VoidCallback? onIrADeudas;
  final VoidCallback? onIrAIngresos;
  const ReportesPage({super.key, this.onIrADeudas, this.onIrAIngresos});

  @override
  State<ReportesPage> createState() => ReportesPageState();
}

class ReportesPageState extends State<ReportesPage> {
  List<GastoGrafica> _gastos = [];
  List<GastoFijo> _gastosFijos = [];
  double _totalFijosPeriodo = 0;
  double _totalDeudaPendiente = 0;
  double _totalDeudaOriginal = 0;
  double _totalDeudaPagada = 0;
  double _totalIngresosPeriodo = 0;

  // Período seleccionado
  String _periodo = 'Mensual'; // 'Diario', 'Mensual', 'Anual'
  DateTime _referencia = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarGastosFijos();
    _cargarIngresos();
  }

  void recargar() {
    _cargarDatos();
    _cargarGastosFijos();
    _cargarIngresos();
  }

  void _onPeriodoCambiado() {
    _cargarDatos();
    _actualizarFijosPeriodo();
    _cargarIngresos();
  }

  // ── Rango de fechas según período ─────────────────────────────────────────

  DateTime get _inicio {
    switch (_periodo) {
      case 'Diario':
        return DateTime(_referencia.year, _referencia.month, _referencia.day);
      case 'Anual':
        return DateTime(_referencia.year, 1, 1);
      case 'Mensual':
      default:
        return DateTime(_referencia.year, _referencia.month, 1);
    }
  }

  DateTime get _fin {
    switch (_periodo) {
      case 'Diario':
        return DateTime(_referencia.year, _referencia.month, _referencia.day, 23, 59, 59);
      case 'Anual':
        return DateTime(_referencia.year, 12, 31, 23, 59, 59);
      case 'Mensual':
      default:
        return DateTime(_referencia.year, _referencia.month + 1, 0, 23, 59, 59);
    }
  }

  String get _etiquetaPeriodo {
    switch (_periodo) {
      case 'Diario':
        return '${_referencia.day}/${_referencia.month}/${_referencia.year}';
      case 'Anual':
        return '${_referencia.year}';
      case 'Mensual':
      default:
        const meses = [
          '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
          'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
        ];
        return '${meses[_referencia.month]} ${_referencia.year}';
    }
  }

  // ── Navegación anterior / siguiente ───────────────────────────────────────

  void _anterior() {
    setState(() {
      switch (_periodo) {
        case 'Diario':
          _referencia = _referencia.subtract(const Duration(days: 1));
          break;
        case 'Anual':
          _referencia = DateTime(_referencia.year - 1, _referencia.month, _referencia.day);
          break;
        case 'Mensual':
        default:
          _referencia = DateTime(_referencia.year, _referencia.month - 1, 1);
      }
    });
    _cargarDatos();
  }

  void _siguiente() {
    setState(() {
      switch (_periodo) {
        case 'Diario':
          _referencia = _referencia.add(const Duration(days: 1));
          break;
        case 'Anual':
          _referencia = DateTime(_referencia.year + 1, _referencia.month, _referencia.day);
          break;
        case 'Mensual':
        default:
          _referencia = DateTime(_referencia.year, _referencia.month + 1, 1);
      }
    });
    _onPeriodoCambiado();
  }

  // ── Gastos fijos ───────────────────────────────────────────────────────────

  // Fecha real de pago = mes anterior a fechaLimite
  DateTime _fechaPago(GastoFijo f) {
    int year  = f.fechaLimite.year;
    int month = f.fechaLimite.month - 1;
    if (month < 1) { month = 12; year--; }
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, f.fechaLimite.day.clamp(1, lastDay));
  }

  Future<void> _cargarGastosFijos() async {
    final maps = await DatabaseHelper.instance.obtenerGastosFijos();
    final items = maps.map(GastoFijo.fromMap).toList();
    final conDeuda = items.where((g) => g.tieneDeuda).toList();
    setState(() {
      _gastosFijos        = items;
      _totalDeudaPendiente = conDeuda.fold(0, (s, g) => s + g.saldoPendiente);
      _totalDeudaOriginal  = conDeuda.fold(0, (s, g) => s + (g.deudaTotal ?? 0));
      _totalDeudaPagada    = conDeuda.fold(0, (s, g) => s + g.deudaPagada);
    });
    _actualizarFijosPeriodo();
  }

  void _actualizarFijosPeriodo() {
    final pagados = _gastosFijos.where((f) {
      if (!f.pagado) return false;
      final pago = _fechaPago(f);
      return pago.isAfter(_inicio.subtract(const Duration(seconds: 1))) &&
             pago.isBefore(_fin.add(const Duration(seconds: 1)));
    });
    setState(() {
      _totalFijosPeriodo = pagados.fold(0, (s, f) => s + f.montoMensual);
    });
  }

  Future<void> _cargarIngresos() async {
    final maps = await DatabaseHelper.instance.obtenerIngresos();
    final ingresos = maps.map(Ingreso.fromMap).toList();
    final filtrados = ingresos.where((i) =>
        i.fecha.isAfter(_inicio.subtract(const Duration(seconds: 1))) &&
        i.fecha.isBefore(_fin.add(const Duration(seconds: 1))));
    setState(() {
      _totalIngresosPeriodo = filtrados.fold(0, (s, i) => s + i.monto);
    });
  }

  // ── Carga y filtrado ───────────────────────────────────────────────────────

  Future<void> _cargarDatos() async {
    final todos      = await DatabaseHelper.instance.obtenerGastos();
    final gasolinaMaps = await DatabaseHelper.instance.obtenerGasolina();

    final filtrados = todos.where((g) =>
        g.fecha.isAfter(_inicio.subtract(const Duration(seconds: 1))) &&
        g.fecha.isBefore(_fin.add(const Duration(seconds: 1)))).toList();

    final gasolinaFiltrada = gasolinaMaps.where((m) {
      final fecha = DateTime.parse(m['fecha'] as String);
      return fecha.isAfter(_inicio.subtract(const Duration(seconds: 1))) &&
             fecha.isBefore(_fin.add(const Duration(seconds: 1)));
    });

    final totalPersonal = filtrados
        .where((g) => g.tipo == 'Personal')
        .fold<double>(0, (sum, g) => sum + g.monto);
    final totalEmpresa = filtrados
        .where((g) => g.tipo == 'Empresa')
        .fold<double>(0, (sum, g) => sum + g.monto);
    final totalGasolina = gasolinaFiltrada
        .fold<double>(0, (sum, m) => sum + (m['total'] as num).toDouble());

    setState(() {
      _gastos = [
        GastoGrafica(categoria: 'Personal', monto: totalPersonal, color: Colors.green),
        GastoGrafica(categoria: 'Empresa',  monto: totalEmpresa,  color: Colors.blue),
        GastoGrafica(categoria: 'Gasolina', monto: totalGasolina, color: Colors.orange),
      ];
    });
  }

  double get _total => _gastos.fold<double>(0, (sum, g) => sum + g.monto) + _totalFijosPeriodo;

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('JRB'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Selector de período ───────────────────────────────────
            Row(
              children: ['Diario', 'Mensual', 'Anual'].map((p) {
                final activo = _periodo == p;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _periodo = p;
                        _referencia = DateTime.now();
                      });
                      _onPeriodoCambiado();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: activo ? Colors.green : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: activo ? Colors.green : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        p,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: activo ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // ── Navegador anterior / siguiente ────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _anterior,
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.green,
                ),
                Text(
                  _etiquetaPeriodo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _siguiente,
                  icon: const Icon(Icons.chevron_right),
                  color: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Total gastado ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total gastado',
                    style: TextStyle(color: Colors.white70, fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Resumen gastos fijos ──────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gastos fijos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.onIrADeudas,
              child: Row(
                children: [
                  Expanded(
                    child: _buildFijoTile(
                      icono: Icons.calendar_month,
                      label: 'Deuda mensual',
                      valor: _totalFijosPeriodo,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFijoTile(
                      icono: Icons.account_balance_wallet,
                      label: 'Deuda Total',
                      valor: _totalDeudaPendiente,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Ingresos del período ──────────────────────────────────
            GestureDetector(
              onTap: widget.onIrAIngresos,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.trending_up, color: Colors.blue.shade700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ingresos del período',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text('\$${_totalIngresosPeriodo.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              )),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Balance', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        Text(
                          '\$${(_totalIngresosPeriodo - _total).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: (_totalIngresosPeriodo - _total) >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: Colors.blue.shade300),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Barra de progreso de deuda ────────────────────────────
            if (_totalDeudaOriginal > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progreso de deuda',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${((_totalDeudaOriginal - _totalDeudaPendiente) / _totalDeudaOriginal * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ((_totalDeudaOriginal - _totalDeudaPendiente) / _totalDeudaOriginal).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.orange.shade100,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pagado: \$${(_totalDeudaOriginal - _totalDeudaPendiente).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                        ),
                        Text(
                          'Pendiente: \$${_totalDeudaPendiente.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Desglose por categoría ────────────────────────────────
            ..._gastos.map((g) => _buildLeyendaItem(g)),

            if (_totalFijosPeriodo > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Deuda mensual pagada', style: TextStyle(fontSize: 15)),
                    ),
                    Text(
                      '\$${_totalFijosPeriodo.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFijoTile({
    required IconData icono,
    required String label,
    required double valor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\$${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeyendaItem(GastoGrafica g) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: g.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              g.categoria,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            '\$${g.monto.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
