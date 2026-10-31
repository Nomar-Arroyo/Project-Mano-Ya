class BillableJob {
  const BillableJob({
    required this.id,
    required this.title,
    required this.clientId,
    required this.clientName,
    required this.workerId,
    required this.workerName,
    required this.price,
    required this.status,
  });

  final String id;
  final String title;
  final String clientId;
  final String clientName;
  final String workerId;
  final String workerName;
  final double price;
  final String status;

  factory BillableJob.fromJson(Map<String, dynamic> json) {
    final price = json['price'];
    if (price is! num) {
      throw const FormatException('El monto del trabajo no es válido.');
    }

    return BillableJob(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      clientId: _requiredString(json, 'client_id'),
      clientName: _displayName(json['client_name'], 'Cliente'),
      workerId: _requiredString(json, 'worker_id'),
      workerName: _displayName(json['worker_name'], 'Trabajador'),
      price: price.toDouble(),
      status: _requiredString(json, 'status'),
    );
  }

  static String _displayName(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('El campo "$key" del trabajo no es válido.');
    }
    return value;
  }
}
