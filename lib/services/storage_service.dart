import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Handles uploads to Firebase Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadPlacePhoto({
    required XFile file,
    required String userId,
    required String placeId,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = _storage.ref().child('place_photos/$placeId/$userId/$fileName');
    final uploadTask = await ref.putFile(File(file.path));
    return uploadTask.ref.getDownloadURL();
  }
}
