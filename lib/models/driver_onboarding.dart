/// Modèles du parcours chauffeur v2 (docs backend : API_CONTRACT_DRIVER.md).
/// Lecture tolérante : un champ absent ne doit jamais faire planter l'app.
library;

String? _str(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

int? _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Statut du compte chauffeur (`account_status`).
class DriverAccountStatus {
  DriverAccountStatus._();
  static const pendingDocuments = 'pending_documents';
  static const pendingReview = 'pending_review';
  static const active = 'active';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
}

/// Étape suivante (`next_action`).
class DriverNextAction {
  DriverNextAction._();
  static const uploadDocuments = 'UPLOAD_DOCUMENTS';
  static const replaceRejectedDocuments = 'REPLACE_REJECTED_DOCUMENTS';
  static const waitForReview = 'WAIT_FOR_REVIEW';
  static const none = 'NONE';
  static const contactSupport = 'CONTACT_SUPPORT';
}

/// Statut d'un document (`documents[].status`).
class DriverDocumentStatus {
  DriverDocumentStatus._();
  static const missing = 'missing';
  static const uploaded = 'uploaded';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

// ── registration-options ─────────────────────────────────────────────────────

class DriverDocumentSpec {
  final String type;
  final String label;
  const DriverDocumentSpec({required this.type, required this.label});

  factory DriverDocumentSpec.fromJson(Map<String, dynamic> json) =>
      DriverDocumentSpec(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? json['type']?.toString() ?? '',
      );
}

class DriverCountry {
  final String code; // code ISO à deux lettres (MA, TN, FR…)
  final String name;
  final String dialCode; // +212…
  /// Chiffres d'un numéro mobile, sans l'indicatif ni le 0 initial.
  /// Vide si le serveur ne les donne pas (voir DriverPhone.knownLengths).
  final List<int> phoneLengths;
  final String defaultLanguage;
  final List<DriverDocumentSpec> requiredDocuments;
  final List<DriverDocumentSpec> optionalDocuments;

  const DriverCountry({
    required this.code,
    required this.name,
    required this.dialCode,
    this.phoneLengths = const [],
    required this.defaultLanguage,
    this.requiredDocuments = const [],
    this.optionalDocuments = const [],
  });

  factory DriverCountry.fromJson(Map<String, dynamic> json) {
    final docs = _map(json['documents']);
    List<DriverDocumentSpec> specs(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => DriverDocumentSpec.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
    return DriverCountry(
      code: json['code']?.toString().toUpperCase() ?? '',
      name: json['name']?.toString() ?? '',
      dialCode: json['dial_code']?.toString() ?? '',
      phoneLengths: (json['phone_lengths'] is List ? json['phone_lengths'] as List : const [])
          .map(_int)
          .whereType<int>()
          .toList(),
      defaultLanguage: json['default_language']?.toString() ?? 'fr',
      requiredDocuments: specs(docs['required']),
      optionalDocuments: specs(docs['optional']),
    );
  }
}

class DriverVehicleType {
  final String value; // voiture, moto…
  final String label;
  final String? serviceId;
  final String? serviceName;

  const DriverVehicleType({
    required this.value,
    required this.label,
    this.serviceId,
    this.serviceName,
  });

  factory DriverVehicleType.fromJson(Map<String, dynamic> json) {
    final service = json['service'] is Map ? _map(json['service']) : null;
    return DriverVehicleType(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value']?.toString() ?? '',
      serviceId: _str(service?['id']),
      serviceName: _str(service?['name']),
    );
  }
}

class DriverRegistrationOptions {
  final List<DriverCountry> countries;
  final List<DriverVehicleType> vehicleTypes;
  final int maxFileBytes;
  /// E-mail demandé à l'inscription : le code y est envoyé (contrat du 14/10).
  final bool emailRequired;
  final bool otpAvailable;
  final int otpCodeLength;
  final int otpResendAfter;
  final int passwordMinLength;
  final int reviewSlaHours;

  const DriverRegistrationOptions({
    required this.countries,
    required this.vehicleTypes,
    this.maxFileBytes = 10485760,
    this.emailRequired = false,
    this.otpAvailable = true,
    this.otpCodeLength = 6,
    this.otpResendAfter = 60,
    this.passwordMinLength = 8,
    this.reviewSlaHours = 24,
  });

  factory DriverRegistrationOptions.fromJson(Map<String, dynamic> json) {
    final files = _map(json['files']);
    final otp = _map(json['otp']);
    final password = _map(json['password']);
    return DriverRegistrationOptions(
      countries: (json['countries'] is List ? json['countries'] as List : const [])
          .whereType<Map>()
          .map((e) => DriverCountry.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.code.isNotEmpty)
          .toList(),
      vehicleTypes: (json['vehicle_types'] is List ? json['vehicle_types'] as List : const [])
          .whereType<Map>()
          .map((e) => DriverVehicleType.fromJson(Map<String, dynamic>.from(e)))
          .where((v) => v.value.isNotEmpty)
          .toList(),
      maxFileBytes: _int(files['max_size_bytes']) ?? 10485760,
      emailRequired: _map(json['email'])['required'] == true || otp['channel'] == 'email',
      otpAvailable: otp['available'] != false,
      otpCodeLength: _int(otp['code_length']) ?? 6,
      otpResendAfter: _int(otp['resend_after']) ?? 60,
      passwordMinLength: _int(password['min_length']) ?? 8,
      reviewSlaHours: _int(json['review_sla_hours']) ?? 24,
    );
  }

  DriverCountry? country(String? code) {
    for (final c in countries) {
      if (c.code == code) return c;
    }
    return null;
  }
}

// ── OTP ──────────────────────────────────────────────────────────────────────

class DriverOtpRequest {
  final String requestId;
  /// `email` (ou `whatsapp` sur un serveur pas encore à jour).
  final String channel;
  /// Adresse où le code est parti, masquée (`y•••••f@example.com`).
  final String? sentTo;
  final int expiresIn;
  final int resendAfter;

  const DriverOtpRequest({
    required this.requestId,
    this.channel = 'email',
    this.sentTo,
    this.expiresIn = 300,
    this.resendAfter = 60,
  });

  factory DriverOtpRequest.fromJson(Map<String, dynamic> json) => DriverOtpRequest(
        requestId: json['request_id']?.toString() ?? '',
        channel: json['channel']?.toString() ?? 'email',
        sentTo: _str(json['sent_to']),
        expiresIn: _int(json['expires_in']) ?? 300,
        resendAfter: _int(json['resend_after']) ?? 60,
      );

  bool get isEmail => channel == 'email';
}

// ── Profil chauffeur (GET /v2/driver/me) ─────────────────────────────────────

class DriverDocument {
  final String type;
  final String label;
  final bool required;
  final String status;
  final String? rejectionReason;
  final DateTime? uploadedAt;
  final int uploadCount;

  const DriverDocument({
    required this.type,
    required this.label,
    required this.required,
    required this.status,
    this.rejectionReason,
    this.uploadedAt,
    this.uploadCount = 0,
  });

  factory DriverDocument.fromJson(Map<String, dynamic> json) => DriverDocument(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? json['type']?.toString() ?? '',
        required: json['required'] == true,
        status: json['status']?.toString() ?? DriverDocumentStatus.missing,
        rejectionReason: _str(json['rejection_reason']),
        uploadedAt: DateTime.tryParse(json['uploaded_at']?.toString() ?? ''),
        uploadCount: _int(json['upload_count']) ?? 0,
      );

  bool get isMissing => status == DriverDocumentStatus.missing;
  bool get isRejected => status == DriverDocumentStatus.rejected;
  bool get isApproved => status == DriverDocumentStatus.approved;
}

class DriverProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String? country;
  final String? city;
  final String? vehicleType;
  final String accountStatus;
  final String nextAction;
  final String? rejectionReason;
  final int reviewSlaHours;
  final List<String> requiredDocuments;
  final List<String> missingDocuments;
  final List<String> rejectedDocuments;
  final List<DriverDocument> documents;
  final bool hasPassword;

  const DriverProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.country,
    this.city,
    this.vehicleType,
    required this.accountStatus,
    required this.nextAction,
    this.rejectionReason,
    this.reviewSlaHours = 24,
    this.requiredDocuments = const [],
    this.missingDocuments = const [],
    this.rejectedDocuments = const [],
    this.documents = const [],
    this.hasPassword = false,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        id: json['id']?.toString() ?? '',
        firstName: json['first_name']?.toString() ?? '',
        lastName: json['last_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        country: _str(json['country']),
        city: _str(json['city']),
        vehicleType: _str(json['vehicle_type']),
        accountStatus: json['account_status']?.toString() ?? DriverAccountStatus.pendingDocuments,
        nextAction: json['next_action']?.toString() ?? DriverNextAction.uploadDocuments,
        rejectionReason: _str(json['rejection_reason']),
        reviewSlaHours: _int(json['review_sla_hours']) ?? 24,
        requiredDocuments: _strings(json['required_documents']),
        missingDocuments: _strings(json['missing_documents']),
        rejectedDocuments: _strings(json['rejected_documents']),
        documents: (json['documents'] is List ? json['documents'] as List : const [])
            .whereType<Map>()
            .map((e) => DriverDocument.fromJson(Map<String, dynamic>.from(e)))
            .where((d) => d.type.isNotEmpty)
            .toList(),
        hasPassword: json['has_password'] == true,
      );

  bool get isActive => accountStatus == DriverAccountStatus.active;
  bool get isSuspended => accountStatus == DriverAccountStatus.suspended;
}

/// Réponse de `register` et `login` : jetons + profil.
class DriverSession {
  final String accessToken;
  final String refreshToken;
  final DriverProfile driver;

  const DriverSession({
    required this.accessToken,
    required this.refreshToken,
    required this.driver,
  });

  factory DriverSession.fromJson(Map<String, dynamic> json) => DriverSession(
        accessToken: json['access_token']?.toString() ?? '',
        refreshToken: json['refresh_token']?.toString() ?? '',
        driver: DriverProfile.fromJson(_map(json['driver'])),
      );
}
