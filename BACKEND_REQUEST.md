# Demande à l'équipe backend : documents chauffeur

*Équipe app mobile — 21 octobre 2026 — branche `feat/driver-documents-funnel`*

## 1. Contexte

Notre parcours d'inscription chauffeur perd presque tout le monde à l'étape des documents :
**1 920** installations → **1 100** choix du type de compte (clients et chauffeurs confondus) →
seulement **203 chauffeurs** ont envoyé au moins un document (1 218 envois au total).
La cause principale : les chauffeurs **ont peur** d'envoyer leur CIN, leur permis et leur carte grise à une
app qu'ils ne connaissent pas. Il y a aussi des échecs techniques (photos lourdes, réseau faible).
Objectif : passer d'environ 10 % à **25 % et plus** de chauffeurs qui envoient leurs documents.

## 2. Ce qui a été fait côté app (Flutter)

- **Mesure détaillée** du parcours : formulaire, code de vérification, ouverture de « Mon dossier »,
  début / réussite / échec de chaque envoi (avec le motif : taille, format, réseau, serveur).
- **Envoi plus fiable** : photos compressées sous 1 Mo (1600 px, JPEG), photos iPhone (HEIC)
  converties en JPEG, 3 essais automatiques, « Réessayer » sans reprendre la photo, messages clairs.
  **Le format de la requête ne change pas** (`POST /v2/driver/documents/{type}`, multipart, champ `file`).
- **Métadonnées retirées** : plus aucune donnée EXIF (position GPS, téléphone, date) dans les photos envoyées.
- **Carte « Vos documents sont protégés »** en haut de « Mon dossier » : pourquoi on demande les documents,
  et trois promesses — *visibles uniquement par l'équipe de vérification*, *jamais partagés*,
  *stockés de façon sécurisée*. **Ces promesses doivent être vraies côté serveur** : voir le besoin 3.1.
- **Documents progressifs** prêts côté app mais **désactivés** : rien ne change tant que le
  backend n'accepte pas un dossier partiel (besoin 3.2). Aucune validation serveur n'est contournée.

## 3. Ce dont on a besoin côté backend

### 3.1 Sécurité des documents — priorité **haute**

**Besoin.** Confirmer (ou mettre en place) :

1. **Stockage non public** : aucun fichier dans un bucket ou un dossier lisible sans authentification,
   aucune URL devinable (pas de `…/uploads/<id>.jpg` en accès libre).
2. **Accès par URL signée à expiration courte** (5 à 15 minutes), générée à la demande pour un admin.
3. **Contrôle d'accès** : un chauffeur ne peut lire que *ses* documents, jamais ceux d'un autre
   (vérifier qu'aucune route ne renvoie un fichier à partir d'un identifiant passé par le client).
4. **Journal d'audit** : qui a consulté quel document, quand (admin, document, date, IP).
5. **Suppression des métadonnées EXIF côté serveur** (dont la **position GPS**) :
   nous avons constaté que les photos envoyées par les versions actuelles de l'app peuvent contenir
   les coordonnées GPS, le modèle du téléphone et la date de prise de vue.
   **C'est corrigé côté app** dans cette branche : toutes les métadonnées sont retirées avant l'envoi
   (testé). Le serveur doit quand même les retirer :
   - **à chaque fichier reçu**, en double sécurité (versions déjà installées, et HEIC que l'app
     n'arrive pas à convertir et envoie tel quel) ;
   - **sur les photos déjà stockées**, avec un traitement unique sur l'existant.
6. **Chiffrement au repos** du stockage et **durée de conservation** : que deviennent les documents
   d'un compte refusé, abandonné ou supprimé (l'app propose la suppression de compte) ?

**Pourquoi.** L'app promet ces garanties aux chauffeurs ; si l'une est fausse, c'est un risque légal
et de réputation, sur des pièces d'identité.

**Proposition de contrat (admin).**

```
GET /v1/admin/drivers/{driverId}/documents/{type}/url
→ 200 { "url": "https://…signature…", "expires_at": "2026-10-21T17:05:00Z" }
   (écrit une ligne d'audit : admin_id, driver_id, type, date, ip)

GET /v1/admin/documents/audit?driver_id=…  → 200 { "items": [ { admin_id, type, viewed_at, ip } ] }
```

Côté chauffeur, aucune URL de fichier n'est nécessaire : l'app n'affiche que le statut des documents.

**Avant la mise en production de la carte de confiance**, nous avons besoin d'une confirmation écrite
des points 1 à 4.

### 3.2 Dossier partiel / documents progressifs — priorité **haute** (après 3.1)

