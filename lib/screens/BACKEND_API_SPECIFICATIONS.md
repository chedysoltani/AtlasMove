# 📋 Spécifications API Backend - AtlasMove Booking

## 🎯 Objectif

Ajouter 2 nouveaux endpoints API pour supporter les fonctionnalités dynamiques de réservation de courses dans l'application mobile AtlasMove.

---

## 🚀 Endpoints à Implémenter

### 1️⃣ **GET /api/v1/truck-sizes** - Récupération des tailles de camions

#### Description
Retourne la liste des tailles de camions disponibles avec leurs caractéristiques (description, icône, poids max, prix par km).

#### Méthode HTTP
```
GET
```

#### URL
```
https://api.atla.business/api/v1/truck-sizes
```

#### Headers Requis
```http
Content-Type: application/json
```

#### Paramètres de Requête
Aucun (endpoint public)

#### Réponse Succès (200 OK)
```json
{
  "success": true,
  "truck_sizes": [
    {
      "id": 1,
      "size": "Petit (3-5m)",
      "description": "Colis et petites livraisons",
      "icon": "local_shipping",
      "max_weight_kg": 500,
      "price_per_km": 5.0,
      "base_price": 20.0
    },
    {
      "id": 2,
      "size": "Moyen (6-8m)",
      "description": "Meubles et déménagement moyen",
      "icon": "moving",
      "max_weight_kg": 2000,
      "price_per_km": 8.0,
      "base_price": 35.0
    },
    {
      "id": 3,
      "size": "Grand (9-12m)",
      "description": "Grands volumes et marchandises",
      "icon": "local_shipping",
      "max_weight_kg": 5000,
      "price_per_km": 12.0,
      "base_price": 50.0
    },
    {
      "id": 4,
      "size": "Très grand (13-16m)",
      "description": "Déménagement complet et industriel",
      "icon": "local_shipping",
      "max_weight_kg": 10000,
      "price_per_km": 18.0,
      "base_price": 80.0
    },
    {
      "id": 5,
      "size": "Extra large (17-20m)",
      "description": "Transport de charges très lourdes",
      "icon": "local_shipping",
      "max_weight_kg": 20000,
      "price_per_km": 25.0,
      "base_price": 120.0
    },
    {
      "id": 6,
      "size": "Spécial (sur mesure)",
      "description": "Transport spécialisé",
      "icon": "settings",
      "max_weight_kg": null,
      "price_per_km": null,
      "base_price": null
    }
  ]
}
```

#### Réponse Erreur (500 Internal Server Error)
```json
{
  "success": false,
  "error": "Failed to retrieve truck sizes"
}
```

#### Implémentation Backend Suggérée
```python
# Django Example
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import TruckSize

@api_view(['GET'])
def get_truck_sizes(request):
    """
    Retrieve all available truck sizes
    """
    try:
        truck_sizes = TruckSize.objects.all()
        data = {
            "success": True,
            "truck_sizes": [
                {
                    "id": ts.id,
                    "size": ts.size,
                    "description": ts.description,
                    "icon": ts.icon,
                    "max_weight_kg": ts.max_weight_kg,
                    "price_per_km": float(ts.price_per_km),
                    "base_price": float(ts.base_price),
                } for ts in truck_sizes
            ]
        }
        return Response(data, status=200)
    except Exception as e:
        return Response({
            "success": False,
            "error": str(e)
        }, status=500)
```

#### Structure de la Table SQL Suggérée
```sql
CREATE TABLE truck_sizes (
    id SERIAL PRIMARY KEY,
    size VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50) DEFAULT 'local_shipping',
    max_weight_kg INTEGER,
    price_per_km DECIMAL(10, 2),
    base_price DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Données initiales
INSERT INTO truck_sizes (size, description, icon, max_weight_kg, price_per_km, base_price) VALUES
('Petit (3-5m)', 'Colis et petites livraisons', 'local_shipping', 500, 5.0, 20.0),
('Moyen (6-8m)', 'Meubles et déménagement moyen', 'moving', 2000, 8.0, 35.0),
('Grand (9-12m)', 'Grands volumes et marchandises', 'local_shipping', 5000, 12.0, 50.0),
('Très grand (13-16m)', 'Déménagement complet et industriel', 'local_shipping', 10000, 18.0, 80.0),
('Extra large (17-20m)', 'Transport de charges très lourdes', 'local_shipping', 20000, 25.0, 120.0),
('Spécial (sur mesure)', 'Transport spécialisé', 'settings', NULL, NULL, NULL);
```

