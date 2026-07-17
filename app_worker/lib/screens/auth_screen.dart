import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'post_auth_router.dart';

/// Email-OTP login/signup — single flow for both, per plan §12.
class AuthScreen extends StatefulWidget {
  final String language;

  const AuthScreen({super.key, required this.language});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Step { email, otp }

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  _Step _step = _Step.email;
  String? _pendingUserId;
  bool _busy = false;
  String? _error;

  Future<void> _requestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final userId = await AppServices.auth.requestOtp(email);
      setState(() {
        _pendingUserId = userId;
        _step = _Step.otp;
      });
    } catch (e) {
      setState(() => _error = 'Could not send code: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _pendingUserId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.auth.verifyOtp(userId: _pendingUserId!, otp: otp);
      final authUser = await AppServices.auth.getCurrentUser();
      if (authUser == null) throw Exception('session not created');
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PostAuthRouter(
            authId: authUser.$id,
            email: authUser.email,
            language: widget.language,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Invalid or expired code: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in / Sign up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_step == _Step.email) ...[
              const Text('Enter your email — we will send you a one-time code.'),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 24),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: _busy ? null : _requestOtp,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Send code'),
              ),
            ] else ...[
              Text('Enter the code sent to ${_emailController.text.trim()}'),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
              const SizedBox(height: 24),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: _busy ? null : _verifyOtp,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Verify'),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _step = _Step.email),
                child: const Text('Use a different email'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
