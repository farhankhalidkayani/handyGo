import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'dashboard_screen.dart';
import 'not_authorized_screen.dart';

/// Email-OTP login — same flow as the other two apps (plan §12), gated to `role == 'admin'`
/// after verification.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

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

      final profile = await AppServices.profiles.findByAuthId(authUser.$id);
      if (!mounted) return;

      if (profile != null && profile.role == UserRole.admin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const NotAuthorizedScreen()),
          (route) => false,
        );
      }
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
      appBar: AppBar(title: const Text('Handy Go — Admin login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_step == _Step.email) ...[
                  const Text('Enter your admin email — we will send you a one-time code.'),
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
        ),
      ),
    );
  }
}
