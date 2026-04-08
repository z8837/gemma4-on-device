import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../data/gemma_runtime_service.dart';
import '../data/studio_persistence_repository.dart';
import '../domain/models/gemma_preset.dart';
import '../domain/models/studio_message.dart';
import 'studio_state.dart';

final studioControllerProvider =
    NotifierProvider<StudioController, StudioState>(StudioController.new);

class StudioController extends Notifier<StudioState> {
  static const _defaultImagePrompt = '이 사진을 한국어로 자세히 설명하고 핵심 내용을 정리해 주세요.';
  static const _defaultAudioPrompt = '이 음성을 한국어로 전사하고 핵심 내용을 요약해 주세요.';
  static const _maxRecordingDuration = Duration(seconds: 60);

  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Timer? _recordingTimer;
  OpenedGemmaSession? _openedSession;
  bool _didInitialize = false;

  GemmaRuntimeService get _runtime => ref.read(gemmaRuntimeServiceProvider);
  StudioPersistenceRepository get _persistence =>
      ref.read(studioPersistenceRepositoryProvider);

  @override
  StudioState build() {
    ref.onDispose(() {
      _recordingTimer?.cancel();
      _audioRecorder.dispose();
      final currentSession = _openedSession;
      _openedSession = null;
      if (currentSession != null) {
        unawaited(currentSession.model.close());
      }
    });

    if (!_didInitialize) {
      _didInitialize = true;
      unawaited(_bootstrap());
    }

    return StudioState.initial();
  }

  Future<void> _bootstrap() async {
    final preferences = await _persistence.loadPreferences();
    state = state.copyWith(
      preferGpu: preferences.preferGpu,
      enableThinking: preferences.enableThinking,
    );

    await refreshInstalledModels(
      preferredModelId: preferences.lastActiveModelId,
    );

    final lastActiveModelId = preferences.lastActiveModelId;
    if (lastActiveModelId == null) {
      return;
    }

    if (!state.installedModels.contains(lastActiveModelId)) {
      state = state.copyWith(
        statusText: '이전에 선택한 모델을 찾을 수 없습니다. 드로어에서 다시 선택해 주세요.',
      );
      return;
    }

    await openInstalledModel(lastActiveModelId, forceReload: true);
  }

  Future<void> persistSession() async {
    await _persistence.savePreferences(
      StudioPreferences(
        lastActiveModelId: state.activeModelId,
        preferGpu: state.preferGpu,
        enableThinking: state.enableThinking,
      ),
    );

    final activeModelId = state.activeModelId;
    if (activeModelId == null) {
      return;
    }

    final persistableMessages = state.messages
        .where(
          (message) =>
              message.role != StudioRole.system && !message.isStreaming,
        )
        .toList(growable: false);

    await _persistence.saveConversation(activeModelId, persistableMessages);
  }

  Future<void> refreshInstalledModels({String? preferredModelId}) async {
    try {
      final installedModels = await _runtime.listInstalledModels();
      state = state.copyWith(
        installedModels: installedModels,
        selectedInstalledModelId: _resolveInstalledModelSelection(
          installedModels,
          preferredModelId: preferredModelId,
        ),
        statusText: state.activeModelLabel == null && !state.isBusy
            ? installedModels.isEmpty
                  ? 'gemma4 모델을 다운로드하거나 로컬 .litertlm 파일을 가져오세요.'
                  : '설치된 모델을 선택하면 바로 사용할 수 있습니다.'
            : state.statusText,
      );
    } catch (_) {
      state = state.copyWith(
        installedModels: const <String>[],
        selectedInstalledModelId: null,
      );
    }
  }

  Future<void> selectPreset(GemmaPreset preset) async {
    state = state.copyWith(
      selectedPreset: preset,
      statusText: state.installedModels.contains(preset.modelId)
          ? '${preset.label}을(를) 바로 다시 여는 중입니다...'
          : '${preset.label}을(를) 선택했습니다. 다운로드 또는 가져오기로 준비해 주세요.',
    );

    if (state.installedModels.contains(preset.modelId)) {
      await openInstalledModel(preset.modelId);
    }
  }

  Future<void> setPreferGpu(bool value) async {
    state = state.copyWith(
      preferGpu: value,
      statusText: state.activeModelId == null
          ? '설정이 저장되었습니다. 다음 모델 열기부터 적용됩니다.'
          : '설정을 적용하기 위해 현재 모델을 다시 여는 중입니다...',
    );

    final activeModelId = state.activeModelId;
    if (activeModelId != null) {
      await openInstalledModel(activeModelId, forceReload: true);
      return;
    }

    await persistSession();
  }

