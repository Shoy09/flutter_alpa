import 'package:flutter/material.dart';
import 'package:i_miner/screens/Operaciones/Mediciones/horizontal/horizontal.dart';
import 'package:i_miner/screens/widgets/CompactReportButton%20.dart';

class Selecc_Tipo_explo_zona extends StatelessWidget {
  const Selecc_Tipo_explo_zona({super.key});

  void _navigateToNextScreen(BuildContext context, String zona) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistroExplosivoPagehorizontal(zona: zona),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operaciones Mineras'),
        backgroundColor: Color(0xFF21899C),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón MEDIA
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.15,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ExpandedReportButton(
                    title: 'ZONA MEDIA',
                    backgroundColor: const Color(0xFF21899C),
                    onPressed: () {
                      _navigateToNextScreen(context, 'MEDIA');
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 20),

              // Botón BAJA
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.15,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ExpandedReportButton(
                    title: 'ZONA BAJA',
                    backgroundColor: const Color(0xFF21899C),
                    onPressed: () {
                      _navigateToNextScreen(context, 'BAJA');
                    },
                  ),
                ),  
              ),

              const SizedBox(height: 20),

              // Botón HORIZONTE
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.15,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ExpandedReportButton(
                    title: 'ZONA HORIZONTE',
                    backgroundColor: const Color(0xFF21899C),
                    onPressed: () {
                      _navigateToNextScreen(context, 'HORIZONTE');
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
