import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'ai_chat_screen.dart';
import 'ai_intake_screen.dart';
import 'language_select_screen.dart';
import 'rating_screen.dart';
import 'service_request_screen.dart';
import 'tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Booking?> _activeBookingFuture;

  @override
  void initState() {
    super.initState();
    _activeBookingFuture = AppServices.bookings.findActiveForCustomer(widget.profile.id);
  }

  Future<void> _logout(BuildContext context) async {
    await AppServices.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LanguageSelectScreen()),
      (route) => false,
    );
  }

  void _openActiveBooking(Booking booking) {
    if (booking.status == BookingStatus.completed && booking.ratingGiven == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RatingScreen(profile: widget.profile, bookingId: booking.id),
        ),
      );
    } else if (booking.status != BookingStatus.completed) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrackingScreen(profile: widget.profile, bookingId: booking.id),
        ),
      );
    }
  }

  Future<void> _requestService() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiIntakeScreen(profile: widget.profile)),
    );
    setState(() => _activeBookingFuture = AppServices.bookings.findActiveForCustomer(widget.profile.id));
  }

  Future<void> _requestServiceManually() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceRequestScreen(profile: widget.profile)),
    );
    setState(() => _activeBookingFuture = AppServices.bookings.findActiveForCustomer(widget.profile.id));
  }

  void _openAiChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiChatScreen(profile: widget.profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Handy Go'),
        actions: [
          IconButton(icon: const Icon(Icons.smart_toy), tooltip: 'AI Assistant', onPressed: _openAiChat),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome, ${widget.profile.name}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            FutureBuilder<Booking?>(
              future: _activeBookingFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final booking = snapshot.data;
                if (booking == null) return const SizedBox.shrink();
                final needsRating = booking.status == BookingStatus.completed && booking.ratingGiven == null;
                return Card(
                  child: ListTile(
                    title: Text(needsRating ? 'Rate your last service' : 'Active booking'),
                    subtitle: Text(booking.status.wire),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openActiveBooking(booking),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _requestService, child: const Text('Request a service')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _requestServiceManually, child: const Text('Pick a category manually')),
          ],
        ),
      ),
    );
  }
}
