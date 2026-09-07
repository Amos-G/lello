class UsernameValidationResult {
  final bool isValid;
  final String? errorMessage;

  const UsernameValidationResult({required this.isValid, this.errorMessage});

  static UsernameValidationResult validate(String input) {
    final sanitized = input.trim();
    if (sanitized.isEmpty) {
      return const UsernameValidationResult(
        isValid: false,
        errorMessage: 'Inserisci un nome utente',
      );
    }
    if (sanitized.length < 3) {
      return const UsernameValidationResult(
        isValid: false,
        errorMessage: 'Il nome utente deve contenere almeno 3 caratteri',
      );
    }
    if (sanitized.length > 30) {
      return const UsernameValidationResult(
        isValid: false,
        errorMessage: 'Il nome utente non può superare i 30 caratteri',
      );
    }
    final validChars = RegExp(r'^[a-zA-Z0-9_.-]+$');
    if (!validChars.hasMatch(sanitized)) {
      return const UsernameValidationResult(
        isValid: false,
        errorMessage:
            'Il nome utente può contenere solo lettere, numeri, punti, trattini e underscore',
      );
    }
    return const UsernameValidationResult(isValid: true);
  }
}

class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSymbol;
  final bool isNotCommon;
  final bool doesNotContainUsername;

  const PasswordValidationResult({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSymbol,
    required this.isNotCommon,
    required this.doesNotContainUsername,
  });

  bool get isValid =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      hasSymbol &&
      isNotCommon &&
      doesNotContainUsername;

  String? get errorMessage {
    if (!hasMinLength) return 'La password deve avere almeno 8 caratteri';
    if (!hasUppercase) {
      return 'La password deve contenere almeno una lettera maiuscola';
    }
    if (!hasLowercase) {
      return 'La password deve contenere almeno una lettera minuscola';
    }
    if (!hasDigit) return 'La password deve contenere almeno un numero';
    if (!hasSymbol) {
      return 'La password deve contenere almeno un simbolo speciale';
    }
    if (!doesNotContainUsername) {
      return 'La password non può contenere il tuo nome utente';
    }
    if (!isNotCommon) {
      return 'Questa password è troppo comune o facilmente indovinabile';
    }
    return null;
  }

  static const Set<String> _commonPasswords = {
    '12345678',
    '123456789',
    '1234567890',
    'password',
    'password1',
    'password123',
    'password123!',
    'password!',
    'admin123',
    'admin123!',
    'qwerty123',
    'qwerty1234',
    'qwertyuiop',
    'iloveyou',
    'sunshine',
    'welcome1',
    'welcome123',
    'welcome123!',
    'letmein123',
    'superadmin',
    'partysync',
    'partysync123!',
    'lello123',
    'lello2024',
    'lello2025',
    'lello2026',
    'lello123!',
    'principessa',
    'juventus',
    'cambiami',
    'cambiami123!',
    'ciaociao',
    'ciaociao1!',
  };

  static PasswordValidationResult validate(
    String password, {
    String? username,
  }) {
    final trimmed = password.trim();
    final hasMinLength = trimmed.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(trimmed);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(trimmed);
    final hasDigit = RegExp(r'[0-9]').hasMatch(trimmed);
    final hasSymbol = RegExp(r'[^a-zA-Z0-9\s]').hasMatch(trimmed);

    final normalized = trimmed.toLowerCase();
    final isNotCommon = !_commonPasswords.contains(normalized);

    var doesNotContainUsername = true;
    if (username != null && username.trim().length >= 3) {
      final normUser = username.trim().toLowerCase();
      if (normalized.contains(normUser)) {
        doesNotContainUsername = false;
      }
    }

    return PasswordValidationResult(
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasDigit: hasDigit,
      hasSymbol: hasSymbol,
      isNotCommon: isNotCommon,
      doesNotContainUsername: doesNotContainUsername,
    );
  }
}
