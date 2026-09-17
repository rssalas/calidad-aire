import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'export_service.dart';

// IMPORTANTE: la base de datos reservada "(default)" quedo en modo Datastore
// (incompatible), por eso toda consulta a Firestore en la app debe apuntar
// explicitamente a la base nombrada "default" (sin parentesis), igual que
// ya se hace en las Cloud Functions.
FirebaseFirestore get _db =>
    FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

// ============================================================================
// Definición de variables graficables
// ============================================================================
enum VariableSensor { temperatura, humedad, co, no2, pm25, pm10 }

class _InfoVariable {
  final String etiqueta;
  final String unidad;
  final Color color;
  const _InfoVariable(this.etiqueta, this.unidad, this.color);
}

const Map<VariableSensor, _InfoVariable> _infoVariables = {
  VariableSensor.temperatura: _InfoVariable('Temperatura', '°C', Color(0xFFFF7675)),
  VariableSensor.humedad: _InfoVariable('Humedad', '%', Color(0xFF74B9FF)),
  VariableSensor.co: _InfoVariable('Monóxido de Carbono', 'ppm', Color(0xFFFDCB6E)),
  VariableSensor.no2: _InfoVariable('Dióxido de Nitrógeno', 'ppm', Color(0xFFE17055)),
  VariableSensor.pm25: _InfoVariable('PM2.5', 'µg/m³', Color(0xFF00CEC9)),
  VariableSensor.pm10: _InfoVariable('PM10', 'µg/m³', Color(0xFF0984E3)),
};

/// Umbrales (advertencia, alarma) por variable — mismos valores usados en
/// el firmware del ESP32 (UMBRALES) y en la Cloud Function sincronizarYAlertar.
const Map<VariableSensor, (double advertencia, double alarma)> _umbrales = {
  VariableSensor.temperatura: (26, 30),
  VariableSensor.humedad: (60, 70),
  VariableSensor.co: (4, 8.7),
  VariableSensor.no2: (0.013, 0.027),
  VariableSensor.pm25: (15, 25),
  VariableSensor.pm10: (45, 75),
};

// ============================================================================
// Definición de rangos de tiempo y su resolución de agrupamiento
// ============================================================================
enum RangoTiempo { hora, dia, semana, mes }

class _InfoRango {
  final String etiqueta;
  final Duration duracion;
  final Duration resolucion;
  const _InfoRango(this.etiqueta, this.duracion, this.resolucion);
}

const Map<RangoTiempo, _InfoRango> _infoRangos = {
  RangoTiempo.hora: _InfoRango('1H', Duration(hours: 1), Duration(minutes: 10)),
  RangoTiempo.dia: _InfoRango('24H', Duration(days: 1), Duration(hours: 1)),
  RangoTiempo.semana: _InfoRango('7D', Duration(days: 7), Duration(hours: 12)),
  RangoTiempo.mes: _InfoRango('30D', Duration(days: 30), Duration(days: 1)),
};

// ============================================================================
// Punto de dato ya agrupado, listo para graficar
// ============================================================================
class _PuntoGrafica {
  final DateTime tiempo;
  final double valor;
  const _PuntoGrafica(this.tiempo, this.valor);
}

// ============================================================================
// Pantalla principal
// ============================================================================
class GraphsScreen extends StatefulWidget {
  const GraphsScreen({super.key});