  Future<void> setEnableThinking(bool value) async {
    state = state.copyWith(
      enableThinking: value,
      statusText: state.activeModelId == null
          ? '설정이 저장되었습니다. 다음 모델 열기부터 적용됩니다.'
          : '설정을 적용하기 위해 현재 모델을 다시 여는 중입니다...',
    );

    final activeModelId = state.activeModelId;
    if (activeModelId != null) {
      await openInstalledModel(activeModelId, forceReload: true);
      return;
    }

    await persistSession();
  }

  Future<void> installSelectedPreset() async {
    if (state.isBusy) {
      return;
    }

    final preset = state.selectedPreset;
    state = state.copyWith(
      isInstalling: true,
      installProgress: 0,
      statusText: '${preset.label} 다운로드 또는 활성화 중입니다...',
    );

    try {
      await _runtime.installPreset(
        preset,
        onProgress: (progress) {
          state = state.copyWith(installProgress: progress);
        },
      );

      await _openActiveModel(
        displayName: preset.label,
        modelId: preset.modelId,
      );
      await refreshInstalledModels(preferredModelId: preset.modelId);
    } catch (error) {
      state = state.copyWith(statusText: '모델 설치 실패: $error');
      _pushNotice('모델 설치에 실패했습니다.');
    } finally {
      state = state.copyWith(isInstalling: false);
    }
  }

  Future<void> importLocalModel() async {
    if (state.isBusy) {
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['litertlm'],
      dialogTitle: 'gemma4 .litertlm 파일 선택',
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final modelPath = result.files.single.path;
    if (modelPath == null || modelPath.isEmpty) {
      _pushNotice('경로가 있는 로컬 파일만 가져올 수 있습니다.');
      return;
    }

    final modelId = path.basename(modelPath);
    state = state.copyWith(
      isInstalling: true,
      installProgress: 0,
      statusText: '로컬 모델을 가져오는 중입니다...',
    );

    try {
      await _runtime.installModelFromFile(modelPath);
      await _openActiveModel(displayName: modelId, modelId: modelId);
      await refreshInstalledModels(preferredModelId: modelId);
    } catch (error) {
      state = state.copyWith(statusText: '로컬 모델 가져오기 실패: $error');
      _pushNotice('로컬 모델을 불러오지 못했습니다.');
    } finally {
      state = state.copyWith(isInstalling: false);
    }
  }

  Future<void> openInstalledModel(
    String modelId, {
    bool forceReload = false,
  }) async {
    if (state.isBusy) {
      return;
    }

    if (!forceReload &&
        state.activeModelId == modelId &&
        _openedSession != null) {
      return;
    }

    final preset = GemmaPreset.fromModelId(modelId);
    state = state.copyWith(
      selectedInstalledModelId: modelId,
      selectedPreset: preset ?? state.selectedPreset,
      statusText:
          '${preset?.label ?? _installedModelDisplayName(modelId)} 준비 중입니다...',
    );

    try {
      await _runtime.activateInstalledModel(modelId);
      await _openActiveModel(
        displayName: preset?.label ?? _installedModelDisplayName(modelId),
        modelId: modelId,
      );
      await refreshInstalledModels(preferredModelId: modelId);
    } catch (error) {
      state = state.copyWith(statusText: '설치된 모델 열기 실패: $error');
      _pushNotice('설치된 모델을 열지 못했습니다.');
    }
  }

  Future<void> pickImage() async {
    if (state.isBusy || state.isSending || state.isRecording) {
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (image == null) {
        return;
      }

      state = state.copyWith(
        pendingImageBytes: await image.readAsBytes(),
        pendingImageName: image.name,
        pendingAudioBytes: null,
        pendingAudioDuration: null,
        statusText: '사진을 첨부했습니다.',
      );
    } catch (error) {
      _pushNotice('사진을 선택하지 못했습니다: $error');
    }
  }

  Future<void> toggleRecording() async {
    if (state.isBusy || state.isSending) {
      return;
    }

    if (state.isRecording) {
      await _stopRecording();
      return;
    }

    await _startRecording();
  }

  void clearPendingImage() {
    state = state.copyWith(pendingImageBytes: null, pendingImageName: null);
  }

  void clearPendingAudio() {
    state = state.copyWith(pendingAudioBytes: null, pendingAudioDuration: null);
  }

  Future<bool> sendMessage(String draft) async {
    if (_openedSession == null) {
      _pushNotice('먼저 gemma4 모델을 설치하거나 선택해 주세요.');
      return false;
    }

    if (state.isBusy || state.isSending || state.isRecording) {
      return false;
    }

    final rawText = draft.trim();
    final imageBytes = state.pendingImageBytes;
    final imageName = state.pendingImageName;
    final audioBytes = state.pendingAudioBytes;
    final audioDuration = state.pendingAudioDuration;

    if (rawText.isEmpty && imageBytes == null && audioBytes == null) {
      return false;
    }

    final promptText = rawText.isNotEmpty
        ? rawText
        : audioBytes != null
        ? _defaultAudioPrompt
        : _defaultImagePrompt;

    final outboundMessage = audioBytes != null
        ? Message.withAudio(
            text: promptText,
            audioBytes: audioBytes,
            isUser: true,
          )
        : imageBytes != null
        ? Message.withImage(
            text: promptText,
            imageBytes: imageBytes,
            isUser: true,
          )
        : Message.text(text: promptText, isUser: true);

    final messages = <StudioMessage>[
      ...state.messages,
      StudioMessage.user(
        text: promptText,
        imageBytes: imageBytes,
        imageName: imageName,
        audioBytes: audioBytes,
        audioDuration: audioDuration,
      ),
      StudioMessage.assistant(isStreaming: true),
    ];

    state = state.copyWith(
      messages: messages,
      pendingImageBytes: null,
      pendingImageName: null,
      pendingAudioBytes: null,
      pendingAudioDuration: null,
      isSending: true,
      transientThinking: '',
      statusText: 'gemma4가 응답을 생성하고 있습니다...',
    );

    try {
      await _openedSession!.chat.addQuery(outboundMessage);

      var assistantText = '';
      var thinkingText = '';

      await for (final response
          in _openedSession!.chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          assistantText += response.token;
          _updateLastAssistantMessage(text: assistantText, isStreaming: true);
        } else if (response is ThinkingResponse) {
          thinkingText += response.content;
          state = state.copyWith(transientThinking: thinkingText);
        }
      }

      _updateLastAssistantMessage(
        text: assistantText.trim().isEmpty ? '(응답이 비어 있습니다)' : assistantText,
        isStreaming: false,
      );
      state = state.copyWith(
        isSending: false,
        transientThinking: '',
        statusText: '응답 생성이 완료되었습니다.',
      );
    } catch (error) {
      final currentAssistant = _lastAssistantMessage;
      final nextText =
          currentAssistant == null || currentAssistant.text.trim().isEmpty
          ? '오류: $error'
          : '${currentAssistant.text}\n\n[오류] $error';
      _updateLastAssistantMessage(text: nextText, isStreaming: false);
      state = state.copyWith(
        isSending: false,
        transientThinking: '',
        statusText: '응답 생성 중 오류가 발생했습니다.',
      );
      _pushNotice('응답 생성 중 오류가 발생했습니다.');
    } finally {
      await persistSession();
    }

    return true;
  }

