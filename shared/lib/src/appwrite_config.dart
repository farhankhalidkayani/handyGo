import 'package:appwrite/appwrite.dart';

/// Central place the three apps build their Appwrite client from. Values come from
/// --dart-define at build time — never hard-code the project id/endpoint (§11, §16.1).
class HandyGoConfig {
  static const endpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://cloud.appwrite.io/v1',
  );
  static const projectId = String.fromEnvironment('APPWRITE_PROJECT', defaultValue: 'handygo');
  static const databaseId = String.fromEnvironment('APPWRITE_DB', defaultValue: 'handygo');

  static Client buildClient() {
    return Client()
      ..setEndpoint(endpoint)
      ..setSelfSigned(status: false)
      ..setProject(projectId);
  }
}

/// Collection ids — must match appwrite.json exactly.
class Collections {
  static const users = 'users';
  static const customerProfiles = 'customer_profiles';
  static const workerProfiles = 'worker_profiles';
  static const serviceCategories = 'service_categories';
  static const bookings = 'bookings';
  static const workerOffers = 'worker_offers';
  static const bookingStatusHistory = 'booking_status_history';
  static const messages = 'messages';
  static const notifications = 'notifications';
  static const transactions = 'transactions';
  static const walletWithdrawals = 'wallet_withdrawals';
  static const workerLocations = 'worker_locations';
  static const sosAlerts = 'sos_alerts';
  static const fraudReports = 'fraud_reports';
  static const aiLogs = 'ai_logs';
  static const analyticsDaily = 'analytics_daily';
}

/// Storage bucket ids — must match appwrite.json exactly.
class Buckets {
  static const problemMedia = 'problem_media';
}