**Besoin.** Permettre à un chauffeur d'envoyer d'abord **les documents de base** (pièce d'identité + permis),
puis le reste plus tard.

1. Accepter un dossier partiel : la vérification peut commencer sur les documents de base.
2. Deux niveaux distincts : **« documents de base OK »** et **« dossier complet »**.
3. La liste des documents demandés **par étape et par pays** renvoyée par l'API
   (elle ne doit pas être codée en dur dans l'app).
4. **Admin** : filtrer les dossiers « base OK / complet », voir les documents manquants,
   relancer le chauffeur.

**Pourquoi.** Demander 2 documents au lieu de 5 à un chauffeur qui ne nous connaît pas encore
fait baisser la peur et l'effort. L'app est prête à le tester (A/B 50/50) dès que le backend suit.

**Proposition de contrat.**

`GET /v2/driver/registration-options` — ajouter l'étape de chaque document :

```json
"countries": [{
  "code": "DZ",
  "documents": {
    "required": [
      { "type": "id_card_front", "label": "CIN (recto)", "stage": "start" },
      { "type": "driving_license", "label": "Permis de conduire", "stage": "start" },
      { "type": "vehicle_registration", "label": "Carte grise", "stage": "later" }
    ],
    "optional": [ … ]
  }
}]
```

`GET /v2/driver/me` — ajouter :

```json
{
  "documents_stage": "none | start_complete | complete",
  "next_action": "UPLOAD_DOCUMENTS | UPLOAD_REMAINING_DOCUMENTS | WAIT_FOR_REVIEW | …",
  "documents": [ { "type": "…", "stage": "start | later", "required": true, "status": "…" } ]
}
```

Nouveau `next_action` : `UPLOAD_REMAINING_DOCUMENTS` (base validée, reste à envoyer).
Les chauffeurs déjà inscrits ne doivent pas changer de statut.

**Question métier à trancher** (voir section 4) : un chauffeur « base OK » peut-il déjà travailler ?

### 3.3 Types exacts des documents par pays — priorité **haute** (rapide)

**Besoin.** La liste complète des `type` de documents, **par pays**, et en particulier :
**quels sont les types exacts de la pièce d'identité — un seul type ou recto/verso séparés ?**

**Pourquoi.** L'app en a besoin pour la variante « documents progressifs ». Aujourd'hui, seuls
`driving_license`, `vehicle_registration`, `selfie` et `vehicle_photo_*` apparaissent dans l'app.

**Proposition.** Un tableau dans la réponse, ou simplement par écrit : `pays → [type, libellé, obligatoire]`.

### 3.4 Erreurs d'envoi explicites, taille max, HEIC — priorité **moyenne**

**Besoin.**

1. **Toujours** une réponse JSON avec un `code` stable, **même quand la limite est atteinte
   au niveau du proxy** (un proxy comme nginx renvoie par défaut une page HTML 413, que l'app ne peut
   pas lire — à vérifier sur notre configuration).
   Codes attendus :
   `FILE_TOO_LARGE` (413), `FILE_TYPE_NOT_ALLOWED` (415), `FILE_UNREADABLE` (422),
   `UPLOAD_INTERRUPTED`, `DOCUMENT_TYPE_UNKNOWN` (404), `DOCUMENT_ALREADY_APPROVED` (409).
2. **Confirmer la taille maximale** : l'app suppose 10 Mo (contrat). Le proxy doit accepter au moins
   autant que l'API. `files.max_size_bytes` de `registration-options` doit être la seule source.
3. **Confirmer que le HEIC/HEIF est accepté et converti** (l'app envoie encore un HEIC brut
   si elle n'arrive pas à le convertir).
4. **Liste des formats acceptés** dans `registration-options` : `files.allowed_mime_types`.

**Format d'erreur proposé (unique pour toutes les routes `/v2/driver/*`).**

```json
{ "code": "FILE_TOO_LARGE", "message": "Photo trop lourde (10 Mo maximum).",
  "details": { "max_size_bytes": 10485760 } }
```

Aujourd'hui, l'app doit lire le code à deux endroits (`code` ou `error.code`) et certains codes
des refus d'éligibilité (403) arrivent en minuscules : merci d'uniformiser
(`code` au premier niveau, en `MAJUSCULES_SOULIGNÉES`).

### 3.5 Code de vérification par SMS ou WhatsApp — priorité **moyenne**

**Besoin.** Proposer l'envoi du code par **SMS** ou **WhatsApp** en plus de l'e-mail.

**Pourquoi.** Beaucoup de chauffeurs ne consultent pas leurs e-mails. Les nouveaux évènements
`driver_otp_sent` / `driver_otp_verified` / `driver_otp_failed` vont mesurer la perte à cette étape.

**Proposition de contrat.**

```
POST /v2/driver/auth/otp/send
{ "phone": "+213…", "country": "DZ", "purpose": "register", "channel": "whatsapp" }
→ 200 { "request_id": "…", "channel": "whatsapp", "sent_to": "+213•••••42",
        "expires_in": 300, "resend_after": 60 }
```

Dans `registration-options` : `"otp": { "channels": ["email", "sms", "whatsapp"], "default": "whatsapp" }`
(par pays si besoin). L'app affichera « Recevoir le code par… » selon la liste.
Le champ `channel` existe déjà dans la réponse : l'app le lit et le mesure.

### 3.6 Langues darija (ar-DZ, ar-MA) — priorité **basse**

**Besoin.** Accepter `Accept-Language: ar-DZ` et `ar-MA`, avec repli sur `ar`
(et jamais de message vide ou en anglais).

**Pourquoi.** L'app prépare la darija algérienne et marocaine (pas encore proposée).
Les messages d'erreur et les libellés des documents viennent du serveur.

Remarque : l'app envoie aujourd'hui `fr`, `ar` ou `en` uniquement ; l'italien, l'allemand et
l'espagnol retombent sur `fr`.

### 3.7 Environnement de test (staging) — priorité **haute**

**Besoin.**

1. Une URL de **staging** avec sa propre base et son propre stockage.
2. Un **code de vérification fixe** pour quelques numéros / e-mails de test.
3. La possibilité de **supprimer** ou réinitialiser un compte de test.
4. Un compte admin de test pour valider / refuser des documents.

**Pourquoi.** Aujourd'hui, tester l'inscription crée de **vrais comptes en production** avec de vraies photos.
Pour cette version, nous allons créer **un seul** compte nommé « TEST AtlasMove - ne pas valider »
avec des images factices : merci de ne pas le valider, il sera supprimé ensuite.

### 3.8 Autres points relevés dans le code de l'app

| # | Besoin | Pourquoi | Priorité |
|---|---|---|---|
| a | **Évènement serveur « documents complets »** (une fois par chauffeur), envoyé à Meta (Conversions API) ou exposé dans `/me` (`documents_completed_at`) | L'app l'envoie une fois par appareil ; un chauffeur qui réinstalle ou change de téléphone peut le renvoyer. Meta l'utilisera pour optimiser les campagnes : il doit être fiable. | Moyenne |
| b | **Relances** push / e-mail aux chauffeurs inscrits sans document après 24 h, puis 72 h | La plupart de la perte arrive après la création du compte ; les notifications « dossier » existent déjà (`metadata.category = driver_onboarding`). | Moyenne |
| c | La réponse de `POST /v2/driver/documents/{type}` doit **toujours** contenir le profil complet (`data.driver`) | Sinon l'app refait un `GET /me` (un appel de plus sur réseau faible). | Basse |
| d | `review_sla_hours` à jour par pays | Affiché au chauffeur (« vérification sous 24 h ») : doit être tenu. | Basse |
| e | **Politique de confidentialité** (`/legal/privacy-policy`) : une section claire sur les documents chauffeur (qui y accède, durée de conservation, suppression) | La carte de confiance y renvoie. L'URL est réglable dans Remote Config. | Moyenne |

## 4. Questions ouvertes

1. Les fichiers sont-ils aujourd'hui accessibles **sans authentification** par une URL ? Où sont-ils stockés ?
2. Qui, chez nous, peut voir les documents (rôles admin) ? Existe-t-il déjà un journal des consultations ?
3. **Quels sont les types exacts des documents d'identité (recto/verso ?) et la liste complète des types par pays ?**
4. Un chauffeur « documents de base OK » peut-il recevoir des courses, ou seulement après le dossier complet ?
   Combien de temps a-t-il pour envoyer le reste ?
5. Taille max réelle acceptée par le proxy ? HEIC accepté et converti ?
6. Les métadonnées (EXIF / GPS) sont-elles supprimées à l'enregistrement ? Combien de photos déjà
   stockées en contiennent, et quand peut-on les nettoyer ?
7. Durée de conservation des documents d'un compte refusé, abandonné ou supprimé ?
8. Coût et fournisseur envisageables pour le SMS / WhatsApp (DZ, MA) ?
9. Un staging est-il envisageable rapidement, même minimal ?

## 5. Ordre de livraison souhaité

1. **Sécurité des documents** (3.1) — au minimum une confirmation écrite des points 1 à 4,
   *avant* la mise en production de la carte de confiance.
2. **Types de documents par pays** (3.3) — réponse écrite, rapide.
3. **Staging** (3.7).
4. **Erreurs d'envoi, taille, HEIC** (3.4).
5. **Code par SMS / WhatsApp** (3.5) — à décider selon les chiffres de `driver_otp_failed` / `driver_otp_verified`.
6. **Dossier partiel** (3.2) — l'app est prête, il suffit d'activer le test A/B.
7. **Relances et évènement serveur** (3.8 a, b).
8. **Darija** (3.6).
