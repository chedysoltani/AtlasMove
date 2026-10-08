import 'package:shared_preferences/shared_preferences.dart';

/// Textes des notifications système (canaux Android, notifications locales,
/// notification du suivi GPS).
///
/// Ces notifications peuvent être construites hors de l'arbre de widgets : dans
/// l'isolate d'arrière-plan de Firebase Messaging (app fermée) ou avant runApp,
/// là où les traductions easy_localization ne sont pas chargées. On lit donc
/// directement la langue choisie dans l'app et on garde ici les textes concernés.
class SystemStrings {
  SystemStrings._();

  /// Même clé que LocaleProvider (langue choisie par l'utilisateur).
  static const _localeKey = 'selected_locale';
  static String _lang = 'fr';

  /// Relit la langue choisie ; à appeler avant de construire une notification.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _lang = prefs.getString(_localeKey) ?? 'fr';
    } catch (_) {}
  }

  static String get(String key, {Map<String, String> args = const {}}) {
    var text = _strings[_lang]?[key] ?? _strings['fr']![key] ?? key;
    args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }

  static const Map<String, Map<String, String>> _strings = {
    'fr': {
      'ride_channel': 'Nouvelles courses',
      'ride_channel_desc': 'Alerte quand une nouvelle course est disponible',
      'call_channel': 'Appels entrants',
      'call_channel_desc': 'Sonnerie d\'appel entrant client / chauffeur',
      'rdv_channel': 'Nouveaux rendez-vous',
      'rdv_channel_desc': 'Alerte quand un nouveau rendez-vous est disponible',
      'location_channel': 'Suivi de position',
      'location_channel_desc': 'Maintient le suivi GPS actif pendant une course',
      'accept': 'Accepter',
      'refuse': 'Refuser',
      'answer': 'Répondre',
      'ride_title': 'Nouvelle course disponible !',
      'ride_waiting': 'Une course vous attend',
      'ride_pickup': 'Départ : {pickup}',
      'ride_ticker': 'Nouvelle course',
      'call_default': 'Appel entrant',
      'call_body': 'Appel AtlasMove entrant…',
      'rdv_title': 'Nouveau rendez-vous disponible',
      'location_title': '🚗 AtlasMove — Course active',
      'location_body': 'Suivi de position en cours…',
    },
    'en': {
      'ride_channel': 'New rides',
      'ride_channel_desc': 'Alert when a new ride is available',
      'call_channel': 'Incoming calls',
      'call_channel_desc': 'Customer / driver incoming call ringtone',
      'rdv_channel': 'New appointments',
      'rdv_channel_desc': 'Alert when a new appointment is available',
      'location_channel': 'Location tracking',
      'location_channel_desc': 'Keeps GPS tracking active during a ride',
      'accept': 'Accept',
      'refuse': 'Decline',
      'answer': 'Answer',
      'ride_title': 'New ride available!',
      'ride_waiting': 'A ride is waiting for you',
      'ride_pickup': 'Pickup: {pickup}',
      'ride_ticker': 'New ride',
      'call_default': 'Incoming call',
      'call_body': 'Incoming AtlasMove call…',
      'rdv_title': 'New appointment available',
      'location_title': '🚗 AtlasMove — Active ride',
      'location_body': 'Location tracking in progress…',
    },
    'ar': {
      'ride_channel': 'رحلات جديدة',
      'ride_channel_desc': 'تنبيه عند توفر رحلة جديدة',
      'call_channel': 'المكالمات الواردة',
      'call_channel_desc': 'رنين المكالمات الواردة بين العميل والسائق',
      'rdv_channel': 'مواعيد جديدة',
      'rdv_channel_desc': 'تنبيه عند توفر موعد جديد',
      'location_channel': 'تتبّع الموقع',
      'location_channel_desc': 'يُبقي تتبّع GPS نشطًا أثناء الرحلة',
      'accept': 'قبول',
      'refuse': 'رفض',
      'answer': 'رد',
      'ride_title': 'رحلة جديدة متاحة!',
      'ride_waiting': 'رحلة بانتظارك',
      'ride_pickup': 'الانطلاق: {pickup}',
      'ride_ticker': 'رحلة جديدة',
      'call_default': 'مكالمة واردة',
      'call_body': 'مكالمة AtlasMove واردة…',
      'rdv_title': 'موعد جديد متاح',
      'location_title': '🚗 AtlasMove — رحلة نشطة',
      'location_body': 'تتبّع الموقع جارٍ…',
    },
    'de': {
      'ride_channel': 'Neue Fahrten',
      'ride_channel_desc': 'Benachrichtigung, wenn eine neue Fahrt verfügbar ist',
      'call_channel': 'Eingehende Anrufe',
      'call_channel_desc': 'Klingelton für eingehende Anrufe Kunde / Fahrer',
      'rdv_channel': 'Neue Termine',
      'rdv_channel_desc': 'Benachrichtigung, wenn ein neuer Termin verfügbar ist',
      'location_channel': 'Standortverfolgung',
      'location_channel_desc': 'Hält die GPS-Verfolgung während einer Fahrt aktiv',
      'accept': 'Annehmen',
      'refuse': 'Ablehnen',
      'answer': 'Annehmen',
      'ride_title': 'Neue Fahrt verfügbar!',
      'ride_waiting': 'Eine Fahrt wartet auf Sie',
      'ride_pickup': 'Abholung: {pickup}',
      'ride_ticker': 'Neue Fahrt',
      'call_default': 'Eingehender Anruf',
      'call_body': 'Eingehender AtlasMove-Anruf…',
      'rdv_title': 'Neuer Termin verfügbar',
      'location_title': '🚗 AtlasMove — Aktive Fahrt',
      'location_body': 'Standortverfolgung läuft…',
    },
    'es': {
      'ride_channel': 'Nuevos viajes',
      'ride_channel_desc': 'Aviso cuando hay un nuevo viaje disponible',
      'call_channel': 'Llamadas entrantes',
      'call_channel_desc': 'Tono de llamada entrante cliente / conductor',
      'rdv_channel': 'Nuevas citas',
      'rdv_channel_desc': 'Aviso cuando hay una nueva cita disponible',
      'location_channel': 'Seguimiento de ubicación',
      'location_channel_desc': 'Mantiene el seguimiento GPS activo durante un viaje',
      'accept': 'Aceptar',
      'refuse': 'Rechazar',
      'answer': 'Responder',
      'ride_title': '¡Nuevo viaje disponible!',
      'ride_waiting': 'Un viaje te espera',
      'ride_pickup': 'Salida: {pickup}',
      'ride_ticker': 'Nuevo viaje',
      'call_default': 'Llamada entrante',
      'call_body': 'Llamada entrante de AtlasMove…',
      'rdv_title': 'Nueva cita disponible',
      'location_title': '🚗 AtlasMove — Viaje activo',
      'location_body': 'Seguimiento de ubicación en curso…',
    },
    'it': {
      'ride_channel': 'Nuove corse',
      'ride_channel_desc': 'Avviso quando è disponibile una nuova corsa',
      'call_channel': 'Chiamate in arrivo',
      'call_channel_desc': 'Suoneria delle chiamate in arrivo cliente / autista',
      'rdv_channel': 'Nuovi appuntamenti',
      'rdv_channel_desc': 'Avviso quando è disponibile un nuovo appuntamento',
      'location_channel': 'Tracciamento posizione',
      'location_channel_desc': 'Mantiene attivo il tracciamento GPS durante una corsa',
      'accept': 'Accetta',
      'refuse': 'Rifiuta',
      'answer': 'Rispondi',
      'ride_title': 'Nuova corsa disponibile!',
      'ride_waiting': 'Una corsa ti aspetta',
      'ride_pickup': 'Partenza: {pickup}',
      'ride_ticker': 'Nuova corsa',
      'call_default': 'Chiamata in arrivo',
      'call_body': 'Chiamata AtlasMove in arrivo…',
      'rdv_title': 'Nuovo appuntamento disponibile',
      'location_title': '🚗 AtlasMove — Corsa attiva',
      'location_body': 'Tracciamento della posizione in corso…',
    },
  };
}
