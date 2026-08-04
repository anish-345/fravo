import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'block_screen_context.dart';

/// Utility class that bootstraps the block screen Dart entrypoint.
///
/// This is called from within a `@pragma('vm:entry-point')` function that the
/// user defines. It sets up the Flutter binding, listens for `onAppBlocked`
/// events from the native accessibility service via a dedicated [MethodChannel],
/// and calls the user's [BlockScreenWidgetBuilder] to render the overlay.
///
/// ## Usage
///
/// In the user's app, define a top-level function:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void onBlockScreenRequested() {
///   ZoBlockScreenRunner.run(
///     builder: (context) => MyCustomBlockScreen(context: context),
///   );
/// }
/// ```
///
/// Then register it at app startup:
///
/// ```dart
/// ZoAppBlocker.instance.initialize(
///   blockScreenCallback: onBlockScreenRequested,
/// );
/// ```
class ZoBlockScreenRunner {
  ZoBlockScreenRunner._();

  /// The dedicated [MethodChannel] for communication between the block screen
  /// Dart isolate and the native accessibility service.
  ///
  /// This is separate from the main `zo_app_blocker` channel used by the
  /// primary app isolate.
  static const MethodChannel _channel =
      MethodChannel('zo_app_blocker_block_screen');

  /// Bootstraps the block screen entrypoint.
  ///
  /// Call this from your `@pragma('vm:entry-point')` function. It:
  /// 1. Initializes the Flutter binding
  /// 2. Listens for `onAppBlocked` events from the native service
  /// 3. Calls [builder] with a [BlockScreenContext] containing the blocked app info
  /// 4. Renders the returned widget as a fullscreen overlay
  ///
  /// Updates to the same blocked package (e.g. icon arriving after the overlay
  /// is already displayed) are handled reactively — the widget is updated
  /// in-place without a flicker-inducing full `runApp()` call.
  ///
  /// If [builder] is not provided, the package's built-in default block screen
  /// is used.
  static void run({BlockScreenWidgetBuilder? builder}) {
    WidgetsFlutterBinding.ensureInitialized();

    // ValueNotifier holds the current BlockScreenContext and drives reactive
    // updates when the icon/name arrives asynchronously.
    final contextNotifier = ValueNotifier<BlockScreenContext?>(null);

    // Notify native side that the Dart isolate is ready to receive events.
    _channel.invokeMethod<void>('blockScreenReady');

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAppBlocked') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final packageName = args['packageName'] as String;
        final appName = args['appName'] as String?;

        // Decode the app icon bytes if provided.
        Uint8List? appIcon;
        final iconData = args['appIcon'];
        if (iconData != null) {
          if (iconData is Uint8List) {
            appIcon = iconData;
          } else if (iconData is List) {
            appIcon = Uint8List.fromList(iconData.cast<int>());
          }
        }

        final newContext = BlockScreenContext(
          packageName: packageName,
          appName: appName,
          appIcon: appIcon,
          onDismiss: () {
            _channel.invokeMethod<void>('dismissBlockScreen');
          },
          onRequestTemporarySessionUnlock: () async {
            final result = await _channel.invokeMethod<bool>(
              'temporarySessionUnlock',
            );
            return result ?? false;
          },
        );

        final current = contextNotifier.value;
        if (current == null) {
          // First block event for a new package — boot the UI.
          contextNotifier.value = newContext;
          runApp(
            _BlockScreenApp(
              contextNotifier: contextNotifier,
              builder: builder,
            ),
          );
        } else {
          // Subsequent event for the same (or new) package — update reactively.
          // This handles the two-phase pattern:
          //   phase 1: overlay shown immediately with null icon/name
          //   phase 2: icon/name arrives from background thread, widget updates in-place
          contextNotifier.value = newContext;
        }
      }
    });
  }
}

/// Root app widget that holds the [contextNotifier] and rebuilds
/// reactively when the blocked app data updates (e.g. icon arrives).
class _BlockScreenApp extends StatelessWidget {
  const _BlockScreenApp({
    required this.contextNotifier,
    this.builder,
  });

  final ValueNotifier<BlockScreenContext?> contextNotifier;
  final BlockScreenWidgetBuilder? builder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ValueListenableBuilder<BlockScreenContext?>(
        valueListenable: contextNotifier,
        builder: (_, ctx, __) {
          if (ctx == null) return const SizedBox.shrink();
          return builder != null
              ? builder!(ctx)
              : _DefaultBlockScreen(context: ctx);
        },
      ),
    );
  }
}

/// A simple fallback block screen used when no custom builder is provided
/// to [ZoBlockScreenRunner.run].
///
/// This is intentionally minimal — the real default block screen with rich
/// styling is in `default_block_screen.dart` and is used when the user calls
/// `ZoBlockScreenRunner.run()` without a builder.
class _DefaultBlockScreen extends StatelessWidget {
  const _DefaultBlockScreen({required this.context});

  final BlockScreenContext context;

  @override
  Widget build(BuildContext buildContext) {
    return Scaffold(
      backgroundColor: const Color(0xFFF44336),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (context.appIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        context.appIcon!,
                        width: 72,
                        height: 72,
                      ),
                    ),
                  ),
                Text(
                  context.appName != null
                      ? '${context.appName} is Blocked'
                      : 'App Blocked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app is currently restricted.\nTap below to go back.',
                  style: TextStyle(
                    color: Color(0xFFFFCDD2),
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: context.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFF44336),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Go Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
