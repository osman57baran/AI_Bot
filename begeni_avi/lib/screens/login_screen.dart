import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _emailMode = false;
  bool _register = false;
  bool _busy = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  Future<void> _do(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Logo(),
              const SizedBox(height: 12),
              const Text(
                'Arkadaşlarının TikTok beğenilerini izle,\nkimin beğendiğini tahmin et!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 40),
              if (!_emailMode) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: _busy ? null : () => _do(AuthService.signInWithGoogle),
                  icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                  label: const Text('Google ile devam et'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => setState(() => _emailMode = true),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('E-posta ile devam et'),
                ),
              ] else ...[
                if (_register) ...[
                  TextField(controller: _name, decoration: const InputDecoration(hintText: 'Adın (oyunda görünecek)')),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'E-posta'),
                ),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(hintText: 'Şifre')),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _do(() => _register
                          ? AuthService.register(
                              _name.text.trim().isEmpty ? _email.text.split('@').first : _name.text,
                              _email.text,
                              _pass.text,
                            )
                          : AuthService.signInWithEmail(_email.text, _pass.text)),
                  child: Text(_register ? 'Kayıt ol' : 'Giriş yap'),
                ),
                TextButton(
                  onPressed: () => setState(() => _register = !_register),
                  child: Text(_register ? 'Zaten hesabın var mı? Giriş yap' : 'Hesabın yok mu? Kayıt ol'),
                ),
                TextButton(
                  onPressed: () => setState(() => _emailMode = false),
                  child: const Text('← Geri', style: TextStyle(color: AppColors.muted)),
                ),
              ],
              if (_busy) const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator())),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        Transform.translate(offset: const Offset(-3, -3), child: const Icon(Icons.favorite, size: 96, color: AppColors.cyan)),
        Transform.translate(offset: const Offset(3, 3), child: const Icon(Icons.favorite, size: 96, color: AppColors.pink)),
        const Icon(Icons.favorite, size: 96, color: Colors.white),
        const Text('?', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppColors.bg)),
      ]),
      const SizedBox(height: 12),
      const Text('Beğeni Avı', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
    ]);
  }
}
