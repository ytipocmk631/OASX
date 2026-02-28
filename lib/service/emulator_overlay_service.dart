import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:get/get.dart';
import 'package:win32/win32.dart';

/// 如果 win32 版本没有导出这个常量，自己定义
const GWLP_HWNDPARENT = -8;

typedef _UpdateLayeredWindowN = Int32 Function(
    IntPtr,
    IntPtr,
    Pointer<POINT>,
    Pointer<SIZE>,
    IntPtr,
    Pointer<POINT>,
    Uint32,
    Pointer<BLENDFUNCTION>,
    Uint32);
typedef _UpdateLayeredWindowD = int Function(int, int, Pointer<POINT>,
    Pointer<SIZE>, int, Pointer<POINT>, int, Pointer<BLENDFUNCTION>, int);

final _u32 = DynamicLibrary.open('user32.dll');
final _ulw = _u32.lookupFunction<_UpdateLayeredWindowN, _UpdateLayeredWindowD>(
    'UpdateLayeredWindow');

const _kUlwAlpha = 0x00000002;
const _kAcSrcOver = 0x00;
const _hwndTopmost = -1; // HWND_TOPMOST: 置于所有非置顶窗口之上

class _Entry {
  final int eHwnd;
  final int oHwnd;
  final String label;
  _Entry(this.eHwnd, this.oHwnd, this.label);
}

class EmulatorOverlayService extends GetxService {
  final isEnabled = false.obs;

  final _map = <int, _Entry>{};
  Timer? _timer;

  static const _cls = 'OASXEmuOverlay';
  static const _width = 90;
  static const _height = 35;
  bool _clsReg = false;

  void toggle() => isEnabled.value ? disable() : enable();

