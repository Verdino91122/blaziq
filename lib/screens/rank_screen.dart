import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  int _filterIndex = 0;
  static const _filters = ['Worldwide', 'Canada', 'Friends'];

  // static final because leaderboardAvatars list indexing is a runtime operation
  static final _topThree = [
    _PlayerData('Rita Singh', '54,780', AppTheme.leaderboardAvatars[0], 2),
    _PlayerData('Stephan Jones', '96,255', AppTheme.leaderboardAvatars[1], 1),
    _PlayerData('Sami Kamara', '81,650', AppTheme.leaderboardAvatars[2], 3),
  ];

  static final _restPlayers = [
    _PlayerData('Elena Rodriguez', '80,390', AppTheme.leaderboardAvatars[3], 4),
    _PlayerData('Marco Rossi', '79,580', AppTheme.leaderboardAvatars[4], 5),
    _PlayerData('Amara Okoro', '79,000', AppTheme.leaderboardAvatars[5], 6),
    _PlayerData('Leo Dubois', '78,700', AppTheme.leaderboardAvatars[6], 7),
    _PlayerData('Julia Silva', '75,990', AppTheme.leaderboardAvatars[7], 8),
    _PlayerData('David Cuevas', '75,234', AppTheme.leaderboardAvatars[8], 9),
    _PlayerData('Sarah Miller', '74,100', AppTheme.leaderboardAvatars[9], 10),
  ];

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
            _Podium(topThree: _topThree),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.divider, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _restPlayers.length,
                itemBuilder: (context, index) => _PlayerRow(player: _restPlayers[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final List<String> filters;
  final int selected;
  final ValueChanged<int> onSelect;

  const _FilterTabs({required this.filters, required this.selected, required this.onSelect});

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

class _PlayerData {
  final String name;
  final String score;
  final Color avatarColor;
  final int rank;
  const _PlayerData(this.name, this.score, this.avatarColor, this.rank);
}

class _Podium extends StatelessWidget {
  final List<_PlayerData> topThree;
  const _Podium({required this.topThree});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumCard(player: topThree[0], isFirst: false)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumCard(player: topThree[1], isFirst: true)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumCard(player: topThree[2], isFirst: false)),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final _PlayerData player;
  final bool isFirst;
  const _PodiumCard({required this.player, required this.isFirst});

  Color get _rankBadgeColor {
    switch (player.rank) {
      case 1:
        return AppTheme.blazeGold;
      case 2:
        return AppTheme.rankSilver;
      default:
        return AppTheme.rankBronze;
    }
  }

  String _ordinal(int n) {
    switch (n) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = isFirst ? 172.0 : 148.0;
    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: player.avatarColor.withAlpha(50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFirst ? AppTheme.blazeGold.withAlpha(120) : player.avatarColor.withAlpha(80),
          width: isFirst ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _rankBadgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${player.rank}${_ordinal(player.rank)}', style: AppTheme.rankBadge),
          ),
          const SizedBox(height: 6),
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: isFirst ? 26 : 22,
                backgroundColor: player.avatarColor,
                child: Text(
                  player.name[0],
                  style: AppTheme.podiumName.copyWith(fontSize: isFirst ? 22 : 18),
                ),
              ),
              if (isFirst)
                const Positioned(
                  bottom: -4,
                  child: Icon(Icons.emoji_events_rounded, color: AppTheme.blazeGold, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              player.name.split(' ').first,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.podiumName,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: AppTheme.blazeGold, size: 12),
              const SizedBox(width: 2),
              Text(player.score, style: AppTheme.podiumScore),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final _PlayerData player;
  const _PlayerRow({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${player.rank}', style: AppTheme.rankNumber),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: player.avatarColor,
            child: Text(
              player.name[0],
              style: AppTheme.playerName.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(player.name, style: AppTheme.playerName)),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppTheme.blazeGold, size: 16),
              const SizedBox(width: 4),
              Text(player.score, style: AppTheme.score),
            ],
          ),
        ],
      ),
    );
  }
}
