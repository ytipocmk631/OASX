import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:oasx/config/translation/i18n_content.dart';
import 'package:oasx/controller/batchedit/batch_edit_controller.dart';
import 'package:oasx/views/nav/view_nav.dart';

class BatchEditView extends StatelessWidget {
  const BatchEditView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<BatchEditController>();
    return Column(
      children: [
        _Toolbar(ctrl: ctrl),
        const Divider(height: 1),
        Expanded(child: _Body(ctrl: ctrl)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 工具栏
// ─────────────────────────────────────────────────────────────────────────────
class _Toolbar extends StatelessWidget {
  final BatchEditController ctrl;
  const _Toolbar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final navCtrl = Get.find<NavCtrl>();
    return Obx(() {
      final tasks = ctrl.availableTasks;
      final scripts = navCtrl.navNameList.skip(1).toList();

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：任务选择 + 加载按钮
            Row(
              children: [
                Text('${I18n.batch_edit_select_task.tr}:',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 8),
                if (tasks.isEmpty)
                  Text(I18n.no_data.tr,
                      style: Theme.of(context).textTheme.bodySmall)
                else
                  DropdownButton<String>(
                    value: ctrl.selectedTask.value.isEmpty ||
                            !tasks.contains(ctrl.selectedTask.value)
                        ? tasks.first
                        : ctrl.selectedTask.value,
                    items: tasks
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t.tr)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) ctrl.selectedTask.value = v;
                    },
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: ctrl.isLoading.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(I18n.batch_edit_load.tr),
                  onPressed:
                      ctrl.isLoading.value ? null : ctrl.loadCommonFields,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 第二行：脚本多选 chips
            if (scripts.isNotEmpty) ...[
              Text('${I18n.batch_edit_select_scripts.tr}:',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: scripts
                    .map((s) => FilterChip(
                          label: Text(s.tr,
                              style: Theme.of(context).textTheme.bodySmall),
                          selected: ctrl.selectedScripts.contains(s),
                          onSelected: (_) => ctrl.toggleScript(s),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 主体区域
// ─────────────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final BatchEditController ctrl;
  const _Body({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (ctrl.groupNames.isEmpty) {
        if (ctrl.commonGroups.isEmpty) {
          // 未加载提示
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune,
                    size: 48,
                    color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Text(
                  '${I18n.batch_edit_select_task.tr} → ${I18n.batch_edit_load.tr}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }
        // 加载后无公共字段
        return Center(
          child: Text(
            I18n.batch_edit_no_common.tr,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }

      final scripts = ctrl.selectedScripts.toList();
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        itemCount: ctrl.groupNames.length,
        itemBuilder: (context, index) {
          final groupName = ctrl.groupNames[index];
          final fields = ctrl.commonGroups[groupName] ?? [];
          return _GroupSection(
            groupName: groupName,
            fields: fields,
            scripts: scripts,
            ctrl: ctrl,
          );
        },
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 分组折叠区
// ─────────────────────────────────────────────────────────────────────────────
class _GroupSection extends StatelessWidget {
  final String groupName;
  final List<CommonFieldModel> fields;
  final List<String> scripts;
  final BatchEditController ctrl;

  const _GroupSection({
    required this.groupName,
    required this.fields,
    required this.scripts,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title:
            Text(groupName.tr, style: Theme.of(context).textTheme.titleSmall),
        children: fields
            .map((f) => _FieldCard(
                  field: f,
                  scripts: scripts,
                  ctrl: ctrl,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 单字段卡片（垂直布局，无溢出风险）
// ─────────────────────────────────────────────────────────────────────────────
class _FieldCard extends StatefulWidget {
  final CommonFieldModel field;
  final List<String> scripts;
  final BatchEditController ctrl;

  const _FieldCard({
    required this.field,
    required this.scripts,
    required this.ctrl,
  });

  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  Timer? _debounce;
  late dynamic _pendingValue;
  TextEditingController? _serialIpController;

  @override
  void initState() {
    super.initState();
    _pendingValue = widget.field.newValue;
    if (widget.field.argName == 'serial') {
      final raw = _pendingValue?.toString() ?? '';
      final colonIdx = raw.lastIndexOf(':');
      final ip = colonIdx > 0 ? raw.substring(0, colonIdx) : raw;
      _serialIpController = TextEditingController(text: ip);
    }
  }

  void _setPending(dynamic value) {
    _pendingValue = value;
    widget.field.newValue = value;
  }

  Future<void> _apply() async {
    if (widget.field.argName == 'serial') {
      final newIp = _serialIpController?.text ?? '';
      final perScriptValues = <String, dynamic>{};
      for (final s in widget.scripts) {
        final current = widget.field.currentValues[s]?.toString() ?? '';
        final colonIdx = current.lastIndexOf(':');
        final port = colonIdx > 0 ? current.substring(colonIdx + 1) : '';
        perScriptValues[s] = port.isEmpty ? newIp : '$newIp:$port';
      }
      await widget.ctrl.applyPerScript(
        widget.field.groupName,
        widget.field.argName,
        widget.field.type,
        perScriptValues,
      );
    } else {
      await widget.ctrl.applyToSelected(
        widget.field.groupName,
        widget.field.argName,
        widget.field.type,
        _pendingValue,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _serialIpController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 行一：字段名 + Apply 按钮 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.argName.tr,
                        style: Theme.of(context).textTheme.bodyMedium),
                    if (f.description != null && f.description!.isNotEmpty)
                      Text(f.description!.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.outline)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _apply,
                child: Text(I18n.batch_edit_apply.tr,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── 行二：各脚本当前值 ──
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.scripts.map((s) {
              final val = f.currentValues[s];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$s: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500)),
                  Text('$val',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.outline)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // ── 行三：新值输入 ──
          Row(
            children: [
              Icon(Icons.arrow_forward, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(child: _buildInput(f)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput(CommonFieldModel f) {
    switch (f.type) {
      case 'boolean':
        return Row(
          children: [
            Switch(
              value: _pendingValue as bool? ?? false,
              onChanged: (v) => setState(() => _setPending(v)),
            ),
            const SizedBox(width: 8),
            Text(
              (_pendingValue as bool? ?? false).toString().tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );

      case 'enum':
        return DropdownButton<String>(
          isExpanded: true,
          value: _pendingValue?.toString(),
          items: (f.enumEnum ?? [])
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.tr,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _setPending(v)),
        );

      case 'number':
        return TextFormField(
          key: ValueKey('num_${f.argName}'),
          initialValue: _pendingValue?.toString() ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[-0-9.]'))
          ],
          decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 600),
                () => setState(() => _setPending(v)));
          },
        );

      case 'integer':
        return TextFormField(
          key: ValueKey('int_${f.argName}'),
          initialValue: _pendingValue?.toString() ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[-0-9]'))
          ],
          decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 600),
                () => setState(() => _setPending(v)));
          },
        );

      case 'string':
      case 'multi_line':
        if (f.argName == 'serial') {
          return TextFormField(
            controller: _serialIpController,
            decoration: const InputDecoration(
                isDense: true,
                hintText: 'IP',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return TextFormField(
          key: ValueKey('str_${f.argName}'),
          initialValue: _pendingValue?.toString() ?? '',
          maxLines: f.type == 'multi_line' ? 3 : 1,
          decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce =
                Timer(const Duration(milliseconds: 600), () => _setPending(v));
          },
        );

      default:
        // date_time / time / time_delta
        return TextFormField(
          key: ValueKey('default_${f.argName}'),
          initialValue: _pendingValue?.toString() ?? '',
          decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce =
                Timer(const Duration(milliseconds: 600), () => _setPending(v));
          },
        );
    }
  }
}
