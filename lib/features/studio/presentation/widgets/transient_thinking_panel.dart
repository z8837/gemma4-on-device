import 'package:flutter/material.dart';

class TransientThinkingPanel extends StatelessWidget {
  const TransientThinkingPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF112334),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8AD9FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '생각 과정',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF8AD9FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: SingleChildScrollView(
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
