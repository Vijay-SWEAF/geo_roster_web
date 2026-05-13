import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final SupabaseClient _client = supabase;

  /// Upload a file to a given bucket and return the public URL.
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required File file,
    String contentType = 'image/jpeg',
  }) async {
    await _client.storage.from(bucket).upload(
          path,
          file,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Upload profile photo and return public URL.
  Future<String> uploadProfilePhoto(String userId, File file) =>
      uploadFile(
        bucket: 'profile-photos',
        path: '$userId/avatar.jpg',
        file: file,
        contentType: 'image/jpeg',
      );

  /// Upload a post/memory image and return public URL.
  Future<String> uploadPostImage(String postId, File file, {int index = 0}) =>
      uploadFile(
        bucket: 'post-images',
        path: '$postId/$index.jpg',
        file: file,
        contentType: 'image/jpeg',
      );

  /// Upload a memory archive image and return public URL.
  Future<String> uploadMemoryImage(String memoryId, File file,
          {bool isThen = true}) =>
      uploadFile(
        bucket: 'memory-archive',
        path: '$memoryId/${isThen ? "then" : "now"}.jpg',
        file: file,
        contentType: 'image/jpeg',
      );

  /// Upload audio for a story and return signed URL.
  Future<String> uploadStoryAudio(String storyId, File file) async {
    final path = '$storyId/audio.mp3';
    await _client.storage.from('story-audio').upload(
          path,
          file,
          fileOptions:
              const FileOptions(contentType: 'audio/mpeg', upsert: true),
        );
    final signedUrl = await _client.storage
        .from('story-audio')
        .createSignedUrl(path, 60 * 60 * 24 * 7); // 7 days
    return signedUrl;
  }

  /// Delete a file from a bucket.
  Future<void> deleteFile(String bucket, String path) async {
    await _client.storage.from(bucket).remove([path]);
  }
}
