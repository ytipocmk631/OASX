import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/model/script_model.dart';
import 'package:oasx/service/run_history_service.dart';
import 'package:oasx/config/translation/i18n_content.dart';

class RunHistoryView extends StatelessWidget {
  const RunHistoryView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = Get.find<RunHistoryService>();
    return Obx(() {
      final entries = service.getSortedHistory();
      if (entries.isEmpty) {
        return Center(
          child: Text(
            I18n.run_history_empty.tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }

      // 按日期分组，日期倒序
      final grouped = <String, List<MapEntry<String, Map<String, String>>>>{};
      for (final e in entries) {
        final date = e.key.split(' ')[0];
        grouped.putIfAbsent(date, () => []).add(e);
      }
      final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      return Column(
        children: [
          _buildToolbar(context, service),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                return _DateGroup(
                  date: date,
                  slots: grouped[date]!,
                  initiallyExpanded: index == 0,
                  isLatestDate: index == 0,
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildToolbar(BuildContext context, RunHistoryService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            I18n.run_history.tr,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          IconButton(
            tooltip: '立即刷新',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: service.recordAllActive,
          ),
        ],
      ),
    );
  }
}

// ── Level 1：日期 ──────────────────────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.date,
    required this.slots,
    required this.initiallyExpanded,
    required this.isLatestDate,
  });

  final String date;
  final List<MapEntry<String, Map<String, String>>> slots;
  final bool initiallyExpanded;
  final bool isLatestDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: PageStorageKey(date),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.calendar_today_outlined, size: 16),
        title: Text(
          date,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        children: [
          const Divider(height: 1),
          ...List.generate(
              slots.length,
              (i) => _TimeSlotGroup(
                    entry: slots[i],
                    // 仅最新日期的第一条时间项默认展开
                    initiallyExpanded: isLatestDate && i == 0,
                  )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Level 2：时间 ──────────────────────────────────────────────────────────────

class _TimeSlotGroup extends StatelessWidget {
  const _TimeSlotGroup({
    required this.entry,
    required this.initiallyExpanded,
  });

  final MapEntry<String, Map<String, String>> entry;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final hourKey = entry.key;
    final time = hourKey.split(' ').last;
    final stateMap = entry.value;
    final theme = Theme.of(context);

    return ExpansionTile(
      key: PageStorageKey(hourKey),
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.only(left: 12, right: 12),
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        Icons.access_time_rounded,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        time,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: stateMap.entries
          .map((e) => _ScriptRow(name: e.key, stateStr: e.value))
          .toList(),
    );
  }
}

// ── Level 3：编号 + 状态 ────────────────────────────────────────────────────────

class _ScriptRow extends StatelessWidget {
  const _ScriptRow({required this.name, required this.stateStr});

  final String name;
  final String stateStr;

  @override
  Widget build(BuildContext context) {
    final (color, label) = _resolve(stateStr);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 12, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${name.tr}  $label',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  (Color, String) _resolve(String stateStr) {
    return switch (stateStr) {
      'running' => (Colors.green, ScriptState.running.name.tr),
      'warning' => (Colors.orange, ScriptState.warning.name.tr),
      _ => (Colors.grey, stateStr),
    };
  }
}
