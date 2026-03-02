import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:oasx/config/translation/i18n_content.dart';
import 'package:oasx/model/script_model.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/views/nav/view_nav.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scriptService = Get.find<ScriptService>();
    final navCtrl = Get.find<NavCtrl>();

    return Obx(() {
      final scripts = navCtrl.navNameList.skip(1).toList();
      // subscribe to each model's state so the grid rebuilds on state change
      for (final name in scripts) {
        scriptService.scriptModelMap[name]?.state.value;
      }

      if (scripts.isEmpty) {
        return Center(
          child: Text(I18n.no_data.tr,
              style: Theme.of(context).textTheme.bodyMedium),
        );
      }

      return LayoutBuilder(builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 220).floor().clamp(1, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: scripts.length,
          itemBuilder: (context, index) {
            final name = scripts[index];
            final model = scriptService.scriptModelMap[name];
            return _ScriptCard(
              name: name,
              model: model,
              onTap: () => navCtrl.switchScriptByName(name),
              onToggle: () {
                if (model == null) return;
                if (model.state.value != ScriptState.running) {
                  scriptService.startScript(name);
                } else {
                  scriptService.stopScript(name);
                }
              },
            );
          },
        );
      });
    });
  }
}

class _ScriptCard extends StatelessWidget {
  final String name;
  final ScriptModel? model;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _ScriptCard({
    required this.name,
    required this.model,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Obx(() {
      final state = model?.state.value ?? ScriptState.inactive;
      final runningTask = model?.runningTask.value;
      final hasTask = runningTask != null && !runningTask.isAllEmpty();

      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── 顶行：状态图标 + 脚本名 + 开关按钮 ──
                Row(
                  children: [
                    _StateIcon(state: state),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name.tr,
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.power_settings_new_rounded,
                        size: 18,
                        color: state == ScriptState.running
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      onPressed: onToggle,
                    ),
                  ],
                ),
                // ── 底行：当前任务 ──
                Text(
                  hasTask ? runningTask!.taskName.tr : '—',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasTask
                            ? colorScheme.onSurface
                            : colorScheme.outline,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _StateIcon extends StatelessWidget {
  final ScriptState state;
  const _StateIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ScriptState.running =>
        const SpinKitChasingDots(color: Colors.green, size: 14),
      ScriptState.warning =>
        const SpinKitDoubleBounce(color: Colors.orange, size: 14),
      ScriptState.updating =>
        const Icon(Icons.browser_updated_rounded, size: 14, color: Colors.blue),
      ScriptState.inactive =>
        const Icon(Icons.circle_outlined, size: 14, color: Colors.grey),
    };
  }
}
