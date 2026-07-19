import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_services.dart';

const _terminalStatuses = [
  BookingStatus.completed,
  BookingStatus.cancelled,
  BookingStatus.refunded,
];

Color _statusColor(BookingStatus s) {
  switch (s) {
    case BookingStatus.completed:
      return Colors.green;
    case BookingStatus.cancelled:
    case BookingStatus.refunded:
      return Colors.grey;
    case BookingStatus.disputed:
      return Colors.red;
    case BookingStatus.searchingWorkers:
    case BookingStatus.offersReceived:
      return Colors.orange;
    default:
      return Colors.blue;
  }
}

/// Plan §12 Admin Panel checklist: "Booking management (full detail + audit history +
/// actions)" + §10.4 dispute resolution (raise a dispute off a non-terminal booking, then
/// resolve it to refunded/completed — both legal `disputed` exits per transitionBooking.js's
/// guard table).
class BookingsBody extends StatefulWidget {
  const BookingsBody({super.key});

  @override
  State<BookingsBody> createState() => _BookingsBodyState();
}

class _BookingsBodyState extends State<BookingsBody> {
  final List<Booking> _bookings = [];
  RealtimeSubscription? _subscription;
  bool _loading = true;
  String? _error;
  String? _adminAuthId;

  @override
  void initState() {
    super.initState();
    _load();
    AppServices.auth.getCurrentUser().then((u) {
      if (mounted) setState(() => _adminAuthId = u?.$id);
    });
    _subscription = AppServices.bookings.subscribeToBookings();
    _subscription!.stream.listen((event) {
      final payload = event.payload;
      final booking = Booking.fromMap(payload);
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == booking.id);
        if (i != -1) {
          _bookings[i] = booking;
        } else {
          _bookings.insert(0, booking);
        }
      });
    });
  }

  Future<void> _load() async {
    final bookings = await AppServices.bookings.listAllBookings();
    if (!mounted) return;
    setState(() {
      _bookings
        ..clear()
        ..addAll(bookings);
      _loading = false;
    });
  }

  Future<void> _transition(
    Booking booking,
    BookingStatus next, {
    String? confirmMessage,
  }) async {
    if (confirmMessage != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _error = null);
    try {
      await AppServices.bookings.transition(
        bookingId: booking.id,
        nextStatus: next,
        changedByRole: 'admin',
        changedById: _adminAuthId ?? 'admin',
      );
    } catch (e) {
      setState(() => _error = 'Action failed: $e');
    }
  }

  Future<void> _showDetail(Booking b) async {
    final history = await AppServices.bookings.listStatusHistory(b.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking detail'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  b.problemText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(b.addressText),
                Text('Category: ${b.categoryId}'),
                if (b.finalQuote != null)
                  Text('Quote: Rs. ${b.finalQuote!.toStringAsFixed(0)}'),
                if (b.workSummary != null && b.workSummary!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Work summary: ${b.workSummary}'),
                ],
                const Divider(height: 24),
                Text(
                  'Status history',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const Text('No history recorded yet.')
                else
                  ...history.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${h['status']} — ${h['changedByRole']} · ${h['timestamp'] ?? ''}'
                        '${(h['note'] as String?)?.isNotEmpty == true ? '\n  ${h['note']}' : ''}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _contact(String userId) async {
    setState(() => _error = null);
    try {
      final user = await AppServices.profiles.findById(userId);
      final phone = user?.phone;
      if (phone == null || phone.isEmpty) {
        setState(() => _error = 'No phone number on file for this user');
        return;
      }
      if (!await launchUrl(Uri(scheme: 'tel', path: phone))) {
        setState(() => _error = 'Could not launch phone dialer');
      }
    } catch (e) {
      setState(() => _error = 'Call failed: $e');
    }
  }

  Future<void> _reassign(Booking b) async {
    if (b.workerId == null) return;
    final workersRes = await AppServices.databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerProfiles,
      queries: [
        Query.equal('verificationStatus', 'approved'),
        Query.notEqual('userId', b.workerId!),
        Query.limit(50),
      ],
    );
    final candidates = workersRes.documents
        .map((d) => WorkerProfile.fromMap({...d.data, '\$id': d.$id}))
        .toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      setState(
        () => _error = 'No other approved workers available to reassign to',
      );
      return;
    }
    final chosen = await showDialog<WorkerProfile>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Reassign to which worker?'),
        children: candidates
            .map(
              (w) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(w),
                child: Text(
                  '${w.skills.join(', ')} · rating ${w.rating.toStringAsFixed(1)}',
                ),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !mounted) return;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for reassigning'),
        content: TextField(controller: reasonController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(reasonController.text.trim()),
            child: const Text('Reassign'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _error = null);
    try {
      await AppServices.reassignWorker(
        bookingId: b.id,
        newWorkerId: chosen.userId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking reassigned.')));
    } catch (e) {
      setState(() => _error = 'Reassign failed: $e');
    }
  }

  Future<void> _penalize(Booking b, {required bool worker}) async {
    final userId = worker ? b.workerId : b.customerId;
    if (userId == null) return;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Penalize this ${worker ? 'worker' : 'customer'}'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(reasonController.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _error = null);
    try {
      await AppServices.applyPenalty(
        bookingId: b.id,
        userId: userId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Penalty applied.')));
    } catch (e) {
      setState(() => _error = 'Penalty failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No bookings yet.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookings.length,
              itemBuilder: (context, i) {
                final b = _bookings[i];
                final statusColor = _statusColor(b.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showDetail(b),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.problemText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.addressText,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  b.status.wire,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (b.finalQuote != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Rs. ${b.finalQuote!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (b.status == BookingStatus.disputed) ...[
                                FilledButton(
                                  onPressed: () => _transition(
                                    b,
                                    BookingStatus.refunded,
                                    confirmMessage: 'Refund this booking?',
                                  ),
                                  child: const Text('Refund'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _transition(
                                    b,
                                    BookingStatus.completed,
                                    confirmMessage:
                                        'Mark completed (no refund)?',
                                  ),
                                  child: const Text('Mark completed'),
                                ),
                              ] else if (!_terminalStatuses.contains(b.status))
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                  ),
                                  onPressed: () => _transition(
                                    b,
                                    BookingStatus.disputed,
                                    confirmMessage:
                                        'Raise a dispute on this booking?',
                                  ),
                                  child: const Text('Raise dispute'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => _contact(b.customerId),
                                icon: const Icon(Icons.call, size: 16),
                                label: const Text('Call customer'),
                              ),
                              if (b.workerId != null) ...[
                                OutlinedButton.icon(
                                  onPressed: () => _contact(b.workerId!),
                                  icon: const Icon(Icons.call, size: 16),
                                  label: const Text('Call worker'),
                                ),
                                if (!_terminalStatuses.contains(b.status) &&
                                    b.status != BookingStatus.disputed)
                                  OutlinedButton(
                                    onPressed: () => _reassign(b),
                                    child: const Text('Reassign worker'),
                                  ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.deepOrange,
                                  ),
                                  onPressed: () => _penalize(b, worker: true),
                                  child: const Text('Penalize worker'),
                                ),
                              ],
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepOrange,
                                ),
                                onPressed: () => _penalize(b, worker: false),
                                child: const Text('Penalize customer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
