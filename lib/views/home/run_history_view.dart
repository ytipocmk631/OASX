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

      final scriptNames = <String>{};
      for (final e in entries) {
        scriptNames.addAll(e.value.keys);
      }
      final sortedScripts = scriptNames.toList()..sort();

      return Column(
        children: [
          _buildToolbar(context, service),
          _buildHeader(context, sortedScripts),
          Expanded(
            child: _buildBody(context, entries, sortedScripts),
          ),
        ],
      );
    });
  }

  // 操作栏
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

  // 固定表头行
  Widget _buildHeader(BuildContext context, List<String> scripts) {
    final theme = Theme.of(context);
    final headerStyle =
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);
    final headerBg = theme.colorScheme.surfaceContainerHighest;
    final divider = theme.dividerColor;

    return Card(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Table(
        columnWidths: const {0: FixedColumnWidth(148)},
        defaultColumnWidth: const FlexColumnWidth(1),
        border: TableBorder(
          horizontalInside: BorderSide(color: divider, width: 0.5),
          verticalInside: BorderSide(color: divider, width: 0.5),
          bottom: BorderSide(color: divider, width: 0.5),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            children: [
              _headerCell('时间', headerStyle),
              ...scripts.map((name) => _headerCell(name.tr, headerStyle)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(text, style: style, overflow: TextOverflow.ellipsis),
    );
  }

  // 可垂直滚动的数据区
  Widget _buildBody(
    BuildContext context,
    List<MapEntry<String, Map<String, String>>> entries,
    List<String> scripts,
  ) {
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.labelSmall;
    final divider = theme.dividerColor;
    final evenBg = theme.colorScheme.surface;
    final oddBg = theme.colorScheme.surfaceContainerLow;

    final rows = List.generate(entries.length, (i) {
      final entry = entries[i];
      final hourKey = entry.key;
      final stateMap = entry.value;
      return TableRow(
        decoration: BoxDecoration(color: i.isEven ? evenBg : oddBg),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(hourKey, style: timeStyle),
          ),
          ...scripts.map((name) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StateChip(stateStr: stateMap[name]),
                ),
              )),
        ],
      );
    });

    return Card(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {0: FixedColumnWidth(148)},
          defaultColumnWidth: const FlexColumnWidth(1),
          border: TableBorder(
            horizontalInside: BorderSide(color: divider, width: 0.5),
            verticalInside: BorderSide(color: divider, width: 0.5),
          ),
          children: rows,
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({this.stateStr});

  final String? stateStr;

  @override
  Widget build(BuildContext context) {
    if (stateStr == null) return const SizedBox.shrink();
    final (color, label) = _resolve(stateStr!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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
