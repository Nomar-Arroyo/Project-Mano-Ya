import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Servicio de Supabase Storage para las imágenes de Mano Ya.
///
/// Gestiona dos buckets públicos:
/// - `avatars`: foto de perfil de clientes y trabajadores.
/// - `portfolios`: fotografías de trabajos previos del portafolio express.
///
/// Cuando Supabase no está configurado el servicio devuelve `null` y la
/// interfaz conserva la ruta local del archivo, de modo que la app sigue
/// funcionando con normalidad en modo mock.
class SupabaseStorageService {
  SupabaseStorageService._();

  /// Bucket público donde se guardan las fotos de perfil.
  static const String avatarsBucket = 'avatars';

  /// Bucket público donde se guardan las fotos del portafolio del trabajador.
  static const String portfoliosBucket = 'portfolios';

  /// Indica si el almacenamiento de Supabase está disponible.
  static bool get isAvailable => SupabaseService.client != null;

  /// Sube una imagen a un bucket y devuelve su URL pública.
  ///
  /// Devuelve `null` cuando Supabase no está configurado o cuando la subida
  /// falla, para que la interfaz pueda conservar la referencia local.
  static Future<String?> uploadImage({
    required Uint8List bytes,
    required String bucket,
    required String userId,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final client = SupabaseService.client;
    if (client == null) return null;

    // La ruta se organiza por usuario: "<userId>/<timestamp>_<archivo>".
    // Esto facilita las políticas RLS por carpeta y evita nombres repetidos.
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Elimina un archivo previamente subido a un bucket.
  ///
  /// Los errores se ignoran de forma deliberada: borrar una imagen antigua no
  /// debe impedir que el usuario continúe con el flujo de perfil.
  static Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (_) {
      // Silencioso: el archivo puede haber sido borrado previamente.
    }
  }

  /// Construye la URL pública de un archivo que ya vive en el bucket.
  static String? publicUrl({required String bucket, required String path}) {
    final client = SupabaseService.client;
    if (client == null) return null;
    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Extrae la ruta interna de un archivo a partir de su URL pública.
  ///
  /// Las URLs de Supabase tienen la forma
  /// `<proyecto>/storage/v1/object/public/<bucket>/<ruta>`, por lo que la ruta
  /// interna es la parte posterior al nombre del bucket. Devuelve `null` si la
  /// URL no corresponde al bucket indicado.
  static String? pathFromPublicUrl({
    required String url,
    required String bucket,
  }) {
    final marker = '/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index == -1) return null;
    final path = url.substring(index + marker.length);
    return path.isEmpty ? null : path;
  }
}
