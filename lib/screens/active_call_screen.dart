import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/call_models.dart';
import '../services/call_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final CallSession session;

  /// true  = I am the caller (driver), waiting for the callee to pick up
  /// false = I am the callee (client), already connected
  final bool isOutgoing;

  const ActiveCallScreen({
    super.key,
    required this.session,
    required this.isOutgoing,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool _isActive = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // If we are the callee we are already in the channel — call is immediately active
    _isActive = !widget.isOutgoing;
    if (_isActive) _startTimer();

    // Caller side: watch for callee acceptance
    CallService.onCallAccepted = (_) {
      if (!mounted) return;
      setState(() => _isActive = true);
      _startTimer();
    };

    // Either party hung up
    CallService.onCallEnded = (_) {
      if (mounted) _handleCallOver();
    };

    // Callee rejected (caller side only)
    CallService.onCallRejected = (_) {
      if (mounted) _handleCallOver();
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    CallService.onCallAccepted = null;
    CallService.onCallEnded = null;
    CallService.onCallRejected = null;
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _handleCallOver() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    await CallService().endCall();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleMute() async {
    await CallService().toggleMute();
    setState(() => _isMuted = CallService().isMuted);
  }

  Future<void> _toggleSpeaker() async {
    await CallService().toggleSpeaker();
    setState(() => _isSpeakerOn = CallService().isSpeakerOn);
  }

  String get _formattedDuration {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _remotePartyName {
    return widget.isOutgoing
        ? widget.session.callee.name
        : widget.session.caller.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildHeader(),
            const Spacer(flex: 2),
            _buildAvatar(),
            const SizedBox(height: 20),
            _buildNameAndStatus(),
            const Spacer(flex: 3),
            _buildControlRow(),
            const SizedBox(height: 40),
            _buildEndCallButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'call.minimize'.tr(),
            ),
          ),
          const Spacer(),
          Text(
            'AtlasMove',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final initial = _remotePartyName.isNotEmpty
        ? _remotePartyName[0].toUpperCase()
        : '?';

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E293B),
        border: Border.all(
          color: _isActive
              ? const Color(0xFF22C55E).withOpacity(0.5)
              : const Color(0xFFFF6600).withOpacity(0.4),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isActive
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFFF6600))
                .withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNameAndStatus() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _remotePartyName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        _isActive
            ? Text(
                _formattedDuration,
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              )
            : _PulsingLabel(text: 'call.connecting'.tr()),
      ],
    );
  }

  Widget _buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: _isMuted ? 'call.muted'.tr() : 'call.mic'.tr(),
          active: _isMuted,
          onTap: _isActive ? _toggleMute : null,
        ),
        const SizedBox(width: 32),
        _ControlButton(
          icon: _isSpeakerOn
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          label: _isSpeakerOn ? 'call.speaker'.tr() : 'call.earpiece'.tr(),
          active: !_isSpeakerOn,
          onTap: _isActive ? _toggleSpeaker : null,
        ),
      ],
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 34),
      ),
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? Colors.white.withOpacity(0.85)
                    : Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              child: Icon(
                icon,
                color: active ? const Color(0xFF0F172A) : Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingLabel extends StatefulWidget {
  final String text;
  const _PulsingLabel({required this.text});

  @override
  State<_PulsingLabel> createState() => _PulsingLabelState();
}

class _PulsingLabelState extends State<_PulsingLabel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        widget.text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
