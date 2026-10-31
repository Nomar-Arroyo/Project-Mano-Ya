import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/supabase_storage_service.dart';
import '../../../../core/utils/local_image.dart';
import '../../../../core/utils/venezuelan_phone_input_formatter.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/city_autocomplete_field.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../workers/domain/worker_categories.dart';
import '../profile_provider.dart';

/// Edición del perfil: nombre, teléfono, ciudad, foto de avatar y bio.
///
/// La foto se sube al bucket público `avatars` de Supabase Storage cuando el
/// backend está configurado; en modo mock se conserva la ruta local del
/// archivo (solo móvil) o la URL temporal del navegador (web).
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bioCtrl;
  String? _cityName;
  String? _category;
  String? _subcategory;
  double? _latitude;
  double? _longitude;
  String? _avatarUrl;
  bool _saving = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(authStateProvider);
    _nameCtrl = TextEditingController(text: state.displayName ?? '');
    _phoneCtrl = TextEditingController(
      text: VenezuelanPhoneInputFormatter.formatNational(state.phone ?? ''),
    );
    _bioCtrl = TextEditingController();
    _cityName = state.city;
    _category = state.category;
    _subcategory = state.subcategory;
    _latitude = state.latitude;
    _longitude = state.longitude;
    _avatarUrl = state.avatarUrl;

    // La bio vive en el perfil extendido del trabajador.
    final profile = ref.read(workerProfileProvider);
    profile.whenData((data) {
      if (data.bio.isNotEmpty) _bioCtrl.text = data.bio;
      _category = data.category.isNotEmpty ? data.category : _category;
      _subcategory = data.subcategory.isNotEmpty
          ? data.subcategory
          : _subcategory;
      _latitude = data.latitude ?? _latitude;
      _longitude = data.longitude ?? _longitude;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  /// Elige una foto de la galería o de la cámara y la registra en el avatar.
  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked == null) return;

      final reference = await _storeAvatar(picked);
      if (reference == null) return;

      setState(() => _avatarUrl = reference);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo elegir la foto: $error')),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  /// Sube la foto a Supabase Storage o devuelve la referencia local.
  Future<String?> _storeAvatar(XFile picked) async {
    final userId = ref.read(currentUserIdProvider);

    if (SupabaseStorageService.isAvailable) {
      final bytes = await picked.readAsBytes();
      final url = await SupabaseStorageService.uploadImage(
        bytes: bytes,
        bucket: SupabaseStorageService.avatarsBucket,
        userId: userId,
        fileName: 'avatar.jpg',
      );
      if (url == null) {
        _showMessage('No se pudo subir la imagen a Supabase Storage.');
        return null;
      }
      return url;
    }

    // En móvil se conserva el archivo local; en web la URL temporal.
    if (supportsLocalFiles) return picked.path;
    return picked.path.startsWith('blob:') ? picked.path : null;
  }

  /// Guarda los cambios del perfil (datos de sesión, avatar y bio).
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final role = ref.read(authStateProvider).role;
    if (role == UserRole.worker &&
        (_category == null ||
            _subcategory == null ||
            _cityName?.trim().isEmpty != false ||
            _latitude == null ||
            _longitude == null)) {
      _showMessage(
        'Completa tu oficio, especialidad y selecciona la zona en las '
        'sugerencias para calcular distancias.',
      );
      return;
    }
    setState(() => _saving = true);

    try {
      await ref
          .read(authStateProvider.notifier)
          .updateProfile(
            displayName: _nameCtrl.text.trim(),
            phone: VenezuelanPhoneInputFormatter.formatInternational(
              _phoneCtrl.text,
            ),
            city: _cityName,
            avatarUrl: _avatarUrl,
          );
      if (role == UserRole.worker) {
        await ref
            .read(profileControllerProvider.notifier)
            .saveWorkerDetails(
              bio: _bioCtrl.text.trim(),
              category: _category!,
              subcategory: _subcategory!,
              latitude: _latitude,
              longitude: _longitude,
            );
      }
    } catch (error) {
      if (mounted) _showMessage('No se pudo guardar el perfil: $error');
      if (mounted) setState(() => _saving = false);
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    Navigator.of(context).pop();
  }

  /// Muestra un mensaje breve al usuario.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authStateProvider).role;
    final isWorker = role == UserRole.worker;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: UserAvatar(
                    imageUrl: _avatarUrl,
                    name: _nameCtrl.text,
                    radius: 44,
                    fallbackIcon: Icons.person,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _pickingImage ? null : _pickImage,
                    icon: _pickingImage
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera),
                    label: const Text('Cambiar foto'),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [VenezuelanPhoneInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '412 123 4567',
                    prefixText: '+58 ',
                  ),
                ),
                const SizedBox(height: 12),
                // Zona/ciudad con autocompletado geolocalizado.
                CityAutocompleteField(
                  initialText: _cityName,
                  onChanged: (value) => setState(() {
                    _cityName = value;
                    _latitude = null;
                    _longitude = null;
                  }),
                  onSelected: (place) {
                    _cityName = place.displayName;
                    _latitude = place.latitude;
                    _longitude = place.longitude;
                  },
                  onCleared: () {
                    _cityName = null;
                    _latitude = null;
                    _longitude = null;
                  },
                ),
                if (isWorker) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Oficio principal',
                    ),
                    items: WorkerCategories.categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Selecciona tu oficio principal' : null,
                    onChanged: (value) => setState(() {
                      _category = value;
                      _subcategory = null;
                    }),
                  ),
                  if (_category != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _subcategory,
                      decoration: const InputDecoration(
                        labelText: 'Especialidad',
                      ),
                      items: WorkerCategories.subcategories[_category]!
                          .map(
                            (subcategory) => DropdownMenuItem(
                              value: subcategory,
                              child: Text(subcategory),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Selecciona tu especialidad' : null,
                      onChanged: (value) =>
                          setState(() => _subcategory = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 4,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: 'Mi presentación (bio)',
                      hintText:
                          'Ej.: Maestro de obra con 15 años de experiencia '
                          'en mampostería y acabados.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: ManoYaColors.muted,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'La bio se muestra en tu ficha del catálogo y ayuda '
                          'a que te contraten.',
                          style: TextStyle(
                            fontSize: 12,
                            color: ManoYaColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
