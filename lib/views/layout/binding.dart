import 'package:get/get.dart';
import 'package:oasx/controller/batchedit/batch_edit_controller.dart';
import 'package:oasx/service/emulator_overlay_service.dart';
import 'package:oasx/service/run_history_service.dart';
import 'package:oasx/service/script_service.dart';

import 'package:oasx/views/nav/view_nav.dart';
import 'package:oasx/views/args/args_view.dart';

class LayoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<NavCtrl>(permanent: true, NavCtrl()); // 全局唯一的
    Get.lazyPut(fenix: true, () => ArgsController()); // 全局唯一的
    Get.lazyPut(fenix: true, () => BatchEditController()); // 批量配置编辑器
    Get.put<ScriptService>(ScriptService(), permanent: true);
    Get.put<EmulatorOverlayService>(EmulatorOverlayService(), permanent: true);
    Get.putAsync(() async => RunHistoryService(), permanent: true);
  }
}
