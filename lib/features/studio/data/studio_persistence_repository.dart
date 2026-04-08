import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/studio_message.dart';

final studioPersistenceRepositoryProvider =
    Provider<StudioPersistenceRepository>((ref) {
      return const StudioPersistenceRepository();
    });

class StudioPreferences {
  const StudioPreferences({
    this.lastActiveModelId,
    this.preferGpu = false,
    this.enableThinking = false,
  });

  final String? lastActiveModelId;
  final bool preferGpu;
  final bool enableThinking;
}

class StudioPersistenceRepository {
  const StudioPersistenceRepository();

  static const _rootDirectoryName = 'gemma_studio';
  static const _schemaVersion = 1;
  static const _lastActiveModelIdKey = 'studio.last_active_model_id';
  static const _preferGpuKey = 'studio.prefer_gpu';
  static const _enableThinkingKey = 'studio.enable_thinking';

  Future<StudioPreferences> loadPreferences() async {
    final prefs = SharedPreferencesAsync();
    return StudioPreferences(
      lastActiveModelId: await prefs.getString(_lastActiveModelIdKey),
      preferGpu: await prefs.getBool(_preferGpuKey) ?? false,
      enableThinking: await prefs.getBool(_enableThinkingKey) ?? false,
    );
  }

  Future<void> savePreferences(StudioPreferences preferences) async {
    final prefs = SharedPreferencesAsync();

    if (preferences.lastActiveModelId == null ||
        preferences.lastActiveModelId!.isEmpty) {
      await prefs.remove(_lastActiveModelIdKey);
    } else {
      await prefs.setString(
        _lastActiveModelIdKey,
        preferences.lastActiveModelId!,
      );
    }

    await prefs.setBool(_preferGpuKey, preferences.preferGpu);
    await prefs.setBool(_enableThinkingKey, preferences.enableThinking);
  }

  Future<List<StudioMessage>> loadConversation(String modelId) async {
    try {
      final file = await _conversationFile(modelId);
      if (!await file.exists()) {
        return const <StudioMessage>[];
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <StudioMessage>[];
      }

      final messages = decoded['messages'];
      if (messages is! List) {
        return const <StudioMessage>[];
      }

      final attachmentsDirectory = await _attachmentsDirectory(modelId);
      final restored = <StudioMessage>[];

      for (final item in messages) {
        if (item is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(item);
        final roleName = map['role'] as String? ?? StudioRole.user.name;
        final role = StudioRole.values.firstWhere(
          (value) => value.name == roleName,
          orElse: () => StudioRole.user,
        );

        final imageFileName = map['imageFileName'] as String?;
        final audioFileName = map['audioFileName'] as String?;
        final imageBytes = imageFileName == null
            ? null
            : await _readBytesIfExists(
                File(path.join(attachmentsDirectory.path, imageFileName)),
              );
        final audioBytes = audioFileName == null
            ? null
            : await _readBytesIfExists(
                File(path.join(attachmentsDirectory.path, audioFileName)),
              );

        restored.add(
          StudioMessage(
            role: role,
            text: map['text'] as String? ?? '',
            imageBytes: imageBytes,
            imageName: map['imageName'] as String?,
            audioBytes: audioBytes,
            audioDuration: map['audioDurationMs'] == null
                ? null
                : Duration(milliseconds: map['audioDurationMs'] as int),
          ),
        );
      }

      return restored;
    } catch (_) {
      return const <StudioMessage>[];
    }
  }

  Future<void> saveConversation(
    String modelId,
    List<StudioMessage> messages,
  ) async {
    final file = await _conversationFile(modelId);
    final attachmentsDirectory = await _attachmentsDirectory(modelId);

    await file.parent.create(recursive: true);
    await attachmentsDirectory.create(recursive: true);
    await _clearDirectory(attachmentsDirectory);

    final serializedMessages = <Map<String, dynamic>>[];

    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      final indexLabel = index.toString().padLeft(4, '0');

      String? imageFileName;
      if (message.imageBytes != null) {
        imageFileName =
            'msg_${indexLabel}_image${_imageExtension(message.imageName)}';
        await File(
          path.join(attachmentsDirectory.path, imageFileName),
        ).writeAsBytes(message.imageBytes!, flush: true);
      }

      String? audioFileName;
      if (message.audioBytes != null) {
        audioFileName = 'msg_${indexLabel}_audio.wav';
        await File(
          path.join(attachmentsDirectory.path, audioFileName),
        ).writeAsBytes(message.audioBytes!, flush: true);
      }

      serializedMessages.add(<String, dynamic>{
        'role': message.role.name,
        'text': message.text,
        'imageName': message.imageName,
        'imageFileName': imageFileName,
        'audioFileName': audioFileName,
        'audioDurationMs': message.audioDuration?.inMilliseconds,
      });
    }

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'version': _schemaVersion,
        'messages': serializedMessages,
      }),
      flush: true,
    );
  }

  Future<File> _conversationFile(String modelId) async {
    final root = await _rootDirectory();
    return File(
      path.join(root.path, 'conversations', '${_safeModelKey(modelId)}.json'),
    );
  }

  Future<Directory> _attachmentsDirectory(String modelId) async {
    final root = await _rootDirectory();
    return Directory(
      path.join(root.path, 'attachments', _safeModelKey(modelId)),
    );
  }

  Future<Directory> _rootDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(path.join(supportDirectory.path, _rootDirectoryName));
  }

  Future<void> _clearDirectory(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list()) {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<Uint8List?> _readBytesIfExists(File file) async {
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  String _safeModelKey(String value) {
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  String _imageExtension(String? imageName) {
    if (imageName == null || imageName.isEmpty) {
      return '.bin';
    }

    final extension = path.extension(imageName);
    return extension.isEmpty ? '.bin' : extension;
  }
}
