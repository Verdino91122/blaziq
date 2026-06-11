import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'lobby_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final raw = _controller.text.trim().toUpperCase();
    // Accept with or without the BLAZIQ- prefix
    final roomId = raw.startsWith('BLAZIQ-') ? raw : 'BLAZIQ-$raw';

    debugPrint('[JoinScreen] validating roomId: "$roomId" (length ${roomId.length})');

    // Valid format: BLAZIQ- followed by exactly 4 digits (11 chars total)
    if (!RegExp(r'^BLAZIQ-\d{4}$').hasMatch(roomId)) {
      setState(() => _error = 'Enter the full room code (e.g. BLAZIQ-4829).');
      return;
    }

    final user = AuthService.currentUser;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userData = await UserService.getUserData(user.uid);
      await RoomService.joinRoom(
        roomId: roomId,
        guest: user,
        guestData: userData ?? {},
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomId: roomId,
            myUid: user.uid,
            isHost: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.ink),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('JOIN A GAME', style: AppTheme.screenTitle),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Enter the room code shared by your friend.',
                style: AppTheme.bodyMuted,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Room code input
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.softGrey,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _error != null
                            ? AppTheme.blazeOrange
                            : AppTheme.deepGrey,
                        width: _error != null ? 1.5 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        UpperCaseTextFormatter(),
                        LengthLimitingTextInputFormatter(12),
                      ],
                      textAlign: TextAlign.center,
                      style: AppTheme.subheading.copyWith(
                        letterSpacing: 3,
                        fontSize: 22,
                      ),
                      decoration: InputDecoration(
                        hintText: 'BLAZIQ-XXXX',
                        hintStyle: AppTheme.bodyMuted.copyWith(
                          letterSpacing: 2,
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                      ),
                      onSubmitted: (_) => _join(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: AppTheme.bodyMuted
                          .copyWith(color: AppTheme.blazeOrange),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _loading ? null : _join,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _loading
                            ? AppTheme.electricBlue.withAlpha(120)
                            : AppTheme.electricBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text('JOIN ROOM', style: AppTheme.buttonLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    return next.copyWith(text: next.text.toUpperCase());
  }
}
