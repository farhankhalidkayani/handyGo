import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'dashboard_screen.dart';
import 'under_review_screen.dart';
import 'worker_registration_screen.dart';

/// Decides where a logged-in worker lands: registration (no `users` doc yet), under-review
/// (registered but not yet approved), or the dashboard (approved). Shared by SplashScreen
/// (existing session) and AuthScreen (fresh OTP login) so the routing logic lives in one
/// place — see plan §12 Worker App checklist ("Registration ... → under-review state").
class PostAuthRouter extends StatefulWidget {
  final String authId;
  final String email;
  final String language;

  const PostAuthRouter({
    super.key,
    required this.authId,
    required this.email,
    required this.language,
  });

  @override
  State<PostAuthRouter> createState() => _PostAuthRouterState();
}

class _PostAuthRouterState extends State<PostAuthRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final userProfile = await AppServices.profiles.findByAuthId(widget.authId);
    if (!mounted) return;

    if (userProfile == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkerRegistrationScreen(
            authId: widget.authId,
            email: widget.email,
            language: widget.language,
          ),
        ),
      );
      return;
    }

    final workerProfile = await AppServices.profiles.findWorkerProfileByUserId(
      userProfile.id,
    );
    if (!mounted) return;

    if (workerProfile == null ||
        workerProfile.verificationStatus != 'approved') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UnderReviewScreen(
            status: workerProfile?.verificationStatus ?? 'incomplete',
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(profile: userProfile, worker: workerProfile),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
