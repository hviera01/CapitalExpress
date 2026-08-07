import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Sube fotos a Firebase Storage (mismo backend que la app Kotlin original,
/// que tambien usa Firebase Storage para las fotos de clientes/prestamos).
class StorageService {
  final _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  Future<String> subirFoto({
    required Uint8List bytes,
    required String carpeta,
  }) async {
    final ref = _storage.ref().child('$carpeta/${_uuid.v4()}.jpg');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}
