class WorkerCategories {
  const WorkerCategories._();

  static const Map<String, List<String>> subcategories = {
    'Construcción': ['Albañilería', 'Acabados', 'Remodelaciones'],
    'Belleza': ['Peluquería', 'Manicure', 'Cuidado personal'],
    'Costura': ['Confección', 'Arreglos', 'Diseño de prendas'],
    'Mantenimiento': ['Electricidad', 'Plomería', 'Mantenimiento general'],
    'Automotriz': ['Mecánica', 'Revisión vehicular', 'Mantenimiento vehicular'],
    'Eventos': ['Decoración', 'Organización de eventos'],
  };

  static List<String> get categories => subcategories.keys.toList();
}