---

### 2️⃣ **POST /api/v1/trips/estimate** - Calcul d'estimation de course

#### Description
Calcule le prix estimé, la distance et le temps de trajet pour une course donnée en fonction du point de départ, destination et type de service.

#### Méthode HTTP
```
POST
```

#### URL
```
https://api.atla.business/api/v1/trips/estimate
```

#### Headers Requis
```http
Content-Type: application/json
```

#### Corps de la Requête (Request Body)
```json
{
  "departure": "Casablanca, Morocco",
  "destination": "Rabat, Morocco",
  "service_type": "delivery",
  "passengers": 2,
  "weight_kg": 150.5,
  "truck_size": "Moyen (6-8m)",
  "is_fragile": true,
  "need_loading_help": false
}
```

#### Paramètres

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `departure` | string | ✅ Oui | Adresse ou coordonnées de départ |
| `destination` | string | ✅ Oui | Adresse ou coordonnées d'arrivée |
| `service_type` | string | ✅ Oui | Type de service: `taxi`, `moto_taxi`, `delivery`, `moving`, `heavy_truck`, `yacht`, `car` |
| `passengers` | integer | ❌ Non | Nombre de passagers (pour transport) |
| `weight_kg` | float | ❌ Non | Poids en kg (pour livraison/camion) |
| `truck_size` | string | ❌ Non | Taille du camion (pour camion) |
| `is_fragile` | boolean | ❌ Non | Colis fragile (pour livraison) |
| `need_loading_help` | boolean | ❌ Non | Besoin d'aide au chargement (pour camion) |

#### Réponse Succès (200 OK)
```json
{
  "success": true,
  "price": 245.50,
  "distance": 91.2,
  "estimated_time": 75,
  "currency": "MAD",
  "breakdown": {
    "base_price": 35.0,
    "distance_price": 182.4,
    "fragile_surcharge": 15.0,
    "loading_help_surcharge": 0.0,
    "service_fee": 13.1
  },
  "route_info": {
    "departure_coordinates": {
      "latitude": 33.5731,
      "longitude": -7.5898
    },
    "destination_coordinates": {
      "latitude": 34.0209,
      "longitude": -6.8416
    }
  }
}
```

#### Réponse Erreur (400 Bad Request)
```json
{
  "success": false,
  "error": "Missing required fields: departure, destination"
}
```

#### Réponse Erreur (404 Not Found)
```json
{
  "success": false,
  "error": "Unable to calculate route between provided addresses"
}
```

#### Logique de Calcul Suggérée