  Future<void> stopGeneration() async {
    if (_openedSession == null || !state.isSending) {
      return;
    }

    try {
      await _openedSession!.chat.stopGeneration();
    } catch (_) {}

    final currentAssistant = _lastAssistantMessage;
    if (currentAssistant != null) {
      _updateLastAssistantMessage(
        text: currentAssistant.text.trim().isEmpty
            ? '(생성을 중지했습니다)'
            : currentAssistant.text,
        isStreaming: false,
      );
    }

    state = state.copyWith(
      isSending: false,
      transientThinking: '',
      statusText: '생성을 중지했습니다.',
    );

    await persistSession();
  }

  void clearNotice() {
    if (state.noticeMessage == null) {
      return;
    }
    state = state.copyWith(noticeMessage: null);
  }

  String installedModelDropdownLabel(String modelId) {
    return _installedModelDisplayName(modelId);
  }

  Future<void> _openActiveModel({
    required String displayName,
    required String modelId,
  }) async {
    state = state.copyWith(
      isPreparingModel: true,
      statusText: '$displayName 준비 중입니다...',
    );

    await _closeCurrentModel();

    try {
      final openedSession = await _runtime.openCurrentActiveModel(
        preset: GemmaPreset.fromModelId(modelId) ?? state.selectedPreset,
        preferGpu: state.preferGpu,
        enableThinking: state.enableThinking,
      );

      final restoredMessages = await _persistence.loadConversation(modelId);
      if (restoredMessages.isNotEmpty) {
        await openedSession.chat.clearHistory(
          replayHistory: restoredMessages.map(_toGemmaMessage).toList(),
        );
      }

      _openedSession = openedSession;

      state = state.copyWith(
        isPreparingModel: false,
        activeModelId: modelId,
        activeModelLabel: displayName,
        runtimeBackendLabel: openedSession.backendLabel,
        transientThinking: '',
        messages: <StudioMessage>[
          StudioMessage.system(
            '$displayName 준비 완료. 텍스트, 사진, 음성을 같은 대화 맥락으로 계속 사용할 수 있습니다.',
          ),
          ...restoredMessages,
        ],
        statusText: restoredMessages.isEmpty
            ? '$displayName 준비 완료'
            : '$displayName 준비 완료 · 이전 대화를 복원했습니다.',
      );

      await persistSession();
    } catch (error) {
      state = state.copyWith(
        isPreparingModel: false,
        statusText: '모델 초기화 실패: $error',
      );
      _pushNotice('모델을 초기화하지 못했습니다.');
    }
  }

