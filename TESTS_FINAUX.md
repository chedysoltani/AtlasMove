# Tests finaux — funnel documents chauffeur

Branche `feat/driver-documents-funnel`. À faire ensemble avant le merge sur master.
Les cases cochées ont déjà été vérifiées pendant le développement (21/10).

## Préparation

- Émulateur Android `Medium_Phone_API_36`, app en debug.
- Mode debug Analytics : `adb shell setprop debug.firebase.analytics.app com.atlasmove.app`,
  puis **DebugView** ouvert dans la console Firebase.
- Images factices dans la galerie de l'émulateur (`Pictures/AtlasMoveTest`) : CIN, permis,
  carte grise, selfie, véhicule, grosse photo (8 Mo), fichier illisible. Aucune vraie pièce.
- **Un seul** compte de test : prénom « TEST AtlasMove », nom « ne pas valider ».
  Une adresse e-mail et un numéro de téléphone fournis par vous. Idéalement, le backend configure
  un **code fixe** pour cette adresse (`DRIVER_OTP_TEST_EMAILS`) : aucun e-mail réel, pas besoin de
  transmettre le code. Le compte sera supprimé depuis l'admin à la fin.
- **Release backend du 21/10 déployée** (journal des consultations, `documents_completed_at`,
  relances 24 h / 72 h, proxy réglé). Sans elle, les scénarios de la section 5 ne sont pas testables.
- Meta Events Manager ouvert sur **Tester les évènements**.

## 1. Analytics (étape 1)

- [x] Formulaire envoyé incomplet → `driver_signup_form_error` une fois par champ manquant,
      `field` = nom du champ, aucune valeur saisie dans l'évènement
- [ ] Formulaire valide → `driver_signup_form_submitted` puis `driver_otp_sent` (`purpose=register`, `channel=email`)
- [ ] « Renvoyer le code » → `driver_otp_resent`
- [ ] Mauvais code → `driver_otp_failed` (`stage=verify`, `reason=otp_invalid`)
- [ ] Bon code → `driver_otp_verified`, puis `driver_account_created`
- [ ] Ouverture de « Mon dossier » → `document_screen_viewed` (une fois, pas au rafraîchissement)
- [ ] Bouton d'aide WhatsApp → `document_help_whatsapp_clicked`
- [ ] Dernier document obligatoire envoyé → `driver_documents_completed` (une seule fois,
      pas en rouvrant le dossier ni après un remplacement)
- [ ] `driver_documents_completed` reçu dans Meta Events Manager, sous ce nom exact
- [ ] Déconnexion puis connexion par code → `driver_otp_sent` / `driver_otp_verified` avec `purpose=login`

## 2. Envoi des documents (étape 2)

- [ ] Envoi normal depuis la galerie → progression en %, `document_upload_started` puis
      `document_uploaded` **et** `driver_document_uploaded`, statut « Envoyé »
- [ ] Envoi avec l'appareil photo (demande de permission caméra)
- [ ] Grosse photo (8 Mo) → « Préparation de la photo… », puis envoi d'un fichier de moins de 1 Mo
- [ ] Réseau coupé pendant l'envoi (mode avion) → « Connexion faible, nouvel essai (2/3)… »,
      puis message réseau + `document_upload_failed` (`reason=network`)
- [ ] « Réessayer » après la coupure → renvoie la même photo, sans rouvrir la galerie
- [ ] Fichier illisible → message + bouton « Reprendre la photo »
      (`reason=format` ou `unknown` selon la réponse du serveur)
- [ ] HEIC : sur iPhone uniquement (TestFlight, après le merge) — photo de l'appareil envoyée en JPEG
- [x] Métadonnées : photo avec GPS, téléphone, date et rotation → plus aucun EXIF ni GPS en sortie,
      rotation appliquée (test automatique, aussi pour un HEIC converti en JPEG)
- [ ] Métadonnées en réel : photo prise **avec la localisation activée** (émulateur : position
      simulée dans les réglages de l'appareil photo), envoyée, puis téléchargée depuis l'admin →
      aucune donnée GPS (`exiftool photo.jpg` ou propriétés du fichier)
- [ ] iPhone : même vérification avec une photo HEIC de l'appareil
- [ ] Remplacement d'un document refusé (si un document du compte de test est refusé depuis l'admin)

## 3. Carte « Vos documents sont protégés » (étape 3)

- [x] Aperçu français : phrase Algérie/Maroc pour DZ, phrase générique pour un autre pays, carte repliée
- [x] Aperçu arabe : affichage de droite à gauche correct
- [x] `ar_DZ` avec les clés vides → arabe standard, jamais de texte vide
- [ ] Dans le vrai « Mon dossier » : carte dépliée avant le premier envoi, repliée après
- [ ] Carte absente quand le dossier est en vérification ou refusé
- [ ] Lien « politique de confidentialité » → s'ouvre dans le navigateur
- [ ] Remote Config `driver_social_proof_count = 0` → phrase masquée (au lancement suivant)
- [ ] Remote Config `privacy_policy_url` modifiée → nouveau lien (au lancement suivant)
- [ ] Build iOS Xcode Cloud (après votre merge) : pod Remote Config installé, app qui démarre

## 4. Documents progressifs (étape 4)

- [x] Au démarrage : propriété utilisateur `onboarding_variant = A` envoyée
- [ ] Par défaut (flag à `false`) : « Mon dossier » identique à avant, une seule liste
- [x] Types confirmés par le backend : `id_card` (recto), `driving_license`… — valeur par défaut mise à jour
- [ ] Condition Remote Config limitée à l'appareil de test : flag `true` + variante `B` →
      sections « Pour commencer » / « Plus tard », documents toujours envoyables
