import 'package:flutter/material.dart';

import '../../../../core/utils/duration_formatter.dart';
import '../../domain/models/studio_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final StudioMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == StudioRole.system) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF153148),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF2FD0A5).withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFF2FD0A5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final isUser = message.role == StudioRole.user;
    final bubbleColor = isUser
        ? const Color(0xFF1C7D69)
        : const Color(0xFF101C29);
    final accentColor = isUser
        ? const Color(0xFF88F0D2)
        : const Color(0xFF8AD9FF);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isUser ? 22 : 8),
              bottomRight: Radius.circular(isUser ? 8 : 22),
            ),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    message.imageBytes!,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (message.audioDuration != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, size: 18),
                      const SizedBox(width: 8),
                      Text('음성 ${formatDuration(message.audioDuration!)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if (message.isStreaming) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '생성 중...',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
