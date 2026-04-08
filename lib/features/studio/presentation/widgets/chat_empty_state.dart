import 'package:flutter/material.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '대화를 시작할 준비가 필요합니다.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text('왼쪽 상단 메뉴에서 모델 선택, 실행 설정, 사용 방법을 확인하세요.'),
          const SizedBox(height: 8),
          const Text('모델이 준비되면 이 화면에는 대화 기록만 남습니다.'),
        ],
      ),
    );
  }
}
