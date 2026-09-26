import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _signUpMode = false;
  bool _busy = false;
  String? _error;
  String? _resetMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _resetMessage = null;
    });
    try {
      if (_signUpMode) {
        await _auth.signUp(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
      } else {
        await _auth.signIn(_emailCtrl.text, _passCtrl.text);
      }
      // Navigation happens automatically via the authStateChanges stream in main.dart.
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = "Indique ton e-mail pour recevoir le lien de réinitialisation.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.resetPassword(_emailCtrl.text);
      setState(() => _resetMessage = "E-mail de réinitialisation envoyé, vérifie ta boîte de réception.");
    } catch (e) {
      setState(() => _error = e.toString());
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/logo.png', width: 36, height: 36),
                          const SizedBox(width: 10),
                          const Text('Recettes du Tiroir',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(child: _ModeTab(label: 'Connexion', selected: !_signUpMode, onTap: () => setState(() { _signUpMode = false; _error = null; _resetMessage = null; }))),
                            Expanded(child: _ModeTab(label: 'Créer un compte', selected: _signUpMode, onTap: () => setState(() { _signUpMode = true; _error = null; _resetMessage = null; }))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_signUpMode) ...[
                        const Text('PRÉNOM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft, letterSpacing: .5)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          autocorrect: false,
                        ),
                        const SizedBox(height: 14),
                      ],
                      const Text('E-MAIL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft, letterSpacing: .5)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 14),
                      const Text('MOT DE PASSE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft, letterSpacing: .5)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                      ],
                      if (_resetMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(_resetMessage!, style: const TextStyle(color: AppColors.herb, fontSize: 13)),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? '…' : (_signUpMode ? 'Créer mon compte' : 'Se connecter')),
                      ),
                      if (!_signUpMode) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected ? [const BoxShadow(color: Color(0x14000000), blurRadius: 3)] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
