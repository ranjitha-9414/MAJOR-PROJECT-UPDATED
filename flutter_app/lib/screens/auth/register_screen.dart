import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  String _userType = "Passenger";
  String? _department;

  bool _loading = false;

  final _departments = [
    "Technical",
    "Cleaning",
    "Infrastructure",
    "Safety",
    "Misconduct"
  ];

  late AnimationController _controller;
  late Animation<double> _trainSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

    _trainSlide = Tween<double>(begin: -0.7, end: 1.3)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.trim().isEmpty ||
        _confirmCtrl.text.trim().isEmpty) {
      _msg("All fields are required");
      return;
    }

    if (_passCtrl.text.trim() != _confirmCtrl.text.trim()) {
      _msg("Passwords do not match");
      return;
    }

    if (_userType == "Staff" && _department == null) {
      _msg("Select a department");
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final name = _nameCtrl.text.trim();

      // Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passCtrl.text.trim(),
      );

      await cred.user!.updateDisplayName(name);

      // Firestore Save
      await FirebaseFirestore.instance.collection("users").doc(cred.user!.uid).set({
        "uid": cred.user!.uid,
        "name": name,
        "email": email,
        "userType": _userType,
        "department": _userType == "Staff" ? _department : null,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // LOCAL SAVE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("current_user", email);
      await prefs.setString(
        "user_$email",
        jsonEncode({
          "name": name,
          "email": email,
          "role": _userType,
          "department": _department,
        }),
      );

      setState(() => _loading = false);

      // SUCCESS POPUP
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Success"),
          content: Text("Account created for $name."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, "/login"),
              child: const Text("Go to Login"),
            )
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      _msg(e.message ?? "Registration failed");
      setState(() => _loading = false);
    }
  }

  void _msg(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffD4EAFF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _RegBg())),

            Positioned(
              bottom: 310,
              left: 0,
              right: 0,
              height: 120,
              child: AnimatedBuilder(
                animation: _trainSlide,
                builder: (_, child) => FractionalTranslation(
                  translation: Offset(_trainSlide.value, 0),
                  child: child,
                ),
                child: const Icon(Icons.train, size: 90, color: Colors.red),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(22),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(blurRadius: 20, color: Colors.black26, offset: Offset(0, 8)),
                  ],
                ),

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Create Account",
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      _box(_nameCtrl, "Full Name"),
                      const SizedBox(height: 14),

                      _box(_emailCtrl, "Email"),
                      const SizedBox(height: 14),

                      _box(_passCtrl, "Password", isPassword: true),
                      const SizedBox(height: 14),

                      _box(_confirmCtrl, "Confirm Password", isPassword: true),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: _userType,
                        decoration: _dropdown("User Type"),
                        items: const [
                          DropdownMenuItem(value: "Passenger", child: Text("Passenger")),
                          DropdownMenuItem(value: "Staff", child: Text("Staff")),
                          DropdownMenuItem(value: "Admin", child: Text("Admin")),
                        ],
                        onChanged: (v) => setState(() => _userType = v!),
                      ),

                      if (_userType == "Staff")
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: DropdownButtonFormField<String>(
                            value: _department,
                            decoration: _dropdown("Select Department"),
                            items: _departments
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (v) => setState(() => _department = v),
                          ),
                        ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent, padding: const EdgeInsets.all(14)),
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Register", style: TextStyle(color: Colors.white)),
                        ),
                      ),

                      const SizedBox(height: 14),

                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, "/login"),
                        child: const Text("Already have an account? Login",
                            style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(TextEditingController c, String label, {bool isPassword = false}) {
    return TextField(
      controller: c,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  InputDecoration _dropdown(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[200],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }
}

class _RegBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();

    p.color = const Color(0xffC8E4FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), p);

    p.color = const Color(0xff7ED957);
    final hill = Path()
      ..moveTo(0, s.height * .58)
      ..quadraticBezierTo(s.width * .4, s.height * .45, s.width, s.height * .58)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height);

    canvas.drawPath(hill, p);

    p.color = Colors.white.withOpacity(.9);
    canvas.drawCircle(const Offset(120, 110), 30, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
