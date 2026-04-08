import 'package:path/path.dart' as path;

enum GemmaPreset {
  e2b(
    label: 'gemma4 E2B',
    sizeLabel: '2.4GB',
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    maxTokens: 4096,
    runtimeMaxTokens: 2048,
  ),
  e4b(
    label: 'gemma4 E4B',
    sizeLabel: '4.3GB',
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    maxTokens: 4096,
    runtimeMaxTokens: 2048,
  );

  const GemmaPreset({
    required this.label,
    required this.sizeLabel,
    required this.downloadUrl,
    required this.maxTokens,
    required this.runtimeMaxTokens,
  });

  final String label;
  final String sizeLabel;
  final String downloadUrl;
  final int maxTokens;
  final int runtimeMaxTokens;

  String get dropdownLabel => '$label · $sizeLabel';

  String get modelId => path.basename(Uri.parse(downloadUrl).path);

  static GemmaPreset? fromModelId(String modelId) {
    for (final preset in GemmaPreset.values) {
      if (preset.modelId == modelId) {
        return preset;
      }
    }

    final normalized = modelId.toLowerCase();
    if (normalized.contains('e4b')) {
      return GemmaPreset.e4b;
    }
    if (normalized.contains('e2b')) {
      return GemmaPreset.e2b;
    }

    return null;
  }
}
