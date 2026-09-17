import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/firebase/multiple_sensor_display.dart';
import 'package:go_router/go_router.dart';

class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DataScreenVIew();
  }
}

class _DataScreenVIew extends StatelessWidget {
  const _DataScreenVIew({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // focusColor: Color(0xff2563EB),
        // hoverColor: Color(0xff2563EB),
        backgroundColor: Color(0xff2563EB),
        child: Icon(Icons.home_filled, color: Colors.white),
        onPressed: () {
          context.go('/');
        },
      ),
      appBar: AppBar(
        title: Text(
          "Hospital Santa Cruz",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xff2563EB),
      ),
      body: Stack(
        children: [
          // Imagen de fondo con opacidad
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/imagenes/UNIVERSIDAD.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Si la imagen no carga, muestra un fondo gris para que no rompa la app
                  return Container(color: Colors.grey[200]);
                },
              ),
            ),
          ),
          // Contenido principal
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        // Text("Dashboard", style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),

                        // Text(
                        //   "Hospital Santa Cruz",
                        //   style: TextStyle(
                        //     fontSize: 30,
                        //     fontWeight: FontWeight.bold,
                        //   ),
                        // ),
                      ],
                    ),

                    // IconButton.filled(
                    //   onPressed: () => context.go('/'),
                    //   icon: const Icon(Icons.home_rounded),
                    // ),
                  ],
                ),

                const SizedBox(height: 30),

                // AQUÍ VA EL CUADRO NUEVO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Monitoreo Ambiental',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 8),

                            Text(
                              'Hospital Santa Cruz de Urumita',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xff2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            SizedBox(height: 12),

                            Text(
                              'Visualización en tiempo real de temperatura, humedad y calidad del aire.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xffEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.monitor_heart_rounded,
                          color: Color(0xff2563EB),
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Tarjetas de sensores
                const MultipleSensorDisplay(),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.go('/graficas'),
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Ver histórico y gráficas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // IconButton.filled(
          //     onPressed: () {
          //       context.go('/');
          //     },
          //     icon: Icon(Icons.home)
          //   )
        ],
      ),
      // bottomNavigationBar: BottomAppBar(
      //   child: Padding(
      //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      //       children: <Widget>[],
      //     ),
      //   ),
      // ),
    );
  }
}
