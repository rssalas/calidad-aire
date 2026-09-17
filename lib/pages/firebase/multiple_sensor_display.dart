import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class MultipleSensorDisplay extends StatefulWidget {
  const MultipleSensorDisplay({Key? key}) : super(key: key);

  @override
  _MultipleSensorDisplayState createState() => _MultipleSensorDisplayState();
}

class _MultipleSensorDisplayState extends State<MultipleSensorDisplay> {
  double? _humedad;
  double? _temperatura;
  double? _coRaw;
  double? _no2Raw;
  double? _pm10;
  double? _pm25;

  final _humedadRef = FirebaseDatabase.instance.ref('estado_actual/dht22/humedad');
  final _temperaturaRef = FirebaseDatabase.instance.ref('estado_actual/dht22/temperatura');
  final _coRawRef = FirebaseDatabase.instance.ref('estado_actual/mics4514/co_ppm');
  final _no2RawRef = FirebaseDatabase.instance.ref('estado_actual/mics4514/no2_ppm');
  final _pm10Ref = FirebaseDatabase.instance.ref('estado_actual/sds011/pm10');
  final _pm25Ref = FirebaseDatabase.instance.ref('estado_actual/sds011/pm25');

  late StreamSubscription<DatabaseEvent> _humedadSubscription;
  late StreamSubscription<DatabaseEvent> _temperaturaSubscription;
  late StreamSubscription<DatabaseEvent> _coRawSubscription;
  late StreamSubscription<DatabaseEvent> _no2RawSubscription;
  late StreamSubscription<DatabaseEvent> _pm10Subscription;
  late StreamSubscription<DatabaseEvent> _pm25Subscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _humedadSubscription.cancel();
    _temperaturaSubscription.cancel();
    _coRawSubscription.cancel();
    _no2RawSubscription.cancel();
    _pm10Subscription.cancel();
    _pm25Subscription.cancel();
    super.dispose();
  }

  void _startListening() {
    _humedadSubscription = _humedadRef.onValue.listen(
      (DatabaseEvent event) {
        final dynamic value = event.snapshot.value;
        if (event.snapshot.exists && value is num) {
          setState(() {
            _humedad = value.toDouble();
          });
        } else {
          setState(() {
            _humedad = null;
          });
          // Considera usar un logger en lugar de print para apps en producción
          print('No hay datos o valores invalidos de humedad');
        }
      },
      onError: (Object error) {
        print('Error al leer humedad: $error');
        setState(() {
          _humedad = null;
        });
      },
    );

    _temperaturaSubscription = _temperaturaRef.onValue.listen(
      (DatabaseEvent event) {
        final dynamic value = event.snapshot.value;
        if (event.snapshot.exists && value is num) {
          setState(() {
            _temperatura = value.toDouble();
          });
        } else {
          setState(() {
            _temperatura = null;
          });
          print('No hay datos o valores invalidos de temperatura');
        }
      },
      onError: (Object error) {
        print('Error al leer temperatura: $error');
        setState(() {
          _temperatura = null;
        });
      },
    );

    _coRawSubscription = _coRawRef.onValue.listen(
      (DatabaseEvent event) {
        final dynamic value = event.snapshot.value;
        if (event.snapshot.exists && value is num) {
          setState(() {
            _coRaw = value.toDouble();
          });
        } else {
          setState(() {
            _coRaw = null;
          });
          print('No hay datos o valores invalidos de co_raw');
        }
      },
      onError: (Object error) {
        print('Error al leer co_raw: $error');
        setState(() {
          _coRaw = null;
        });
      },
    );

    _no2RawSubscription = _no2RawRef.onValue.listen(
      (DatabaseEvent event) {
        final dynamic value = event.snapshot.value;
        if (event.snapshot.exists && value is num) {
          setState(() {
            _no2Raw = value.toDouble();
          });
        } else {
          setState(() {
            _no2Raw = null;
          });
          print('No hay datos o valores invalidos de no2_raw');
        }
      },
      onError: (Object error) {
        print('Error al leer no2_raw: $error');
        setState(() {
          _no2Raw = null;
        });
      },
    );

    _pm10Subscription = _pm10Ref.onValue.listen(
      (DatabaseEvent event) {
        final dynamic value = event.snapshot.value;
        if (event.snapshot.exists && value is num) {
          setState(() {
            _pm10 = value.toDouble();
          });
        } else {
          setState(() {
            _pm10 = null;
          });
          print('No hay datos o valores invalidos de pm10');
        }
      },
      onError: (Object error) {
        print('Error al leer pm10: $error');
        setState(() {
          _pm10 = null;
        });
      },
    );

    _pm25Subscription = _pm25Ref.onValue.listen(
      (DatabaseEvent event) {
        final dynamic value = event.snapshot.value;
        if (event.snapshot.exists && value is num) {
          setState(() {
            _pm25 = value.toDouble();
          });
        } else {
          setState(() {
            _pm25 = null;
          });
          print('No hay datos o valores invalidos de pm25');
        }
      },
      onError: (Object error) {
        print('Error al leer pm25: $error');
        setState(() {
          _pm25 = null;
        });
      },
    );
  }

  // Helper mejorado para mostrar un valor o un placeholder dentro de una Card
  Widget _buildSensorCard(
    String label,
    double? value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),

          const Spacer(),

          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),

          const SizedBox(height: 5),

          if (value != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: " $unit",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            const Text(
              "--",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),

          const SizedBox(height: 15),

          Container(
            height: 5,
            decoration: BoxDecoration(
              color: color.withOpacity(.18),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),

      crossAxisSpacing: 18,
      mainAxisSpacing: 18,

      childAspectRatio: .80,

      children: [
        _buildSensorCard(
          "Temperatura",
          _temperatura,
          "°C",
          Icons.thermostat_rounded,
          Colors.deepOrange,
        ),

        _buildSensorCard(
          "Humedad",
          _humedad,
          "%",
          Icons.water_drop_rounded,
          Colors.blue,
        ),

        _buildSensorCard("CO", _coRaw, "ppm", Icons.air, Colors.red),

        _buildSensorCard(
          "NO₂",
          _no2Raw,
          "ppm",
          Icons.science,
          Colors.deepPurple,
        ),

        _buildSensorCard("PM10", _pm10, "µg/m³", Icons.blur_on, Colors.green),

        _buildSensorCard("PM2.5", _pm25, "µg/m³", Icons.blur_on, Colors.teal),
      ],
    );
  }
}
