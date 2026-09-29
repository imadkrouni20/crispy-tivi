import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/screen_brightness_helper.dart';
import '../providers/pip_provider.dart';
import '../providers/player_settings_providers.dart';
import '../providers/playback_progress_provider.dart';
import 'player_fullscreen_overlay.dart';

/// Caches the notifiers the fullscreen overlay needs while it is being
/// disposed, when `ref` is no longer safe to read, and resets the
/// brightness, always-on-top and progress state on player exit.
mixin PlayerFullscreenExitMixin on ConsumerState<PlayerFullscreenOverlay> {
  late final PipNotifier pipNotifier;
  late final ScreenBrightnessNotifier _brightnessNotifier;
  late final AlwaysOnTopNotifier _alwaysOnTopNotifier;
  late final PlaybackProgressNotifier _progressNotifier;
  double? _brightnessOverride;
  bool _alwaysOnTop = false;

  /// Call from `initState`, before any use of the cached notifiers.
  void initExitState() {
    pipNotifier = ref.read(pipProvider.notifier);
    _brightnessNotifier = ref.read(screenBrightnessProvider.notifier);
    _alwaysOnTopNotifier = ref.read(alwaysOnTopProvider.notifier);
    _progressNotifier = ref.read(playbackProgressProvider.notifier);
    _brightnessOverride = ref.read(screenBrightnessProvider);
    _alwaysOnTop = ref.read(alwaysOnTopProvider);
    ref.listenManual(
      screenBrightnessProvider,
      (_, n) => _brightnessOverride = n,
    );
    ref.listenManual(alwaysOnTopProvider, (_, n) => _alwaysOnTop = n);
  }

  /// Reset screen brightness (REQ-04) and always-on-top on player exit.
  void resetExitState() {
    if (_brightnessOverride != null) {
      _brightnessNotifier.resetToSystem();
      ScreenBrightnessHelper.resetBrightness();
    }
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux) && _alwaysOnTop) {
      _alwaysOnTopNotifier.set(false);
      windowManager.setAlwaysOnTop(false);
    }
  }

  void saveProgressOnExit() => _progressNotifier.saveNow();
}
