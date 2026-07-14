String formatPhoneForCall(String rawPhone) {
  // Strip spaces and other non-digits/non-plus characters
  String phone = rawPhone.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^\d+]'), '');
  
  if (phone.startsWith('+')) {
    phone = phone.substring(1);
  }
  if (phone.startsWith('91') && phone.length > 10) {
    phone = phone.substring(2);
  }
  if (phone.startsWith('0')) {
    phone = phone.substring(1);
  }
  
  return '+91$phone';
}
