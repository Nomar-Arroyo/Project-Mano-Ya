import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/maps_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../requests/presentation/pages/request_form_page.dart';
import '../../../shared/widgets/city_autocomplete_field.dart';
import '../../../shared/models/user_role.dart';
import '../../data/recommendation_repository.dart';
import '../../domain/worker_recommendation.dart';

class RecommendWorkersPage extends ConsumerStatefulWidget {
  const RecommendWorkersPage({super.key});

  @override
  ConsumerState<RecommendWorkersPage> createState() =>
      _RecommendWorkersPageState();
}

class _RecommendWorkersPageState extends ConsumerState<RecommendWorkersPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _repository = RecommendationRepository();

  String? _cityName;
  Place? _origin;
  WorkerRecommendationResult? _result;
  String? _errorMessage;
  bool _loading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente de Mano Ya')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cuéntanos qué necesitas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Te ayudaremos a encontrar trabajadores reales del catálogo. '
            'Evita incluir contraseñas, datos de pago u otra información privada.',
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: '¿Qué trabajo necesitas?',
                    hintText: 'Ej.: Necesito reparar una fuga en la cocina',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Describe brevemente el trabajo';
                    }
                    if (value.trim().length > 2000) {
                      return 'Usa un máximo de 2000 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CityAutocompleteField(
                  label: 'Ciudad o zona',
                  helperText:
                      'Selecciona una sugerencia para calcular distancia.',
                  initialText: _cityName,
                  onSelected: (place) => setState(() {
                    _cityName = place.displayName;
                    _origin = place;
                    _errorMessage = null;
                  }),
                  onChanged: (value) => setState(() {
                    _cityName = value;
                    _origin = null;
                  }),
                  onCleared: () => setState(() {
                    _cityName = null;
                    _origin = null;
                  }),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _loading ? 'Buscando...' : 'Buscar recomendaciones',
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _MessageCard(
              icon: Icons.error_outline,
              color: ManoYaColors.danger,
              message: _errorMessage!,
            ),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 20),
            if (result.clarificationRequired) ...[
              _MessageCard(
                icon: Icons.help_outline,
                color: ManoYaColors.info,
                message:
                    '${result.question ?? '¿Podrías contarme un poco más sobre el oficio que necesitas?'} '
                    'Agrega esa información a tu descripción y vuelve a consultar.',
              ),
            ] else if (result.recommendations.isEmpty) ...[
              _MessageCard(
                icon: Icons.search_off,
                color: ManoYaColors.muted,
                message:
                    result.message ??
                    'No encontramos trabajadores para esa necesidad. '
                        'Prueba con otra descripción o ciudad.',
              ),
            ] else ...[
              Text(
                'Opciones encontradas'
                '${result.category == null ? '' : ' · ${result.category}'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final recommendation in result.recommendations) ...[
                _RecommendationCard(recommendation: recommendation),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final origin = _origin;
    final city = _cityName;
    if (origin == null || city == null) {
      setState(() {
        _errorMessage =
            'Selecciona una ciudad o zona de la lista para calcular la '
            'distancia real de los trabajadores.';
        _result = null;
      });
      return;
    }
    final auth = ref.read(authStateProvider);
    if (!auth.isAuthenticated) {
      setState(() {
        _errorMessage = 'Inicia sesión para usar el asistente.';
        _result = null;
      });
      return;
    }
    if (auth.role != UserRole.client) {
      setState(() {
        _errorMessage =
            'El asistente de recomendaciones está disponible para clientes.';
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _repository.recommend(
        description: _descriptionController.text,
        city: city,
        latitude: origin.latitude,
        longitude: origin.longitude,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on FunctionException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _functionErrorMessage(error));
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No pudimos consultar las recomendaciones. '
            'Revisa tu conexión e inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _functionErrorMessage(FunctionException error) {
    return switch (error.status) {
      401 => 'Tu sesión no es válida. Inicia sesión nuevamente.',
      429 => 'Alcanzaste el límite de recomendaciones por hora. Inténtalo más tarde.',
      502 || 503 => 'El asistente no está disponible en este momento. Puedes buscar trabajadores en el catálogo.',
      _ => 'No pudimos procesar la búsqueda. Inténtalo de nuevo o usa el catálogo.',
    };
  }
}

class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({required this.recommendation});

  final WorkerRecommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = recommendation.worker;
    final clientName = ref.watch(authStateProvider).displayName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: ManoYaColors.primary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.handyman_outlined,
                    color: ManoYaColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          worker.subcategory.isEmpty
                              ? worker.category
                              : '${worker.category} · ${worker.subcategory}',
                          worker.city,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(recommendation.reason),
            if (worker.reviewsCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 18, color: ManoYaColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '${worker.rating.toStringAsFixed(1)} '
                    '(${worker.reviewsCount} reseñas)',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/worker/${worker.id}'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Ver perfil'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RequestFormPage(
                        workerId: worker.id,
                        workerName: worker.name,
                        workerCategory: worker.category,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Solicitar'),
                ),
                if (worker.phone?.isNotEmpty == true)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final message = WhatsAppService.buildMessage(
                        workerName: worker.name,
                        category: worker.category,
                        subcategory: worker.subcategory,
                        city: worker.city,
                        clientName: clientName,
                      );
                      final opened = await WhatsAppService.openChat(
                        phone: worker.phone!,
                        message: message,
                      );
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se pudo abrir WhatsApp en este dispositivo',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(message),
      ),
    );
  }
}
