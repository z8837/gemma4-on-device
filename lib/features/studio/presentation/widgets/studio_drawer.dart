import 'package:flutter/material.dart';

import '../../application/studio_state.dart';
import '../../domain/models/gemma_preset.dart';

class StudioDrawer extends StatelessWidget {
  const StudioDrawer({
    super.key,
    required this.state,
    required this.installedModelLabelBuilder,
    required this.onPresetChanged,
    required this.onPreferGpuChanged,
    required this.onEnableThinkingChanged,
    required this.onInstallPressed,
    required this.onImportLocalPressed,
    required this.onInstalledModelSelected,
  });

  final StudioState state;
  final String Function(String modelId) installedModelLabelBuilder;
  final ValueChanged<GemmaPreset> onPresetChanged;
  final ValueChanged<bool> onPreferGpuChanged;
  final ValueChanged<bool> onEnableThinkingChanged;
  final VoidCallback onInstallPressed;
  final VoidCallback onImportLocalPressed;
  final ValueChanged<String> onInstalledModelSelected;

  @override
  Widget build(BuildContext context) {
    final progressValue = state.isInstalling && state.installProgress > 0
        ? state.installProgress / 100
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'gemma4',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 18),
          DropdownButtonFormField<GemmaPreset>(
            initialValue: state.selectedPreset,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '모델 프리셋',
              border: OutlineInputBorder(),
            ),
            items: GemmaPreset.values
                .map(
                  (preset) => DropdownMenuItem<GemmaPreset>(
                    value: preset,
                    child: Text(
                      preset.dropdownLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: state.isBusy
                ? null
                : (value) {
                    if (value != null) {
                      onPresetChanged(value);
                    }
                  },
          ),

          const SizedBox(height: 14),
          _ToggleTile(
            title: 'GPU 우선',
            subtitle: '지원되는 기기에서는 GPU를 먼저 사용합니다.',
            value: state.preferGpu,
            onChanged: state.isBusy ? null : onPreferGpuChanged,
          ),
          const SizedBox(height: 12),
          _ToggleTile(
            title: '생각 과정 표시',
            subtitle: '지원되는 모델에서는 생성 중 임시 패널로만 보여줍니다.',
            value: state.enableThinking,
            onChanged: state.isBusy ? null : onEnableThinkingChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isBusy ? null : onInstallPressed,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(state.isInstalling ? '설치 중...' : '선택한 프리셋 설치'),
            ),
          ),
          const SizedBox(height: 16),
          if (state.isInstalling) ...[
            LinearProgressIndicator(value: progressValue),
            const SizedBox(height: 10),
          ],
          Text(state.statusText, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (state.installedModels.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '설치된 모델 선택',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.installedModels.map((modelId) {
                return ChoiceChip(
                  label: Text(
                    installedModelLabelBuilder(modelId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: modelId == state.selectedInstalledModelId,
                  onSelected: state.isBusy
                      ? null
                      : (selected) {
                          if (selected) {
                            onInstalledModelSelected(modelId);
                          }
                        },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label · $value'),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
