import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F8FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo o Icono
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xff1565C0),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(.20),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  "Buenos días 👋",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Bienvenido al Sistema\nde Monitoreo de Calidad del Aire",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff0D47A1),
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "E.S.E. Hospital Santa Cruz de Urumita",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 35),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.air_rounded,
                        size: 55,
                        color: Color(0xff1565C0),
                      ),

                      SizedBox(height: 18),

                      Text(
                        "Este sistema ha sido diseñado para apoyar el monitoreo de las condiciones ambientales dentro de las instalaciones del hospital, facilitando el acceso a la información y contribuyendo a la gestión de espacios seguros para pacientes, visitantes y personal de salud.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  "Utilice el menú de navegación para acceder a las diferentes funcionalidades del sistema.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffE3F2FD),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    "“Monitorear hoy es proteger la salud del mañana.”",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Color(0xff1565C0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                IconButton.filled(
                  onPressed: () {
                    context.go('/data');
                  },
                  icon: Icon(Icons.arrow_forward_sharp),
                ),

                const Text(
                  "Versión 1.0.0",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
