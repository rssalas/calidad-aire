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
      appBar: AppBar(
        title: const Text(
          'E.S.E HOSPITAL SANTA CRUZ DE URUMITA.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15, // Ajustado ligeramente para que quepa mejor
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          // Imagen de fondo con opacidad
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
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
          const SingleChildScrollView(
            child: Center(child: MultipleSensorDisplay()),
          ),
          IconButton.filled(
              onPressed: () {
                context.go('/');
              },
              icon: Icon(Icons.home)
            )
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[],
          ),
        ),
      ),
    );
  }
}
