import 'dart:async';

import 'package:cyberguard/const/channels.dart';
import 'package:cyberguard/domain/error.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A provider that tracks and handles requests to verify the presence of the
/// user when accessing sensitive data. The value of this provider is a [bool]
/// indicating whether the user is present (true) or not.
///
/// The provider automatically locks itself when the application is
/// backgrounded (or otherwise if the application lifecycle state changes) and
/// after a period of inactivity. The provider will unlock itself on a
/// successful call to [checkPresence] and will remain unlocked until it locks
/// itself again, or until [clearPresenceStatus] is called.
///
/// Additionally, if a [checkPresence] call is interrupted by a call to
/// [cancelPresenceCheck], the provider will lock itself.
class UserPresenceProvider extends StateNotifier<bool>
    with WidgetsBindingObserver {
  /// A reference to the Flutter Platform Channel for CyberGuard User Presence
  /// services.
  static const _userPresencePlatform = MethodChannel(kUserPresenceChannel);

  /// The version of the platform channel implementation this service is expecting.
  /// Bump only for breaking changes.
  static const _userPresencePlatformVersion = 1;

  // ---

  /// The duration of inactivity after which the [UserPresenceProvider] will
  /// lock itself.
  static const inactivityPeriod = Duration(minutes: 5);

  // ---

  UserPresenceProvider._() : super(false) {
    WidgetsBinding.instance.addObserver(this);
  }

  // ---

  /// The timer that automatically re-locks the [UserPresenceProvider] after
  /// a period of inactivity. This reference is to enable the timer to be
  /// cancelled if the user's presence is verified before the timer completes
  /// to extend the period of inactivity, or to clear the timer if the user
  /// presence status is cleared.
  Timer? _presenceTimer;

  /// Clears the presence timer, if it is active, and clears the reference to
  /// the timer.
  void _clearPresenceTimer() {
    if (_presenceTimer != null) {
      // If the timer is active, cancel it.
      if (_presenceTimer!.isActive) {
        _presenceTimer!.cancel();
      }

      // Then clear the reference to the timer.
      _presenceTimer = null;
    }
  }

  // ---

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    // If the lifecycle state is not resumed (i.e., the application is
    // backgrounded), and the provider is unlocked, lock the provider.
    if (state != AppLifecycleState.resumed && this.state) {
      clearPresenceStatus();
    }
  }

  // ---

  /// This should be the only method that updates the state of the
  /// [UserPresenceProvider] to true. It is private to ensure that the state
  /// can only be updated by the [checkPresence] method.
  ///
  /// This method is used to initialize the timer that will lock the provider
  /// after a period of inactivity.
  void _unlock() {
    // Clear the presence timer if it is active, to ensure that it is not
    // running concurrently with the new timer (i.e., extend the period of
    // inactivity required to lock the provider).
    _clearPresenceTimer();

    // Start the timer to clear the presence status after a period of
    // inactivity.
    _presenceTimer = Timer(
      inactivityPeriod,
      clearPresenceStatus,
    );

    // Then, update the state to true to indicate that the user is present.
    state = true;
  }

  // ---

  /// Requests that the user presence service check for the presence of the
  /// user by presenting a biometric (or other platform) prompt. If the user
  /// is present, the [UserPresenceProvider] will update its state to true.
  /// Otherwise the state will remain (or be set to) false.
  ///
  /// If the [force] flag is set to true, the [UserPresenceProvider] will
  /// update its state to false to ensure that the user is required to
  /// re-authenticate. Otherwise, if the user is already authenticated, the
  /// [UserPresenceProvider] will not update its state and the user will NOT
  /// be prompted to re-authenticate.
  Future<void> checkPresence({final bool force = false}) async {
    // If the app is already unlocked, either lock the app if the force flag
    // is set, or return early.
    if (state) {
      if (force) {
        clearPresenceStatus();
      } else {
        return;
      }
    }

    try {
      // The platform must explicitly return true for the presence check to
      // succeed.
      if ((await _userPresencePlatform.invokeMethod('verifyUserPresence')
          as bool)) {
        _unlock();
      } else {
        clearPresenceStatus();
      }
    } catch (_) {
      // If the platform channel is unavailable or throws an error, we assume
      // that the user is not present.
      clearPresenceStatus();
    }
  }

  /// Cancels any pending presence check. This will cause the
  /// [UserPresenceProvider] to update its state to false, if it is not already
  /// false.
  void cancelPresenceCheck() async {
    // Clears the presence status first, before issuing the command to the
    // platform channel to ensure that the state is updated immediately.
    clearPresenceStatus();
    await _userPresencePlatform.invokeMethod('cancelVerifyUserPresence');
  }

  /// Clears the presence status of the user. This will cause the
  /// [UserPresenceProvider] to update its state to false, if it is not already
  /// false.
  void clearPresenceStatus() {
    _clearPresenceTimer();

    // Finally, update the state to false to indicate that the user is not
    // present.
    state = false;
  }

  /// Initializes the [UserPresenceProvider], returning a Future that completes
  /// with a new instance of the provider if the platform channel is available,
  /// otherwise throws a [CGCompatibilityError].
  static Future<UserPresenceProvider> initialize() async {
    if (!await _platformChannelPing()) {
      throw CGUserPresenceCompatibilityError();
    }

    // If the platform channel is available, we can safely return a new
    // instance of the UserPresenceProvider.
    return UserPresenceProvider._();
  }

  //region Platform Channel Code

  static Future<Map<dynamic, dynamic>> _getPlatformChannelInfo() async {
    return (await _userPresencePlatform
        .invokeMethod('ping')
        .timeout(const Duration(milliseconds: 1000))) as Map<dynamic, dynamic>;
  }

  /// Pings the platform channel interface to determine whether there is a compliant
  /// implementation on the current platform. Returns true if there is, otherwise
  /// false.
  static Future<bool> _platformChannelPing() async {
    try {
      final Map<dynamic, dynamic> pingResponse =
          await _getPlatformChannelInfo();

      return pingResponse['ping'] == 'pong' &&
          pingResponse['version'] == _userPresencePlatformVersion;
    } catch (_) {
      return false;
    }
  }

  //endregion
}

final userPresenceProvider = StateNotifierProvider<UserPresenceProvider, bool>(
  (final ref) => throw TypeError(),
);
