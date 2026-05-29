import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.arenaBlack,
      body: SafeArea(
        child: Column(
          children: [
            const _StoreHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: const [
                  _BundleCard(
                    title: 'MINI BUNDLE',
                    price: '12.99',
                    coins: 600,
                    jokers: 5,
                    extras: [],
                    isBestOffer: false,
                    coinIconSize: 52,
                  ),
                  SizedBox(height: 14),
                  _BundleCard(
                    title: 'MEDIUM BUNDLE',
                    price: '22.99',
                    coins: 1000,
                    jokers: 10,
                    extras: [Icons.flash_on_rounded, Icons.shield_rounded],
                    isBestOffer: true,
                    coinIconSize: 60,
                  ),
                  SizedBox(height: 14),
                  _BundleCard(
                    title: 'LARGE BUNDLE',
                    price: '38.99',
                    coins: 1600,
                    jokers: 20,
                    extras: [Icons.flash_on_rounded, Icons.shield_rounded, Icons.timer_rounded],
                    isBestOffer: false,
                    coinIconSize: 68,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.voidBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppTheme.blazeGold, size: 18),
                const SizedBox(width: 6),
                Text('67', style: AppTheme.coinBalance),
              ],
            ),
          ),
          const Spacer(),
          Text('SHOP', style: AppTheme.storeTitle),
          const Spacer(),
          const SizedBox(width: 64),
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  final String title;
  final String price;
  final int coins;
  final int jokers;
  final List<IconData> extras;
  final bool isBestOffer;
  final double coinIconSize;

  const _BundleCard({
    required this.title,
    required this.price,
    required this.coins,
    required this.jokers,
    required this.extras,
    required this.isBestOffer,
    required this.coinIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.blazeGold.withAlpha(102), width: 1),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      _ItemIcon(
                        icon: Icons.monetization_on_rounded,
                        color: AppTheme.blazeGold,
                        size: coinIconSize,
                        label: coins.toString(),
                      ),
                      const SizedBox(width: 14),
                      _ItemIcon(
                        icon: Icons.extension_rounded,
                        color: AppTheme.blazeGold,
                        size: 44,
                        label: 'x$jokers',
                      ),
                      for (final icon in extras) ...[
                        const SizedBox(width: 8),
                        _ItemIcon(
                          icon: icon,
                          color: AppTheme.powerUpBlue,
                          size: 36,
                          label: '',
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.blazeGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(price, style: AppTheme.priceText),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: AppTheme.voidBlack,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(title, textAlign: TextAlign.center, style: AppTheme.bundleName),
                ),
              ],
            ),
          ),
          if (isBestOffer)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.bestOfferRed,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Text('BEST OFFER', style: AppTheme.ribbonLabel),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String label;

  const _ItemIcon({required this.icon, required this.color, required this.size, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: size * 0.6),
        if (label.isNotEmpty) Text(label, style: AppTheme.itemLabel),
      ],
    );
  }
}
