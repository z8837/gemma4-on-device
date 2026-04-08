import 'dart:typed_data';

import '../domain/models/gemma_preset.dart';
import '../domain/models/studio_message.dart';

const _stateSentinel = Object();

class StudioState {
  const StudioState({
    required this.selectedPreset,
    required this.messages,
    required this.installedModels,
    this.selectedInstalledModelId,
    this.activeModelId,
    this.activeModelLabel,
    this.runtimeBackendLabel,
    this.pendingImageBytes,
    this.pendingImageName,
    this.pendingAudioBytes,
    this.pendingAudioDuration,
    this.preferGpu = false,
    this.enableThinking = false,
    this.isInstalling = false,
    this.isPreparingModel = false,
    this.isSending = false,
    this.isRecording = false,
    this.installProgress = 0,
    this.recordingDuration = Duration.zero,
    this.transientThinking = '',
    this.statusText = 'Gemma4 모델을 다운로드하거나 로컬 .litertlm 파일을 가져오세요.',
    this.noticeMessage,
  });

  factory StudioState.initial() {
    return const StudioState(
      selectedPreset: GemmaPreset.e2b,
      messages: <StudioMessage>[],
      installedModels: <String>[],
    );
  }

  final GemmaPreset selectedPreset;
  final List<StudioMessage> messages;
  final List<String> installedModels;
  final String? selectedInstalledModelId;
  final String? activeModelId;
  final String? activeModelLabel;
  final String? runtimeBackendLabel;
  final Uint8List? pendingImageBytes;
  final String? pendingImageName;
  final Uint8List? pendingAudioBytes;
  final Duration? pendingAudioDuration;
  final bool preferGpu;
  final bool enableThinking;
  final bool isInstalling;
  final bool isPreparingModel;
  final bool isSending;
  final bool isRecording;
  final int installProgress;
  final Duration recordingDuration;
  final String transientThinking;
  final String statusText;
  final String? noticeMessage;

  bool get isBusy => isInstalling || isPreparingModel;

  String get appBarSubtitle {
    if (isBusy || isSending || isRecording) {
      return statusText;
    }
    if (activeModelLabel == null) {
      return '메뉴에서 모델과 설정을 확인할 수 있습니다';
    }
    return '$activeModelLabel${runtimeBackendLabel == null ? '' : ' · $runtimeBackendLabel'}';
  }

  String get composerHintText {
    if (isRecording) {
      return '녹음 중입니다...';
    }
    if (pendingAudioBytes != null) {
      return '음성에 대한 질문이나 지시를 입력하세요';
    }
    if (pendingImageBytes != null) {
      return '사진에 대한 질문이나 지시를 입력하세요';
    }
    return 'Gemma4에게 메시지를 보내세요';
  }

  StudioState copyWith({
    GemmaPreset? selectedPreset,
    List<StudioMessage>? messages,
    List<String>? installedModels,
    Object? selectedInstalledModelId = _stateSentinel,
    Object? activeModelId = _stateSentinel,
    Object? activeModelLabel = _stateSentinel,
    Object? runtimeBackendLabel = _stateSentinel,
    Object? pendingImageBytes = _stateSentinel,
    Object? pendingImageName = _stateSentinel,
    Object? pendingAudioBytes = _stateSentinel,
    Object? pendingAudioDuration = _stateSentinel,
    bool? preferGpu,
    bool? enableThinking,
    bool? isInstalling,
    bool? isPreparingModel,
    bool? isSending,
    bool? isRecording,
    int? installProgress,
    Duration? recordingDuration,
    String? transientThinking,
    String? statusText,
    Object? noticeMessage = _stateSentinel,
  }) {
    return StudioState(
      selectedPreset: selectedPreset ?? this.selectedPreset,
      messages: messages ?? this.messages,
      installedModels: installedModels ?? this.installedModels,
      selectedInstalledModelId:
          identical(selectedInstalledModelId, _stateSentinel)
          ? this.selectedInstalledModelId
          : selectedInstalledModelId as String?,
      activeModelId: identical(activeModelId, _stateSentinel)
          ? this.activeModelId
          : activeModelId as String?,
      activeModelLabel: identical(activeModelLabel, _stateSentinel)
          ? this.activeModelLabel
          : activeModelLabel as String?,
      runtimeBackendLabel: identical(runtimeBackendLabel, _stateSentinel)
          ? this.runtimeBackendLabel
          : runtimeBackendLabel as String?,
      pendingImageBytes: identical(pendingImageBytes, _stateSentinel)
          ? this.pendingImageBytes
          : pendingImageBytes as Uint8List?,
      pendingImageName: identical(pendingImageName, _stateSentinel)
          ? this.pendingImageName
          : pendingImageName as String?,
      pendingAudioBytes: identical(pendingAudioBytes, _stateSentinel)
          ? this.pendingAudioBytes
          : pendingAudioBytes as Uint8List?,
      pendingAudioDuration: identical(pendingAudioDuration, _stateSentinel)
          ? this.pendingAudioDuration
          : pendingAudioDuration as Duration?,
      preferGpu: preferGpu ?? this.preferGpu,
      enableThinking: enableThinking ?? this.enableThinking,
      isInstalling: isInstalling ?? this.isInstalling,
      isPreparingModel: isPreparingModel ?? this.isPreparingModel,
      isSending: isSending ?? this.isSending,
      isRecording: isRecording ?? this.isRecording,
      installProgress: installProgress ?? this.installProgress,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      transientThinking: transientThinking ?? this.transientThinking,
      statusText: statusText ?? this.statusText,
      noticeMessage: identical(noticeMessage, _stateSentinel)
          ? this.noticeMessage
          : noticeMessage as String?,
    );
  }
}
