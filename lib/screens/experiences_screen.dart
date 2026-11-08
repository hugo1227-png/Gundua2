import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/experiences_service.dart';
import '../services/place_service.dart';
import '../services/profile_service.dart';

class ExperiencesScreen extends StatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  State<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  static const Color background = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF111111);
  static const Color secondaryColor = Color(0xFF767676);
  static const Color accentColor = Color(0xFFFF5A5F);

  final ExperiencesService _service = ExperiencesService();
  List<Map<String, dynamic>> _experiences = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExperiences();
  }

  Future<void> _loadExperiences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final experiences = await _service.getExperiences();
      if (!mounted) return;
      setState(() {
        _experiences = experiences;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível carregar as experiências.';
        _isLoading = false;
      });
      debugPrint('Erro ao carregar experiências: $error');
    }
  }

  Future<void> _openCreateExperience() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateExperienceScreen()),
    );

    if (created == true && mounted) {
      await _loadExperiences();
    }
  }

  Future<void> _deleteExperience(Map<String, dynamic> experience) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Eliminar experiência?'),
        content: const Text('Esta ação não pode ser anulada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteExperience(experience);
      if (!mounted) return;
      await _loadExperiences();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Experiência eliminada.')));
    } catch (error) {
      if (!mounted) return;
      debugPrint('Erro ao eliminar experiência: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível eliminar a experiência.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: const Text(
          'As minhas experiências',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateExperience,
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: const Text('Partilhar experiência'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExperiences,
        color: accentColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.cloud_off_outlined, size: 48, color: secondaryColor),
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: secondaryColor),
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton(
              onPressed: _loadExperiences,
              child: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }

    if (_experiences.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 100, 28, 120),
        children: const [
          Icon(
            Icons.photo_camera_back_outlined,
            size: 58,
            color: secondaryColor,
          ),
          SizedBox(height: 18),
          Text(
            'As tuas experiências começam aqui',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Partilha um momento da tua viagem e associa-o ao lugar '
            'onde aconteceu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: secondaryColor),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: _experiences.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final experience = _experiences[index];
        return _ExperienceCard(
          experience: experience,
          onDelete: () => _deleteExperience(experience),
        );
      },
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.experience, required this.onDelete});

  final Map<String, dynamic> experience;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final encodedImage = experience['imageBase64']?.toString();
    Uint8List? imageBytes;

    if (encodedImage != null && encodedImage.isNotEmpty) {
      try {
        imageBytes = base64Decode(encodedImage);
      } on FormatException {
        imageBytes = null;
      }
    }

    final date = DateTime.tryParse(experience['createdAt']?.toString() ?? '');
    final dateLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageBytes != null)
            Image.memory(
              imageBytes,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        experience['title']?.toString() ??
                            'Experiência sem título',
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar experiência',
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFFF5A5F),
                      ),
                    ),
                  ],
                ),
                if ((experience['description']?.toString() ?? '')
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    experience['description'].toString(),
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      color: Color(0xFFFF5A5F),
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience['placeName']?.toString() ?? 'Lugar',
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            experience['placeLocation']?.toString() ?? '',
                            style: const TextStyle(
                              color: Color(0xFF767676),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ExperiencesService.getAuthorName(experience),
                        style: const TextStyle(
                          color: Color(0xFF767676),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: Color(0xFF767676),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateExperienceScreen extends StatefulWidget {
  const CreateExperienceScreen({super.key, this.initialPlace});

  final Map<String, dynamic>? initialPlace;

  @override
  State<CreateExperienceScreen> createState() => _CreateExperienceScreenState();
}

class _CreateExperienceScreenState extends State<CreateExperienceScreen> {
  static const Color background = Color(0xFFF8F9FA);
  static const Color textColor = Color(0xFF111111);
  static const Color secondaryColor = Color(0xFF767676);
  static const Color accentColor = Color(0xFFFF5A5F);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ExperiencesService _experiencesService = ExperiencesService();
  final PlaceService _placeService = PlaceService();
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();

  Map<String, dynamic>? _selectedPlace;
  List<Map<String, dynamic>> _placeResults = [];
  Uint8List? _imageBytes;
  bool _isSearching = false;
  bool _isSaving = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _selectedPlace = widget.initialPlace;
    if (_selectedPlace != null) {
      _placeController.text =
          _selectedPlace!['name']?.toString() ??
          _selectedPlace!['display_name']?.toString() ??
          '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    final query = _placeController.text.trim();
    if (query.length < 3) {
      setState(() {
        _searchError = 'Escreve pelo menos 3 caracteres.';
        _placeResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _selectedPlace = null;
    });

    try {
      final results = await _placeService.searchPlaces(query);
      if (!mounted) return;
      setState(() {
        _placeResults = results;
        _isSearching = false;
        if (results.isEmpty) {
          _searchError = 'Não foram encontrados lugares.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = 'Não foi possível pesquisar lugares.';
      });
      debugPrint('Erro ao pesquisar lugar para experiência: $error');
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.length > 700 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escolhe uma fotografia inferior a 700 KB.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Erro ao selecionar fotografia: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível selecionar a fotografia.'),
        ),
      );
    }
  }

  Future<void> _saveExperience() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesquisa e seleciona um lugar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final place = _selectedPlace!;
    final placeName = place['name']?.toString().trim().isNotEmpty == true
        ? place['name'].toString().trim()
        : (place['display_name']?.toString() ?? 'Lugar');
    final placeLocation = place['display_name']?.toString() ?? placeName;

    try {
      final profile = await _profileService.getProfile();
      final authorName = profile['name']?.trim();

      await _experiencesService.addExperience(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        placeName: placeName,
        placeLocation: placeLocation,
        authorName: authorName,
        imageBase64: _imageBytes == null ? null : base64Encode(_imageBytes!),
        place: place,
        placeId: ExperiencesService.getPlaceId(place),
        placeLatitude: (place['lat'] ?? place['latitude'])?.toString(),
        placeLongitude: (place['lon'] ?? place['longitude'])?.toString(),
        placeDisplayName: place['display_name']?.toString(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      debugPrint('Erro ao guardar experiência: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível guardar a experiência.'),
        ),
      );
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFEDEEEF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFEDEEEF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: textColor, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: const Text(
          'Nova experiência',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          children: [
            const Text(
              'Partilha um momento da tua viagem.',
              style: TextStyle(color: secondaryColor, fontSize: 15),
            ),
            const SizedBox(height: 22),
            const Text(
              'Título',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _decoration('Dá um título à tua experiência'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'O título é obrigatório.'
                  : null,
            ),
            const SizedBox(height: 18),
            const Text(
              'A tua experiência',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: _decoration('O que viveste neste lugar?'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'A descrição é obrigatória.'
                  : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'Associar a um lugar',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _placeController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchPlaces(),
                    decoration: _decoration('Ex.: Torre de Belém, Lisboa'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSearching ? null : _searchPlaces,
                  style: IconButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 8),
              Text(
                _searchError!,
                style: const TextStyle(color: accentColor, fontSize: 13),
              ),
            ],
            if (_placeResults.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEDEEEF)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _placeResults.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 14, endIndent: 14),
                  itemBuilder: (context, index) {
                    final place = _placeResults[index];
                    final displayName =
                        place['display_name']?.toString() ?? 'Lugar';
                    final name = place['name']?.toString().trim();
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: accentColor,
                      ),
                      title: Text(
                        name == null || name.isEmpty
                            ? displayName.split(',').first
                            : name,
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: secondaryColor,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPlace = place;
                          _placeResults = [];
                          _placeController.text = name == null || name.isEmpty
                              ? displayName
                              : name;
                        });
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
              ),
            ],
            if (_selectedPlace != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEDEEEF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedPlace!['display_name']?.toString() ??
                            _selectedPlace!['name']?.toString() ??
                            'Lugar selecionado',
                        style: const TextStyle(color: textColor, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _selectedPlace = null;
                        _placeController.clear();
                      }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Fotografia (opcional)',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(
                  _imageBytes!,
                  height: 190,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _imageBytes == null
                    ? 'Escolher fotografia'
                    : 'Alterar fotografia',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: const BorderSide(color: Color(0xFFEDEEEF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveExperience,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  _isSaving ? 'A publicar...' : 'Publicar experiência',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
