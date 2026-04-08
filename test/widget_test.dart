import 'package:flutter_test/flutter_test.dart';
import 'package:on_device_ai_project/features/studio/domain/models/gemma_preset.dart';

void main() {
  test('gemma4 프리셋이 노출된다', () {
    expect(GemmaPreset.values, hasLength(2));
    expect(GemmaPreset.e2b.label, 'gemma4 E2B');
    expect(GemmaPreset.e4b.maxTokens, 4096);
  });
}
