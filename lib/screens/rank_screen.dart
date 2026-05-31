import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _Entry {
  final String uid;
  final String username;
  final int score;
  final String country;
  final String avatarUrl;

  const _Entry({
    required this.uid,
    required this.username,
    required this.score,
    required this.country,
    required this.avatarUrl,
  });

  factory _Entry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _Entry(
      uid: doc.id,
      username: (d['username'] as String?) ?? 'Player',
      score: (d['score'] as num?)?.toInt() ?? 0,
      country: (d['country'] as String?) ?? '',
      avatarUrl: (d['avatarUrl'] as String?) ?? '',
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(int score) {
  final s = score.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

Color _avatarColor(String uid) {
  final colors = AppTheme.leaderboardAvatars;
  return colors[uid.hashCode.abs() % colors.length];
}

// ── Screen ────────────────────────────────────────────────────────────────────

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  int _filterIndex = 0;
  static const _filters = ['Worldwide', 'Canada', 'Friends'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.arenaBlack,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text('LEADERBOARD', style: AppTheme.screenTitle),
            const SizedBox(height: 20),
            _FilterTabs(
              filters: _filters,
              selected: _filterIndex,
              onSelect: (i) => setState(() => _filterIndex = i),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _filterIndex == 2
                  ? const _ComingSoonView()
                  : _LeaderboardBody(filterIndex: _filterIndex),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter tabs ───────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final List<String> filters;
  final int selected;
  final ValueChanged<int> onSelect;

  const _FilterTabs({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(filters.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppTheme.blazeGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  filters[i],
                  textAlign: TextAlign.center,
                  style: AppTheme.filterTab.copyWith(
                    color: active ? Colors.white : AppTheme.mutedText,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Leaderboard body (StreamBuilder) ─────────────────────────────────────────

class _LeaderboardBody extends StatelessWidget {
  final int filterIndex;

  const _LeaderboardBody({required this.filterIndex});

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: UserService.leaderboardStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.blazeGold,
              strokeWidth: 3,
            ),
          );
        }

        var entries = (snapshot.data?.docs ?? []).map(_Entry.fromDoc).toList();

        // Canada tab: client-side filter
        if (filterIndex == 1) {
          entries = entries.where((e) => e.country == 'CA').toList();
        }

        if (entries.isEmpty) {
          return _EmptyState(
            message: filterIndex == 1
                ? 'No Canadian players yet.'
                : 'No scores yet — play a game!',
          );
        }

        final podium = entries.take(3).toList();
        final rest = entries.length > 3 ? entries.sublist(3) : <_Entry>[];

        return Column(
          children: [
            _Podium(entries: podium, currentUid: currentUid),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.divider, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: rest.length,
                itemBuilder: (context, i) => _PlayerRow(
                  entry: rest[i],
                  rank: i + 4,
                  isCurrentUser: rest[i].uid == currentUid,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<_Entry> entries;
  final String? currentUid;

  const _Podium({required this.entries, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    // Layout order: 2nd (left) · 1st (center, taller) · 3rd (right)
    // Render only slots that have a player — no empty placeholder cards.
    final has1 = entries.isNotEmpty;
    final has2 = entries.length >= 2;
    final has3 = entries.length >= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (has2) ...[
            Expanded(
              child: _PodiumCard(
                entry: entries[1],
                rank: 2,
                isFirst: false,
                isCurrentUser: entries[1].uid == currentUid,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (has1)
            Expanded(
              child: _PodiumCard(
                entry: entries[0],
                rank: 1,
                isFirst: true,
                isCurrentUser: entries[0].uid == currentUid,
              ),
            ),
          if (has3) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _PodiumCard(
                entry: entries[2],
                rank: 3,
                isFirst: false,
                isCurrentUser: entries[2].uid == currentUid,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final _Entry entry;
  final int rank;
  final bool isFirst;
  final bool isCurrentUser;

  const _PodiumCard({
    required this.entry,
    required this.rank,
    required this.isFirst,
    required this.isCurrentUser,
  });

  Color get _badgeColor => switch (rank) {
    1 => AppTheme.blazeGold,
    2 => AppTheme.rankSilver,
    _ => AppTheme.rankBronze,
  };

  String get _ordinal => switch (rank) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };

  @override
  Widget build(BuildContext context) {
    final cardHeight = isFirst ? 172.0 : 148.0;
    final avatarRadius = isFirst ? 26.0 : 22.0;
    final accentColor = _avatarColor(entry.uid);

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.blazeGold.withAlpha(30)
            : accentColor.withAlpha(40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.blazeGold
              : isFirst
              ? AppTheme.blazeGold.withAlpha(120)
              : accentColor.withAlpha(80),
          width: isCurrentUser || isFirst ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rank badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$rank$_ordinal', style: AppTheme.rankBadge),
          ),
          const SizedBox(height: 6),

          // Avatar
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: accentColor,
                backgroundImage: entry.avatarUrl.isNotEmpty
                    ? NetworkImage(entry.avatarUrl)
                    : null,
                child: entry.avatarUrl.isEmpty
                    ? Text(
                        entry.username.isNotEmpty
                            ? entry.username[0].toUpperCase()
                            : '?',
                        style: AppTheme.podiumName.copyWith(
                          fontSize: isFirst ? 22 : 18,
                        ),
                      )
                    : null,
              ),
              if (isFirst)
                const Positioned(
                  bottom: -4,
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: AppTheme.blazeGold,
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              entry.username.split(' ').first,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.podiumName,
            ),
          ),
          const SizedBox(height: 4),

          // Score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppTheme.blazeGold,
                size: 12,
              ),
              const SizedBox(width: 2),
              Text(_fmt(entry.score), style: AppTheme.podiumScore),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Player row (4th place and below) ─────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  final _Entry entry;
  final int rank;
  final bool isCurrentUser;

  const _PlayerRow({
    required this.entry,
    required this.rank,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _avatarColor(entry.uid);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.blazeGold.withAlpha(18)
            : AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: AppTheme.blazeGold.withAlpha(160), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$rank', style: AppTheme.rankNumber)),
          CircleAvatar(
            radius: 18,
            backgroundColor: accentColor,
            backgroundImage: entry.avatarUrl.isNotEmpty
                ? NetworkImage(entry.avatarUrl)
                : null,
            child: entry.avatarUrl.isEmpty
                ? Text(
                    entry.username.isNotEmpty
                        ? entry.username[0].toUpperCase()
                        : '?',
                    style: AppTheme.playerName.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(entry.username, style: AppTheme.playerName)),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppTheme.blazeGold,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(_fmt(entry.score), style: AppTheme.score),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              color: AppTheme.mutedText,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTheme.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Coming Soon (Friends tab) ─────────────────────────────────────────────────

class _ComingSoonView extends StatelessWidget {
  const _ComingSoonView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              color: AppTheme.mutedText,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'COMING SOON',
              style: AppTheme.sectionHeader.copyWith(
                color: AppTheme.blazeGold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Challenge your friends once\nfriend mode is live.',
              style: AppTheme.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
