# 📨 Message pour l'Équipe Backend - Nouveaux Endpoints Requis

Bonjour l'équipe Backend ! 👋

Nous avons amélioré l'écran de réservation (booking) dans l'application mobile AtlasMove. Pour finaliser ces améliorations, nous avons besoin de **2 nouveaux endpoints API**.

---

## 🎯 Résumé Rapide

Nous avons transformé les données statiques (codées en dur) en données dynamiques chargées depuis votre API.

**Ce qui change :**
- ✅ Les tailles de camions viennent maintenant de l'API
- ✅ Les estimations (prix, distance, temps) sont calculées en temps réel
- ✅ L'utilisateur voit des prix précis avant de réserver

---

## 📋 Endpoints à Implémenter

### 1️⃣ GET /api/v1/truck-sizes
**Objectif :** Retourner la liste des tailles de camions disponibles

**Exemple de Réponse :**
```json
{
  "success": true,
  "truck_sizes": [
    {
      "size": "Petit (3-5m)",
      "description": "Colis et petites livraisons",
      "icon": "local_shipping",
      "max_weight_kg": 500,
      "price_per_km": 5.0,
      "base_price": 20.0
    }
  ]
}
```

---

### 2️⃣ POST /api/v1/trips/estimate
**Objectif :** Calculer le prix, la distance et le temps de trajet

**Exemple de Requête :**
```json
{
  "departure": "Casablanca, Morocco",
  "destination": "Rabat, Morocco",
  "service_type": "delivery",
  "weight_kg": 150,
  "truck_size": "Moyen (6-8m)",
  "is_fragile": true,
  "need_loading_help": false
}
```

**Exemple de Réponse :**
```json
{
  "success": true,
  "price": 245.50,
  "distance": 91.2,
  "estimated_time": 75,
  "currency": "MAD"
}
```

---

## 📄 Documentation Complète

**Tout est dans ce fichier :**  
👉 **`BACKEND_API_SPECIFICATIONS.md`**

Ce document contient :
- ✅ Spécifications détaillées des endpoints
- ✅ Exemples de code (Python/Django)
- ✅ Schémas SQL pour la base de données
- ✅ Configuration Google Maps API
- ✅ Logique de calcul de prix
- ✅ Tests curl pour validation
- ✅ Gestion d'erreurs

---

## 🚀 Dépendances Techniques

### Google Maps API
Vous aurez besoin d'une clé API Google Maps pour :
- Calculer les distances réelles entre deux points
- Estimer les temps de trajet
- Obtenir les coordonnées GPS

**Services à activer :**
- Directions API
- Distance Matrix API
- Geocoding API

**Installation (Python) :**
```bash
pip install googlemaps
```

---

## 🧪 Tests Rapides

### Test 1 : Tailles de camions
```bash
curl -X GET https://api.atla.business/api/v1/truck-sizes
```

### Test 2 : Estimation
```bash
curl -X POST https://api.atla.business/api/v1/trips/estimate \
  -H "Content-Type: application/json" \
  -d '{
    "departure": "Casablanca",
    "destination": "Rabat",
    "service_type": "taxi"
  }'
```

---

## ⏰ Priorité

**Urgence :** Moyenne  
**Impact :** Haute expérience utilisateur  
**Dépendances :** Aucune modification requise des endpoints existants

---

## 📞 Contact

Pour toute question ou clarification :
- 📱 **Équipe Mobile** : Questions sur le format des données
- 🗺️ **Google Maps** : Configuration de l'API

---

## ✅ Checklist

**Veuillez cocher quand c'est fait :**

- [ ] Lecture du document `BACKEND_API_SPECIFICATIONS.md`
- [ ] Création de la table `truck_sizes` en base de données
- [ ] Implémentation de `GET /api/v1/truck-sizes`
- [ ] Implémentation de `POST /api/v1/trips/estimate`
- [ ] Configuration de Google Maps API
- [ ] Tests avec curl
- [ ] Déploiement en environnement de staging
- [ ] Tests avec l'application mobile
- [ ] Déploiement en production
- [ ] Notification à l'équipe mobile ✅

---

## 🎁 Bonus : Exemple de Code Django

Voici un exemple rapide pour démarrer :

```python
@api_view(['GET'])
def get_truck_sizes(request):
    truck_sizes = TruckSize.objects.all()
    return Response({
        "success": True,
        "truck_sizes": [
            {
                "size": ts.size,
                "description": ts.description,
                "icon": ts.icon,
                "max_weight_kg": ts.max_weight_kg,
                "price_per_km": float(ts.price_per_km),
                "base_price": float(ts.base_price),
            } for ts in truck_sizes
        ]
    })
```

**Le code complet est dans `BACKEND_API_SPECIFICATIONS.md` !**

---

Merci beaucoup ! 🙏  
L'équipe mobile attend vos retours.

**Questions ?** N'hésitez pas à nous contacter ! 💬
