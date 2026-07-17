import 'package:appwrite/appwrite.dart';
import 'package:handygo_shared/handygo_shared.dart';

/// Single shared Appwrite client + service instances for the Customer app.
class AppServices {
  AppServices._();

  static final Client client = HandyGoConfig.buildClient();
  static final AuthService auth = AuthService(client);
  static final ProfileRepository profiles = ProfileRepository(client);
}
