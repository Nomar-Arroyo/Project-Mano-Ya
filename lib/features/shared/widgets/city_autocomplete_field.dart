import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/maps_service.dart';

/// Campo de texto con autocompletado de zonas/ciudades geolocalizadas.
///
/// Consulta [MapsService] mientras el usuario escribe (con "debounce") y
/// muestra sugerencias seleccionables. Al elegir una, entrega un [Place]
/// con nombre y coordenadas para filtrar u ordenar trabajadores cercanos.
class CityAutocompleteField extends StatefulWidget {
  final String label;
  final String? hintText;
  final String? helperText;
  final String? initialText;
  final ValueChanged<Place> onSelected;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCleared;

  const CityAutocompleteField({
    super.key,
    this.label = 'Ciudad/zona',
    this.hintText,
    this.helperText,
    this.initialText,
    required this.onSelected,
    this.onChanged,
    this.onCleared,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _link = LayerLink();

  Timer? _debounce;
  List<Place> _suggestions = const [];
  bool _loading = false;
  String? _errorMessage;
  int _requestId = 0;

  // Evita relanzar la búsqueda cuando cambiamos el texto por código.
  bool _suppress = false;

  // Ancho real del campo, usado para dimensionar el panel de sugerencias.
  double _fieldWidth = 280;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _controller.text = widget.initialText!;
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_suppress) return;
    final text = _controller.text.trim();
    widget.onChanged?.call(text);

    if (text.length < 3) {
      _debounce?.cancel();
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      if (_overlayController.isShowing) _overlayController.hide();
      if (text.isEmpty) widget.onCleared?.call();
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await MapsService.autocomplete(text);
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
      if (results.isNotEmpty && !_overlayController.isShowing) {
        _overlayController.show();
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'city autocomplete',
          context: ErrorDescription('while searching for a city or zone'),
        ),
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _errorMessage = 'No se pudo buscar la zona. Inténtalo nuevamente.';
      });
    }
  }

  void _select(Place place) {
    _suppress = true;
    _controller.text = place.displayName;
    _controller.selection = TextSelection.collapsed(
      offset: place.displayName.length,
    );
    _suppress = false;
    if (_overlayController.isShowing) _overlayController.hide();
    setState(() => _suggestions = const []);
    FocusScope.of(context).unfocus();
    widget.onSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _fieldWidth = constraints.maxWidth;
        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: _buildOverlay,
            child: TextField(
              controller: _controller,
              onTap: () {
                if (_suggestions.isNotEmpty && !_overlayController.isShowing) {
                  _overlayController.show();
                }
              },
              decoration: InputDecoration(
                labelText: widget.label,
                hintText:
                    widget.hintText ?? 'Escribe ciudad, parroquia o sector',
                helperText: _errorMessage == null ? widget.helperText : null,
                errorText: _errorMessage,
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    return Positioned(
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        showWhenUnlinked: false,
        child: SizedBox(
          width: _fieldWidth,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 18),
                    title: Text(
                      place.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _select(place),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
