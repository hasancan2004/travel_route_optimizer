import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:travel_route_optimizer/features/auth/presentation/view/register_view.dart';
import '../../../trip_optimizer/presentation/view/trip_form_view.dart';
import '../viewmodel/auth_cubit.dart';
import '../viewmodel/auth_state.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = true; // Beni hatırla seçeneği

  // Koyu Tema Renk Paleti (Uygulamanın kalanıyla uyumlu)
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);
  final Color inputBg = const Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    // Uygulama açıldığı an daha önce giriş yapılmış mı diye kontrol et ("Beni Hatırla")
    context.read<AuthCubit>().checkSession();
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Şifreni mi Unuttun? 🔑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: resetController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'E-posta Adresin',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('İptal', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                if (resetController.text.isNotEmpty) {
                  context.read<AuthCubit>().resetPassword(resetController.text.trim());
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Şifre sıfırlama bağlantısı e-postanıza gönderildi!')),
                  );
                }
              },
              child: const Text('Gönder', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            // Başarılı giriş durumunda ana ekrana yönlendir
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TripFormView()),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo veya Başlık Alanı
                  const Icon(Icons.travel_explore, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Trip Optimizer',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yapay Zeka Destekli Seyahat Rehberine Hoş Geldin',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 40),

                  // Form Kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // E-posta TextField
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'E-posta',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.email, color: Colors.blueAccent),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Şifre TextField
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Beni Hatırla & Şifremi Unuttum Satırı
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: Colors.blueAccent,
                                  onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                ),
                                const Text('Beni Hatırla', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                            TextButton(
                              onPressed: () => _showForgotPasswordDialog(context),
                              child: const Text('Şifremi Unuttum', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Giriş Yap Butonu
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            if (email.isNotEmpty && password.isNotEmpty) {
                              context.read<AuthCubit>().signIn(email, password);
                            }
                          },
                          child: const Text('Giriş Yap', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Kayıt Ol Yönlendirmesi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Hesabın yok mu?', style: TextStyle(color: Colors.grey.shade400)),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterView()),
                          );
                        },
                        child: const Text('Kayıt Ol', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}