  @override
  State<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {
  VariableSensor _variableSeleccionada = VariableSensor.pm25;
  RangoTiempo _rangoSeleccionado = RangoTiempo.dia;

  bool _cargando = false;
  String? _error;
  List<_PuntoGrafica> _puntos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // --------------------------------------------------------------------
  // Extrae el valor numérico correcto del documento según la variable
  // --------------------------------------------------------------------
  double? _extraerValor(Map<String, dynamic> datos, VariableSensor variable) {
    dynamic crudo;
    switch (variable) {
      case VariableSensor.temperatura:
        crudo = datos['temperatura'];
        break;
      case VariableSensor.humedad:
        crudo = datos['humedad'];
        break;
      case VariableSensor.co:
        crudo = datos['co_ppm'];
        break;
      case VariableSensor.no2:
        crudo = datos['no2_ppm'];
        break;
      case VariableSensor.pm25:
        crudo = datos['pm25'];
        break;
      case VariableSensor.pm10:
        crudo = datos['pm10'];
        break;
    }
    if (crudo == null) return null;
    if (crudo is num) return crudo.toDouble();
    return double.tryParse(crudo.toString());
  }

  // --------------------------------------------------------------------
  // Agrupa una lista de puntos crudos (10 min) en la resolución objetivo.
  // Si la resolución objetivo YA es 10 minutos, no se agrupa más.
  // --------------------------------------------------------------------
  List<_PuntoGrafica> _agruparPorResolucion(
    List<_PuntoGrafica> crudos,
    Duration resolucion,
  ) {
    if (crudos.isEmpty) return [];
    if (resolucion <= const Duration(minutes: 10)) return crudos;

    final List<_PuntoGrafica> resultado = [];
    DateTime inicioBucket = crudos.first.tiempo;
    double suma = 0;
    int n = 0;

    for (final punto in crudos) {
      if (punto.tiempo.difference(inicioBucket) >= resolucion) {
        if (n > 0) {
          resultado.add(_PuntoGrafica(inicioBucket, suma / n));
        }
        inicioBucket = punto.tiempo;
        suma = 0;
        n = 0;
      }
      suma += punto.valor;
      n++;
    }
    if (n > 0) {
      resultado.add(_PuntoGrafica(inicioBucket, suma / n));
    }
    return resultado;
  }

  // --------------------------------------------------------------------
  // Consulta Firestore y arma la serie de puntos ya agrupada
  // --------------------------------------------------------------------
  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await initializeDateFormatting('es_ES');

      final infoRango = _infoRangos[_rangoSeleccionado]!;
      final DateTime ahora = DateTime.now();
      final DateTime inicio = ahora.subtract(infoRango.duracion);

      final snapshot = await _db
          .collection('promedios_10min')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .orderBy('timestamp')
          .get();

      final List<_PuntoGrafica> crudos = [];
      for (final doc in snapshot.docs) {
        final datos = doc.data();
        final Timestamp? ts = datos['timestamp'] as Timestamp?;
        if (ts == null) continue;
        final valor = _extraerValor(datos, _variableSeleccionada);
        if (valor == null) continue;
        crudos.add(_PuntoGrafica(ts.toDate(), valor));
      }

      final agrupados = _agruparPorResolucion(crudos, infoRango.resolucion);

      setState(() {
        _puntos = agrupados;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar los datos. Verifique su conexión.';
        _cargando = false;
      });
      debugPrint('Error cargando gráfica: $e');
    }
  }

  void _cambiarVariable(VariableSensor v) {
    setState(() => _variableSeleccionada = v);
    _cargarDatos();
  }

  void _cambiarRango(RangoTiempo r) {
    setState(() => _rangoSeleccionado = r);
    _cargarDatos();
  }

  bool _exportando = false;

  Future<void> _exportar(String formato) async {
    final ahora = DateTime.now();
    final infoRangoActual = _infoRangos[_rangoSeleccionado]!;

    final rangoElegido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: ahora,
      initialDateRange: DateTimeRange(
        start: ahora.subtract(infoRangoActual.duracion),
        end: ahora,
      ),
      helpText: 'Seleccione el periodo a exportar',
      saveText: 'Exportar',
    );

    // El usuario canceló el selector: no hacer nada
    if (rangoElegido == null) return;

    // El selector solo da fechas (sin hora); se completa el día entero
    final inicio = DateTime(
      rangoElegido.start.year,
      rangoElegido.start.month,
      rangoElegido.start.day,
    );
    DateTime fin = DateTime(
      rangoElegido.end.year,
      rangoElegido.end.month,
      rangoElegido.end.day,
      23,
      59,
      59,
    );
    if (fin.isAfter(ahora)) fin = ahora;

    setState(() => _exportando = true);
    try {
      if (formato == 'pdf') {
        await exportarPDF(inicio: inicio, fin: fin);
      } else {
        await exportarCSV(inicio: inicio, fin: fin);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar el reporte. Intente de nuevo.')),
        );
      }
      debugPrint('Error exportando: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoVar = _infoVariables[_variableSeleccionada]!;

    return Scaffold(
      backgroundColor: const Color(0xffF4F8FB),
      appBar: AppBar(
        title: const Text(
          'Histórico y Gráficas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xff2563EB),
        actions: [
          if (_exportando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share, color: Colors.white),
              onSelected: _exportar,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'pdf', child: Text('Exportar como PDF')),
                PopupMenuItem(value: 'csv', child: Text('Exportar como CSV')),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff2563EB),
        child: const Icon(Icons.home_filled, color: Colors.white),
        onPressed: () => context.go('/'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SelectorVariable(
              seleccionada: _variableSeleccionada,
              onCambiar: _cambiarVariable,
            ),
            _SelectorRango(
              seleccionado: _rangoSeleccionado,
              onCambiar: _cambiarRango,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _EstadoError(mensaje: _error!, onReintentar: _cargarDatos)
                      : _puntos.isEmpty
                          ? const _EstadoVacio()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 20, 24),
                              child: _GraficaLinea(
                                puntos: _puntos,
                                color: infoVar.color,
                                unidad: infoVar.unidad,
                                rango: _rangoSeleccionado,
                                variable: _variableSeleccionada,
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Selector de variable (chips horizontales)
// ============================================================================
class _SelectorVariable extends StatelessWidget {
  final VariableSensor seleccionada;
  final ValueChanged<VariableSensor> onCambiar;

  const _SelectorVariable({required this.seleccionada, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: VariableSensor.values.map((v) {
          final info = _infoVariables[v]!;
          final activo = v == seleccionada;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(info.etiqueta),
              selected: activo,
              selectedColor: info.color.withOpacity(0.25),
              onSelected: (_) => onCambiar(v),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// Selector de rango (segmented buttons)
// ============================================================================
class _SelectorRango extends StatelessWidget {
  final RangoTiempo seleccionado;
  final ValueChanged<RangoTiempo> onCambiar;

  const _SelectorRango({required this.seleccionado, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<RangoTiempo>(
        segments: RangoTiempo.values
            .map((r) => ButtonSegment(value: r, label: Text(_infoRangos[r]!.etiqueta)))
            .toList(),
        selected: {seleccionado},
        onSelectionChanged: (nuevo) => onCambiar(nuevo.first),
      ),
    );
  }
}

// ============================================================================
// La gráfica de línea en sí (fl_chart)
// ============================================================================
class _GraficaLinea extends StatelessWidget {
  final List<_PuntoGrafica> puntos;
  final Color color;
  final String unidad;
  final RangoTiempo rango;
  final VariableSensor variable;

  const _GraficaLinea({
    required this.puntos,
    required this.color,
    required this.unidad,
    required this.rango,
    required this.variable,
  });

  String _formatoEtiqueta(DateTime t) {
    switch (rango) {
      case RangoTiempo.hora:
      case RangoTiempo.dia:
        return DateFormat('HH:mm').format(t);
      case RangoTiempo.semana:
        return DateFormat('E d', 'es').format(t);
      case RangoTiempo.mes:
        return DateFormat('d MMM', 'es').format(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < puntos.length; i++) FlSpot(i.toDouble(), puntos[i].valor),
    ];

    final umbral = _umbrales[variable];

    var minY = puntos.map((p) => p.valor).reduce((a, b) => a < b ? a : b);
    var maxY = puntos.map((p) => p.valor).reduce((a, b) => a > b ? a : b);

    // Si hay umbral definido, se asegura que el eje lo incluya siempre,
    // aunque los datos del periodo no lleguen tan alto.
    if (umbral != null && umbral.$2 > maxY) {
      maxY = umbral.$2;
    }

    final rangoDatos = (maxY - minY).abs();
    // El piso del margen ahora es proporcional al valor máximo del eje
    // (5%), no un numero fijo — antes un minimo de 0.5 aplastaba variables
    // de escala pequeña como NO2 (valores tipicos ~0.01-0.03 ppm).
    final pisoMargen = (maxY.abs() * 0.05).clamp(0.001, double.infinity);
    final margen = (rangoDatos * 0.15).clamp(pisoMargen, double.infinity);

    // Evita saturar el eje X de etiquetas cuando hay muchos puntos
    final pasoEtiquetas = (puntos.length / 6).ceil().clamp(1, puntos.length);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 24, 20, 12),
      child: LineChart(
        LineChartData(
          minY: (minY - margen),
          maxY: (maxY + margen),
          extraLinesData: umbral == null
              ? null
              : ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: umbral.$1, // advertencia
                      color: Colors.orange,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                        labelResolver: (line) => 'Advertencia (${umbral.$1})',
                      ),
                    ),
                    HorizontalLine(
                      y: umbral.$2, // alarma
                      color: Colors.redAccent,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.bottomRight,
                        style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        labelResolver: (line) => 'Alarma (${umbral.$2})',
                      ),
                    ),
                  ],
                ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ((maxY - minY).abs() / 4).clamp(pisoMargen / 2, double.infinity),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: pasoEtiquetas.toDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= puntos.length) return const SizedBox.shrink();
                  if (idx % pasoEtiquetas != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatoEtiqueta(puntos[idx].tiempo),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final idx = s.x.toInt();
                final t = puntos[idx].tiempo;
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(2)} $unidad\n${DateFormat('d MMM HH:mm', 'es').format(t)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: puntos.length <= 20),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.15)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Estados de carga / error / vacío
// ============================================================================
class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No hay datos suficientes en este rango todavía.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _EstadoError({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}