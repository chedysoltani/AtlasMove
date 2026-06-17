import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/call_models.dart';
import '../services/call_service.dart';
import 'active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallSession session;

  const IncomingCallScreen({super.key, required this.session});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isAnswering = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // If caller hangs up before we answer, close this screen
    CallService.onCallEnded = (_) {
      if (mounted) Navigator.of(context).pop();
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Only clear if this screen set the callback
    if (CallService.onCallEnded != null) {
      CallService.onCallEnded = null;
    }
    super.dispose();
  }

  Future<void> _accept() async {
    if (_isAnswering) return;
    setState(() => _isAnswering = true);

    final ok = await CallService().acceptCall(
      widget.session.callSessionId,
      widget.session.channelName,
      widget.session.agoraToken,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            session: widget.session,
            isOutgoing: false,
          ),
        ),
      );
    } else {
      setState(() => _isAnswering = false);
      final err = CallService().lastError ?? 'Erreur inconnue';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('call.join_error'.tr()),
          content: SelectableText(err),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  Future<void> _reject() async {
    await CallService().rejectCall(widget.session.callSessionId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.session.caller;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Caller avatar with pulse animation
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.25),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    caller.name.isNotEmpty ? caller.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Caller name
            Text(
              caller.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            // Status label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF22C55E).withOpacity(0.3),
                ),
              ),
              child: Text(
                'call.incoming'.tr(),
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const Spacer(flex: 3),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reject
                  _CallActionButton(
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFEF4444),
                    label: 'common.reject'.tr(),
                    onTap: _reject,
                  ),

                  // Accept
                  _CallActionButton(
                    icon: _isAnswering
                        ? Icons.hourglass_top_rounded
                        : Icons.call_rounded,
                    color: const Color(0xFF22C55E),
                    label: 'common.accept'.tr(),
                    onTap: _isAnswering ? null : _accept,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
