import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/error/app_exception.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

/// Inicio de sesión sin contraseña mediante código OTP.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _email = TextEditingController(text: 'ana@neobank.com');
  final _code = TextEditingController();
  OtpChallenge? _challenge;
  bool _requesting = false;
  bool _verifying = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      final challenge =
          await ref.read(authRepositoryProvider).requestOtp(_email.text.trim());
      setState(() => _challenge = challenge);
    } on AppException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (challenge == null) return;
    setState(() => _verifying = true);
    await ref.read(authControllerProvider.notifier).verifyOtp(
          challengeId: challenge.challengeId,
          code: _code.text.trim(),
        );
    if (mounted) setState(() => _verifying = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        final error = next.error;
        _showError(
          error is AppException ? error.message : 'Código inválido',
        );
      }
    });

    final challenge = _challenge;
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso con OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sms_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'Te enviaremos un código de 6 dígitos.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                enabled: challenge == null,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (challenge == null)
                FilledButton(
                  onPressed: _requesting ? null : _request,
                  child: _requesting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Enviar código'),
                )
              else ...[
                if (challenge.devCode != null)
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Código de desarrollo: ${challenge.devCode}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    prefixIcon: Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Verificar'),
                ),
                TextButton(
                  onPressed: () => setState(() => _challenge = null),
                  child: const Text('Usar otro email'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
