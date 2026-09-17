import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

FirebaseFirestore get _db =>
    FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

/// Consulta la coleccion promedios_10min en su resolucion NATIVA (sin
/// agrupar), para el rango [inicio, fin]. Se usa exclusivamente para
/// reportes descargables, nunca para las graficas en pantalla.
Future<List<Map<String, dynamic>>> obtenerDatosParaReporte(
  DateTime inicio,
  DateTime fin,
) async {
  final snapshot = await _db
      .collection('promedios_10min')
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
      .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(fin))
      .orderBy('timestamp')
      .get();

  return snapshot.docs.map((d) => d.data()).toList();
}

const List<String> _encabezados = [
  'N°',
  'Fecha y hora',
  'Temperatura (°C)',
  'Humedad (%)',
  'CO (ppm)',
  'NO2 (ppm)',
  'PM2.5 (µg/m³)',
  'PM10 (µg/m³)',
  'N° muestras',
  'Recuperado de buffer',
];

List<String> _filaDesdeDocumento(int numero, Map<String, dynamic> d) {
  final ts = d['timestamp'] as Timestamp?;
  final fecha = ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : '—';
  String val(dynamic v) => v == null ? '—' : v.toString();

  return [
    numero.toString(),
    fecha,
    val(d['temperatura']),
    val(d['humedad']),
    val(d['co_ppm']),
    val(d['no2_ppm']),
    val(d['pm25']),
    val(d['pm10']),
    val(d['n_muestras']),
    (d['recuperado_de_buffer'] == true) ? 'Sí' : 'No',
  ];
}

// ============================================================================
// EXPORTAR A CSV
// ============================================================================
Future<void> exportarCSV({
  required DateTime inicio,
  required DateTime fin,
}) async {
  final datos = await obtenerDatosParaReporte(inicio, fin);

  final filas = <List<String>>[_encabezados];
  for (int i = 0; i < datos.length; i++) {
    filas.add(_filaDesdeDocumento(i + 1, datos[i]));
  }

  final csv = const ListToCsvConverter().convert(filas);

  final dir = await getTemporaryDirectory();
  final nombreArchivo =
      'reporte_calidad_aire_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
  final archivo = File('${dir.path}/$nombreArchivo');
  await archivo.writeAsString(csv);

  await Share.shareXFiles(
    [XFile(archivo.path)],
    subject: 'Reporte de calidad del aire - Hospital Santa Cruz de Urumita',
    text:
        'Reporte del ${DateFormat('d MMM y').format(inicio)} al ${DateFormat('d MMM y').format(fin)}',
  );
}

// ============================================================================
// EXPORTAR A PDF
// ============================================================================
Future<void> exportarPDF({
  required DateTime inicio,
  required DateTime fin,
}) async {
  final datos = await obtenerDatosParaReporte(inicio, fin);

  final doc = pw.Document();

  // Estadisticas resumen (max, min, promedio) por variable, para la
  // portada del reporte - independiente de la tabla detallada.
  final resumen = _calcularResumen(datos);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Reporte de Calidad del Aire',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'E.S.E Hospital Santa Cruz de Urumita - Área de Urgencias',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Periodo: ${DateFormat('d MMM y HH:mm').format(inicio)} — ${DateFormat('d MMM y HH:mm').format(fin)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Generado: ${DateFormat('d MMM y HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Divider(),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 8),
        pw.Text('Resumen del periodo', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _tablaResumen(resumen),
        pw.SizedBox(height: 16),
        pw.Text(
          'Registros detallados (${datos.length})',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: _encabezados,
          data: [
            for (int i = 0; i < datos.length; i++) _filaDesdeDocumento(i + 1, datos[i]),
          ],
          headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 6.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.5),   // N°
            1: pw.FlexColumnWidth(1.8),   // Fecha y hora
            2: pw.FlexColumnWidth(1.0),   // Temperatura
            3: pw.FlexColumnWidth(1.0),   // Humedad
            4: pw.FlexColumnWidth(0.9),   // CO
            5: pw.FlexColumnWidth(0.9),   // NO2
            6: pw.FlexColumnWidth(1.0),   // PM2.5
            7: pw.FlexColumnWidth(1.0),   // PM10
            8: pw.FlexColumnWidth(0.8),   // N° muestras
            9: pw.FlexColumnWidth(1.1),   // Recuperado de buffer
          },
        ),
      ],
    ),
  );

  final nombreArchivo =
      'reporte_calidad_aire_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
  await Printing.sharePdf(bytes: await doc.save(), filename: nombreArchivo);
}

class _ResumenVariable {
  final String nombre;
  final String unidad;
  double? min, max, promedio;
  _ResumenVariable(this.nombre, this.unidad);
}

Map<String, _ResumenVariable> _calcularResumen(List<Map<String, dynamic>> datos) {
  final campos = {
    'temperatura': _ResumenVariable('Temperatura', '°C'),
    'humedad': _ResumenVariable('Humedad', '%'),
    'co_ppm': _ResumenVariable('CO', 'ppm'),
    'no2_ppm': _ResumenVariable('NO2', 'ppm'),
    'pm25': _ResumenVariable('PM2.5', 'µg/m³'),
    'pm10': _ResumenVariable('PM10', 'µg/m³'),
  };

  final sumas = <String, double>{};
  final conteos = <String, int>{};

  for (final d in datos) {
    for (final campo in campos.keys) {
      final v = d[campo];
      if (v is num) {
        final val = v.toDouble();
        sumas[campo] = (sumas[campo] ?? 0) + val;
        conteos[campo] = (conteos[campo] ?? 0) + 1;
        final r = campos[campo]!;
        r.min = (r.min == null) ? val : (val < r.min! ? val : r.min);
        r.max = (r.max == null) ? val : (val > r.max! ? val : r.max);
      }
    }
  }

  for (final campo in campos.keys) {
    if (conteos[campo] != null && conteos[campo]! > 0) {
      campos[campo]!.promedio = sumas[campo]! / conteos[campo]!;
    }
  }

  return campos;
}

pw.Widget _tablaResumen(Map<String, _ResumenVariable> resumen) {
  final filas = resumen.values.map((r) {
    String f(double? v) => v == null ? '—' : v.toStringAsFixed(2);
    return [r.nombre, f(r.min), f(r.promedio), f(r.max), r.unidad];
  }).toList();

  return pw.TableHelper.fromTextArray(
    headers: ['Variable', 'Mínimo', 'Promedio', 'Máximo', 'Unidad'],
    data: filas,
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 9),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
  );
}