  void enable() {
    if (isEnabled.value) return;
    isEnabled.value = true;
    _regClass();
    _syncWindows();
    _timer = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _syncWindows());
  }

  void disable() {
    if (!isEnabled.value) return;
    isEnabled.value = false;
    _timer?.cancel();
    _timer = null;
    _destroyAll();
  }

  @override
  void onClose() {
    disable();
    super.onClose();
  }

  static bool _isMumuInstance(String title) {
    if (!title.startsWith('MuMu')) return false;
    if (!title.contains('-')) return false;
    final dash = title.lastIndexOf('-');
    if (dash == title.length - 1) return false;
    final afterDash = title.substring(dash + 1);
    return afterDash.isNotEmpty &&
        afterDash.codeUnits.every((c) => c >= 48 && c <= 57);
  }

  void _syncWindows() {
    final current = <int>{};
    final buf = calloc<Uint16>(512).cast<Utf16>();
    final rect = calloc<RECT>();

    try {
      int h = FindWindowEx(NULL, NULL, nullptr, nullptr);
      while (h != 0) {
        final n = GetWindowText(h, buf, 511);
        if (n > 0) {
          final title = buf.toDartString(length: n);
          if (_isMumuInstance(title)) {
            GetWindowRect(h, rect);
            final isMinimized = rect.ref.left <= -30000;

            if (!isMinimized) {
              current.add(h);

              if (!_map.containsKey(h)) {
                final ov = _createOverlay(h, title);
                if (ov != 0) {
                  _map[h] = _Entry(h, ov, title);
                }
              } else {
                _syncPos(h, _map[h]!.oHwnd);
              }
            }
          }
        }
        h = FindWindowEx(NULL, h, nullptr, nullptr);
      }
    } finally {
      calloc.free(buf);
      calloc.free(rect);
    }

    final gone = _map.keys.where((k) => !current.contains(k)).toList();
    for (final k in gone) {
      DestroyWindow(_map[k]!.oHwnd);
      _map.remove(k);
    }
  }

  void _regClass() {
    if (_clsReg) return;

    final cn = _cls.toNativeUtf16();

    try {
      final wc = calloc<WNDCLASSEX>();
      wc.ref.cbSize = sizeOf<WNDCLASSEX>();
      wc.ref.lpfnWndProc = Pointer.fromFunction<WNDPROC>(_defProc, 0);
      wc.ref.hInstance = GetModuleHandle(nullptr);
      wc.ref.lpszClassName = cn;
      wc.ref.hbrBackground = NULL;

      RegisterClassEx(wc);
      calloc.free(wc);
      _clsReg = true;
    } finally {
      calloc.free(cn);
    }
  }

  static int _defProc(int h, int m, int w, int l) {
    // 让所有鼠标命中测试返回 HTTRANSPARENT，使覆层完全穿透鼠标点击
    if (m == WM_NCHITTEST) return HTTRANSPARENT;
    return DefWindowProc(h, m, w, l);
  }

  int _createOverlay(int eHwnd, String title) {
    final dash = title.lastIndexOf('12');
    final shortLabel = dash >= 0 ? ' ${title.substring(dash)}' : '#0';

    final cn = _cls.toNativeUtf16();
    final wn = ''.toNativeUtf16();
    final rect = calloc<RECT>();

    try {
      GetWindowRect(eHwnd, rect);

      final x = rect.ref.left;
      final y = rect.ref.top;

      final oHwnd = CreateWindowEx(
        WINDOW_EX_STYLE.WS_EX_LAYERED |
            WINDOW_EX_STYLE.WS_EX_TOOLWINDOW |
            WINDOW_EX_STYLE.WS_EX_NOACTIVATE |
            WINDOW_EX_STYLE.WS_EX_TRANSPARENT |
            WINDOW_EX_STYLE.WS_EX_TOPMOST,
        cn,
        wn,
        WINDOW_STYLE.WS_POPUP,
        x,
        y,
        _width,
        _height,
        NULL,
        NULL,
        GetModuleHandle(nullptr),
        nullptr,
      );

      if (oHwnd == 0) return 0;

      // 🔥 关键：绑定 Owner
      SetWindowLongPtr(oHwnd, GWLP_HWNDPARENT, eHwnd);

      _paint(oHwnd, shortLabel, x, y);

      ShowWindow(oHwnd, SHOW_WINDOW_CMD.SW_SHOWNOACTIVATE);

      SetWindowPos(
        oHwnd,
        _hwndTopmost,
        x,
        y,
        _width,
        _height,
        SET_WINDOW_POS_FLAGS.SWP_NOACTIVATE |
            SET_WINDOW_POS_FLAGS.SWP_SHOWWINDOW,
      );

      return oHwnd;
    } finally {
      calloc.free(cn);
      calloc.free(wn);
      calloc.free(rect);
    }
  }

  void _paint(int oHwnd, String label, int x, int y) {
    const opacity = 220;
    const bgR = 30, bgG = 30, bgB = 30;

    final hScr = GetDC(NULL);
    final hMem = CreateCompatibleDC(hScr);

    final bi = calloc<BITMAPINFO>();
    bi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bi.ref.bmiHeader.biWidth = _width;
    bi.ref.bmiHeader.biHeight = -_height;
    bi.ref.bmiHeader.biPlanes = 1;
    bi.ref.bmiHeader.biBitCount = 32;
    bi.ref.bmiHeader.biCompression = BI_COMPRESSION.BI_RGB;

    final pvPtr = calloc<Pointer<Uint32>>();
    final hBmp = CreateDIBSection(
        hMem, bi, DIB_USAGE.DIB_RGB_COLORS, pvPtr.cast(), NULL, 0);
    calloc.free(bi);

    if (hBmp == 0) {
      calloc.free(pvPtr);
      DeleteDC(hMem);
      ReleaseDC(NULL, hScr);
      return;
    }

    final old = SelectObject(hMem, hBmp);

    const bgColor = (bgB & 0xFF) | ((bgG & 0xFF) << 8) | ((bgR & 0xFF) << 16);

    final pixels = pvPtr.value;
    for (int i = 0; i < _width * _height; i++) {
      pixels[i] = bgColor;
    }
    calloc.free(pvPtr);

    SetBkMode(hMem, BACKGROUND_MODE.TRANSPARENT);
    SetTextColor(hMem, RGB(255, 255, 255));

    final lbl = label.toNativeUtf16();
    final txRc = calloc<RECT>()
      ..ref.left = 10
      ..ref.top = 4
      ..ref.right = _width - 4
      ..ref.bottom = _height - 4;

    DrawText(
      hMem,
      lbl,
      -1,
      txRc,
      DRAW_TEXT_FORMAT.DT_LEFT |
          DRAW_TEXT_FORMAT.DT_VCENTER |
          DRAW_TEXT_FORMAT.DT_SINGLELINE |
          DRAW_TEXT_FORMAT.DT_END_ELLIPSIS,
    );

    calloc.free(txRc);
    calloc.free(lbl);

    final src = calloc<POINT>()
      ..ref.x = 0
      ..ref.y = 0;
    final sz = calloc<SIZE>()
      ..ref.cx = _width
      ..ref.cy = _height;
    final dst = calloc<POINT>()
      ..ref.x = x
      ..ref.y = y;

    final bf = calloc<BLENDFUNCTION>()
      ..ref.BlendOp = _kAcSrcOver
      ..ref.BlendFlags = 0
      ..ref.SourceConstantAlpha = opacity
      ..ref.AlphaFormat = 0;

    _ulw(oHwnd, hScr, dst, sz, hMem, src, 0, bf, _kUlwAlpha);

    calloc.free(src);
    calloc.free(sz);
    calloc.free(dst);
    calloc.free(bf);

    SelectObject(hMem, old);
    DeleteObject(hBmp);
    DeleteDC(hMem);
    ReleaseDC(NULL, hScr);
  }

  void _syncPos(int eHwnd, int oHwnd) {
    final r = calloc<RECT>();
    try {
      if (GetWindowRect(eHwnd, r) == 0) return;

      if (r.ref.left <= -30000) {
        ShowWindow(oHwnd, SHOW_WINDOW_CMD.SW_HIDE);
        return;
      }

      SetWindowPos(
        oHwnd,
        _hwndTopmost,
        r.ref.left,
        r.ref.top,
        _width,
        _height,
        SET_WINDOW_POS_FLAGS.SWP_NOACTIVATE |
            SET_WINDOW_POS_FLAGS.SWP_SHOWWINDOW,
      );
    } finally {
      calloc.free(r);
    }
  }

  void _destroyAll() {
    for (final e in _map.values) {
      DestroyWindow(e.oHwnd);
    }
    _map.clear();
  }
}
