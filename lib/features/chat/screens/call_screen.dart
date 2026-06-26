import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../models/call_log.dart';
import '../services/call_service.dart';

/// Wrapper screen for ZegoCloud prebuilt voice/video call.
///
/// Handles:
/// - Initializing ZegoCloud call with correct app credentials
/// - Passing caller/callee info
/// - Logging call start, end, and duration to Firestore
class CallScreen extends StatefulWidget {
  final CallType callType;
  final String callId;
  final String conversationId;
  final String orderId;
  final String localUserId;
  final String localUserName;
  final String remoteUserId;
  final String remoteUserName;

  const CallScreen({
    super.key,
    required this.callType,
    required this.callId,
    required this.conversationId,
    required this.orderId,
    required this.localUserId,
    required this.localUserName,
    required this.remoteUserId,
    required this.remoteUserName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();

  /// Navigate to this screen to start a call.
  static void startCall(
    BuildContext context, {
    required CallType callType,
    required String conversationId,
    required String orderId,
    required String localUserId,
    required String localUserName,
    required String remoteUserId,
    required String remoteUserName,
  }) {
    final callService = CallService();
    final callId = callService.generateCallId(conversationId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callType: callType,
          callId: callId,
          conversationId: conversationId,
          orderId: orderId,
          localUserId: localUserId,
          localUserName: localUserName,
          remoteUserId: remoteUserId,
          remoteUserName: remoteUserName,
        ),
      ),
    );
  }
}

class _CallScreenState extends State<CallScreen> {
  final _callService = CallService();
  String? _callLogId;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _logCallStart();
  }

  Future<void> _logCallStart() async {
    try {
      _callLogId = await _callService.logCallStarted(
        conversationId: widget.conversationId,
        orderId: widget.orderId,
        callType: widget.callType,
        receiverId: widget.remoteUserId,
        receiverName: widget.remoteUserName,
      );
      _callStartTime = DateTime.now();
    } catch (e) {
      debugPrint('[CallScreen] Failed to log call start: $e');
    }
  }

  Future<void> _logCallEnd() async {
    if (_callLogId == null) return;
    try {
      if (_callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!).inSeconds;
        if (duration > 2) {
          // Call was connected (at least 2 seconds)
          await _callService.logCallCompleted(
            callLogId: _callLogId!,
            durationSeconds: duration,
          );
        } else {
          // Very short — likely missed/declined
          await _callService.logCallMissed(callLogId: _callLogId!);
        }
      } else {
        await _callService.logCallMissed(callLogId: _callLogId!);
      }
    } catch (e) {
      debugPrint('[CallScreen] Failed to log call end: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.callType == CallType.video;

    return ZegoUIKitPrebuiltCall(
      appID: CallService.zegoAppId,
      appSign: CallService.zegoAppSign,
      userID: widget.localUserId,
      userName: widget.localUserName,
      callID: widget.callId,
      config: isVideoCall
          ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      onDispose: () {
        _logCallEnd();
      },
    );
  }
}
