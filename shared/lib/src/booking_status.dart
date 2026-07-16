/// Single source of truth for booking status across all three apps (§16.4).
/// The wire value (stored in Appwrite) is the snake_case name below — Customer,
/// Worker and Admin apps must never invent their own status strings.
enum BookingStatus {
  draft,
  searchingWorkers,
  offersReceived,
  workerSelected,
  confirmed,
  workerOnTheWay,
  workerArrived,
  serviceStarted,
  inProgress,
  completionRequested,
  paymentPending,
  completed,
  cancelled,
  disputed,
  refunded,
}

extension BookingStatusWire on BookingStatus {
  static const _wireNames = {
    BookingStatus.draft: 'draft',
    BookingStatus.searchingWorkers: 'searching_workers',
    BookingStatus.offersReceived: 'offers_received',
    BookingStatus.workerSelected: 'worker_selected',
    BookingStatus.confirmed: 'confirmed',
    BookingStatus.workerOnTheWay: 'worker_on_the_way',
    BookingStatus.workerArrived: 'worker_arrived',
    BookingStatus.serviceStarted: 'service_started',
    BookingStatus.inProgress: 'in_progress',
    BookingStatus.completionRequested: 'completion_requested',
    BookingStatus.paymentPending: 'payment_pending',
    BookingStatus.completed: 'completed',
    BookingStatus.cancelled: 'cancelled',
    BookingStatus.disputed: 'disputed',
    BookingStatus.refunded: 'refunded',
  };

  String get wire => _wireNames[this]!;

  static BookingStatus fromWire(String value) => _wireNames.entries
      .firstWhere((e) => e.value == value, orElse: () => const MapEntry(BookingStatus.draft, 'draft'))
      .key;
}
