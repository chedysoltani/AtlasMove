class CryptoAsset {
  final String id;
  final String name;          // ex: "TRC20-USDT"
  final String symbol;        // ex: "USDT"
  final String network;       // ex: "Tron (TRC20)"
  final String walletAddress;  // Adresse réelle de dépôt
  final double minDeposit;    // Dépôt minimum en dollar / crypto
  final String networkLogo;   // Logo du réseau blockchain

  CryptoAsset({
    required this.id,
    required this.name,
    required this.symbol,
    required this.network,
    required this.walletAddress,
    this.minDeposit = 10.0,
    required this.networkLogo,
  });

  // Liste prédéfinie des actifs correspondants exactement aux captures d'écran de l'utilisateur
  static List<CryptoAsset> get defaultAssets => [
    CryptoAsset(
      id: 'usdt-trc20',
      name: 'TRC20-USDT',
      symbol: 'USDT',
      network: 'Tron (TRC20)',
      walletAddress: 'TPrYh1FzcVVMkQTYa3ZZWHKdikTxaCXDYy',
      networkLogo: 'TRX',
      minDeposit: 90.0,
    ),
    CryptoAsset(
      id: 'trx',
      name: 'TRX',
      symbol: 'TRX',
      network: 'Tron Native',
      walletAddress: 'TPrYh1FzcVVMkQTYa3ZZWHKdikTxaCXDYy',
      networkLogo: 'TRX',
      minDeposit: 1500.0, // Équivalent de 90$ en TRX
    ),
    CryptoAsset(
      id: 'usdt-bep20',
      name: 'BEP20-USDT',
      symbol: 'USDT',
      network: 'BNB Smart Chain (BEP20)',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'BNB',
      minDeposit: 90.0,
    ),
    CryptoAsset(
      id: 'bnb',
      name: 'BNB',
      symbol: 'BNB',
      network: 'BNB Beacon Chain (BEP2)',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'BNB',
      minDeposit: 0.16, // Équivalent de 90$ en BNB
    ),
    CryptoAsset(
      id: 'usdc-bep20',
      name: 'BEP20-USDC',
      symbol: 'USDC',
      network: 'BNB Smart Chain (BEP20)',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'BNB',
      minDeposit: 90.0,
    ),
    CryptoAsset(
      id: 'usdt-polygon',
      name: 'POLYGON-USDT',
      symbol: 'USDT',
      network: 'Polygon Network',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'MATIC',
      minDeposit: 90.0,
    ),
    CryptoAsset(
      id: 'usdt-erc20',
      name: 'ETH-USDT',
      symbol: 'USDT',
      network: 'Ethereum (ERC20)',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'ETH',
      minDeposit: 90.0,
    ),
    CryptoAsset(
      id: 'usdc-polygon',
      name: 'POLYGON-USDC',
      symbol: 'USDC',
      network: 'Polygon Network',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'MATIC',
      minDeposit: 90.0,
    ),
    CryptoAsset(
      id: 'usdc-erc20',
      name: 'ETH-USDC',
      symbol: 'USDC',
      network: 'Ethereum (ERC20)',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'ETH',
      minDeposit: 90.0,
    ),
    CryptoAsset(
      id: 'eth',
      name: 'ETH',
      symbol: 'ETH',
      network: 'Ethereum Native',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'ETH',
      minDeposit: 0.03, // Équivalent de 90$ en ETH
    ),
    CryptoAsset(
      id: 'polygon',
      name: 'POLYGON',
      symbol: 'POLYGON',
      network: 'Polygon Native (MATIC)',
      walletAddress: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
      networkLogo: 'MATIC',
      minDeposit: 135.0, // Équivalent de 90$ en MATIC
    ),
  ];
}
