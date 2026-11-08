import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/experiences_service.dart';
import '../services/profile_service.dart';
import '../services/location_service.dart';
import '../services/recently_viewed_service.dart';
import '../services/visited_places_service.dart';
import 'experiences_screen.dart';
import '../theme/gundua_theme.dart';
import 'welcome_get_started_screen.dart';

/// Profile inspired by TheFork's approachable account hierarchy, with
/// GUNDUA's visited places, local contributions and travel interests.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _ink = GunduaTheme.ink;
  static const _accent = GunduaTheme.accent;
  static const _muted = GunduaTheme.muted;

  final _service = ProfileService();
  Map<String, String> _profile = {};
  int _visitedCount = 0;
  int _experienceCount = 0;
  int _recentCount = 0;
  bool _notifications = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final profile = await _service.getProfile();
      final visited = await VisitedPlacesService().getVisitedPlaces();
      final experiences = await ExperiencesService().getExperiences();
      final recent = await RecentlyViewedService().getRecentlyViewed();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _visitedCount = visited.length;
        _experienceCount = experiences.length;
        _recentCount = recent.length;
        _notifications = prefs.getBool('gundua_notifications_preference') ?? false;
      });
    } catch (error) {
      if (mounted) _message('Não foi possível atualizar o perfil.');
    }
  }

  String get _name => _profile['name'] ?? 'Viajante';
  String get _username {
    final saved = _profile['username'] ?? '';
    if (saved.isNotEmpty) return '@$saved';
    final email = _profile['email'] ?? '';
    return email.contains('@') ? '@${email.split('@').first}' :'E-mail';
  }

  Uint8List? get _avatar {
    final raw = _profile['avatar'] ?? '';
    if (raw.isEmpty) return null;
    try { return base64Decode(raw); } catch (_) { return null; }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 540, imageQuality: 68,
      );
      if (picked == null) return;
      final data = await picked.readAsBytes();
      if (data.lengthInBytes > 750000) {
        _message('Escolhe uma fotografia mais pequena (até 750 KB).');
        return;
      }
      await _service.updateProfile(
        name: _name,
        bio: _profile['bio'] ?? '',
        location: _profile['location'] ?? '',
        avatarBase64: base64Encode(data),
      );
      await _refresh();
    } catch (error) {
      if (mounted) _message('Não foi possível guardar a fotografia.');
    }
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _name);
    final username = TextEditingController(text: _profile['username'] ?? '');
    final bio = TextEditingController(text: _profile['bio'] ?? '');
    final location = TextEditingController(text: _profile['location'] ?? '');
    final interests = TextEditingController(text: _profile['interests'] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Editar perfil'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(name, 'Nome'),
            _field(username, 'Nome de utilizador'),
            _field(bio, 'Biografia', lines: 2),
            _field(location, 'Cidade / localização no perfil'),
            _field(interests, 'Interesses de viagem', lines: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (saved == true) {
      try {
        await _service.updateProfile(
          name: name.text,
          username: username.text,
          bio: bio.text,
          location: location.text,
          interests: interests.text,
        );
        await _refresh();
      } catch (error) {
        if (mounted) _message('Não foi possível guardar as alterações.');
      }
    }
    // Disposing after the dialog transition avoids disposed controllers while
    // the closing route is still animating.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      name.dispose(); username.dispose(); bio.dispose();
      location.dispose(); interests.dispose();
    });
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  void _infoPage(String title, String message) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: GunduaTheme.canvas,
        appBar: AppBar(title: Text(title)),
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, style: const TextStyle(fontSize: 15, height: 1.6)),
        )),
      ),
    ));
  }

  void _account() => _infoPage(
    'Informações pessoais',
    'Email: ${_profile['email'] ?? 'Não definido'}\n'
    'Cidade: ${(_profile['location'] ?? '').isEmpty ? 'Por definir' : _profile['location']}',
  );

  void _privacy() => _infoPage(
    'Privacidade e segurança',
    '...',
  );

  Future<void> _settings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Preferências', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SwitchListTile.adaptive(
                title: const Text('Notificações'),
                // A preferência de notificações é guardada localmente.
                value: _notifications,
                onChanged: (value) async {
                  await prefs.setBool('gundua_notifications_preference', value);
                  if (!mounted) return;
                  setState(() => _notifications = value);
                  update(() {});
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _help() => _infoPage(
    'Ajuda',
    '..'
  );

  Future<void> _openExperiences() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ExperiencesScreen()),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _logout() async {
    await _service.signOut();
    await LocationPreferenceService().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeGetStartedScreen()),
      (_) => false,
    );
  }

  Widget _stat(int count, String title, IconData icon) => Expanded(
    child: Column(children: [
      Icon(icon, color: _accent, size: 22),
      const SizedBox(height: 7),
      Text('$count', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
      Text(title, style: const TextStyle(fontSize: 11, color: _muted)),
    ]),
  );

  Widget _menu(String title, List<_ProfileAction> actions) => Padding(
    padding: const EdgeInsets.only(top: 30),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 20,
          fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 12),
      for (final action in actions) ...[
        ListTile(
          minLeadingWidth: 28,
          contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
          leading: Icon(action.icon, color: _ink, size: 23),
          title: Text(action.label, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: _ink)),
          trailing: const Icon(Icons.chevron_right_rounded, color: _ink),
          onTap: action.onTap,
        ),
        const SizedBox(height: 2),
      ],
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar;
    final interestText = _profile['interests'] ?? '';
    final interests = interestText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: GunduaTheme.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 27, 22, 148),
            children: [
              const Text('O teu perfil', style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.8, color: _ink)),
              const SizedBox(height: 21),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(GunduaTheme.cardRadius)),
                child: Column(children: [
                  Row(children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(38),
                      onTap: _pickAvatar,
                      child: Stack(children: [
                        CircleAvatar(
                          radius: 37,
                          backgroundColor: const Color(0xFFE8E9F0),
                          backgroundImage: avatar == null ? null : MemoryImage(avatar),
                          child: avatar == null ? Text(
                            _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28, color: _ink,
                                fontWeight: FontWeight.bold)) : null,
                        ),
                        const Positioned(bottom: 0, right: 0,
                          child: CircleAvatar(radius: 12, backgroundColor: _ink,
                            child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 13))),
                   ]),
                    ),
                    const SizedBox(width: 17),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name, style: const TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w800, color: _ink)),
                        const SizedBox(height: 3),
                        Text(_username, style: const TextStyle(fontSize: 13, color: _muted)),
                        const SizedBox(height: 5),
                        Text(_profile['bio'] ?? '',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: _muted)),
                      ],
                    )),
               ]),
                  const SizedBox(height: 17),
                  SizedBox(width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Editar perfil'),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 17),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 19),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(GunduaTheme.cardRadius)),
                child: Row(children: [
                  _stat(_recentCount, 'Descobertos', Icons.explore_outlined),
                  _stat(_visitedCount, 'Visitados', Icons.place_outlined),
                  _stat(_experienceCount, 'Partilhas', Icons.photo_library_outlined),
                ]),
              ),
              if (interests.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Interesses',
                    style: TextStyle(fontSize: 18, color: _ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 16, runSpacing: 8,
                  children: interests.map((item) => Text(item, style: const TextStyle(color: _muted))).toList()),
              ],
              _menu('As minhas experiências', [
                _ProfileAction(
                  Icons.photo_library_outlined,
                  'Ver experiências',
                  _openExperiences,
                ),
              ]),
              _menu('Sobre ti', [
                _ProfileAction(Icons.person_outline, 'Informações pessoais', _account),
                _ProfileAction(Icons.settings_outlined, 'Definições e notificações', _settings),
                _ProfileAction(Icons.lock_outline, 'Privacidade e segurança', _privacy),
              ]),
              _menu('Centro de ajuda', [
                _ProfileAction(Icons.help_outline, 'Obter apoio', _help),
              ]),
              const SizedBox(height: 26),
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: _accent),
                label: const Text('Terminar sessão', style: TextStyle(color: _accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAction {
  const _ProfileAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