  Future<void> _startRecording() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _pushNotice('음성 입력을 사용하려면 마이크 권한이 필요합니다.');
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _pushNotice('이 기기에서는 마이크를 사용할 수 없습니다.');
      return;
    }

    final tempFile = path.join(
      Directory.systemTemp.path,
      'gemma4_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: tempFile,
      );

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final nextDuration =
            state.recordingDuration + const Duration(seconds: 1);
        state = state.copyWith(recordingDuration: nextDuration);
        if (nextDuration >= _maxRecordingDuration) {
          unawaited(_stopRecording());
        }
      });

      state = state.copyWith(
        pendingImageBytes: null,
        pendingImageName: null,
        pendingAudioBytes: null,
        pendingAudioDuration: null,
        recordingDuration: Duration.zero,
        isRecording: true,
        statusText: '음성을 녹음하는 중입니다...',
      );
    } catch (error) {
      _recordingTimer?.cancel();
      _pushNotice('녹음을 시작하지 못했습니다: $error');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final recordedDuration = state.recordingDuration;

    try {
      final filePath = await _audioRecorder.stop();
      if (filePath == null) {
        state = state.copyWith(
          isRecording: false,
          recordingDuration: Duration.zero,
          statusText: '녹음을 취소했습니다.',
        );
        return;
      }

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      if (await file.exists()) {
        await file.delete();
      }

      state = state.copyWith(
        isRecording: false,
        recordingDuration: Duration.zero,
        pendingImageBytes: null,
        pendingImageName: null,
        pendingAudioBytes: bytes,
        pendingAudioDuration: recordedDuration,
        statusText: '음성을 첨부했습니다.',
      );
    } catch (error) {
      state = state.copyWith(
        isRecording: false,
        recordingDuration: Duration.zero,
        statusText: '음성 처리 실패: $error',
      );
      _pushNotice('녹음 파일을 처리하지 못했습니다.');
    }
  }

  Future<void> _closeCurrentModel() async {
    final currentSession = _openedSession;
    _openedSession = null;
    if (currentSession != null) {
      await currentSession.model.close();
    }
  }

  void _pushNotice(String message) {
    state = state.copyWith(noticeMessage: message);
  }

  String? _resolveInstalledModelSelection(
    List<String> installedModels, {
    String? preferredModelId,
  }) {
    if (installedModels.isEmpty) {
      return null;
    }

    if (preferredModelId != null &&
        installedModels.contains(preferredModelId)) {
      return preferredModelId;
    }

    final current = state.selectedInstalledModelId;
    if (current != null && installedModels.contains(current)) {
      return current;
    }

    return installedModels.first;
  }

  String _installedModelDisplayName(String modelId) {
    final preset = GemmaPreset.fromModelId(modelId);
    return preset?.label ?? _truncateMiddle(modelId);
  }

  String _truncateMiddle(String text, {int maxLength = 28}) {
    if (text.length <= maxLength) {
      return text;
    }

    final headLength = (maxLength / 2).floor() - 2;
    final tailLength = maxLength - headLength - 3;
    final head = text.substring(0, headLength);
    final tail = text.substring(text.length - tailLength);
    return '$head...$tail';
  }

  Message _toGemmaMessage(StudioMessage message) {
    return Message(
      text: message.text,
      isUser: message.role == StudioRole.user,
      imageBytes: message.imageBytes,
      audioBytes: message.audioBytes,
    );
  }

  StudioMessage? get _lastAssistantMessage {
    for (final message in state.messages.reversed) {
      if (message.role == StudioRole.assistant) {
        return message;
      }
    }
    return null;
  }

  void _updateLastAssistantMessage({
    required String text,
    required bool isStreaming,
  }) {
    final messages = <StudioMessage>[...state.messages];
    for (var index = messages.length - 1; index >= 0; index -= 1) {
      if (messages[index].role == StudioRole.assistant) {
        messages[index] = messages[index].copyWith(
          text: text,
          isStreaming: isStreaming,
        );
        state = state.copyWith(messages: messages);
        return;
      }
    }
  }
}
