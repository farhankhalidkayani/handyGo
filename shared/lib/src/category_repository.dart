import 'package:appwrite/appwrite.dart';

import 'appwrite_config.dart';
import 'models/service_category.dart';

class CategoryRepository {
  final Databases databases;

  CategoryRepository(Client client) : databases = Databases(client);

  Future<List<ServiceCategory>> listAll() async {
    final res = await databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.serviceCategories,
      queries: [Query.limit(100)],
    );
    return res.documents
        .map((d) => ServiceCategory.fromMap({...d.data, '\$id': d.$id}))
        .toList();
  }
}
