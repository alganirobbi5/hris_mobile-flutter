import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/profile_avatar_store.dart';
import '../theme/app_theme.dart';
import '../screens/profil_screen.dart';

class ProfileAvatarButton extends StatefulWidget {
  const ProfileAvatarButton({super.key, this.standalone = true});

  final bool standalone;

  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  String? _avatar;
  String _initials = '';

  @override
  void initState() {
    super.initState();
    _load();
    ProfileAvatarStore.revision.addListener(_load);
  }

  @override
  void dispose() {
    ProfileAvatarStore.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final int? userId = await AppSession.resolveUserId();
    final String? image = await ProfileAvatarStore.loadImage(userId);
    final String name = (AppSession.name ?? AppSession.username ?? '').trim();
    final List<String> parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final String initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
                .toUpperCase();
    if (!mounted) return;
    setState(() {
      _avatar = image;
      _initials = initials;
    });
  }

  Widget _avatarContent() {
    final String? value = _avatar;
    if (value != null && value.isNotEmpty) {
      if (value.startsWith('data:image/')) {
        final int comma = value.indexOf(',');
        if (comma > 0) {
          try {
            return Image.memory(
              base64Decode(value.substring(comma + 1)),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(_initials),
            );
          } catch (_) {
            return Text(_initials);
          }
        }
      }
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Text(_initials),
      );
    }
    return Text(_initials);
  }

  @override
  Widget build(BuildContext context) {
    final Widget badge = Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: 'Profil',
        child: InkWell(
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ProfilScreen(),
              ),
            );
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface.withValues(alpha: 0.92),
              border: Border.all(color: AppColors.border, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
              child: _avatarContent(),
            ),
          ),
        ),
      ),
    );
    if (!widget.standalone) return badge;
    final double top = MediaQuery.of(context).padding.top;
    return Positioned(top: top + 10, right: 16, child: badge);
  }
}
