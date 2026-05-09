# GPS Location Tracking Implementation

## Overview

This implementation provides real-time GPS location tracking for delivery drivers in the AtlasMove application. The system automatically detects the driver's location and sends it to the backend API via HTTP PUT requests.

## Features

- ✅ Real-time GPS location detection using device geolocation
- ✅ Automatic location updates when driver goes online
- ✅ Manual location refresh capability
- ✅ Comprehensive error handling for permissions and API failures
- ✅ Visual status indicators in the dashboard
- ✅ Detailed console logging for debugging
- ✅ Clean architecture with dedicated services

## Implementation Details

### 1. Location Tracking Service (`lib/services/location_tracking_service.dart`)

A singleton service that handles:
- GPS location detection using `geolocator` package
- HTTP PATCH requests to the backend API
- **Periodic location updates every minute** for real-time tracking
- Movement-based updates for responsive tracking when driver moves
- Error handling and logging

**Key Methods:**
- `startLocationTracking(token)` - Starts continuous tracking
- `sendCurrentLocation(token)` - Sends current location once
- `isLocationServiceAvailable()` - Checks permissions and service availability
- `stopLocationTracking()` - Stops tracking and cleans up resources

### 2. Driver Dashboard Integration (`lib/screens/driver_dashboard.dart`)

The dashboard now includes:
- Automatic location tracking initialization on load
- Visual status indicator for location tracking
- Manual refresh button
- Debug test screen access
- Comprehensive error notifications

### 3. API Integration

**Endpoint:** `https://api.atla.business/api/v1/l/trips/location`

**Method:** PATCH

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Body:**
```json
{
  "latitude": 36.8065,
  "longitude": 10.1815
}
```

## Usage

### Automatic Tracking
1. Driver logs in and navigates to dashboard
2. Location tracking starts automatically
3. Current location is sent immediately
4. Continuous tracking begins with real-time updates

### Manual Refresh
1. Tap "🔄 Actualiser la localisation" button
2. Current location is retrieved and sent to API
3. Success/error notification is displayed

### Debug Testing
1. Tap "🧪 Test Localisation (Debug)" button
2. Navigate to test screen
3. View detailed status and test functionality

## Error Handling

The system handles various error scenarios:

### Location Permission Errors
- Permission denied → Shows user-friendly message
- Permission permanently denied → Directs user to settings
- Location service disabled → Prompts to enable GPS

### API Errors
- Network timeout → 10-second timeout with retry logic
- Invalid token → Shows authentication error
- Server errors → Detailed error logging and user notification
- Connection issues → Shows clear error messages to user

### Location Service Errors
- GPS unavailable → Falls back to default location for testing
- Timeout errors → Graceful degradation with user notification

## Console Logging

Detailed console logs help with debugging:

```
DEBUG: Token livreur = [token_value]
DEBUG: User livreur = [user_name]
DEBUG: Starting location tracking with token: [token_prefix]...
DEBUG: Location tracking started successfully (updates every minute)
DEBUG: Starting periodic location updates (every 60 seconds)
DEBUG: === Minute update - Getting current position ===
DEBUG: Minute update - Position: [latitude], [longitude]
DEBUG: Sending location data: [coordinates]
DEBUG: Sending to URL: https://api.atla.business/api/v1/l/trips/location
DEBUG: API Response Status: 200
DEBUG: API Response Body: {"success": true, ...}
DEBUG: Minute update - Location sent successfully
DEBUG: === Next update in 60 seconds ===
DEBUG: Movement-based update: [latitude], [longitude] (if driver moves)
```

## Dependencies

Required packages (already in `pubspec.yaml`):
- `geolocator: ^10.1.0` - GPS location services
- `permission_handler: ^11.0.1` - Permission management
- `http: ^1.1.0` - HTTP requests

## Configuration

### Location Settings
- **Accuracy:** High for precise tracking
- **Periodic Updates:** Every 60 seconds (1 minute)
- **Movement Updates:** Every 10 meters of movement
- **Timeout:** 30 seconds for location requests
- **API Timeout:** 10 seconds for HTTP requests

### Permissions Required
- Location permission (While in use)
- Background location (for continuous tracking)

## Testing

### Manual Testing
1. Use the debug test screen (`/location_tracking_test`)
2. Verify location permissions are granted
3. Test with GPS enabled/disabled
4. Monitor console logs for detailed information

### API Testing
Use curl or Postman to test the endpoint:
```bash
curl -X PATCH https://api.atla.business/api/v1/l/trips/location \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"latitude": 36.8065, "longitude": 10.1815}'
```

## Troubleshooting

### Common Issues

1. **Location permission denied**
   - Check app permissions in device settings
   - Ensure location services are enabled

2. **API requests failing**
   - Verify API endpoint is accessible: https://api.atla.business/api/v1/l/trips/location
   - Check authentication token validity
   - Monitor network connectivity
   - Check server status and response codes

3. **Location not updating**
   - Check GPS signal strength
   - Verify movement exceeds distance filter (10m)
   - Check console logs for errors

### Debug Steps

1. Open console logs in development environment
2. Check location service availability in dashboard
3. Verify API endpoint accessibility
4. Monitor HTTP request/response details
5. Use manual refresh button to test API calls

## Security Considerations

- Authentication tokens are never logged in full (only first 10 characters)
- Location data is sent over HTTPS in production
- Location permissions are requested only when needed
- Background tracking respects user privacy settings

## Future Enhancements

- [ ] Background location tracking for iOS/Android
- [ ] Location history and analytics
- [ ] Geofencing capabilities
- [ ] Offline location caching
- [ ] Battery optimization settings
- [ ] Real-time location sharing with dispatch

## Files Modified/Created

- `lib/services/location_tracking_service.dart` (NEW)
- `lib/screens/driver_dashboard.dart` (MODIFIED)
- `lib/main.dart` (MODIFIED)
- `LOCATION_TRACKING.md` (NEW)

## Support

For issues or questions regarding the location tracking implementation, refer to the console logs and dashboard status indicators for detailed information about the system state.