```python
# Django Example
from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.views.decorators.csrf import csrf_exempt
import googlemaps
from decimal import Decimal

@api_view(['POST'])
@csrf_exempt
def calculate_trip_estimate(request):
    """
    Calculate trip price, distance, and time estimate
    """
    try:
        # Extract request data
        departure = request.data.get('departure')
        destination = request.data.get('destination')
        service_type = request.data.get('service_type')
        passengers = request.data.get('passengers', 1)
        weight_kg = request.data.get('weight_kg', 0)
        truck_size = request.data.get('truck_size')
        is_fragile = request.data.get('is_fragile', False)
        need_loading_help = request.data.get('need_loading_help', False)

        # Validation
        if not departure or not destination or not service_type:
            return Response({
                "success": False,
                "error": "Missing required fields: departure, destination, service_type"
            }, status=400)

        # Calculate distance and time using Google Maps API
        gmaps = googlemaps.Client(key='YOUR_GOOGLE_MAPS_API_KEY')
        
        # Get route information
        directions = gmaps.directions(
            departure,
            destination,
            mode="driving",
            departure_time="now"
        )

        if not directions:
            return Response({
                "success": False,
                "error": "Unable to calculate route between provided addresses"
            }, status=404)

        # Extract route info
        route = directions[0]['legs'][0]
        distance_km = route['distance']['value'] / 1000  # Convert to km
        time_minutes = route['duration']['value'] / 60  # Convert to minutes

        # Price calculation based on service type
        base_price = 0
        price_per_km = 0

        if service_type == 'taxi':
            base_price = 10.0
            price_per_km = 3.5
        elif service_type == 'moto_taxi':
            base_price = 5.0
            price_per_km = 2.0
        elif service_type in ['delivery', 'moving', 'heavy_truck']:
            if truck_size:
                truck = TruckSize.objects.filter(size=truck_size).first()
                if truck:
                    base_price = float(truck.base_price)
                    price_per_km = float(truck.price_per_km)
                else:
                    base_price = 30.0
                    price_per_km = 8.0
            else:
                base_price = 30.0
                price_per_km = 8.0
        elif service_type == 'yacht':
            base_price = 500.0
            price_per_km = 50.0
        elif service_type == 'car':
            base_price = 100.0
            price_per_km = 10.0

        # Calculate base distance price
        distance_price = distance_km * price_per_km

        # Additional charges
        fragile_surcharge = 15.0 if is_fragile else 0.0
        loading_help_surcharge = 25.0 if need_loading_help else 0.0
        
        # Service fee (5%)
        subtotal = base_price + distance_price + fragile_surcharge + loading_help_surcharge
        service_fee = subtotal * 0.05

        # Total price
        total_price = subtotal + service_fee

        # Prepare response
        response_data = {
            "success": True,
            "price": round(total_price, 2),
            "distance": round(distance_km, 1),
            "estimated_time": int(time_minutes),
            "currency": "MAD",
            "breakdown": {
                "base_price": base_price,
                "distance_price": round(distance_price, 2),
                "fragile_surcharge": fragile_surcharge,
                "loading_help_surcharge": loading_help_surcharge,
                "service_fee": round(service_fee, 2)
            },
            "route_info": {
                "departure_coordinates": {
                    "latitude": route['start_location']['lat'],
                    "longitude": route['start_location']['lng']
                },
                "destination_coordinates": {
                    "latitude": route['end_location']['lat'],
                    "longitude": route['end_location']['lng']
                }
            }
        }

        return Response(response_data, status=200)

    except Exception as e:
        return Response({
            "success": False,
            "error": str(e)
        }, status=500)
```

---

## 🔐 Configuration Requise

### 1. Google Maps API Key
Pour calculer les distances et temps de trajet, vous aurez besoin d'une clé API Google Maps.

**Services à activer :**
- ✅ Directions API
- ✅ Distance Matrix API
- ✅ Geocoding API

**Installation (Python/Django) :**
```bash
pip install googlemaps
```

**Configuration :**
```python
# settings.py
GOOGLE_MAPS_API_KEY = 'YOUR_API_KEY_HERE'
```

### 2. Variables d'Environnement
```bash
# .env
GOOGLE_MAPS_API_KEY=AIzaSy...
BASE_TAXI_PRICE=10.0
BASE_DELIVERY_PRICE=30.0
SERVICE_FEE_PERCENTAGE=5.0
```

---

## 🧪 Tests Recommandés

### Test 1 : Récupération des tailles de camions
```bash
curl -X GET https://api.atla.business/api/v1/truck-sizes \
  -H "Content-Type: application/json"
```

**Résultat attendu :** Liste de 6 tailles de camions

---

### Test 2 : Calcul d'estimation simple (Taxi)
```bash
curl -X POST https://api.atla.business/api/v1/trips/estimate \
  -H "Content-Type: application/json" \
  -d '{
    "departure": "Casablanca, Morocco",
    "destination": "Rabat, Morocco",
    "service_type": "taxi",
    "passengers": 2
  }'
```

