import '../domain/auth_state.dart';
import '../../shared/models/user_role.dart';

class AuthRepository {
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  AuthState _state = const AuthState.unauthenticated();
  AuthState get state => _state;

  Future<AuthState> loginEmailPassword(String email, String password) async {
    // MOCK: simulaciÃ³n de login
    await Future.delayed(const Duration(milliseconds: 600));
    _state = AuthState.authenticated(
      userId: 'mock_user',
      email: email,
      displayName: email.split('@').first,
      role: UserRole.client,
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
    // MOCK: simulaciÃ³n de registro con rol obligatorio
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

  Future<void> logout() async {
    // await _googleSignIn.signOut();
    _state = const AuthState.unauthenticated();
  }
}
