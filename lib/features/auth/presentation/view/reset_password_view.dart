import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Lütfen tüm alanları doldurun.', Colors.orangeAccent);
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('Şifre en az 6 karakter olmalıdır.', Colors.orangeAccent);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('Şifreler eşleşmiyor!', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        _showSnackBar('Şifreniz başarıyla güncellendi! ✅', Colors.green);
        // Kısa bir süre bekle, ardından login ekranına yönlendir
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showSnackBar('Hata: ${e.message}', Colors.redAccent);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Beklenmeyen hata: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Yeni Şifre Belirle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_reset, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                'Yeni şifrenizi belirleyin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen yeni şifrenizi girin ve onaylayın.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Şifreyi Onayla',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Şifreyi Güncelle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