**Résultat attendu :** 
- Prix entre 200-300 MAD
- Distance ~90 km
- Temps ~75 minutes

---

### Test 3 : Calcul d'estimation avec camion
```bash
curl -X POST https://api.atla.business/api/v1/trips/estimate \
  -H "Content-Type: application/json" \
  -d '{
    "departure": "Tunis, Tunisia",
    "destination": "Sfax, Tunisia",
    "service_type": "delivery",
    "weight_kg": 500,
    "truck_size": "Grand (9-12m)",
    "is_fragile": true,
    "need_loading_help": true
  }'
```

**Résultat attendu :**
- Prix avec surcharges fragile + aide au chargement
- Distance calculée précisément
- Breakdown détaillé des coûts

---

## 📊 Schéma de Base de Données

### Table : `truck_sizes`
```sql
CREATE TABLE truck_sizes (
    id SERIAL PRIMARY KEY,
    size VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50) DEFAULT 'local_shipping',
    max_weight_kg INTEGER,
    price_per_km DECIMAL(10, 2),
    base_price DECIMAL(10, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Table : `trip_estimates` (optionnelle - pour logs)
```sql
CREATE TABLE trip_estimates (
    id SERIAL PRIMARY KEY,
    departure TEXT NOT NULL,
    destination TEXT NOT NULL,
    service_type VARCHAR(50),
    calculated_price DECIMAL(10, 2),
    calculated_distance DECIMAL(10, 2),
    calculated_time INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🚀 Routes à Ajouter (Django URLs)

```python
# urls.py
from django.urls import path
from . import views

urlpatterns = [
    # Existing routes...
    path('api/v1/truck-sizes', views.get_truck_sizes, name='truck_sizes'),
    path('api/v1/trips/estimate', views.calculate_trip_estimate, name='trip_estimate'),
]
```

---

## 📝 Notes Importantes

1. **Sécurité Google Maps API**
   - Limitez l'utilisation de l'API avec des quotas
   - Utilisez des restrictions d'API key (IP whitelist)
   - Surveillez l'utilisation pour éviter les coûts excessifs

2. **Cache des Estimations**
   - Considérez mettre en cache les estimations pour les trajets populaires
   - TTL recommandé : 15-30 minutes

3. **Gestion des Erreurs**
   - Gérez les cas où Google Maps ne trouve pas de route
   - Validez les adresses avant le calcul
   - Retournez des messages d'erreur clairs

4. **Performance**
   - Les appels Google Maps peuvent prendre 1-3 secondes
   - Utilisez des timeout appropriés (10 secondes max)
   - Implémentez un système de retry pour les échecs temporaires

---

## ✅ Checklist de Mise en Œuvre

### Backend
- [ ] Créer le modèle `TruckSize`
- [ ] Implémenter `GET /api/v1/truck-sizes`
- [ ] Implémenter `POST /api/v1/trips/estimate`
- [ ] Configurer Google Maps API
- [ ] Ajouter les données initiales (truck sizes)
- [ ] Tester les endpoints
- [ ] Documenter dans Swagger/Postman
- [ ] Déployer en production

### Frontend (Déjà fait ✅)
- [x] Créer `BookingService`
- [x] Charger les tailles de camions au démarrage
- [x] Calculer les estimations en temps réel
- [x] Afficher les loader pendant les requêtes
- [x] Gérer les erreurs réseau

---

## 📞 Contact & Support

Pour toute question sur l'implémentation, contacter :
- **Équipe Mobile** : Pour clarifications frontend
- **Équipe Backend** : Pour validation de la logique métier

---

## 🎉 Résultat Final Attendu

Une fois ces endpoints implémentés, l'application mobile pourra :

✅ Charger dynamiquement les tailles de camions depuis le serveur  
✅ Calculer en temps réel le prix, la distance et le temps de trajet  
✅ Afficher des estimations précises basées sur Google Maps  
✅ Offrir une expérience utilisateur fluide avec loaders et gestion d'erreurs  

---

**Document créé le :** 2 Août 2026  
**Version :** 1.0  
**Auteur :** Équipe Mobile AtlasMove
