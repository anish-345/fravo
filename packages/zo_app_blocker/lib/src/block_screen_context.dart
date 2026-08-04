import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// The type signature for a user-provided block screen builder function.
///
/// This function receives a [BlockScreenContext] containing all relevant
/// information about the blocked app and action callbacks, and must return
/// a [Widget] that will be displayed as the block screen overlay.
///
/// Example:
/// ```dart
/// Widget myBlockScreenBuilder(BlockScreenContext context) {
///   return Center(
///     child: Column(
///       mainAxisSize: MainAxisSize.min,
///       children: [
///         if (context.appIcon != null) Image.memory(context.appIcon!),
///         Text('${context.appName} is blocked'),
///         ElevatedButton(
///           onPressed: context.onDismiss,
///           child: const Text('Go Home'),
///         ),
///       ],
///     ),
///   );
/// }
/// ```
typedef BlockScreenWidgetBuilder = Widget Function(BlockScreenContext context);

/// Context object passed to the block screen builder with all relevant
/// information about the blocked app and action callbacks.
///
/// This is the single argument to a [BlockScreenWidgetBuilder]. It contains:
/// - Identification of the blocked app ([packageName], [appName], [appIcon])
/// - An [onDismiss] callback to close the overlay and go home
/// - An optional [onRequestTemporarySessionUnlock] callback for pay-to-unlock flows
class BlockScreenContext {
  /// Creates a new [BlockScreenContext].
  const BlockScreenContext({
    required this.packageName,
    this.appName,
    this.appIcon,
    required this.onDismiss,
    this.onRequestTemporarySessionUnlock,
  });

  /// The package name of the blocked app (e.g., 'com.instagram.android').
  final String packageName;

  /// The human-readable name of the blocked app (e.g., 'Instagram').
  ///
  /// May be null if the app name could not be resolved.
  final String? appName;

  /// The app icon as PNG-encoded bytes.
  ///
  /// May be null if the icon could not be retrieved.
  final Uint8List? appIcon;

  /// Dismisses the block screen overlay and sends the user to the home screen.
  ///
  /// Call this from your block screen's "Exit" or "Go Back" button.
  final VoidCallback onDismiss;

  /// Requests temporary session access to the blocked app.
  ///
  /// This is intended for "pay-to-unlock" flows. The app will remain
  /// unblocked for the current session (until the user navigates away or goes home).
  ///
  /// The returned [Future] completes with `true` if the unlock was granted
  /// by the native side, or `false` if it was denied.
  ///
  /// This field is `null` if no unlock handler has been configured.
  final Future<bool> Function()? onRequestTemporarySessionUnlock;
}
