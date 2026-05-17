import 'package:flutter/material.dart';
import '../models/crypto_asset_model.dart';
import '../utils/app_theme.dart';

class DriverCryptoSelectScreen extends StatefulWidget {
  const DriverCryptoSelectScreen({super.key});

  @override
  State<DriverCryptoSelectScreen> createState() => _DriverCryptoSelectScreenState();
}

class _DriverCryptoSelectScreenState extends State<DriverCryptoSelectScreen> {
  final List<CryptoAsset> _assets = CryptoAsset.defaultAssets;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Filtrer la liste en fonction de la saisie
    final filteredAssets = _assets.where((asset) {
      final name = asset.name.toLowerCase();
      final network = asset.network.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || network.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recharger Sélectionner',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Elegant search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161722),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher une crypto ou un réseau...',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Scrollable List of Cryptos
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              itemCount: filteredAssets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final asset = filteredAssets[index];
                return _buildCryptoRow(context, asset);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoRow(BuildContext context, CryptoAsset asset) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/driver_crypto_recharge',
          arguments: asset,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161722),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            // Custom high-end glowing crypto vector logo
            _buildCryptoLogo(asset),
            const SizedBox(width: 16),

            // Asset name & blockchain information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    asset.network,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron trailing indicator
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.25),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoLogo(CryptoAsset asset) {
    Color logoBg = const Color(0xFF009387); // Default USDT green
    String abbreviation = 'T';
    Color labelColor = Colors.white;

    if (asset.symbol == 'USDT') {
      logoBg = const Color(0xFF009387);
      abbreviation = '₮';
    } else if (asset.symbol == 'USDC') {
      logoBg = const Color(0xFF2775CA);
      abbreviation = '\$';
    } else if (asset.symbol == 'TRX') {
      logoBg = const Color(0xFFEC0A27);
      abbreviation = 'T';
    } else if (asset.symbol == 'BNB') {
      logoBg = const Color(0xFFF3BA2F);
      abbreviation = 'B';
      labelColor = Colors.black;
    } else if (asset.symbol == 'ETH') {
      logoBg = const Color(0xFF627EEA);
      abbreviation = 'Ξ';
    } else if (asset.symbol == 'POLYGON') {
      logoBg = const Color(0xFF8247E5);
      abbreviation = 'P';
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Crypto Badge
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: logoBg.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: logoBg.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: logoBg.withOpacity(0.08),
                blurRadius: 8,
              )
            ],
          ),
          child: Center(
            child: Text(
              abbreviation,
              style: TextStyle(
                color: logoBg,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),

        // Sub-Network indicator badge (like the Tron/Binance icon overlay in screenshot)
        Positioned(
          bottom: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1017),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _getNetworkAccentColor(asset.networkLogo),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  asset.networkLogo.substring(0, 1),
                  style: TextStyle(
                    color: asset.networkLogo == 'BNB' ? Colors.black : Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  Color _getNetworkAccentColor(String networkSymbol) {
    switch (networkSymbol) {
      case 'TRX':
        return const Color(0xFFEC0A27);
      case 'BNB':
        return const Color(0xFFF3BA2F);
      case 'ETH':
        return const Color(0xFF627EEA);
      case 'MATIC':
        return const Color(0xFF8247E5);
      default:
        return AppTheme.primaryColor;
    }
  }
}
