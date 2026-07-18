import '../constants/app_constants.dart';

class Validators {
  Validators._();

  static String? validateRequired(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Invalid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < AppConstants.passwordMinLength) {
      return 'Password must be at least ${AppConstants.passwordMinLength} characters';
    }
    if (value.length > AppConstants.passwordMaxLength) {
      return 'Password must not exceed ${AppConstants.passwordMaxLength} characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  static String? validateIpAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IP address is required';
    }
    final ipRegex = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
    );
    final match = ipRegex.firstMatch(value.trim());
    if (match == null) return 'Invalid IP address format';
    for (int i = 1; i <= 4; i++) {
      final octet = int.tryParse(match.group(i)!);
      if (octet == null || octet < 0 || octet > 255) {
        return 'Invalid IP address format';
      }
    }
    return null;
  }

  static String? validateMacAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'MAC address is required';
    }
    final macRegex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
    );
    if (!macRegex.hasMatch(value.trim())) {
      return 'Invalid MAC address format (e.g., AA:BB:CC:DD:EE:FF)';
    }
    return null;
  }

  static String? validateHostname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Hostname is required';
    }
    final hostnameRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$',
    );
    if (!hostnameRegex.hasMatch(value.trim())) {
      return 'Invalid hostname format';
    }
    return null;
  }

  static String? validatePort(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Port is required';
    }
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Port must be between 1 and 65535';
    }
    return null;
  }

  static String? validateSubnet(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Subnet is required';
    }
    final subnetRegex = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$',
    );
    final match = subnetRegex.firstMatch(value.trim());
    if (match == null) return 'Invalid subnet format (e.g., 192.168.1.0/24)';
    for (int i = 1; i <= 4; i++) {
      final octet = int.tryParse(match.group(i)!);
      if (octet == null || octet < 0 || octet > 255) {
        return 'Invalid subnet format';
      }
    }
    final prefix = int.tryParse(match.group(5)!);
    if (prefix == null || prefix < 1 || prefix > 32) {
      return 'Invalid subnet prefix (must be /1 to /32)';
    }
    return null;
  }

  static String? validateVlan(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'VLAN ID is required';
    }
    final vlan = int.tryParse(value.trim());
    if (vlan == null || vlan < 1 || vlan > 4094) {
      return 'VLAN ID must be between 1 and 4094';
    }
    return null;
  }
}
