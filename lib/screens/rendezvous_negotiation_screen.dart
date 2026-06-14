import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_service.dart';
import '../utils/fare_calculator.dart';

const _orange = Color(0xFFFF6B35);
const _navy = Color(0xFF0F172A);
const _surface = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF64748B);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _indigo = Color(0xFF6366F1);
const _amber = Color(0xFFF59E0B);

class RendezvousNegotiationScreen extends StatefulWidget {
  final Rendezvous rdv;
  final bool isDriver; // true = driver view, false = client view

  const RendezvousNegotiationScreen({
    super.key,
    required this.rdv,
    required this.isDriver,
  });

  @override
  State<RendezvousNegotiationScreen> createState() =>
      _RendezvousNegotiationScreenState();
}

class _RendezvousNegotiationScreenState
    extends State<RendezvousNegotiationScreen> {
  List<RendezvousOffer> _offers = [];
  bool _loading = true;
  String? _error;
  final Set<String> _actingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await RendezvousService.getOffers(widget.rdv.id);
      if (mounted) setState(() { _offers = offers; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // 403 = backend permissions not yet configured — show empty state, not error
      if (msg.contains('403') || msg.contains('Forbidden') || msg.contains('role permissions')) {
        setState(() { _offers = []; _loading = false; });
      } else {
        setState(() { _error = msg; _loading = false; });
      }
    }
  }

  Future<void> _acceptOffer(RendezvousOffer offer) async {
    setState(() => _actingIds.add(offer.id));
    try {
      await RendezvousService.acceptOffer(offer.id);
      _showSnack('Offre acceptée — RDV confirmé', success: true);
      await _load();
    } catch (e) {
      _showSnack('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _actingIds.remove(offer.id));
    }
  }

  Future<void> _rejectOffer(RendezvousOffer offer) async {
    setState(() => _actingIds.add(offer.id));
    try {
      await RendezvousService.rejectOffer(offer.id);
      _showSnack('Offre refusée');
      await _load();
    } catch (e) {
      _showSnack('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _actingIds.remove(offer.id));
    }
  }

  Future<void> _counter(RendezvousOffer offer) async {
    final currency = offer.currency;
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Text('💬', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text('Contre-proposition',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offre actuelle : ${FareCalculator.formatFare(offer.proposedFare, currency)}',
              style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Votre prix ($currency)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _indigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: Text('Envoyer',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _actingIds.add(offer.id));
    try {
      await RendezvousService.counterOffer(offer.id, value);
      _showSnack('Contre-proposition de ${FareCalculator.formatFare(value, currency)} envoyée');
      await _load();
    } catch (e) {
      _showSnack('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _actingIds.remove(offer.id));
    }
  }

  void _showSnack(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: success ? _green : _red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: _navy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Négociation',
                style: GoogleFonts.poppins(
                    color: _navy, fontWeight: FontWeight.w700, fontSize: 16)),
            Text(widget.rdv.serviceName,
                style: GoogleFonts.poppins(
                    color: _textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _navy, size: 22),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildRdvSummary()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Historique des offres',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: _navy),
                          ),
                        ),
                      ),
                      _offers.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                  child: _buildOfferCard(_offers[i]),
                                ),
                                childCount: _offers.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 48),
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: _orange),
            label: Text('Réessayer',
                style: GoogleFonts.poppins(
                    color: _orange, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                color: _indigo.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.handshake_rounded, color: _indigo, size: 30),
          ),
          const SizedBox(height: 14),
          Text('Aucune offre pour le moment',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 15, color: _navy)),
          const SizedBox(height: 6),
          Text(
            widget.isDriver
                ? 'Proposez un prix via le bouton "Proposer" sur la carte disponible.'
                : 'Le livreur peut proposer un prix différent. Revenez ici pour répondre.',
            style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Widget _buildRdvSummary() {
    final rdv = widget.rdv;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.event_rounded, color: _orange, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rdv.serviceName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _navy)),
                Text(
                  DateFormat('EEE dd MMM yyyy • HH:mm', 'fr').format(rdv.scheduledAt),
                  style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
                ),
              ]),
            ),
          ]),
          if (rdv.estimatedFare != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prix proposé par le client',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: _textSecondary)),
                  Text(
                    FareCalculator.formatFare(rdv.estimatedFare!, rdv.currency ?? 'TND'),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _orange),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferCard(RendezvousOffer offer) {
    final isFromMe = widget.isDriver
        ? offer.proposedBy == 'driver'
        : offer.proposedBy == 'client';

    Color statusColor;
    String statusLabel;
    switch (offer.status) {
      case 'accepted':
        statusColor = _green;
        statusLabel = 'Acceptée';
        break;
      case 'rejected':
        statusColor = _red;
        statusLabel = 'Refusée';
        break;
      case 'countered':
        statusColor = _amber;
        statusLabel = 'Contre-offre';
        break;
      default:
        statusColor = _indigo;
        statusLabel = 'En attente';
    }

    final isActing = _actingIds.contains(offer.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFromMe ? _orange.withOpacity(0.3) : _indigo.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: (isFromMe ? _orange : _indigo).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFromMe ? Icons.person_rounded : Icons.support_agent_rounded,
                    color: isFromMe ? _orange : _indigo,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFromMe
                                ? (widget.isDriver ? 'Vous (livreur)' : 'Vous (client)')
                                : (widget.isDriver ? 'Client' : 'Livreur'),
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13, color: _navy),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(statusLabel,
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FareCalculator.formatFare(offer.proposedFare, offer.currency),
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isFromMe ? _orange : _indigo),
                      ),
                      Text(
                        DateFormat('dd/MM • HH:mm', 'fr').format(offer.createdAt),
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action buttons — only show for pending offers NOT from me
          if (offer.isPending && !isFromMe) ...[
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  // Reject
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isActing ? null : () => _rejectOffer(offer),
                      icon: isActing
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _red))
                          : const Icon(Icons.close_rounded, size: 16, color: _red),
                      label: Text('Refuser',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _red)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: _red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Counter
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isActing ? null : () => _counter(offer),
                      icon: const Icon(Icons.edit_rounded, size: 16, color: _indigo),
                      label: Text('Contre',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _indigo)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: _indigo),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Accept
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isActing ? null : () => _acceptOffer(offer),
                      icon: isActing
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white),
                      label: Text('Accepter',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
