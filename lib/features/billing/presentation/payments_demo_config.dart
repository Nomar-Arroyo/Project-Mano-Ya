abstract final class PaymentsDemoConfig {
  static const bool _requested = bool.fromEnvironment(
    'PAYMENTS_DEMO',
    defaultValue: false,
  );

  static const bool enabled = _requested;
}
