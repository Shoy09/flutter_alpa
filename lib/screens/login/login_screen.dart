import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:i_miner/config/data/database_helper.dart';
import 'package:i_miner/screens/Dash/reporte_sreen.dart';
import 'package:i_miner/services/api_service.dart';
import 'package:i_miner/services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  bool remember = true;
  bool obscureText = true;

  final TextEditingController dniController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool isLoading = false;

String errorMsg = '';

Future<void> handleLogin() async {
  setState(() {
    isLoading = true;
  });

  final dni = dniController.text.trim();
  final pass = passController.text.trim();

  try {

    /// 1️⃣ LOGIN ONLINE
    try {
      final token = await ApiService().login(dni, pass);

      Map<String, dynamic> userData;
      try {
        userData = await UserService().getUserProfile(token);
      } catch (profileError) {
        // Fallback: extraer datos básicos del payload del JWT
        print("⚠️ getUserProfile falló, usando payload JWT: $profileError");
        final payload = UserService().decodeTokenPayload(token);
        if (payload.isEmpty) rethrow;
        userData = payload;
      }

      await DatabaseHelper().setCurrentUserDni(dni);
      await DatabaseHelper().saveUser(userData, pass);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            token: token,
            dni: dni,
          ),
        ),
      );

      return;

    } catch (e) {
      // Mensaje limpio: quitar prefijo "Exception:" y stack traces
      final msg = e.toString().replaceFirst('Exception: ', '');
      errorMsg = msg;
      print("LOGIN ONLINE: $e");
    }

    /// 2️⃣ LOGIN OFFLINE
    try {
      await DatabaseHelper().setCurrentUserDni(dni);

      if (await DatabaseHelper().loginOffline(dni, pass)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              token: "offline",
              dni: dni,
            ),
          ),
        );
        return;
      }

    } catch (offlineError) {
      final msg = offlineError.toString().replaceFirst('Exception: ', '');
      errorMsg += '\nOffline: $msg';
      print("LOGIN OFFLINE: $offlineError");
    }

    /// 3️⃣ SI TODO FALLA
    _showLoginError(
      errorMsg.isNotEmpty
          ? errorMsg
          : 'Credenciales incorrectas o sin conexión.',
    );

  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

void _showLoginError(String error) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Error de inicio de sesión"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: SelectableText(
            error,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: error));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error copiado")),
            );
          },
          child: const Text("Copiar"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF2B8C99),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            /// LOGO
            Image.asset(
  'assets/images/logo.png',
  height: 70,
  width: 70,
),

            const SizedBox(height: 10),

            const Text(
              "Continuar con su usuario para iniciar sesión en la aplicación",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            /// USUARIO
            inputField(
              icon: Icons.email,
              hint: "Ingrese Usuario o id",
              controller: dniController,
              isPassword: false
            ),

            const SizedBox(height: 15),

            /// PASSWORD
            inputField(
              icon: Icons.lock,
              hint: "Ingrese la contraseña",
              controller: passController,
              isPassword: true
            ),

            const SizedBox(height: 15),

            /// RECORDARME
            Row(
              children: [
                Checkbox(
                  value: remember,
                  onChanged: (value){
                    setState(() {
                      remember = value!;
                    });
                  },
                  activeColor: Colors.white,
                ),

                const Text(
                  "Recordarme",
                  style: TextStyle(color: Colors.white),
                )
              ],
            ),

            const SizedBox(height: 30),

            /// SEPARADOR
            Row(
              children: const [
                Expanded(child: Divider(color: Colors.white70)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "SELECCIONE",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white70)),
              ],
            ),

            const SizedBox(height: 40),

            /// BOTONES
            Row(
              children: [

                Expanded(
                  child: button("Salir", () {
                    Navigator.pop(context);
                  }),
                ),

                const SizedBox(width: 20),

                Expanded(
  child: button(
    isLoading ? "Ingresando..." : "Ingresar",
    isLoading ? () {} : handleLogin,
  ),
),
              ],
            )

          ],
        ),
      ),
    );
  }

  Widget inputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    required bool isPassword
  }){

    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFF4FA4AE),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15),

      child: Row(
        children: [

          Icon(icon, color: Colors.white70),

          const SizedBox(width: 10),

          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword ? obscureText : false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70),
              ),
            ),
          ),

          if(isPassword)
GestureDetector(
  onTap: (){
    setState(() {
      obscureText = !obscureText;
    });
  },
  child: Icon(
    obscureText
        ? Icons.visibility
        : Icons.visibility_off,
    color: Colors.white70,
  ),
)
        ],
      ),
    );
  }

  Widget button(String text, VoidCallback onPressed){
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16
              ),
            ),
          ),
        ),
      ),
    );
  }
}