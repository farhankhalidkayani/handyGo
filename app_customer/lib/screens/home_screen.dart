import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';
import 'ai_chat_screen.dart';
import 'ai_intake_screen.dart';
import 'language_select_screen.dart';
import 'notifications_screen.dart';
import 'offers_screen.dart';
import 'rating_screen.dart';
import 'safety_center_screen.dart';
import 'service_request_screen.dart';
import 'tracking_screen.dart';

IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('plumb')) return Icons.plumbing;
  if (n.contains('electr')) return Icons.bolt;
  if (n.contains('carpent')) return Icons.carpenter;
  if (n.contains('clean')) return Icons.cleaning_services;
  if (n.contains('ac') || n.contains('cooling')) return Icons.ac_unit;
  if (n.contains('appliance')) return Icons.kitchen;
  if (n.contains('paint')) return Icons.format_paint;
  if (n.contains('emergency')) return Icons.warning_amber_rounded;
  return Icons.handyman_outlined;
}

const _statusMeta = {
  BookingStatus.searchingWorkers: (label: 'Finding a worker', color: Colors.orange),
  BookingStatus.offersReceived: (label: 'Offers received', color: Colors.orange),
  BookingStatus.workerSelected: (label: 'Worker on the way', color: Colors.blue),
  BookingStatus.confirmed: (label: 'Confirmed', color: Colors.blue),
  BookingStatus.workerOnTheWay: (label: 'On the way', color: Colors.blue),
  BookingStatus.workerArrived: (label: 'Worker arrived', color: Colors.blue),
  BookingStatus.serviceStarted: (label: 'In progress', color: Colors.indigo),
  BookingStatus.inProgress: (label: 'In progress', color: Colors.indigo),
  BookingStatus.completionRequested: (label: 'Awaiting payment', color: Colors.deepPurple),
  BookingStatus.paymentPending: (label: 'Confirming payment', color: Colors.deepPurple),
  BookingStatus.completed: (label: 'Completed', color: Colors.green),
  BookingStatus.cancelled: (label: 'Cancelled', color: Colors.grey),
  BookingStatus.disputed: (label: 'Disputed', color: Colors.red),
  BookingStatus.refunded: (label: 'Refunded', color: Colors.grey),
};

