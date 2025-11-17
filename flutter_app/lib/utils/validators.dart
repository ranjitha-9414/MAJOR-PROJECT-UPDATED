bool isValidEmail(String email) {
  final re = RegExp(r"^[\w-.]+@([\w-]+\.)+[\w-]{2,4}");
  return re.hasMatch(email);
}

bool isValidPassword(String p) {
  return p.length >= 6;
}

bool isValidPhone(String p) {
  final digits = p.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 7 && digits.length <= 15;
}

String normalizePhone(String p) {
  return p.replaceAll(RegExp(r'\D'), '');
}
