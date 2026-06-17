import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/support_models.dart';
import '../services/support_service.dart';

const _navy    = Color(0xFF0F172A);
const _navyMid = Color(0xFF1E293B);
const _orange  = Color(0xFFFF6B35);
const _green   = Color(0xFF22C55E);
const _amber   = Color(0xFFF59E0B);
const _red     = Color(0xFFEF4444);
const _surface = Color(0xFFF8F9FB);
const _border  = Color(0xFFE8ECF0);

class SupportTicketChatScreen extends StatefulWidget {
  final String ticketId;

  const SupportTicketChatScreen({super.key, required this.ticketId});

  @override
  State<SupportTicketChatScreen> createState() =>
      _SupportTicketChatScreenState();
}

class _SupportTicketChatScreenState extends State<SupportTicketChatScreen> {
  SupportTicketChat? _chat;
  bool _loading = true;
  String? _error;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _connectWebSocket();
  }

  @override
  void dispose() {
    SupportWebSocketService.removeListeners();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final chat = await SupportService.getTicketChat(widget.ticketId);
    if (!mounted) return;
    if (chat == null) {
      setState(() { _loading = false; _error = 'Impossible de charger le chat.'; });
    } else {
      setState(() { _loading = false; _chat = chat; });
      _scrollToBottom();
    }
  }

  Future<void> _connectWebSocket() async {
    await SupportWebSocketService.connect();
    SupportWebSocketService.listenForTicketUpdate(widget.ticketId, (updated) {
      if (mounted) {
        setState(() => _chat = updated);
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final status = _chat?.status ?? 'open';
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 20,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket #${widget.ticketId.length > 8 ? widget.ticketId.substring(0, 8) : widget.ticketId}...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                _buildStatusBadge(status),
              ],
            ),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'resolved':
        color = _green; label = 'Résolu'; break;
      case 'closed':
        color = Colors.grey; label = 'Fermé'; break;
      default:
        color = _amber; label = 'En cours';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _orange),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.poppins(fontSize: 14, color: _red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              child: Text('Réessayer',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final messages = _chat?.messages ?? [];
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Aucun message pour l\'instant',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Text('L\'équipe support vous répondra bientôt.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _orange,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: messages.length,
        itemBuilder: (context, i) => _buildBubble(messages[i]),
      ),
    );
  }

  Widget _buildBubble(SupportMessage msg) {
    switch (msg.sender) {
      case 'user':
        return _buildUserBubble(msg);
      case 'admin':
        return _buildAdminBubble(msg);
      default:
        return _buildSystemBubble(msg);
    }
  }

  Widget _buildUserBubble(SupportMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: _orange.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              msg.message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(msg.timestamp),
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBubble(SupportMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _navyMid,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: _orange, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support AtlasMove',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _navyMid,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.message,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF1A1F36),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(msg.timestamp),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemBubble(SupportMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            msg.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month) {
      return DateFormat('HH:mm').format(dt.toLocal());
    }
    return DateFormat('dd MMM, HH:mm').format(dt.toLocal());
  }
}
