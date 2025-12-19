class Validators {
  static String? emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    // ignore: unused_local_variable
    final passwordRegex = RegExp(
      r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
    );

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!RegExp(r'(?=.*?[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'(?=.*?[a-z])').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'(?=.*?[0-9])').hasMatch(value)) {
      return 'Password must contain at least one digit';
    }

    if (!RegExp(r'(?=.*?[!@#\$&*~])').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  static String? confirmPasswordValidator(
    String? confirmPassword,
    String originalPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Confirm password is required';
    }

    if (confirmPassword != originalPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String? phoneNumberValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegExp = RegExp(r'^\d{10,15}$');
    if (!phoneRegExp.hasMatch(value)) {
      return 'Phone number must be between 10 and 15 digits';
    }
    return null;
  }

  static String? ageValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Age is required';
    }
    final RegExp ageRegex = RegExp(r'^(1[89]|[2-9]\d|\d{3,})$');
    if (!ageRegex.hasMatch(value)) {
      return 'Age must be grater than 18';
    }
    return null;
  }

  static String? nameValidator(String? value, String itemName) {
    if (value == null || value.isEmpty) {
      return '$itemName is required';
    }
    final nameRegExp = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegExp.hasMatch(value)) {
      return 'Name must contain only letters and spaces';
    }
    return null;
  }

  static String? staffCodeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Staff Code is required';
    }
    final nameRegExp = RegExp(r'^[a-zA-Z0-9\s]+$');
    if (!nameRegExp.hasMatch(value)) {
      return 'Staff Code must contain only numbers';
    }
    return null;
  }

  static String? dropdownValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a role';
    }
    return null;
  }

  static String? otpValidator(String? value) {
    if (value == null || value.isEmpty) {
      return "Please enter OTP";
    } else if (value.length < 6) {
      return "OTP must be 6 digits";
    } else if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return "Invalid OTP format";
    }
    return null; // Valid OTP
  }
}

class ProfileValidators {
  static String? emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!RegExp(r'(?=.*?[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'(?=.*?[a-z])').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'(?=.*?[0-9])').hasMatch(value)) {
      return 'Password must contain at least one digit';
    }

    if (!RegExp(r'(?=.*?[!@#\$&*~])').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  static String? confirmPasswordValidator(
    String? confirmPassword,
    String originalPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return null; // Allow empty for profile editing
    }

    if (confirmPassword != originalPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String? phoneNumberValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }
    final phoneRegExp = RegExp(r'^\d{10,15}$');
    if (!phoneRegExp.hasMatch(value)) {
      return 'Phone number must be between 10 and 15 digits';
    }
    return null;
  }

  static String? ageValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }
    final RegExp ageRegex = RegExp(r'^(1[89]|[2-9]\d|\d{3,})$');
    if (!ageRegex.hasMatch(value)) {
      return 'Age must be grater than 18';
    }
    return null;
  }

  static String? nameValidator(String? value, String itemName) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final nameRegExp = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegExp.hasMatch(value)) {
      return 'Name must contain only letters and spaces';
    }
    return null;
  }

  static String? staffCodeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }
    final nameRegExp = RegExp(r'^[a-zA-Z0-9\s]+$');
    if (!nameRegExp.hasMatch(value)) {
      return 'Staff Code must contain only numbers';
    }
    return null;
  }

  static String? dropdownValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }
    return null;
  }

  static String? otpValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }
    if (value.length < 6) {
      return "OTP must be 6 digits";
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return "Invalid OTP format";
    }
    return null;
  }

  static String? aadharValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty for profile editing
    }
    final aadharRegExp = RegExp(r'^\d{12}$');
    if (!aadharRegExp.hasMatch(value)) {
      return 'Aadhar number must be exactly 12 digits';
    }
    return null;
  }
}
