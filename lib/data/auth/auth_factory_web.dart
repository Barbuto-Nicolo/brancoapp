import 'auth_service.dart';
import 'web_auth_service.dart';

/// Browser: login con Google Identity Services (token OAuth di 1 ora).
AuthService creaAuthService() => WebAuthService();
