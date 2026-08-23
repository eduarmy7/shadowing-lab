import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/daily_study_entry.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/empty_state.dart';
import '../common_widgets/skeleton_loader.dart';
import '../home/home_controller.dart';

String _dateKey(int year, int month, int day) =>
    '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

/// #11 학습 기록 상세 — 캘린더 히트맵(GitHub 잔디 스타일) + 누적 통계.
///
/// **2026-08-23**: 월별/일별 목록을 따로 펼쳐 보여주던 방식을 없애고(사용자 요청:
/// "아래 월별 학습기록 없애고, 달력에서 날짜 클릭시 거기에 그날 공부한 상세정보를
/// 보여주자"), 달력에서 날짜를 탭하면 그 날짜의 상세 기록이 바로 아래 카드에 뜨는
/// 방식으로 바꿨다. 달력 자체가 항상 이번 달만 보여주므로 선택 상태는 일(day) 하나만
/// 들고 있으면 된다.
class LearningHistoryScreen extends ConsumerStatefulWidget {
  const LearningHistoryScreen({super.key});

  @override
  ConsumerState<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends ConsumerState<LearningHistoryScreen> {
  late int _selectedDay = DateTime.now().day;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(userStatsProvider);
    final dailyLogAsync = ref.watch(dailyStudyLogProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: statsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenMargin),
          child: SkeletonCardList(count: 3),
        ),
        error: (e, st) => Center(child: Text(l10n.historyLoadError)),
        data: (stats) {
          if (!stats.hasAnyRecord) {
            return Center(
              child: EmptyState(
                icon: Icons.calendar_today_outlined,
                title: l10n.noRecordsTitle,
                description: l10n.noRecordsDescription,
              ),
            );
          }
          return dailyLogAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.screenMargin),
              child: SkeletonCardList(count: 3),
            ),
            error: (e, st) => Center(child: Text(l10n.historyLoadError)),
            data: (dailyLog) {
              final now = DateTime.now();
              final selectedEntries = dailyLog[_dateKey(now.year, now.month, _selectedDay)] ?? const [];

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  _HeatmapGrid(
                    heatmap: stats.dailyHeatmap,
                    selectedDay: _selectedDay,
                    onDaySelected: (day) => setState(() => _selectedDay = day),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SelectedDayCard(year: now.year, month: now.month, day: _selectedDay, entries: selectedEntries),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.cumulativeStats, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _StatRow(label: l10n.totalStudyDaysLabel, value: l10n.totalStudyDaysValue(stats.totalStudyDays)),
                  _StatRow(label: l10n.totalSentencesLabel, value: l10n.totalSentencesValue(stats.totalSentences)),
                  _StatRow(label: l10n.totalStudyTimeLabel, value: Formatters.duration(l10n, stats.totalStudyTimeMs)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 선택된 날짜의 상세 기록 카드 — 총 학습 시간 + 파일별 문장 범위.
class _SelectedDayCard extends StatelessWidget {
  final int year;
  final int month;
  final int day;
  final List<DailyStudyEntry> entries;
  const _SelectedDayCard({required this.year, required this.month, required this.day, required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final totalMs = entries.fold<int>(0, (sum, e) => sum + e.durationMs);
    final mergedEntries = _mergeByFileName(entries);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.dayGroupLabel(month, day),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(l10n.dailyStudyTimeLabel(Formatters.duration(l10n, totalMs)), style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (mergedEntries.isEmpty)
            Text(
              l10n.noRecordsThisDay,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            for (var i = 0; i < mergedEntries.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${i + 1}. ${_shortFileName(mergedEntries[i].fileName)} ${_rangeLabel(l10n, mergedEntries[i])}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
        ],
      ),
    );
  }

  /// **2026-08-23 버그 수정**: 같은 파일을 재분석/다시 불러오면 매번 새 mediaId로
  /// 등록되는 구조라(예: 자막 파싱 버그 수정 뒤 재테스트), 같은 날 같은 파일이
  /// 여러 줄로 쪼개져 보였다("이런 로그가 보이면 안 되잖아" — 사용자 피드백). 실제
  /// 저장된 [DailyStudyEntry]는 mediaId별로 그대로 유지하고(통계 데이터 자체는
  /// 안 건드림), **화면에 보여줄 때만** 같은 날 파일 이름이 같은 항목들을 합쳐
  /// 한 줄로 보여준다.
  List<DailyStudyEntry> _mergeByFileName(List<DailyStudyEntry> entries) {
    final byFileName = <String, DailyStudyEntry>{};
    for (final e in entries) {
      final existing = byFileName[e.fileName];
      byFileName[e.fileName] = existing == null
          ? e
          : existing.copyWith(
              minIndex: math.min(existing.minIndex, e.minIndex),
              maxIndex: math.max(existing.maxIndex, e.maxIndex),
              sentencesStudied: existing.sentencesStudied + e.sentencesStudied,
              durationMs: existing.durationMs + e.durationMs,
            );
    }
    return byFileName.values.toList();
  }

  /// **2026-08-23 가독성 개선**: 긴 파일명이 문장 범위/총 문장수를 밀어내 잘려 보이던
  /// 문제(사용자 피드백: "너무 가독성이 떨어져") 대신, 파일명은 앞 두 단어만 보여주고
  /// 범위·총 문장수는 항상 온전히 보이게 한다.
  String _shortFileName(String fileName) {
    final words = fileName.trim().split(RegExp(r'\s+'));
    return words.take(2).join(' ');
  }

  String _rangeLabel(AppLocalizations l10n, DailyStudyEntry e) {
    // minIndex/maxIndex는 0-based로 저장돼 있다 — 화면 표기는 다른 화면들(#5 목록 등)과
    // 마찬가지로 1-based(+1)로 보여준다.
    if (e.minIndex == e.maxIndex) {
      return l10n.sentenceRangeSingleLabel(e.minIndex + 1);
    }
    return l10n.sentenceRangeLabel(e.minIndex + 1, e.maxIndex + 1, e.sentencesStudied);
  }
}

/// **2026-08-23**: 최근 8주 롤링 스트립 대신, 실제 달력처럼 해당 달(1일~말일)을
/// 요일에 맞춰 7칸씩 배치한다(사용자 요청: "31일까지 있으니, 31개의 칸이 있고
/// 7일씩 된 달력으로 만들어서 해당 날짜칸에 네모 색칠"). 요일 헤더와 날짜 칸을
/// 같은 [GridView]에 넣어(1~7번째 children이 요일 헤더) 열이 항상 정확히 맞도록 한다.
/// 날짜 칸을 탭하면 [onDaySelected]로 그 날짜를 알려주고, [selectedDay]에 해당하는
/// 칸에는 선택 표시(테두리 링)를 그린다.
class _HeatmapGrid extends StatelessWidget {
  final Map<String, int> heatmap;
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  const _HeatmapGrid({required this.heatmap, required this.selectedDay, required this.onDaySelected});

  static const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

  Color _colorFor(ThemeData theme, int count) {
    if (count == 0) return theme.colorScheme.surfaceContainerHighest;
    if (count < 5) return theme.colorScheme.primary.withValues(alpha: 0.3);
    if (count < 15) return theme.colorScheme.primary.withValues(alpha: 0.6);
    return theme.colorScheme.primary;
  }

  Widget _dayCell(ThemeData theme, AppLocalizations l10n, int year, int month, int day) {
    final key = _dateKey(year, month, day);
    final count = heatmap[key] ?? 0;
    final isSelected = day == selectedDay;
    return Tooltip(
      message: l10n.dateSentencesTooltip(month, day, count),
      child: InkWell(
        onTap: () => onDaySelected(day),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.all(isSelected ? 2 : 0),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _colorFor(theme, count), borderRadius: BorderRadius.circular(4)),
            child: Text(
              '$day',
              style: theme.textTheme.labelSmall?.copyWith(
                color: count == 0 ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // DateTime.weekday: 월=1 ... 일=7 → 일요일 시작 달력 기준(일=0 ... 토=6)으로 변환.
    final firstWeekday = DateTime(year, month, 1).weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.monthGroupLabel(year, month), style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
          children: [
            for (final w in _weekdayLabels)
              Center(child: Text(w, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600))),
            for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++) _dayCell(theme, l10n, year, month, day),
          ],
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
