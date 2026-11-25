import 'auth_service.dart';

/// Android e iOS: login nativo con la libreria google_sign_in.
AuthService creaAuthService() => GoogleAuthService();
