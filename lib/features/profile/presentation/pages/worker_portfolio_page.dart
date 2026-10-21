import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/supabase_storage_service.dart';
import '../../../../core/utils/local_image.dart';
import '../../../shared/widgets/app_image.dart';
import '../profile_provider.dart';

/// Pantalla de portafolio express del trabajador.
///
/// El mega-prompt define un portafolio de 3 a 5 fotos de trabajos previos.
/// Cada imagen se sube al bucket público `portfolios` de Supabase Storage; si
/// el backend no está configurado se conserva la ruta local del archivo
/// (solo disponible en móvil) para no perder la funcionalidad.
class WorkerPortfolioPage extends ConsumerStatefulWidget {
  const WorkerPortfolioPage({super.key});

  @override
  ConsumerState<WorkerPortfolioPage> createState() =>
      _WorkerPortfolioPageState();
}

class _WorkerPortfolioPageState extends ConsumerState<WorkerPortfolioPage> {
  /// Número mínimo de fotos exigido por el mega-prompt.
  static const int minPhotos = 3;

  /// Número máximo de fotos admitido por el portafolio express.
  static const int maxPhotos = 5;

  bool _working = false;

  /// Muestra el diálogo para describir la foto antes de elegirla.
  Future<String?> _askCaption() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Describe tu trabajo'),
        content: TextField(
          controller: controller,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Ej.: Reparación de lavadora en Granada',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  /// Permite elegir entre la cámara y la galería del dispositivo.
  Future<ImageSource?> _askSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    return source;
  }

  /// Añade una foto al portafolio: elige imagen, la sube y la registra.
  Future<void> _addPhoto() async {
    final portfolio = await ref.read(portfolioProvider.future);
    if (portfolio.length >= maxPhotos) {
      _showMessage(
        'El portafolio admite máximo $maxPhotos fotos. '
        'Elimina una para agregar otra.',
      );
      return;
    }

    final caption = await _askCaption();
    if (!mounted || caption == null) return;

    final source = await _askSource();
    if (!mounted || source == null) return;

    setState(() => _working = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked == null) return;

      final reference = await _storeImage(picked);
      if (reference == null) return;

      await ref
          .read(profileControllerProvider.notifier)
          .addPortfolioImage(imageUrl: reference, caption: caption);
      ref.invalidate(portfolioProvider);
    } catch (error) {
      _showMessage('No se pudo guardar la foto: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Sube la imagen a Storage o, si no hay backend, devuelve la ruta local.
  Future<String?> _storeImage(XFile picked) async {
    final userId = ref.read(currentUserIdProvider);

    if (SupabaseStorageService.isAvailable) {
      final bytes = await picked.readAsBytes();
      final url = await SupabaseStorageService.uploadImage(
        bytes: bytes,
        bucket: SupabaseStorageService.portfoliosBucket,
        userId: userId,
        fileName: 'portafolio.jpg',
      );
      if (url == null) {
        _showMessage('No se pudo subir la imagen a Supabase Storage.');
        return null;
      }
      return url;
    }

    // Sin backend se conserva el archivo local (solo móvil).
    if (supportsLocalFiles) return picked.path;

    _showMessage(
      'Configura las credenciales de Supabase para subir el portafolio '
      'desde la web.',
    );
    return null;
  }

  /// Elimina una foto del portafolio.
  Future<void> _removePhoto(String itemId, String imageUrl) async {
    await ref
        .read(profileControllerProvider.notifier)
        .removePortfolioImage(itemId);
    ref.invalidate(portfolioProvider);

    // Si la imagen vivía en Supabase Storage se elimina el archivo físico.
    final path = SupabaseStorageService.pathFromPublicUrl(
      url: imageUrl,
      bucket: SupabaseStorageService.portfoliosBucket,
    );
    if (path != null) {
      await SupabaseStorageService.deleteFile(
        bucket: SupabaseStorageService.portfoliosBucket,
        path: path,
      );
    }
  }

  /// Muestra un mensaje breve al usuario.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Portafolio express')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _working ? null : _addPhoto,
        icon: _working
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo_outlined),
        label: const Text('Agregar foto'),
      ),
      body: portfolio.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudo cargar el portafolio: $error')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Muestra tus mejores trabajos',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agrega entre $minPhotos y $maxPhotos fotos reales de '
                      'servicios que hayas realizado. Los clientes confían '
                      'más cuando ven resultados.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (items.length / maxPhotos).clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${items.length} de $maxPhotos fotos',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (items.length < minPhotos) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: ManoYaColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Agrega al menos $minPhotos fotos para que tu '
                              'perfil aparezca como completo.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ManoYaColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Card(
                color: surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tu portafolio está vacío',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Toca "Agregar foto" para subir imágenes de tus '
                        'trabajos realizados.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AppImage(imageUrl: item.imageUrl),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(32, 32),
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Eliminar foto',
                                  onPressed: () =>
                                      _removePhoto(item.id, item.imageUrl),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            item.caption.isEmpty
                                ? 'Trabajo realizado'
                                : item.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}
