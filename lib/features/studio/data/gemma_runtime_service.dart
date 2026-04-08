import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/gemma_preset.dart';

final gemmaRuntimeServiceProvider = Provider<GemmaRuntimeService>((ref) {
  return const GemmaRuntimeService();
});

class OpenedGemmaSession {
  const OpenedGemmaSession({
    required this.model,
    required this.chat,
    required this.backendLabel,
  });

  final InferenceModel model;
  final InferenceChat chat;
  final String backendLabel;
}

class GemmaRuntimeService {
  const GemmaRuntimeService();

  static const systemInstruction =
      '당신은 기기에서 직접 실행되는 gemma4입니다. 사용자가 다른 언어를 요청하지 않으면 항상 한국어로 답변하세요.';

  Future<List<String>> listInstalledModels() {
    return FlutterGemma.listInstalledModels();
  }

  Future<void> installPreset(
    GemmaPreset preset, {
    required void Function(int progress) onProgress,
  }) {
    return FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.litertlm,
        )
        .fromNetwork(preset.downloadUrl, foreground: true)
        .withProgress(onProgress)
        .install();
  }

  Future<void> installModelFromFile(String filePath) {
    return FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromFile(filePath).install();
  }

  Future<void> activateInstalledModel(String modelId) async {
    final isInstalled = await FlutterGemma.isModelInstalled(modelId);
    if (!isInstalled) {
      throw StateError('선택한 모델을 찾을 수 없습니다.');
    }

    final spec = InferenceModelSpec.fromLegacyUrl(
      name: modelId,
      modelUrl: 'https://installed.local/$modelId',
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    );

    FlutterGemmaPlugin.instance.modelManager.setActiveModel(spec);
  }

  Future<OpenedGemmaSession> openCurrentActiveModel({
    required GemmaPreset preset,
    required bool preferGpu,
    required bool enableThinking,
  }) async {
    try {
      return await _openWithBackend(
        preset: preset,
        backend: preferGpu ? PreferredBackend.gpu : PreferredBackend.cpu,
        enableThinking: enableThinking,
      );
    } catch (_) {
      if (!preferGpu) {
        rethrow;
      }

      return _openWithBackend(
        preset: preset,
        backend: PreferredBackend.cpu,
        enableThinking: enableThinking,
      );
    }
  }

  Future<OpenedGemmaSession> _openWithBackend({
    required GemmaPreset preset,
    required PreferredBackend backend,
    required bool enableThinking,
  }) async {
    final model = await FlutterGemma.getActiveModel(
      maxTokens: preset.runtimeMaxTokens,
      preferredBackend: backend,
      supportImage: true,
      supportAudio: true,
      maxNumImages: 1,
    );

    try {
      final chat = await model.createChat(
        temperature: 1.0,
        randomSeed: 1,
        topK: 64,
        topP: 0.95,
        tokenBuffer: 256,
        supportImage: true,
        supportAudio: true,
        isThinking: enableThinking,
        modelType: ModelType.gemmaIt,
        systemInstruction: systemInstruction,
      );

      return OpenedGemmaSession(
        model: model,
        chat: chat,
        backendLabel: backend == PreferredBackend.gpu ? 'GPU' : 'CPU',
      );
    } catch (error) {
      await model.close();
      rethrow;
    }
  }
}
