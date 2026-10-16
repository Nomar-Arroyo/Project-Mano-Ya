import '../domain/auth_state.dart';
import '../../shared/models/user_role.dart';

class AuthRepository {
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  AuthState _state = const AuthState.unauthenticated();
  AuthState get state => _state;

  Future<AuthState> loginEmailPassword(
    String email,
    String password, {
    UserRole role = UserRole.client,
    bool twoFactorEnabled = false,
  }) async {
    // MOCK: simulacion de login
    await Future.delayed(const Duration(milliseconds: 600));
    _state = AuthState.authenticated(
      userId: 'mock_user',
      email: email,
      displayName: email.split('@').first,
      role: role,
      twoFactorEnabled: twoFactorEnabled,
    );
    return _state;
  }

  Future<AuthState> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    String? city,
  }) async {
    // MOCK: simulacion de registro con rol obligatorio
    await Future.delayed(const Duration(milliseconds: 700));
    _state = AuthState.authenticated(
      userId: 'mock_user',
      email: email,
      displayName: name,
      role: role,
      phone: phone,
      city: city,
    );
    return _state;
  }

  Future<AuthState> signInWithGoogle({required UserRole role}) async {
    // MOCK de Google Sign-In (no requiere credenciales reales por ahora)
    await Future.delayed(const Duration(milliseconds: 700));
    _state = AuthState.authenticated(
      userId: 'mock_google',
      email: 'usuario.mock@gmail.com',
      displayName: 'Usuario Mock',
      role: role,
    );
    return _state;
  }

  // Actualiza los datos editables del perfil.
  Future<AuthState> updateProfile({
    String? displayName,
    String? phone,
    String? city,
    String? avatarUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _state = _state.copyWith(
      displayName: displayName,
      phone: phone,
      city: city,
      avatarUrl: avatarUrl,
    );
    return _state;
  }

  // Activa o desactiva el segundo factor (2FA).
  Future<AuthState> setTwoFactor(bool enabled) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _state = _state.copyWith(twoFactorEnabled: enabled);
    return _state;
  }

  // Verifica el codigo 2FA. En modo mock acepta cualquier codigo de 6 digitos.
  Future<bool> verifyTwoFactor(String code) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return code.length == 6 && int.tryParse(code) != null;
  }

  Future<void> logout() async {
    // await _googleSignIn.signOut();
    _state = const AuthState.unauthenticated();
  }
}
