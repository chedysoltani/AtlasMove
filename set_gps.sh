#!/bin/bash

CLIENT="73523F3D-47B5-40D1-ADEA-F9F64B4089D4"
DRIVER="3362559E-3719-49E7-964E-F02DFB435FB7"

echo "📍 Configuration des positions GPS..."

# Client - San Francisco Downtown
xcrun simctl location "$CLIENT" set "37.7749,-122.4194"
echo "✅ Client positionné : 37.7749, -122.4194"

# Chauffeur - ~170m au nord (proche du client)
xcrun simctl location "$DRIVER" set "37.7764,-122.4194"
echo "✅ Chauffeur positionné : 37.7764, -122.4194"

echo ""
echo "📏 Distance entre les 2 : ~170 m"
echo "🗺️  Ville : San Francisco, CA"
