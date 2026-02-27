library nav;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/model/script_model.dart';
import 'package:oasx/service/locale_service.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/service/websocket_service.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:oasx/views/args/args_view.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:treemenu2/treemenu2.dart';

import 'package:oasx/views/overview/overview_view.dart';
import 'package:oasx/api/api_client.dart';

import 'package:oasx/config/translation/i18n_content.dart';
import 'package:oasx/utils//platform_utils.dart';

part '../../controller/ctrl_nav.dart';
part './tree_menu_view.dart';

class Nav extends StatefulWidget {
  const Nav({Key? key}) : super(key: key);

  @override
  State<Nav> createState() => _NavState();
}

class _NavState extends State<Nav> {
  final _searchController = SearchController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: GetX<NavCtrl>(builder: (controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchBar(context, controller),
            _filterChips(context, controller),
            Expanded(child: _navList(context, controller)),
            _trailing(context),
          ],
        );
      }),
    );
  }

  Widget _searchBar(BuildContext context, NavCtrl controller) {
    return Obx(() {
      final hasText = controller.searchText.value.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: SearchBar(
          controller: _searchController,
          hintText: I18n.search.tr,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8),
          ),
          constraints: const BoxConstraints(minHeight: 36),
          leading: null,
          trailing: hasText
              ? [
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      controller.searchText.value = '';
                    },
                    child: const Icon(Icons.clear, size: 16),
                  )
                ]
              : null,
          onChanged: (v) => controller.searchText.value = v,
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _filterChips(BuildContext context, NavCtrl controller) {
    final states = [
      (ScriptState.running, I18n.filter_running.tr),
      (ScriptState.inactive, I18n.inactive.tr),
      (ScriptState.warning, I18n.warning.tr),
    ];
    return Obx(() {
      final current = controller.filterState.value;
      return Wrap(
        spacing: 4,
        runSpacing: 2,
        children: states.map((entry) {
          final (state, label) = entry;
          final isSelected = current == state;
          return FilterChip(
            label: Text(label,
                style: Theme.of(context).textTheme.labelSmall),
            selected: isSelected,
            showCheckmark: false,
            avatar: null,
            onSelected: (v) {
              controller.filterState.value = v ? state : null;
            },
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            selectedColor:
                Theme.of(context).colorScheme.primaryContainer,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ).padding(horizontal: 6, bottom: 4);
    });
  }

  Widget _navList(BuildContext context, NavCtrl controller) {
    final scriptService = Get.find<ScriptService>();
    return Obx(() {
      // 订阅 scriptModelMap 及每个 model 的 state 以响应运行状态变化
      scriptService.scriptModelMap.forEach((k, v) => v.state.value);
      final list = controller.filteredNavList;
      return ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final name = list[index];
          final isSelected = controller.selectedScript.value == name;
          return _navItem(context, controller, name, isSelected);
        },
      );
    });
  }

  Widget _navItem(BuildContext context, NavCtrl controller, String name,
      bool isSelected) {
    return GestureDetector(
      onSecondaryTapDown: name == 'Home'
          ? null
          : (details) {
              if (PlatformUtils.isMobile) return;
              _showContextMenu(context, details.globalPosition, name);
            },
      onLongPressStart: name == 'Home'
          ? null
          : (details) {
              if (!PlatformUtils.isMobile) return;
              _showContextMenu(context, details.globalPosition, name);
            },
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        selected: isSelected,
        selectedTileColor:
            Theme.of(context).colorScheme.secondaryContainer,
        title: Text(
          name.tr,
          style: Theme.of(context).textTheme.labelMedium,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => controller.switchScriptByName(name),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    return <Widget>[
      IconButton(
          icon: const Icon(Icons.add), onPressed: () => addButton(context)),
      // _DarkMode(onPressed: controllerSetting.updateTheme),
      IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Get.toNamed('/settings');
          }),
    ]
        .toColumn(mainAxisAlignment: MainAxisAlignment.end)
        .padding(bottom: 10)
        .expanded();
  }

  Future<void> addButton(BuildContext context) async {
    String newName = await ApiClient().getNewConfigName();
    final template = 'template'.obs;
    List<String> configAll = await ApiClient().getConfigAll();
    NavCtrl controllerNav = Get.find<NavCtrl>();
    Get.defaultDialog(
        title: I18n.config_add.tr,
        middleText: '',
        onConfirm: () async {
          await controllerNav.addConfig(newName, template.value);
          Get.back();
        },
        content: <Widget>[
          Text(I18n.new_name.tr),
          TextFormField(
              initialValue: newName,
              onChanged: (value) {
                newName = value;
              }).constrained(width: 200),
          Text(I18n.config_copy_from_exist.tr),
          Obx(() {
            return DropdownButton<String>(
              value: template.value,
              menuMaxHeight: 300,
              items: configAll
                  .map<DropdownMenuItem<String>>((e) => DropdownMenuItem(
                      value: e.toString(),
                      child: Text(
                        e.toString(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ).constrained(width: 177)))
                  .toList(),
              onChanged: (value) {
                template.value = value.toString();
              },
            );
          }),
        ].toColumn(crossAxisAlignment: CrossAxisAlignment.start));
  }

  // 弹出右键/长按菜单
  void _showContextMenu(BuildContext context, Offset position, String name) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 5, position.dy + 5),
      items: [
        PopupMenuItem(
          child: <Widget>[
            const Icon(Icons.edit, size: 18),
            const SizedBox(width: 3),
            Text(I18n.rename.tr),
          ].toRow(mainAxisSize: MainAxisSize.min).paddingAll(0).constrained(
              minWidth: 20, maxWidth: 80, minHeight: 10, maxHeight: 30),
          onTap: () => _showRenameDialog(name),
        ),
        PopupMenuItem(
          child: <Widget>[
            const Icon(Icons.delete, size: 18, color: Colors.red),
            const SizedBox(width: 3),
            Text(I18n.delete.tr),
          ].toRow(mainAxisSize: MainAxisSize.min).paddingAll(0).constrained(
              minWidth: 20, maxWidth: 80, minHeight: 10, maxHeight: 30),
          onTap: () => _showDeleteDialog(name),
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(String oldName) async {
    final navController = Get.find<NavCtrl>();
    final canRename = await tryCloseScriptWithReason(
        oldName, 'rename script[$oldName] config file');
    if (!canRename) return;

    String newName = oldName;
    final formKey = GlobalKey<FormState>();
    Get.defaultDialog(
      title: I18n.rename.tr,
      textConfirm: I18n.confirm.tr,
      textCancel: I18n.cancel.tr,
      content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            decoration: InputDecoration(
              labelText: I18n.new_name.tr,
            ),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return I18n.name_cannot_empty.tr;
              }
              if (['Home', 'home'].contains(value)) {
                return I18n.name_invalid.tr;
              }
              if (oldName == value ||
                  navController.navNameList.contains(value)) {
                return I18n.name_duplicate.tr;
              }
              return null;
            },
            onChanged: (v) => newName = v,
          )),
      onConfirm: () async {
        if (!(formKey.currentState?.validate() ?? false)) {
          return;
        }
        Get.back();
        await navController.renameConfig(oldName, newName);
      },
      onCancel: () {},
    );
  }

  Future<void> _showDeleteDialog(String name) async {
    final navController = Get.find<NavCtrl>();
    final canDelete = await tryCloseScriptWithReason(
        name, 'delete script[$name] config file');
    if (!canDelete) return;
    Get.defaultDialog(
      title: I18n.delete.tr,
      textConfirm: I18n.confirm.tr,
      textCancel: I18n.cancel.tr,
      middleText: '${I18n.delete_confirm.tr} "$name"?',
      onConfirm: () async {
        Get.back();
        await navController.deleteConfig(name);
      },
      onCancel: () {},
    );
  }

  Future<bool> tryCloseScriptWithReason(
      String scriptName, String reason) async {
    try {
      final wsService = Get.find<WebSocketService>();
      final scriptModel = Get.find<ScriptService>().findScriptModel(scriptName);
      if (scriptModel != null &&
          scriptModel.state.value == ScriptState.running) {
        Get.snackbar(I18n.tip.tr, I18n.config_update_tip.tr,
            duration: const Duration(milliseconds: 2000));
        return false;
      }
      await wsService.close(scriptName);
    } catch (e) {
      // overviewController not found is safe to operate
      if (e.toString().contains('not found')) {
        return true;
      }
      // other exceptions are not safe
      return false;
    }
    // not run and close ws success
    return true;
  }
}
