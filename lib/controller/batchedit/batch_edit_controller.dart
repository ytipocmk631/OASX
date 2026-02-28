import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/config/translation/i18n_content.dart';
import 'package:oasx/views/nav/view_nav.dart';

class CommonFieldModel {
  final String groupName;
  final String argName;
  final String type;
  final String? description;
  final List<String>? enumEnum;
  final dynamic minimum;
  final dynamic maximum;

  /// 各脚本当前值: { scriptName: currentValue }
  final Map<String, dynamic> currentValues;

  /// 新值输入框的临时值（默认取第一个脚本的值）
  dynamic newValue;

  CommonFieldModel({
    required this.groupName,
    required this.argName,
    required this.type,
    required this.currentValues,
    this.description,
    this.enumEnum,
    this.minimum,
    this.maximum,
  }) {
    newValue =
        currentValues.values.isNotEmpty ? currentValues.values.first : null;
  }
}

class BatchEditController extends GetxController {
  final selectedTask = ''.obs;
  final selectedScripts = <String>{}.obs;
  final isLoading = false.obs;

  /// groupName -> list of common fields
  final commonGroups = <String, List<CommonFieldModel>>{}.obs;
  final groupNames = <String>[].obs;

  @override
  void onInit() {
    final navCtrl = Get.find<NavCtrl>();
    // 初始化：选中所有脚本，选中第一个可用任务
    final scripts = navCtrl.navNameList.skip(1).toList();
    selectedScripts.assignAll(scripts.toSet());

    final tasks = availableTasks;
    if (tasks.isNotEmpty) {
      selectedTask.value = tasks.first;
    }
    super.onInit();
  }

  /// 从 scriptMenuJson 提取所有任务名（顶层 key + 子菜单项）
  List<String> get availableTasks {
    final navCtrl = Get.find<NavCtrl>();
    final result = <String>[];
    navCtrl.scriptMenuJson.forEach((key, subList) {
      if (subList.isEmpty) {
        result.add(key);
      } else {
        result.addAll(subList);
      }
    });
    return result;
  }

  /// 并发加载所有选中脚本该任务的参数，求同名字段交集
  Future<void> loadCommonFields() async {
    if (selectedTask.value.isEmpty || selectedScripts.isEmpty) return;
    isLoading.value = true;
    commonGroups.value = {};
    groupNames.value = [];

    try {
      final api = ApiClient();
      final task = selectedTask.value;
      final scripts = selectedScripts.toList();

      // 并发拉取
      final results = await Future.wait(
        scripts.map((s) => api.getScriptTask(s, task)),
      );

      // 构建: groupName -> argName -> { scriptName: argData }
      // 先收集 第一个脚本的所有字段作为候选
      final Map<String, Map<String, dynamic>> firstMap = {};
      final firstResult = results[0];
      firstResult.forEach((groupName, argList) {
        for (final arg in (argList as List)) {
          final name = arg['name'] as String;
          firstMap.putIfAbsent(groupName, () => <String, dynamic>{})[name] =
              arg;
        }
      });

      // 与后续脚本求交集（字段名相同即可）
      // 同时收集每个脚本的当前值
      // structure: groupName -> argName -> { scriptName: value }
      final Map<String, Map<String, Map<String, dynamic>>> valueMap = {};

      for (int i = 0; i < scripts.length; i++) {
        final scriptName = scripts[i];
        final scriptResult = results[i];
        scriptResult.forEach((groupName, argList) {
          for (final arg in (argList as List)) {
            final argName = arg['name'] as String;
            valueMap
                .putIfAbsent(groupName, () => {})
                .putIfAbsent(argName, () => {})[scriptName] = arg['value'];
          }
        });
      }

      // 保留在所有脚本都出现的字段（交集）
      final Map<String, List<CommonFieldModel>> result = {};
      final orderedGroups = <String>[];

      firstMap.forEach((groupName, argsMap) {
        final commonList = <CommonFieldModel>[];
        argsMap.forEach((argName, argData) {
          final perScriptValues = valueMap[groupName]?[argName];
          if (perScriptValues == null) return;
          // 检查所有脚本都有此字段
          if (perScriptValues.length < scripts.length) return;

          commonList.add(CommonFieldModel(
            groupName: groupName,
            argName: argName,
            type: argData['type'] as String,
            description: argData['description'] as String?,
            enumEnum: argData['enumEnum'] != null
                ? List<String>.from(argData['enumEnum'])
                : null,
            minimum: argData['minimum'],
            maximum: argData['maximum'],
            currentValues: Map<String, dynamic>.from(perScriptValues),
          ));
        });
        if (commonList.isNotEmpty) {
          result[groupName] = commonList;
          orderedGroups.add(groupName);
        }
      });

      commonGroups.value = result;
      groupNames.value = orderedGroups;
    } catch (e) {
      printError(info: 'BatchEditController.loadCommonFields error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 对所有选中脚本批量写入某字段
  Future<void> applyToSelected(
      String groupName, String argName, String type, dynamic value) async {
    final api = ApiClient();
    final task = selectedTask.value;
    final scripts = selectedScripts.toList();

    final futures = scripts
        .map((s) => api.putScriptArg(s, task, groupName, argName, type, value));
    final results = await Future.wait(futures);
    final allSuccess = results.every((r) => r);

    if (allSuccess) {
      // 更新本地当前值
      final group = commonGroups[groupName];
      if (group != null) {
        final field = group.firstWhereOrNull((f) => f.argName == argName);
        if (field != null) {
          for (final s in scripts) {
            field.currentValues[s] = value;
          }
          field.newValue = value;
          commonGroups.refresh();
        }
      }
      Get.snackbar(I18n.batch_edit_success.tr, '$argName = $value',
          duration: const Duration(seconds: 2));
    }
  }

  void toggleScript(String name) {
    if (selectedScripts.contains(name)) {
      if (selectedScripts.length > 1) {
        selectedScripts.remove(name);
      }
    } else {
      selectedScripts.add(name);
    }
    selectedScripts.refresh();
  }
}
