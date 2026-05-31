import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
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
            const _ShopHeader(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/inapp_logo.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'COMING SOON',
                        style: AppTheme.storeTitle.copyWith(
                          color: AppTheme.blazeGold,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Power-ups, bundles and more — coming in a future update',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) return _buildHeader(context, coins: 0);
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: UserService.userStream(user.uid),
          builder: (context, snap) {
            final coins = (snap.data?.data()?['coins'] as int?) ?? 0;
            return _buildHeader(context, coins: coins);
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, {required int coins}) {
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
                const Icon(Icons.star_rounded,
                    color: AppTheme.blazeGold, size: 18),
                const SizedBox(width: 6),
                Text('$coins', style: AppTheme.coinBalance),
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
