import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'primary_button.dart';

/// STT(음성인식) 전송 동의 Bottom Sheet — QA 🔴-2 수정.
///
/// 03_api_integration.md 11-1절 요구사항: 온보딩(#0)의 마이크/파일 "권한" 요청과는
/// **별개로**, 첫 파일 업로드 시도 시(#2 화면 진입 직후, 실제 업로드 시작 전) 음성이
/// 제3자 STT 처리업체(AssemblyAI)로 전송된다는 사실에 대한 별도의 명시적 "동의"를
/// 받아야 한다(Apple 5.1.1 대응 항목이기도 함). 기존 [PaywallSheet]와 동일한
/// Bottom Sheet 톤앤매너(핸들바 + 타이틀 + 설명 + Primary CTA)를 재사용해 디자인
/// 일관성을 유지한다.
///
/// 사용: `showModalBottomSheet<bool>(context: context, isScrollControlled: true,
///   isDismissible: false, builder: (_) => const SttConsentSheet());`
/// 반환값 `true`일 때만 동의로 간주 — 시트를 스와이프로 닫거나 뒤로가기를 누르면
/// `null`이 반환되어 "거부"와 동일하게 처리된다(업로드를 진행하지 않음).
class SttConsentSheet extends StatelessWidget {
  const SttConsentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenMargin,
          right: AppSpacing.screenMargin,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('음성 데이터 처리 동의', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '문장 자동분리를 위해 음성이 AI 처리 업체(AssemblyAI)로 전송돼요. '
              '처리 완료 후 원본 음성은 서버에서 자동 삭제됩니다.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                onPressed: () {
                  // 실제 정책 문서 화면 연동은 후속 작업 — 지금은 설정(#12)의
                  // "이용약관/개인정보처리방침" 진입점과 동일 문서를 가리킬 예정.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('개인정보처리방침 화면은 준비 중이에요')),
                  );
                },
                child: Text(
                  '자세히 보기(개인정보처리방침)',
                  style: AppTypography.label.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: '동의하고 계속',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('동의하지 않음'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
