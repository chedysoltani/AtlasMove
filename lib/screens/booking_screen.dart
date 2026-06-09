import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

// Catégories principales
enum TransportCategory {
  transport,
  camion,
  autre,
}

// Services de transport
enum TransportService {
  taxi,
  motoTaxi,
}

// Services de camion
enum CamionService {
  livraison,
  demenagement,
  poidsLourd,
}

// Services autres véhicules
enum AutreService {
  yacht,
  voiture,
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

class RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw route line
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.2,
      size.width * 0.8, size.height * 0.7,
    );
    
    canvas.drawPath(path, paint);
    
    // Draw start point
    final startPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3),
      8,
      startPaint,
    );
    
    // Draw end point
    final endPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      8,
      endPaint,
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
  TransportCategory? _selectedCategory;
  TransportService? _selectedTransportService;
  CamionService? _selectedCamionService;
  AutreService? _selectedAutreService;
  
  // Form controllers
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _passengersController = TextEditingController();
  final TextEditingController _packageTypeController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _truckSizeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _carTypeController = TextEditingController();
  
  // Form values
  bool _isFragile = false;
  bool _needHelp = false;
  DateTime? _selectedDateTime;
  bool _isNow = true;
  String? _selectedTruckDiameter;

  // Available truck diameters (from delivery trucks)
  static const List<Map<String, String>> _truckDiameters = [
    {'size': 'Petit (3-5m)', 'description': 'Colis et petites livraisons', 'icon': 'local_shipping'},
    {'size': 'Moyen (6-8m)', 'description': 'Meubles et déménagement moyen', 'icon': 'moving'},
    {'size': 'Grand (9-12m)', 'description': 'Grands volumes et marchandises', 'icon': 'local_shipping'},
    {'size': 'Très grand (13-16m)', 'description': 'Déménagement complet et industriel', 'icon': 'local_shipping'},
    {'size': 'Extra large (17-20m)', 'description': 'Transport de charges très lourdes', 'icon': 'local_shipping'},
    {'size': 'Spécial (sur mesure)', 'description': 'Transport spécialisé', 'icon': 'settings'},
  ];
  
  // Calculated values
  double _estimatedPrice = 0.0;
  double _distance = 0.0;
  String _estimatedTime = '0';

  @override
  void dispose() {
    _departureController.dispose();
    _destinationController.dispose();
    _passengersController.dispose();
    _packageTypeController.dispose();
    _weightController.dispose();
    _truckSizeController.dispose();
    _durationController.dispose();
    _peopleController.dispose();
    _carTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'booking.title'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          // Map Section
          Expanded(
            flex: 2,
            child: _buildMapSection(),
          ),
          
          // Form Section
          Expanded(
            flex: 3,
            child: _buildFormSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Custom Map Grid
          CustomPaint(
            painter: MapGridPainter(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // Map Controls
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                _buildMapControl(Icons.my_location, () {}),
                const SizedBox(height: 8),
                _buildMapControl(Icons.layers, () {}),
              ],
            ),
          ),
          
          // Route Line (simplified)
          Positioned.fill(
            child: CustomPaint(
              painter: RoutePainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.black,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Selection
            _buildCategorySelection(),
            
            const SizedBox(height: 20),
            
            // Service Selection (based on category)
            if (_selectedCategory != null) _buildServiceSelection(),
            
            const SizedBox(height: 20),
            
            // Dynamic Form Fields
            if (_selectedCategory != null) _buildDynamicForm(),
            
            const SizedBox(height: 20),
            
            // Find Driver Button
            CustomButton(
              text: 'booking.find_driver'.tr(),
              onPressed: _findDriver,
              height: 50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'booking.category'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCategoryCard(
              'booking.transport'.tr(),
              Icons.local_taxi,
              TransportCategory.transport,
              Colors.blue,
            ),
            const SizedBox(width: 12),
            _buildCategoryCard(
              'booking.camion'.tr(),
              Icons.local_shipping,
              TransportCategory.camion,
              Colors.green,
            ),
            const SizedBox(width: 12),
            _buildCategoryCard(
              'booking.other'.tr(),
              Icons.directions_car,
              TransportCategory.autre,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, TransportCategory category, Color color) {
    final isSelected = _selectedCategory == category;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            _selectedTransportService = null;
            _selectedCamionService = null;
            _selectedAutreService = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : Colors.black,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSelection() {
    switch (_selectedCategory) {
      case TransportCategory.transport:
        return _buildTransportServices();
      case TransportCategory.camion:
        return _buildCamionServices();
      case TransportCategory.autre:
        return _buildAutreServices();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTransportServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'booking.transport_type'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildServiceCard(
                'booking.taxi'.tr(),
                Icons.local_taxi,
                TransportService.taxi,
                Colors.blue,
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceCard(
                'booking.moto_taxi'.tr(),
                Icons.motorcycle,
                TransportService.motoTaxi,
                Colors.orange,
                isExpanded: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCamionServices() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'booking.truck_services'.tr(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Services Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCamionServiceCard(
                        'booking.delivery'.tr(),
                        Icons.local_shipping,
                        CamionService.livraison,
                        Colors.green,
                        'Transport de colis et marchandises',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCamionServiceCard(
                        'booking.moving'.tr(),
                        Icons.moving,
                        CamionService.demenagement,
                        Colors.blue,
                        'Services de déménagement complet',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildCamionServiceCard(
                    'booking.heavy_truck'.tr(),
                    Icons.local_shipping,
                    CamionService.poidsLourd,
                    Colors.red,
                    'Transport de charges lourdes',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCamionServiceCard(String title, IconData icon, CamionService service, Color color, String description) {
    final isSelected = _selectedCamionService == service;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCamionService = service;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutreServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'booking.other_vehicle'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildServiceCard(
                'Yacht',
                Icons.sailing,
                AutreService.yacht,
                Colors.cyan,
              ),
              const SizedBox(width: 12),
              _buildServiceCard(
                'Voiture',
                Icons.directions_car,
                AutreService.voiture,
                Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(String title, IconData icon, dynamic service, Color color, {bool isExpanded = false}) {
    final isSelected = (_selectedCategory == TransportCategory.transport && _selectedTransportService == service) ||
                     (_selectedCategory == TransportCategory.camion && _selectedCamionService == service) ||
                     (_selectedCategory == TransportCategory.autre && _selectedAutreService == service);
    
    if (isExpanded) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              if (_selectedCategory == TransportCategory.transport) {
                _selectedTransportService = service;
              } else if (_selectedCategory == TransportCategory.camion) {
                _selectedCamionService = service;
              } else if (_selectedCategory == TransportCategory.autre) {
                _selectedAutreService = service;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.grey.shade600,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? color : Colors.black,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          setState(() {
            if (_selectedCategory == TransportCategory.transport) {
              _selectedTransportService = service;
            } else if (_selectedCategory == TransportCategory.camion) {
              _selectedCamionService = service;
            } else if (_selectedCategory == TransportCategory.autre) {
              _selectedAutreService = service;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : Colors.black,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDynamicForm() {
    // Common fields for all services
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Departure and Destination
        _buildLocationFields(),
        
        const SizedBox(height: 16),
        
        // Date/Time Selection
        _buildDateTimeSelection(),
        
        const SizedBox(height: 16),
        
        // Service-specific fields
        if (_selectedCategory == TransportCategory.transport)
          _buildTransportFormFields(),
        if (_selectedCategory == TransportCategory.camion)
          _buildCamionFormFields(),
        if (_selectedCategory == TransportCategory.autre)
          _buildAutreFormFields(),
        
        const SizedBox(height: 16),
        
        // Price and Time Estimation
        _buildEstimationSection(),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Itinéraire',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              TextField(
                controller: _departureController,
                decoration: InputDecoration(
                  hintText: 'booking.departure'.tr(),
                  prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryColor),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'booking.destination'.tr(),
                  prefixIcon: Icon(Icons.flag, color: AppTheme.primaryColor),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'booking.schedule'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
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
                    color: _isNow ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isNow ? AppTheme.primaryColor : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    'booking.now'.tr(),
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
                  });
                  _selectDateTime();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: !_isNow ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isNow ? AppTheme.primaryColor : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    _selectedDateTime != null 
                        ? '${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year} ${_selectedDateTime!.hour}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}'
                        : 'booking.schedule'.tr(),
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
      ],
    );
  }

  Widget _buildTransportFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Détails du transport',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passengersController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'booking.passenger_count'.tr(),
            prefixIcon: const Icon(Icons.people, color: AppTheme.primaryColor),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildCamionFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Détails de la livraison',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _packageTypeController,
          decoration: InputDecoration(
            labelText: 'booking.package_type'.tr(),
            prefixIcon: const Icon(Icons.inventory_2, color: AppTheme.primaryColor),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'booking.weight_kg'.tr(),
            prefixIcon: const Icon(Icons.scale, color: AppTheme.primaryColor),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        // Dropdown pour le diamètre du camion
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTruckDiameter,
              isExpanded: true,
              hint: const Text(
                'Sélectionner le diamètre du camion',
                style: TextStyle(color: Colors.grey),
              ),
              icon: const Icon(Icons.arrow_drop_down),
              items: _truckDiameters.map((Map<String, String> truck) {
                return DropdownMenuItem<String>(
                  value: truck['size'],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          _getIconForTruck(truck['icon']!),
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                truck['size']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                truck['description']!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTruckDiameter = newValue;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: Text('booking.fragile'.tr()),
                value: _isFragile,
                onChanged: (value) {
                  setState(() {
                    _isFragile = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                title: Text('booking.loading_help'.tr()),
                value: _needHelp,
                onChanged: (value) {
                  setState(() {
                    _needHelp = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutreFormFields() {
    if (_selectedAutreService == AutreService.yacht) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails de la réservation',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'booking.duration_hours'.tr(),
              prefixIcon: const Icon(Icons.access_time, color: AppTheme.primaryColor),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _peopleController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'booking.person_count'.tr(),
              prefixIcon: const Icon(Icons.people, color: AppTheme.primaryColor),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails du véhicule',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _carTypeController,
            decoration: InputDecoration(
              labelText: 'booking.car_type'.tr(),
              prefixIcon: const Icon(Icons.directions_car, color: AppTheme.primaryColor),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passengersController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'booking.passenger_count'.tr(),
              prefixIcon: const Icon(Icons.people, color: AppTheme.primaryColor),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildEstimationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'Distance',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_distance.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            children: [
              const Text(
                'Durée estimée',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_estimatedTime min',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            children: [
              const Text(
                'Prix estimé',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_estimatedPrice.toStringAsFixed(2)} MAD',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForTruck(String iconName) {
    switch (iconName) {
      case 'local_shipping':
        return Icons.local_shipping;
      case 'moving':
        return Icons.moving;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.local_shipping;
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
      );
      
      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _findDriver() {
    // Validation
    if (_departureController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('booking.fill_departure_destination'.tr()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('booking.category'.tr()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Service-specific validation
    if (_selectedCategory == TransportCategory.transport && _selectedTransportService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('booking.select_transport'.tr()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedCategory == TransportCategory.camion) {
      if (_selectedCamionService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('booking.select_truck_service'.tr()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      if (_selectedTruckDiameter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('booking.select_truck_diameter'.tr()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    if (_selectedCategory == TransportCategory.autre && _selectedAutreService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('booking.select_vehicle_type'.tr()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Simulate finding driver and navigate to payment
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('booking.driver_found'.tr()),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
    
    // Navigate to payment page after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushNamed(context, '/payment');
    });
  }
}