- [ ] Même chose avec un type inconnu dans `driver_docs_start_types` → une seule liste
- [ ] `onboarding_variant = B` visible en DebugView pour l'appareil de test
- [ ] Variante B en arabe (droite à gauche)
- [ ] Remettre la condition de test à `false` / `A` à la fin

## 5. Après la release backend du 21/10

- [x] Lecture de `documents_stage`, `documents_completed_at`, `documents[].stage` et
      `UPLOAD_REMAINING_DOCUMENTS` (tests automatiques)
- [ ] `driver_documents_completed` part quand `documents_completed_at` apparaît, et **pas** après le
      remplacement d'un document refusé (vérifier `documents_completed_at` dans l'admin)
- [ ] Relance « dossier incomplet » (24 h après l'inscription, ou envoyée à la main depuis le serveur) :
      le tap ouvre **« Mon dossier »** par-dessus l'app (app ouverte, en arrière-plan, et fermée)
- [ ] Notification « dossier » sur un compte actif : écran principal, pas « Mon dossier »
- [ ] Fichier refusé par le serveur (`FILE_TYPE_NOT_ALLOWED` avec le fichier illisible) : message clair
- [ ] Admin : le compte de test apparaît dans « Consultations des documents » après ouverture d'un
      document depuis le panel (journal)
- [ ] Remote Config `driver_trust_card_enabled = false` → carte de confiance masquée (lancement suivant)
- [ ] Dossier progressif côté serveur (`DRIVER_START_DOCUMENTS`) : **à tester sur le staging seulement**.
      En production, ce réglage change `next_action` pour tous les chauffeurs concernés. Attendus :
      statut « Premiers documents envoyés » après id_card + permis, carte de confiance toujours visible,
      variante B rangée selon `documents[].stage`

## 6. Non-régression

- [ ] Chauffeur déjà inscrit et actif : pas de bandeau, app normale, mise en ligne possible
- [ ] Chauffeur en vérification : bandeau bleu, « Mon dossier » lisible, pas de carte de confiance
- [ ] Client : parcours client inchangé (aucun évènement chauffeur)
- [ ] « Mon dossier » en arabe : tout l'écran de droite à gauche, textes traduits

## 7. Actions dans les consoles

### Firebase Remote Config

| Paramètre | Type | Valeur par défaut | Rôle |
|---|---|---|---|
| `driver_trust_card_enabled` | Booléen | `true` | Affiche la carte « Vos documents sont protégés ». Mettre à `false` si le chiffrement du stockage n'est pas fait au moment de la mise en production. |
| `driver_social_proof_count` | Nombre | `600` | « +600 chauffeurs… » ; `0` masque la phrase. À garder vrai. |
| `privacy_policy_url` | Texte | `https://api.atla.business/legal/privacy-policy` | Lien de la carte de confiance |
| `driver_docs_progressive_enabled` | Booléen | `false` | Interrupteur des documents progressifs. **Rester à `false`** tant que le backend n'accepte pas un dossier partiel. |
| `driver_docs_variant` | Texte | `A` | Variante attribuée par A/B Testing (`A` ou `B`) |
| `driver_docs_start_types` | JSON | `["id_card","driving_license"]` | Types « pour commencer », en secours seulement : si le serveur donne `documents[].stage` (`DRIVER_START_DOCUMENTS`), c'est lui qui fait foi |

Sans ces paramètres, l'app utilise les mêmes valeurs par défaut.

### Firebase A/B Testing (quand le backend sera prêt)

1. Nouvelle expérience Remote Config, cible : app Android + iOS, utilisateurs chauffeurs si possible.
2. Paramètre `driver_docs_variant` : groupe de contrôle `A`, variante `B`, répartition 50/50.
3. Objectif principal : `driver_documents_completed` ; secondaires : `document_uploaded`, `driver_activated`.
4. Passer `driver_docs_progressive_enabled` à `true` au lancement de l'expérience.

### GA4 — dimensions personnalisées (portée « Évènement »)

| Paramètre | Évènements |
|---|---|
| `doc_type` | `document_upload_started`, `document_uploaded`, `document_upload_failed` |
| `reason` | `document_upload_failed` (size/format/network/server/unknown), `driver_otp_failed` (code d'erreur) |
| `http_status` | `document_upload_failed` (métrique ou dimension, au choix) |
| `stage` | `driver_otp_failed` (`send` / `verify`) |
| `field` | `driver_signup_form_error` |
| `purpose` | `driver_otp_sent`, `driver_otp_resent`, `driver_otp_verified`, `driver_otp_failed` |
| `channel` | `driver_otp_sent`, `driver_otp_resent` |

Dimension personnalisée de portée **« Utilisateur »** : `onboarding_variant`.
`document_type` (évènement historique `driver_document_uploaded`) existe déjà.

Entonnoir conseillé dans GA4 (Explorer → Entonnoir) :
`account_type_selected` (filtre `type = driver`) → `driver_signup_form_submitted` →
`driver_otp_verified` → `driver_account_created` → `document_screen_viewed` →
`document_uploaded` → `driver_documents_completed`.

### Meta Events Manager

- Vérifier la réception de `driver_documents_completed` (évènement personnalisé, sans paramètre).
- S'il n'est pas proposé comme évènement d'optimisation pour votre type de campagne, prévenir l'équipe
  app : un évènement standard (`fb_mobile_complete_registration`) peut être envoyé en plus.
- Rappel iOS : Meta ne relie l'évènement à une campagne que si le chauffeur a accepté le suivi (ATT).
