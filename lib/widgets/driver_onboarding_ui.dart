import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/driver_onboarding.dart';

/// Éléments communs aux écrans du parcours chauffeur v2 (inscription, code,
/// connexion, dossier, compte suspendu). Couleurs de l'app ; tout est
/// directionnel (start/end) pour l'arabe.
class DriverUi {
  DriverUi._();

  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFF8C42);
  static const dark = Color(0xFF0F172A);
  static const darkCard = Color(0xFF1A2744);
  static const surface = Color(0xFFF8F9FB);
  static const border = Color(0xFFE2E6EF);
  static const textPrimary = Color(0xFF1A1F36);
  static const textSecondary = Color(0xFF6B7280);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const blue = Color(0xFF3B82F6);

  static TextStyle text(double size,
          {FontWeight weight = FontWeight.w400, Color color = textPrimary, double? height}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color, height: height);

  static InputDecoration input(String hint, {IconData? icon, String? errorText}) => InputDecoration(
        hintText: hint,
        hintStyle: text(13, color: const Color(0xFFB0B7C3)),
        prefixIcon: icon == null ? null : Icon(icon, color: orange, size: 20),
        errorText: errorText,
        errorMaxLines: 3,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: orange, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: red, width: 1.5)),
      );

  static Widget label(String text) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 8, start: 2),
        child: Text(text, style: DriverUi.text(13, weight: FontWeight.w600)),
      );
}

/// En-tête sombre + contenu sur fond clair, défilant.
class DriverOnboardingScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;

  const DriverOnboardingScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBack = true,
    this.trailing,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    Widget body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 32),
      child: child,
    );
    if (onRefresh != null) {
      body = RefreshIndicator(color: DriverUi.orange, onRefresh: onRefresh!, child: body);
    }
    return Scaffold(
      backgroundColor: DriverUi.dark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canPop)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const BackButtonIcon(),
                      color: Colors.white,
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    )
                  else
                    const SizedBox(width: 8),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: DriverUi.text(22, weight: FontWeight.w800, color: Colors.white)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!,
                                style: DriverUi.text(13,
                                    color: Colors.white.withOpacity(0.65), height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: DriverUi.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const DriverPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DriverUi.orange,
          disabledBackgroundColor: DriverUi.orange.withOpacity(0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: DriverUi.text(15, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Message d'erreur (ou d'information) avec une action facultative.
class DriverMessageBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DriverMessageBanner({
    super.key,
    required this.message,
    this.isError = true,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? DriverUi.red : DriverUi.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                  color: color, size: 19),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: DriverUi.text(12.5, color: color, height: 1.45))),
            ],
          ),
          if (actionLabel != null && onAction != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: color),
                child: Text(actionLabel!, style: DriverUi.text(13, weight: FontWeight.w700, color: color)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Choix du pays : champ qui ouvre la liste du serveur (244 pays, les 4
/// marchés principaux en tête) avec recherche par nom, code ou indicatif.
class DriverCountrySelector extends StatelessWidget {
  final List<DriverCountry> countries;
  final String? selected;
  final ValueChanged<String> onChanged;

  const DriverCountrySelector({
    super.key,
    required this.countries,
    required this.selected,
    required this.onChanged,
  });

  /// Drapeau à partir du code ISO (symboles d'indicateur régional).
  static String flag(String code) {
    if (code.length != 2) return '';
    return String.fromCharCodes(
        code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));
  }

  Future<void> _open(BuildContext context) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CountrySheet(countries: countries, selected: selected),
    );
    if (code != null) onChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    DriverCountry? current;
    for (final c in countries) {
      if (c.code == selected) current = c;
    }
    return InkWell(
      onTap: countries.isEmpty ? null : () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: DriverUi.input('driver_v2.country'.tr()).copyWith(
          suffixIcon: const Icon(Icons.expand_more_rounded, color: DriverUi.textSecondary),
        ),
        isEmpty: current == null,
        child: current == null
            ? null
            : Row(
                children: [
                  Text(flag(current.code), style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(current.name,
                        overflow: TextOverflow.ellipsis,
                        style: DriverUi.text(14, weight: FontWeight.w600)),
                  ),
                  Text('\u2066${current.dialCode}\u2069',
                      style: DriverUi.text(13, color: DriverUi.textSecondary)),
                ],
              ),
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  final List<DriverCountry> countries;
  final String? selected;
  const _CountrySheet({required this.countries, required this.selected});

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final q = _fold(_query.trim()).replaceAll('+', '');
    final list = q.isEmpty
        ? widget.countries
        : widget.countries
            .where((c) =>
                _fold(c.name).contains(q) ||
                c.code.toLowerCase() == q ||
                c.dialCode.replaceAll('+', '').startsWith(q))
            .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: DriverUi.border, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: DriverUi.text(14),
                decoration: DriverUi.input('driver_v2.search_country'.tr(), icon: Icons.search_rounded),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 8),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  final selected = c.code == widget.selected;
                  return ListTile(
                    leading: Text(DriverCountrySelector.flag(c.code), style: const TextStyle(fontSize: 22)),
                    title: Text(c.name,
                        style: DriverUi.text(14, weight: selected ? FontWeight.w700 : FontWeight.w500)),
                    trailing: Text('\u2066${c.dialCode}\u2069',
                        style: DriverUi.text(13, color: DriverUi.textSecondary)),
                    selected: selected,
                    selectedTileColor: DriverUi.orange.withOpacity(0.08),
                    onTap: () => Navigator.pop(context, c.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Champ téléphone : indicatif du pays choisi + numéro, toujours de gauche à
/// droite (même en arabe). Accepte espaces, 0 initial, chiffres arabes.
class DriverPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String dialCode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  const DriverPhoneField({
    super.key,
    required this.controller,
    required this.dialCode,
    this.errorText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-.()٠-٩۰-۹]')),
          LengthLimitingTextInputFormatter(20),
        ],
        onChanged: onChanged,
        style: DriverUi.text(15, weight: FontWeight.w600),
        decoration: DriverUi.input('driver_v2.phone_hint'.tr(), errorText: errorText).copyWith(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_iphone_rounded, color: DriverUi.orange, size: 20),
                const SizedBox(width: 8),
                Text(dialCode, style: DriverUi.text(15, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
