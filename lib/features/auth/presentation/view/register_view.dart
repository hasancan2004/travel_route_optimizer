import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../viewmodel/auth_cubit.dart';
import '../viewmodel/auth_state.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Koyu Tema Renk Paleti (Uygulamanın kalanıyla birebir uyumlu)
  final Color darkBg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);
  final Color inputBg = const Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          // DİKKAT: Artık kayıt olunca direkt ana ekrana atmıyoruz!
          // Supabase kayıt olduktan sonra kullanıcıya onay maili gönderir.
          // Bu yüzden kullanıcıyı Login ekranına geri (pop) gönderip bilgilendiriyoruz.
          if (state is Unauthenticated) {
            // Eğer state Unauthenticated olduysa ve kayıt işleminden geldiysek
            // (veya genel bir çıkış/kayıt durumu) kullanıcıyı bilgilendirip login'e atabiliriz.
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
                  // Başlık Alanı
                  const Icon(Icons.person_add_alt_1, size: 70, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Aramıza Katıl 🚀',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seyahat rotalarını buluta kaydetmek için hesap oluştur',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 36),

                  // Kayıt Form Kartı
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
                        const SizedBox(height: 16),

                        // Şifre Tekrar TextField
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Şifre (Tekrar)',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                            ),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Kayıt Ol Butonu
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            final confirmPassword = _confirmPasswordController.text.trim();

                            if (email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lütfen tüm alanları doldurun'), backgroundColor: Colors.orangeAccent),
                              );
                              return;
                            }

                            if (password != confirmPassword) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Şifreler birbiriyle uyuşmuyor!'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }

                            // 1. Cubit üzerinden kayıt sürecini tetikle
                            await context.read<AuthCubit>().signUp(email, password);

                            // Eğer işlem sırasında hata fırlatılmadıysa kullanıcıya bilgi ver ve Login'e dön
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Kayıt başarılı! Lütfen e-postanızı onaylayıp giriş yapın.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              // 2. Login ekranına geri dön
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Kayıt Ol', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Giriş Ekranına Dönüş
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Zaten hesabın var mı?', style: TextStyle(color: Colors.grey.shade400)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Giriş Yap', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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