class HomeScreen extends StatefulWidget {
  final UserProfile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Booking?> _activeBookingFuture;
  late Future<List<ServiceCategory>> _categoriesFuture;
  late Future<List<Booking>> _historyFuture;
  int _unreadCount = 0;
  String? _locationLabel;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeBookingFuture = AppServices.bookings.findActiveForCustomer(widget.profile.id);
    _categoriesFuture = AppServices.categories.listAll();
    _historyFuture = AppServices.bookings.listForCustomer(widget.profile.id);
    _loadUnreadCount();
    _loadLocation();
  }

  /// Plan §12 Customer checklist "Home: location, search, ...". Reverse-geocoding to a
  /// street address needs a geocoding API/package that isn't in this project (zero-cost
  /// scope) — shows raw coordinates instead, same simplification used for lat/lng elsewhere.
  Future<void> _loadLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) {
        setState(() => _locationLabel =
            '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}');
      }
    } catch (_) {
      // location is a nice-to-have display — never block the home screen on it
    }
  }

  void _openCategory(ServiceCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceRequestScreen(profile: widget.profile, initialCategoryId: category.id),
      ),
    );
  }

  void _openPastBooking(Booking booking) {
    if (booking.status == BookingStatus.completed && booking.ratingGiven == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RatingScreen(profile: widget.profile, bookingId: booking.id)),
      );
    }
  }

  /// "Recommended for you" — a customer's own most-booked category, distinct from "Popular"
  /// (all categories) and "Previous bookings" (a plain history list). Falls back to whatever
  /// category this customer hasn't tried yet if they have no history at all.
  List<ServiceCategory> _recommendedCategories(List<ServiceCategory> categories, List<Booking> history) {
    if (categories.isEmpty) return [];
    final counts = <String, int>{};
    for (final b in history) {
      counts[b.categoryId] = (counts[b.categoryId] ?? 0) + 1;
    }
    final sorted = [...categories]..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return sorted.where((c) => (counts[c.id] ?? 0) > 0).take(3).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final notifications = await AppServices.notifications.listForUser(widget.profile.id);
    if (!mounted) return;
    setState(() => _unreadCount = notifications.where((n) => !n.read).length);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsScreen(profile: widget.profile)),
    );
    _loadUnreadCount();
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
    } else if (booking.status == BookingStatus.searchingWorkers ||
        booking.status == BookingStatus.offersReceived) {
      // No worker selected yet — offers (if any) can only be seen/accepted from OffersScreen,
      // which is otherwise only reachable via the one-time push right after booking creation.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OffersScreen(profile: widget.profile, bookingId: booking.id),
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
    setState(() {
      _activeBookingFuture = AppServices.bookings.findActiveForCustomer(widget.profile.id);
    });
  }

  Future<void> _requestServiceManually() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceRequestScreen(profile: widget.profile)),
    );
    setState(() {
      _activeBookingFuture = AppServices.bookings.findActiveForCustomer(widget.profile.id);
    });
  }

  void _openAiChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiChatScreen(profile: widget.profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surface,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    widget.profile.name.isNotEmpty ? widget.profile.name[0].toUpperCase() : '?',
                    style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Handy Go'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_outlined),
                tooltip: 'Safety Center',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SafetyCenterScreen(profile: widget.profile)),
                ),
              ),
              IconButton(icon: const Icon(Icons.smart_toy_outlined), tooltip: 'AI Assistant', onPressed: _openAiChat),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: _openNotifications),
                  if (_unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          '$_unreadCount',
                          style: TextStyle(color: scheme.onError, fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Welcome, ${widget.profile.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                if (_locationLabel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_locationLabel!,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search for a service...',
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 20),
                FutureBuilder<Booking?>(
                  future: _activeBookingFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final booking = snapshot.data;
                    if (booking == null) return const SizedBox.shrink();
                    final needsRating = booking.status == BookingStatus.completed && booking.ratingGiven == null;
                    final meta = _statusMeta[booking.status];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _openActiveBooking(booking),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  needsRating ? Icons.star_rounded : Icons.local_shipping_outlined,
                                  color: scheme.onPrimary,
                                  size: 28,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        needsRating ? 'Rate your last service' : 'Active booking',
                                        style: TextStyle(
                                          color: scheme.onPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        meta?.label ?? booking.status.wire,
                                        style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: scheme.onPrimary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0);
                  },
                ),
                FilledButton.icon(
                  onPressed: _requestService,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Request a service'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _requestServiceManually,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Pick a category manually'),
                ),
                const SizedBox(height: 32),
                FutureBuilder<List<ServiceCategory>>(
                  future: _categoriesFuture,
                  builder: (context, catSnapshot) {
                    final categories = catSnapshot.data ?? [];
                    return FutureBuilder<List<Booking>>(
                      future: _historyFuture,
                      builder: (context, historySnapshot) {
                        final history = historySnapshot.data ?? [];
                        final recommended = _recommendedCategories(categories, history);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recommended.isNotEmpty) ...[
                              Text('Recommended for you', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 92,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: recommended.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (context, i) {
                                    final c = recommended[i];
                                    return _CategoryTile(
                                      category: c,
                                      highlight: true,
                                      onTap: () => _openCategory(c),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                            Text('Popular services', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 10),
                            Builder(builder: (context) {
                              final filtered = _searchQuery.isEmpty
                                  ? categories
                                  : categories.where((c) => c.name.toLowerCase().contains(_searchQuery)).toList();
                              if (categories.isEmpty) return const SizedBox.shrink();
                              if (filtered.isEmpty) return const Text('No matching services.');
                              return SizedBox(
                                height: 92,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (context, i) {
                                    final c = filtered[i];
                                    return _CategoryTile(category: c, onTap: () => _openCategory(c));
                                  },
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text('Previous bookings', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                FutureBuilder<List<Booking>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    final history = (snapshot.data ?? [])
                        .where((b) => [BookingStatus.completed, BookingStatus.cancelled, BookingStatus.refunded]
                            .contains(b.status))
                        .take(5)
                        .toList();
                    if (history.isEmpty) {
                      return Text(
                        'No previous bookings yet.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      );
                    }
                    return Column(
                      children: history.map((b) {
                        final meta = _statusMeta[b.status];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: (meta?.color ?? scheme.primary).withValues(alpha: 0.15),
                                child: Icon(_categoryIcon(b.problemText), color: meta?.color ?? scheme.primary, size: 20),
                              ),
                              title: Text(b.problemText, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (meta?.color ?? scheme.outline).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  meta?.label ?? b.status.wire,
                                  style: TextStyle(
                                    color: meta?.color ?? scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              trailing: b.status == BookingStatus.completed && b.ratingGiven == null
                                  ? const Icon(Icons.star_border)
                                  : null,
                              onTap: () => _openPastBooking(b),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;
  final bool highlight;

  const _CategoryTile({required this.category, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: highlight ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _categoryIcon(category.name),
                color: highlight ? scheme.onPrimaryContainer : scheme.primary,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: highlight ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
