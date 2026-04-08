import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

enum ServiceType {
  taxi,
  moto,
  camion,
  yacht,
  livraison,
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;

    // Draw grid lines
    const gridSize = 50.0;
    
    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // Draw some roads (thicker lines)
    final roadPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 3;
    
    // Horizontal road
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.4),
      roadPaint,
    );
    
    // Vertical road
    canvas.drawLine(
      Offset(size.width * 0.6, 0),
      Offset(size.width * 0.6, size.height),
      roadPaint,
    );
    
    // Diagonal road
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  ServiceType? _selectedService;
  
  // Form controllers
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _passengersController = TextEditingController();
  final TextEditingController _packageTypeController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _truckSizeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  
  // Form values
  bool _isFragile = false;
  bool _needHelp = false;
  DateTime? _selectedDateTime;
  bool _isNow = true;
  
  // Calculated values
  double _estimatedPrice = 0.0;
  double _distance = 0.0;
  String _estimatedTime = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map Background
          _buildMapBackground(),
          
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),
          
          // Service Selection (when no service is selected)
          if (_selectedService == null)
            Positioned.fill(
              child: _buildServiceSelection(),
            ),
          
          // Booking Form (when service is selected)
          if (_selectedService != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBookingForm(),
            ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100,
            Colors.grey.shade200,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Map Grid Pattern
          CustomPaint(
            size: Size.infinite,
            painter: MapGridPainter(),
          ),
          
          // Map Elements
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Current Location Marker
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 3),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Destination Marker
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red, width: 3),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Route Line
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.red],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Map Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Carte Interactive',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Google Maps Integration',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distance: 15.5 km | Temps: 25 min',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Map Controls
          Positioned(
            top: 100,
            right: 20,
            child: Column(
              children: [
                _buildMapControl(Icons.zoom_in, () {
                  // TODO: Zoom in
                }),
                const SizedBox(height: 8),
                _buildMapControl(Icons.zoom_out, () {
                  // TODO: Zoom out
                }),
                const SizedBox(height: 8),
                _buildMapControl(Icons.my_location, () {
                  // TODO: Center on current location
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 24),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          Expanded(
            child: Text(
              _selectedService != null 
                ? 'Réserver ${_getServiceName(_selectedService!)}'
                : 'Choisir un service',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_selectedService != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedService = null;
                  _resetForm();
                });
              },
              icon: const Icon(Icons.close, color: Colors.black),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Quel service souhaitez-vous ?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: ServiceType.values.map((service) {
              return _buildServiceCard(service);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceType service) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = service;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getServiceIcon(service),
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getServiceName(service),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingForm() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Service Info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getServiceIcon(_selectedService!),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _getServiceName(_selectedService!),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Departure
            TextField(
              controller: _departureController,
              decoration: const InputDecoration(
                labelText: 'Adresse de départ',
                hintText: 'Entrez l\'adresse de départ',
                prefixIcon: Icon(Icons.location_on_outlined),
                suffixIcon: Icon(Icons.my_location),
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Destination
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Entrez la destination',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Date/Time Selection
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isNow = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isNow ? AppTheme.primaryColor : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isNow ? AppTheme.primaryColor : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        'Maintenant',
                        style: TextStyle(
                          color: _isNow ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isNow = false;
                        _showDateTimePicker();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !_isNow ? AppTheme.primaryColor : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_isNow ? AppTheme.primaryColor : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        'Planifier',
                        style: TextStyle(
                          color: !_isNow ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Dynamic Fields
            _buildDynamicFields(),
            
            const SizedBox(height: 24),
            
            // Calculation Results
            if (_distance > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildCalculationRow('Distance', '${_distance.toStringAsFixed(1)} km'),
                    _buildCalculationRow('Temps estimé', _estimatedTime),
                    _buildCalculationRow('Prix estimé', '$_estimatedPrice MAD', isPrice: true),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Find Driver Button
            CustomButton(
              text: 'Trouver un chauffeur',
              onPressed: _calculateAndFindDriver,
              height: 56,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicFields() {
    switch (_selectedService) {
      case ServiceType.taxi:
        return Column(
          children: [
            TextField(
              controller: _passengersController,
              decoration: const InputDecoration(
                labelText: 'Nombre de passagers',
                hintText: '1-4 passagers',
                prefixIcon: Icon(Icons.people_outline),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        );
      
      case ServiceType.livraison:
        return Column(
          children: [
            TextField(
              controller: _packageTypeController,
              decoration: const InputDecoration(
                labelText: 'Type de colis',
                hintText: 'Document, paquet, etc.',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Poids (kg)',
                hintText: '0.1 - 50 kg',
                prefixIcon: Icon(Icons.scale_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Fragile'),
                    value: _isFragile,
                    onChanged: (value) {
                      setState(() {
                        _isFragile = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ],
        );
      
      case ServiceType.camion:
        return Column(
          children: [
            TextField(
              controller: _truckSizeController,
              decoration: const InputDecoration(
                labelText: 'Taille du camion',
                hintText: 'Petit, moyen, grand',
                prefixIcon: Icon(Icons.local_shipping_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Aide au chargement'),
                    value: _needHelp,
                    onChanged: (value) {
                      setState(() {
                        _needHelp = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ],
        );
      
      case ServiceType.yacht:
        return Column(
          children: [
            TextField(
              controller: _peopleController,
              decoration: const InputDecoration(
                labelText: 'Nombre de personnes',
                hintText: '1-12 personnes',
                prefixIcon: Icon(Icons.groups_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Durée (heures)',
                hintText: '1-8 heures',
                prefixIcon: Icon(Icons.schedule_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        );
      
      case ServiceType.moto:
        return Container(); // No additional fields for moto
      
      case null:
        return Container();
    }
  }

  Widget _buildCalculationRow(String label, String value, {bool isPrice = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isPrice ? AppTheme.primaryColor : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(ServiceType service) {
    switch (service) {
      case ServiceType.taxi:
        return Icons.local_taxi;
      case ServiceType.moto:
        return Icons.motorcycle;
      case ServiceType.camion:
        return Icons.local_shipping;
      case ServiceType.yacht:
        return Icons.sailing;
      case ServiceType.livraison:
        return Icons.delivery_dining;
    }
  }

  String _getServiceName(ServiceType service) {
    switch (service) {
      case ServiceType.taxi:
        return 'Taxi';
      case ServiceType.moto:
        return 'Moto';
      case ServiceType.camion:
        return 'Camion';
      case ServiceType.yacht:
        return 'Yacht';
      case ServiceType.livraison:
        return 'Livraison';
    }
  }

  void _resetForm() {
    _departureController.clear();
    _destinationController.clear();
    _passengersController.clear();
    _packageTypeController.clear();
    _weightController.clear();
    _truckSizeController.clear();
    _durationController.clear();
    _peopleController.clear();
    
    _isFragile = false;
    _needHelp = false;
    _selectedDateTime = null;
    _isNow = true;
    
    _estimatedPrice = 0.0;
    _distance = 0.0;
    _estimatedTime = '';
  }

  void _showDateTimePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    ).then((date) {
      if (date != null) {
        showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        ).then((time) {
          if (time != null) {
            setState(() {
              _selectedDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          }
        });
      }
    });
  }

  void _calculateAndFindDriver() {
    // TODO: Implement real calculation and navigation
    setState(() {
      _distance = 15.5;
      _estimatedTime = '25 min';
      
      // Price calculation based on service type
      switch (_selectedService) {
        case ServiceType.taxi:
          _estimatedPrice = _distance * 12 + 15;
          break;
        case ServiceType.moto:
          _estimatedPrice = _distance * 8 + 10;
          break;
        case ServiceType.camion:
          _estimatedPrice = _distance * 25 + 50;
          break;
        case ServiceType.yacht:
          _estimatedPrice = _distance * 100 + 200;
          break;
        case ServiceType.livraison:
          _estimatedPrice = _distance * 6 + 5;
          break;
        case null:
          _estimatedPrice = 0.0;
          break;
      }
    });
    
    // TODO: Navigate to driver search screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recherche de chauffeur en cours...'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
