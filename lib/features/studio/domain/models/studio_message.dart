import 'dart:typed_data';

enum StudioRole { user, assistant, system }

const _messageSentinel = Object();

class StudioMessage {
  const StudioMessage({
    required this.role,
    required this.text,
    this.imageBytes,
    this.imageName,
    this.audioBytes,
    this.audioDuration,
    this.isStreaming = false,
  });

  factory StudioMessage.user({
    required String text,
    Uint8List? imageBytes,
    String? imageName,
    Uint8List? audioBytes,
    Duration? audioDuration,
  }) {
    return StudioMessage(
      role: StudioRole.user,
      text: text,
      imageBytes: imageBytes,
      imageName: imageName,
      audioBytes: audioBytes,
      audioDuration: audioDuration,
    );
  }

  factory StudioMessage.assistant({
    String text = '',
    bool isStreaming = false,
  }) {
    return StudioMessage(
      role: StudioRole.assistant,
      text: text,
      isStreaming: isStreaming,
    );
  }

  factory StudioMessage.system(String text) {
    return StudioMessage(role: StudioRole.system, text: text);
  }

  final StudioRole role;
  final String text;
  final Uint8List? imageBytes;
  final String? imageName;
  final Uint8List? audioBytes;
  final Duration? audioDuration;
  final bool isStreaming;

  StudioMessage copyWith({
    StudioRole? role,
    String? text,
    Object? imageBytes = _messageSentinel,
    Object? imageName = _messageSentinel,
    Object? audioBytes = _messageSentinel,
    Object? audioDuration = _messageSentinel,
    bool? isStreaming,
  }) {
    return StudioMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      imageBytes: identical(imageBytes, _messageSentinel)
          ? this.imageBytes
          : imageBytes as Uint8List?,
      imageName: identical(imageName, _messageSentinel)
          ? this.imageName
          : imageName as String?,
      audioBytes: identical(audioBytes, _messageSentinel)
          ? this.audioBytes
          : audioBytes as Uint8List?,
      audioDuration: identical(audioDuration, _messageSentinel)
          ? this.audioDuration
          : audioDuration as Duration?,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
