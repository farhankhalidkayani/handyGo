import 'package:appwrite/appwrite.dart';

import 'appwrite_config.dart';
import 'models/transaction.dart';

/// Read-only for the Admin Panel's finance audit (plan §12 "Payments & finance audit").
/// Every transaction is server-created only (transitionBooking.js) — no client write path.
class TransactionRepository {
  final Databases databases;

  TransactionRepository(Client client) : databases = Databases(client);

  Future<List<BookingTransaction>> listRecent({int limit = 100}) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.transactions,
      queries: [Query.orderDesc('\$createdAt'), Query.limit(limit)],
    );
    return res.documents.map((d) => BookingTransaction.fromMap({...d.data, '\$id': d.$id, '\$createdAt': d.$createdAt})).toList();
  }

  /// The invoice for a completed booking (plan §12 "Completion → invoice → payment").
  Future<BookingTransaction?> findForBooking(String bookingId) async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.transactions,
      queries: [Query.equal('bookingId', bookingId), Query.limit(1)],
    );
    if (res.documents.isEmpty) return null;
    final d = res.documents.first;
    return BookingTransaction.fromMap({...d.data, '\$id': d.$id, '\$createdAt': d.$createdAt});
  }
}
