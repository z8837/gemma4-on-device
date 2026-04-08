import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/duration_formatter.dart';
import '../../application/studio_state.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.messageController,
    required this.state,
    required this.onPickImage,
    required this.onToggleRecording,
    required this.onSend,
    required this.onClearPendingImage,
    required this.onClearPendingAudio,
  });

  final TextEditingController messageController;
  final StudioState state;
  final VoidCallback onPickImage;
  final VoidCallback onToggleRecording;
  final VoidCallback onSend;
  final VoidCallback onClearPendingImage;
  final VoidCallback onClearPendingAudio;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF08111D).withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.pendingImageBytes != null)
              _PendingImageCard(
                imageBytes: state.pendingImageBytes!,
                imageName: state.pendingImageName,
                onClear: onClearPendingImage,
              ),
            if (state.pendingAudioBytes != null)
              _PendingAudioCard(
                duration: state.pendingAudioDuration ?? Duration.zero,
                onClear: onClearPendingAudio,
              ),
            if (state.isRecording)
              _RecordingCard(duration: state.recordingDuration),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton.filledTonal(
                  tooltip: '사진 첨부',
                  onPressed:
                      (state.pendingAudioBytes != null || state.isRecording)
                      ? null
                      : onPickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: state.isRecording ? '녹음 중지' : '음성 녹음',
                  onPressed: state.pendingImageBytes != null
                      ? null
                      : onToggleRecording,
                  icon: Icon(state.isRecording ? Icons.stop : Icons.mic_none),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: !state.isRecording && !state.isBusy,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: state.composerHintText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: '전송',
                  onPressed:
                      (!state.isRecording && !state.isBusy && !state.isSending)
                      ? onSend
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingImageCard extends StatelessWidget {
  const _PendingImageCard({
    required this.imageBytes,
    required this.imageName,
    required this.onClear,
  });

  final Uint8List imageBytes;
  final String? imageName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              imageBytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사진 첨부됨',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  imageName ?? '선택한 사진',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  '텍스트 없이 보내면 기본 이미지 분석 프롬프트를 자동으로 사용합니다.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '사진 제거',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _PendingAudioCard extends StatelessWidget {
  const _PendingAudioCard({required this.duration, required this.onClear});

  final Duration duration;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF183049),
            ),
            child: const Icon(Icons.graphic_eq, size: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '음성 첨부됨',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(formatDuration(duration)),
                const SizedBox(height: 2),
                const Text(
                  '텍스트 없이 보내면 전사와 요약 프롬프트를 자동으로 사용합니다.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '음성 제거',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF491B23),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '녹음 중 ${formatDuration(duration)} / ${formatDuration(const Duration(seconds: 60))}',
            ),
          ),
        ],
      ),
    );
  }
}
