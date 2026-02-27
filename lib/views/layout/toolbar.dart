import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/service/emulator_overlay_service.dart';
import 'package:oasx/utils/platform_utils.dart';

class Toolbar extends StatelessWidget {
  const Toolbar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (PlatformUtils.isWindows) const _EmulatorLabelToggle(),
        ],
      ),
    );
  }
}

/// 工具栏按钮：显示 / 隐藏模拟器编号标签覆层
class _EmulatorLabelToggle extends StatelessWidget {
  const _EmulatorLabelToggle();

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<EmulatorOverlayService>();
    return Obx(() {
      final enabled = svc.isEnabled.value;
      return Tooltip(
        message: enabled ? '隐藏模拟器标签' : '显示模拟器标签',
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: svc.toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.label : Icons.label_off_outlined,
                  size: 18,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '模拟器标签',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}


