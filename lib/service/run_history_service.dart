import 'dart:async';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/model/const/storage_key.dart';
import 'package:oasx/model/script_model.dart';
import 'package:oasx/service/script_service.dart';

class RunHistoryService extends GetxService {
  final _storage = GetStorage('RunHistory');

  // history: hourKey → {scriptName → stateName}
  final historyData = <String, Map<String, String>>{}.obs;

  final _workerMap = <String, Worker>{};
  Timer? _refreshTimer;

  // ── 生命周期 ────────────────────────────────────────────────

  @override
  Future<void> onInit() async {
    _loadFromStorage();
    _cleanOldRecords();
    _setupMapListener();
    _startPeriodicRefresh();
    super.onInit();
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    for (final w in _workerMap.values) {
      w.dispose();
    }
    _workerMap.clear();
    super.onClose();
  }

  // ── 加载 / 持久化 ───────────────────────────────────────────

  void _loadFromStorage() {
    final stored = _storage.read(StorageKey.runHistory.name);
    if (stored is Map) {
      final parsed = <String, Map<String, String>>{};
      stored.forEach((k, v) {
        if (v is Map) {
          parsed[k.toString()] = Map<String, String>.from(
            v.map((a, b) => MapEntry(a.toString(), b.toString())),
          );
        }
      });
      historyData.value = parsed;
    }
  }

  void _persistToStorage() {
    final plain = {
      for (final e in historyData.entries)
        e.key: Map<String, String>.from(e.value)
    };
    _storage.write(StorageKey.runHistory.name, plain);
  }

  // ── 清理 ────────────────────────────────────────────────────

  void _cleanOldRecords() {
    final cutoff = DateTime.now().subtract(const Duration(days: 3));
    historyData.removeWhere((key, _) {
      try {
        final dt = DateTime.parse('${key.replaceFirst(' ', 'T')}:00');
        return dt.isBefore(cutoff);
      } catch (_) {
        return true;
      }
    });
    _persistToStorage();
  }

  // ── 定时全量刷新 ────────────────────────────────────────────

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      recordAllActive();
    });
  }

  /// 把当前所有活跃脚本刷写一遍到当前时间槽（供外部手动调用）
  void recordAllActive() {
    final scriptService = Get.find<ScriptService>();
    bool changed = false;
    for (final entry in scriptService.scriptModelMap.entries) {
      final state = entry.value.state.value;
      if (state == ScriptState.running || state == ScriptState.warning) {
        _writeSlot(entry.key, _hourKey(DateTime.now()), state.name);
        changed = true;
      }
    }
    if (changed) {
      historyData.refresh();
      _persistToStorage();
    }
  }

  // ── Workers（状态变更时即时记录） ───────────────────────────

  void _setupMapListener() {
    final scriptService = Get.find<ScriptService>();
    ever(scriptService.scriptModelMap, (_) => _refreshWorkers(scriptService));
    _refreshWorkers(scriptService);
  }

  void _refreshWorkers(ScriptService scriptService) {
    final current = scriptService.scriptModelMap.keys.toSet();
    for (final name in _workerMap.keys.toSet().difference(current)) {
      _workerMap.remove(name)?.dispose();
    }
    for (final entry in scriptService.scriptModelMap.entries) {
      if (_workerMap.containsKey(entry.key)) continue;
      final name = entry.key;
      _workerMap[name] = ever(entry.value.state, (ScriptState s) {
        _onStateChange(name, s);
      });
    }
  }

  void _onStateChange(String scriptName, ScriptState state) {
    if (state == ScriptState.updating) return;

    final currentKey = _hourKey(DateTime.now());

    if (state == ScriptState.inactive) {
      final slot = historyData[currentKey];
      if (slot != null) {
        slot.remove(scriptName);
        if (slot.isEmpty) {
          historyData.remove(currentKey);
        } else {
          historyData.refresh();
        }
        _persistToStorage();
      }
      return;
    }

    _writeSlot(scriptName, currentKey, state.name);
    historyData.refresh();
    _persistToStorage();
  }

  // ── 工具 ────────────────────────────────────────────────────

  void _writeSlot(String scriptName, String hourKey, String stateName) {
    historyData.update(
      hourKey,
      (e) {
        e[scriptName] = stateName;
        return e;
      },
      ifAbsent: () => {scriptName: stateName},
    );
  }

  String _hourKey(DateTime dt) {
    final minute = (dt.minute ~/ 5) * 5;
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
  /// 按时间倒序返回所有记录
  List<MapEntry<String, Map<String, String>>> getSortedHistory() {
    final entries = historyData.entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }
}
