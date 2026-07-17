import 'package:appwrite/appwrite.dart';

import 'appwrite_config.dart';

/// Plan §12 Customer App checklist: "Service request: manual / AI chatbot / image". Uploads
/// go straight to Storage from the client (problem_media grants create("users")); the
/// resulting file id is stored on the booking's problemImages array. Auto image-captioning
/// (feeding the photo into the AI intake classifier) needs a vision model and isn't wired up
/// — this covers photo attachment itself, which the booking/tracking UI can already display.
class MediaRepository {
  final Storage storage;

  MediaRepository(Client client) : storage = Storage(client);

  Future<String> uploadImage({required List<int> bytes, required String filename}) {
    return uploadFile(bytes: bytes, filename: filename);
  }

  /// Voice-note attachment for problem intake (plan's `bookings.voiceNoteUrl`) — attachment
  /// only, no on-device/server transcription (Vosk STT is a follow-up per the plan's own
  /// tiered AI-cost notes; text/photo intake already covers the MVP demo path).
  Future<String> uploadAudio({required List<int> bytes, required String filename}) {
    return uploadFile(bytes: bytes, filename: filename);
  }

  Future<String> uploadFile({required List<int> bytes, required String filename}) async {
    final file = await storage.createFile(
      bucketId: Buckets.problemMedia,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: bytes, filename: filename),
    );
    return file.$id;
  }

  String viewUrl(String fileId) {
    return '${HandyGoConfig.endpoint}/storage/buckets/${Buckets.problemMedia}/files/$fileId/view'
        '?project=${HandyGoConfig.projectId}';
  }
}
