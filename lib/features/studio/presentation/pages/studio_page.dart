import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/studio_controller.dart';
import '../../application/studio_state.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_empty_state.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/studio_drawer.dart';
import '../widgets/transient_thinking_panel.dart';

class StudioPage extends ConsumerStatefulWidget {
  const StudioPage({super.key});

  @override
  ConsumerState<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends ConsumerState<StudioPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(ref.read(studioControllerProvider.notifier).persistSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    final studioState = ref.watch(studioControllerProvider);
    final controller = ref.read(studioControllerProvider.notifier);

    ref.listen<StudioState>(studioControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.transientThinking != next.transientThinking ||
          previous?.isRecording != next.isRecording) {
        _scrollToBottom();
      }
    });

    ref.listen<String?>(
      studioControllerProvider.select((value) => value.noticeMessage),
      (previous, next) {
        if (next == null || next == previous || !mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
        controller.clearNotice();
      },
    );

    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF08111D),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: StudioDrawer(
              state: studioState,
              installedModelLabelBuilder:
                  controller.installedModelDropdownLabel,
              onPresetChanged: (preset) {
                unawaited(controller.selectPreset(preset));
              },
              onPreferGpuChanged: (value) {
                unawaited(controller.setPreferGpu(value));
              },
              onEnableThinkingChanged: (value) {
                unawaited(controller.setEnableThinking(value));
              },
              onInstallPressed: () {
                unawaited(controller.installSelectedPreset());
              },
              onImportLocalPressed: () {
                unawaited(controller.importLocalModel());
              },
              onInstalledModelSelected: (modelId) {
                unawaited(controller.openInstalledModel(modelId));
              },
            ),
          ),
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'gemma4 테스트',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              studioState.appBarSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '생성 중지',
            onPressed: studioState.isSending
                ? () {
                    unawaited(controller.stopGeneration());
                  }
                : null,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07111D), Color(0xFF0C2233), Color(0xFF07111D)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    if (studioState.messages.isEmpty) const ChatEmptyState(),
                    ...studioState.messages.map(
                      (message) => ChatMessageBubble(message: message),
                    ),
                  ],
                ),
              ),
              if (studioState.isSending &&
                  studioState.enableThinking &&
                  studioState.transientThinking.isNotEmpty)
                TransientThinkingPanel(text: studioState.transientThinking),
              ChatComposer(
                messageController: _messageController,
                state: studioState,
                onPickImage: () {
                  unawaited(controller.pickImage());
                },
                onToggleRecording: () {
                  unawaited(controller.toggleRecording());
                },
                onSend: _handleSend,
                onClearPendingImage: controller.clearPendingImage,
                onClearPendingAudio: controller.clearPendingAudio,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final sent = await ref
        .read(studioControllerProvider.notifier)
        .sendMessage(_messageController.text);
    if (sent) {
      _messageController.clear();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }
}
