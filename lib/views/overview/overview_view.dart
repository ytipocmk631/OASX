library overview;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/component/log/log_mixin.dart';
import 'package:oasx/component/log/log_widget.dart';
import 'package:oasx/model/script_model.dart';
import 'package:oasx/service/script_service.dart';

import 'package:styled_widget/styled_widget.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:oasx/views/nav/view_nav.dart';
import 'package:oasx/config/translation/i18n_content.dart';
import 'package:oasx/api/api_client.dart';

part '../../controller/overview/overview_controller.dart';
part '../../controller/overview/taskitem_model.dart';
part './taskitem_view.dart';

class Overview extends StatelessWidget {
  const Overview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    NavCtrl navController = Get.find<NavCtrl>();
    OverviewController overviewController =
        Get.find<OverviewController>(tag: navController.selectedScript.value);
    if (context.mediaQuery.orientation == Orientation.portrait) {
      // 竖方向
      return SingleChildScrollView(
        child: <Widget>[
          _SchedulerWidget(controller: overviewController),
          _RunningWidget(controller: overviewController),
          _PendingWidget(controller: overviewController),
          _WaitingWidget(controller: overviewController)
              .constrained(maxHeight: 200),
          LogWidget(
                  key: ValueKey(overviewController.hashCode),
                  controller: overviewController,
                  title: I18n.log.tr,
                  enableCollapse: false)
              .constrained(maxHeight: 500)
              .marginOnly(left: 10, top: 10, right: 10)
        ].toColumn(),
      );
    } else {
      //横方向
      return <Widget>[
        // 左边
        <Widget>[
          _SchedulerWidget(controller: overviewController),
          _RunningWidget(controller: overviewController),
          _PendingWidget(controller: overviewController),
          Expanded(child: _WaitingWidget(controller: overviewController)),
        ].toColumn().constrained(width: 300),
        // 右边
        LogWidget(
                key: ValueKey(overviewController.hashCode),
                controller: overviewController,
                title: I18n.log.tr,
                enableCollapse: false)
            .marginOnly(right: 10)
            .expanded()
      ].toRow();
    }
  }
}

class _WaitingWidget extends StatelessWidget {
  const _WaitingWidget({
    required this.controller,
  });

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return <Widget>[
      Text(I18n.waiting.tr,
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium),
      const Divider(),
      Expanded(child: Obx(() {
        return ListView.builder(
            itemBuilder: (context, index) => _buildDraggableTask(
                controller.scriptModel.waitingTaskList[index]),
            itemCount: controller.scriptModel.waitingTaskList.length);
      }))
    ]
        .toColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
        )
        .paddingAll(8)
        .card(margin: const EdgeInsets.fromLTRB(10, 0, 10, 10));
  }
}

class _PendingWidget extends StatelessWidget {
  const _PendingWidget({
    required this.controller,
  });

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return <Widget>[
      Text(I18n.pending.tr,
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium),
      const Divider(),
      SizedBox(
          height: 140,
          child: Obx(() {
            return ListView.builder(
                itemBuilder: (context, index) => _buildDraggableTask(
                    controller.scriptModel.pendingTaskList[index]),
                itemCount: controller.scriptModel.pendingTaskList.length);
          }))
    ]
        .toColumn(crossAxisAlignment: CrossAxisAlignment.start)
        .padding(top: 8, bottom: 0, left: 8, right: 8)
        .card(margin: const EdgeInsets.fromLTRB(10, 0, 10, 10));
  }
}

class _RunningWidget extends StatelessWidget {
  const _RunningWidget({
    required this.controller,
  });

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return DragTarget<TaskItemModel>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final past = DateTime.now().subtract(const Duration(seconds: 1));
        final formatted =
            '${past.year}-${past.month.toString().padLeft(2, '0')}-'
            '${past.day.toString().padLeft(2, '0')} '
            '${past.hour.toString().padLeft(2, '0')}:'
            '${past.minute.toString().padLeft(2, '0')}:'
            '${past.second.toString().padLeft(2, '0')}';
        controller.setTaskEnabled(details.data.taskName, formatted);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Card(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          color: isHovering
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: <Widget>[
            Text(I18n.running.tr,
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Obx(() {
              return TaskItemView(controller.scriptModel.runningTask.value);
            })
          ]
              .toColumn(crossAxisAlignment: CrossAxisAlignment.start)
              .padding(top: 8, bottom: 0, left: 8, right: 8),
        );
      },
    );
  }
}

class _SchedulerWidget extends StatelessWidget {
  const _SchedulerWidget({
    required this.controller,
  });

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return <Widget>[
      Text(I18n.scheduler.tr,
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium),
      <Widget>[
        Obx(() {
          return switch (controller.scriptModel.state.value) {
            ScriptState.running => const SpinKitChasingDots(
                color: Colors.green,
                size: 22,
              ),
            ScriptState.inactive =>
              const Icon(Icons.donut_large, size: 26, color: Colors.grey),
            ScriptState.warning =>
              const SpinKitDoubleBounce(color: Colors.orange, size: 26),
            ScriptState.updating => const Icon(Icons.browser_updated_rounded,
                size: 26, color: Colors.blue),
          };
        }),
        Obx(() {
          return IconButton(
            onPressed: () => {controller.toggleScript()},
            icon: const Icon(Icons.power_settings_new_rounded),
            isSelected:
                controller.scriptModel.state.value == ScriptState.running,
          );
        }),
      ].toRow(mainAxisAlignment: MainAxisAlignment.center)
    ]
        .toRow(mainAxisAlignment: MainAxisAlignment.spaceBetween)
        .constrained(height: 48)
        .paddingOnly(left: 8, right: 8)
        .card(margin: const EdgeInsets.fromLTRB(10, 0, 10, 10));
  }
}

Widget _buildDraggableTask(TaskItemModel item) {
  return Draggable<TaskItemModel>(
    data: item,
    feedback: Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(item.taskName.tr,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    ),
    childWhenDragging: Opacity(
      opacity: 0.4,
      child: TaskItemView(item),
    ),
    child: TaskItemView(item),
  );
}
