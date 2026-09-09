import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../dashboard/dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Used to validate all fields inside the Form.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Personal information controllers.
  final TextEditingController usernameController =
      TextEditingController();

  final TextEditingController firstNameController =
      TextEditingController();

  final TextEditingController lastNameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  // Emergency contact controllers.
  final TextEditingController emergencyNameController =
      TextEditingController();

  final TextEditingController emergencyPhoneController =
      TextEditingController();

  // Password controllers.
  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Default relationship selected in the dropdown.
  String selectedRelationship = 'Parent';

  // Dropdown options.
  final List<String> relationshipOptions = [
    'Parent',
    'Sibling',
    'Spouse',
    'Guardian',
    'Friend',
    'Other',
  ];

  // Controls the loading indicator.
  bool isLoading = false;

  // Controls whether passwords are visible.
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  Future<void> registerUser() async {
    // Close the phone keyboard.
    FocusScope.of(context).unfocus();

    // Check every validator inside the Form.
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final String username =
          usernameController.text.trim();

      final String firstName =
          firstNameController.text.trim();

      final String lastName =
          lastNameController.text.trim();

      final String email =
          emailController.text.trim();

      final String phoneNumber =
          phoneController.text.trim();

      final String emergencyName =
          emergencyNameController.text.trim();

      final String emergencyPhone =
          emergencyPhoneController.text.trim();

      final String password =
          passwordController.text.trim();

      // Step 1: Create the Firebase Authentication account.
      final UserCredential userCredential =
          await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to create the user account.');
      }

      // Step 2: Save the username as the Firebase display name.
      await user.updateDisplayName(username);

      // Refresh the Firebase user information.
      await user.reload();

      // Step 3: Save the complete user profile in Firestore.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'full_name': '$firstName $lastName',
        'email': email,
        'phone_number': phoneNumber,
        'emergency_contact': {
          'name': emergencyName,
          'relationship': selectedRelationship,
          'phone': emergencyPhone,
        },
        'role': 'hiker',
        'is_active': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully.'),
        ),
      );

      // Step 4: Open the hiker dashboard.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'An account already exists for this email.';
          break;

        case 'invalid-email':
          message =
              'Please enter a valid email address.';
          break;

        case 'weak-password':
          message =
              'The password is too weak. Use at least 6 characters.';
          break;

        case 'operation-not-allowed':
          message =
              'Email and password registration is not enabled.';
          break;

        default:
          message =
              e.message ?? 'Registration failed.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String? validateRequiredField(
    String? value,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName.';
    }

    return null;
  }

  String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username.';
    }

    if (value.trim().length < 3) {
      return 'Username must contain at least 3 characters.';
    }

    if (value.trim().length > 20) {
      return 'Username cannot exceed 20 characters.';
    }

    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }

    final RegExp emailPattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a phone number.';
    }

    // Remove spaces and hyphens before validation.
    final String phone =
        value.replaceAll(RegExp(r'[\s-]'), '');

    // Accepts Malaysian numbers starting with 01 or +601.
    final RegExp phonePattern = RegExp(
      r'^(01[0-9]{8,9}|\+601[0-9]{8,9})$',
    );

    if (!phonePattern.hasMatch(phone)) {
      return 'Enter a valid Malaysian phone number.';
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password.';
    }

    if (value.length < 6) {
      return 'Password must contain at least 6 characters.';
    }

    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }

    if (value != passwordController.text) {
      return 'The passwords do not match.';
    }

    return null;
  }

  @override
  void dispose() {
    usernameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF355E3B);
    const Color lightGreen = Color(0xFFEAF2E8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 70,
                  color: darkGreen,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Join Hiking App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Create your account to begin your hiking journey.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                sectionTitle(
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  backgroundColor: lightGreen,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: usernameController,
                  textInputAction: TextInputAction.next,
                  validator: validateUsername,
                  decoration: inputDecoration(
                    label: 'Username',
                    icon: Icons.person,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: firstNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization:
                      TextCapitalization.words,
                  validator: (value) =>
                      validateRequiredField(
                    value,
                    'first name',
                  ),
                  decoration: inputDecoration(
                    label: 'First Name',
                    icon: Icons.badge_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: lastNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization:
                      TextCapitalization.words,
                  validator: (value) =>
                      validateRequiredField(
                    value,
                    'last name',
                  ),
                  decoration: inputDecoration(
                    label: 'Last Name',
                    icon: Icons.badge_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  decoration: inputDecoration(
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: validatePhoneNumber,
                  decoration: inputDecoration(
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    hint: 'Example: 0123456789',
                  ),
                ),

                const SizedBox(height: 28),

                sectionTitle(
                  icon: Icons.emergency_outlined,
                  title: 'Emergency Contact',
                  backgroundColor: lightGreen,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: emergencyNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization:
                      TextCapitalization.words,
                  validator: (value) =>
                      validateRequiredField(
                    value,
                    'emergency contact name',
                  ),
                  decoration: inputDecoration(
                    label: 'Emergency Contact Name',
                    icon: Icons.contact_emergency_outlined,
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedRelationship,
                  decoration: inputDecoration(
                    label: 'Relationship',
                    icon: Icons.people_outline,
                  ),
                  items: relationshipOptions
                      .map(
                        (relationship) =>
                            DropdownMenuItem<String>(
                          value: relationship,
                          child: Text(relationship),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      selectedRelationship = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: validatePhoneNumber,
                  decoration: inputDecoration(
                    label: 'Emergency Contact Phone',
                    icon: Icons.phone_in_talk_outlined,
                    hint: 'Example: 0198765432',
                  ),
                ),

                const SizedBox(height: 28),

                sectionTitle(
                  icon: Icons.lock_outline,
                  title: 'Account Security',
                  backgroundColor: lightGreen,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  textInputAction: TextInputAction.next,
                  validator: validatePassword,
                  decoration: inputDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: hideConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: validateConfirmPassword,
                  onFieldSubmitted: (_) {
                    if (!isLoading) {
                      registerUser();
                    }
                  },
                  decoration: inputDecoration(
                    label: 'Confirm Password',
                    icon: Icons.lock_reset_outlined,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          hideConfirmPassword =
                              !hideConfirmPassword;
                        });
                      },
                      icon: Icon(
                        hideConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle({
    required IconData icon,
    required String title,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF355E3B),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF355E3B),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade400,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF355E3B),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }
}
Widget sectionTitle({
  required IconData icon,
  required String title,
  required Color backgroundColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF355E3B),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF355E3B),
          ),
        ),
      ],
    ),
  );
}
InputDecoration inputDecoration({
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Colors.grey.shade400,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Color(0xFF355E3B),
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
        width: 2,
      ),
    ),
  );
}