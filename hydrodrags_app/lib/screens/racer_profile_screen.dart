import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/app_state_service.dart';
import '../services/auth_service.dart';
import '../services/racer_service.dart';
import '../services/error_handler_service.dart';
import '../widgets/language_toggle.dart';
import '../widgets/step_progress_indicator.dart';
import '../models/racer_profile.dart';
import '../utils/phone_formatter.dart';
import '../l10n/app_localizations.dart';

class RacerProfileScreen extends StatefulWidget {
  const RacerProfileScreen({super.key});

  @override
  State<RacerProfileScreen> createState() => _RacerProfileScreenState();
}

class _RacerProfileScreenState extends State<RacerProfileScreen> {
  int _currentStep = 0;
  int _currentFieldInStep = 0; // Track which field we're on in the current step
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();
  final _step4FormKey = GlobalKey<FormState>();

  // Step 1 controllers and focus nodes
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  DateTime? _selectedDate;
  String? _gender;
  File? _profileImage; // Selected profile image file
  final ImagePicker _imagePicker = ImagePicker();

  // Step 2 controllers and focus nodes
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _emergencyNameFocusNode = FocusNode();
  final _emergencyPhoneFocusNode = FocusNode();

  // Step 3 controllers and focus nodes
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController();
  final _streetFocusNode = FocusNode();
  final _cityFocusNode = FocusNode();
  final _stateFocusNode = FocusNode();
  final _zipFocusNode = FocusNode();
  final _countryFocusNode = FocusNode();

  // Step 4 controllers and focus nodes
  final _membershipNumberController = TextEditingController();
  final _membershipNumberFocusNode = FocusNode();
  DateTime? _membershipPurchasedAtDate;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final profile = appState.racerProfile;
    if (profile != null) {
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _selectedDate = profile.dateOfBirth;
      _gender = profile.gender;
      // Load profile image if path exists
      if (profile.profileImagePath != null && profile.profileImagePath!.isNotEmpty) {
        final imageFile = File(profile.profileImagePath!);
        if (imageFile.existsSync()) {
          _profileImage = imageFile;
        }
      }
      // Format phone number if it exists
      if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) {
        _phoneController.text = PhoneFormatter.formatPhoneNumber(profile.phoneNumber!);
      }
      // Email is loaded from AuthService, not from profile
      _emergencyNameController.text = profile.emergencyContactName ?? '';
      // Format emergency phone number if it exists
      if (profile.emergencyContactPhone != null && profile.emergencyContactPhone!.isNotEmpty) {
        _emergencyPhoneController.text = PhoneFormatter.formatPhoneNumber(profile.emergencyContactPhone!);
      }
      _streetController.text = profile.street ?? '';
      _cityController.text = profile.city ?? '';
      _stateController.text = profile.stateProvince ?? '';
      _zipController.text = profile.zipPostalCode ?? '';
      _countryController.text = profile.country ?? '';
      _membershipNumberController.text = profile.membershipNumber ?? '';
      _membershipPurchasedAtDate = profile.membershipPurchasedAt;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _membershipNumberController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emergencyNameFocusNode.dispose();
    _emergencyPhoneFocusNode.dispose();
    _streetFocusNode.dispose();
    _cityFocusNode.dispose();
    _stateFocusNode.dispose();
    _zipFocusNode.dispose();
    _countryFocusNode.dispose();
    _membershipNumberFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Copy image to app's document directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
        final savedImage = await File(pickedFile.path).copy(path.join(appDir.path, fileName));
        
        setState(() {
          _profileImage = savedImage;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorPickingImage(e.toString()))),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l10n.chooseFromGallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.takeAPhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: Text(l10n.removePhoto),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profileImage = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Get the currently focused field in the current step
  FocusNode? _getCurrentFocusedField() {
    if (_firstNameFocusNode.hasFocus) return _firstNameFocusNode;
    if (_lastNameFocusNode.hasFocus) return _lastNameFocusNode;
    if (_phoneFocusNode.hasFocus) return _phoneFocusNode;
    if (_emergencyNameFocusNode.hasFocus) return _emergencyNameFocusNode;
    if (_emergencyPhoneFocusNode.hasFocus) return _emergencyPhoneFocusNode;
    if (_streetFocusNode.hasFocus) return _streetFocusNode;
    if (_cityFocusNode.hasFocus) return _cityFocusNode;
    if (_stateFocusNode.hasFocus) return _stateFocusNode;
    if (_zipFocusNode.hasFocus) return _zipFocusNode;
    if (_countryFocusNode.hasFocus) return _countryFocusNode;
    if (_membershipNumberFocusNode.hasFocus) return _membershipNumberFocusNode;
    return null;
  }

  /// Get the current field index in the step based on focus
  int _getCurrentFieldIndex() {
    switch (_currentStep) {
      case 0: // Step 1: Personal Info - firstName(0), lastName(1), dateOfBirth(2), gender(3)
        if (_firstNameFocusNode.hasFocus) return 0;
        if (_lastNameFocusNode.hasFocus) return 1;
        return _currentFieldInStep.clamp(0, 3);
      
      case 1: // Step 2: Contact Info - phone(0), emergencyName(1), emergencyPhone(2)
        if (_phoneFocusNode.hasFocus) return 0;
        if (_emergencyNameFocusNode.hasFocus) return 1;
        if (_emergencyPhoneFocusNode.hasFocus) return 2;
        return _currentFieldInStep.clamp(0, 2);
      
      case 2: // Step 3: Address - street(0), city(1), state(2), zip(3), country(4)
        if (_streetFocusNode.hasFocus) return 0;
        if (_cityFocusNode.hasFocus) return 1;
        if (_stateFocusNode.hasFocus) return 2;
        if (_zipFocusNode.hasFocus) return 3;
        if (_countryFocusNode.hasFocus) return 4;
        return _currentFieldInStep.clamp(0, 4);
      
      case 3: // Step 4: Membership - IHRA Membership # (0)
        if (_membershipNumberFocusNode.hasFocus) return 0;
        return _currentFieldInStep.clamp(0, 0);
      
      default:
        return 0;
    }
  }

  /// Get the next focusable field in the current step
  FocusNode? _getNextFieldInStep() {
    final currentIndex = _getCurrentFieldIndex();
    
    switch (_currentStep) {
      case 0: // Step 1: Personal Info
        switch (currentIndex) {
          case 0: // firstName -> lastName
            return _lastNameFocusNode;
          case 1: // lastName -> dateOfBirth (no focus node, will be handled specially)
            return null; // Will trigger date picker
          case 2: // dateOfBirth -> gender (no focus node, will be handled specially)
            return null; // Will trigger gender dropdown
          case 3: // gender -> last field, advance step
            return null;
          default:
            return _firstNameFocusNode;
        }
      
      case 1: // Step 2: Contact Info
        switch (currentIndex) {
          case 0: // phone -> emergencyName
            return _emergencyNameFocusNode;
          case 1: // emergencyName -> emergencyPhone
            return _emergencyPhoneFocusNode;
          case 2: // emergencyPhone -> last field
            return null;
          default:
            return _phoneFocusNode;
        }
      
      case 2: // Step 3: Address
        switch (currentIndex) {
          case 0: // street -> city
            return _cityFocusNode;
          case 1: // city -> state
            return _stateFocusNode;
          case 2: // state -> zip
            return _zipFocusNode;
          case 3: // zip -> country
            return _countryFocusNode;
          case 4: // country -> last field
            return null;
          default:
            return _streetFocusNode;
        }
      
      case 3: // Step 4: Membership - only IHRA Membership #
        switch (currentIndex) {
          case 0: // membershipNumber -> last field
            return null;
          default:
            return _membershipNumberFocusNode;
        }
      
      default:
        return null;
    }
  }

  /// Handle Next button press - either move to next field or advance step
  void _handleNext() {
    final currentIndex = _getCurrentFieldIndex();
    final nextField = _getNextFieldInStep();
    
    if (nextField != null) {
      // Move focus to next field in current step
      _currentFieldInStep = currentIndex + 1;
      FocusScope.of(context).requestFocus(nextField);
    } else {
      // Handle special cases (date picker, dropdowns) or advance step
      switch (_currentStep) {
        case 0: // Step 1: Personal Info
          if (currentIndex == 1) {
            // After lastName, open date picker
            _currentFieldInStep = 2;
            _selectDate(context);
          } else if (currentIndex == 2) {
            // After date picker, focus gender dropdown (can't focus dropdown, so just advance index)
            _currentFieldInStep = 3;
          } else if (currentIndex == 3) {
            // After gender, advance step
            _saveStep1();
          } else {
            _saveStep1();
          }
          break;
        case 1: // Step 2: Contact Info
          _saveStep2();
          break;
        case 2: // Step 3: Address
          _saveStep3();
          break;
        case 3: // Step 4: Membership - only IHRA Membership #
          _completeProfile();
          break;
      }
    }
  }

  void _saveStep1() async {
    if (_step1FormKey.currentState!.validate()) {
      String? imagePath;
      if (_profileImage != null) {
        imagePath = _profileImage!.path;
      }
      
      Provider.of<AppStateService>(context, listen: false).updateRacerProfileStep1(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        dateOfBirth: _selectedDate,
        gender: _gender,
        nationality: null,
        profileImagePath: imagePath,
      );
      setState(() => _currentStep = 1);
    }
  }

  void _saveStep2() {
    if (_step2FormKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Get email from AuthService (already stored from login)
      final email = authService.email;
      
      // Format phone numbers before saving (ensure they're formatted)
      final formattedPhone = PhoneFormatter.formatPhoneNumber(_phoneController.text);
      final formattedEmergencyPhone = PhoneFormatter.formatPhoneNumber(_emergencyPhoneController.text);
      
      // Update controllers with formatted values
      if (formattedPhone != _phoneController.text) {
        _phoneController.text = formattedPhone;
      }
      if (formattedEmergencyPhone != _emergencyPhoneController.text) {
        _emergencyPhoneController.text = formattedEmergencyPhone;
      }
      
      Provider.of<AppStateService>(context, listen: false).updateRacerProfileStep2(
        phoneNumber: PhoneFormatter.getDigitsOnly(formattedPhone), // Store digits only
        email: email, // Use email from AuthService
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: PhoneFormatter.getDigitsOnly(formattedEmergencyPhone), // Store digits only
      );
      setState(() => _currentStep = 2);
    }
  }

  void _saveStep3() {
    if (_step3FormKey.currentState!.validate()) {
      Provider.of<AppStateService>(context, listen: false).updateRacerProfileStep3(
        street: _streetController.text,
        city: _cityController.text,
        stateProvince: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        zipPostalCode: _zipController.text,
      );
      setState(() => _currentStep = 3);
    }
  }

  void _completeProfile() async {
    if (_step4FormKey.currentState!.validate()) {
      final appState = Provider.of<AppStateService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final l10n = AppLocalizations.of(context)!;
      
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        // Update step 4 data
        appState.updateRacerProfileStep4(
          organization: null,
          membershipNumber: _membershipNumberController.text.isEmpty ? null : _membershipNumberController.text,
          membershipPurchasedAt: _membershipPurchasedAtDate,
          classCategory: null,
        );

        final profile = appState.racerProfile;
        if (profile == null) {
          throw Exception('Profile data not found');
        }

        // Create racer service
        final racerService = RacerService(authService);

        // First, upload profile image if it exists
        if (_profileImage != null) {
          final imageUploaded = await racerService.uploadProfileImage(_profileImage!);
          if (!imageUploaded) {
            throw Exception('Failed to upload profile image');
          }
        }

        // Then, update the racer profile
        final profileUpdated = await racerService.updateRacerProfile(profile);
        if (!profileUpdated) {
          throw Exception('Failed to update profile');
        }

        // Mark profile as complete locally
        await authService.markProfileComplete();

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        // Navigate to main screen
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        // Show error message
        ErrorHandlerService.logError(e, context: 'Complete Profile');
        if (mounted) {
          ErrorHandlerService.showError(context, e);
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: l10n.dateOfBirth, // Custom title for the date picker
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentFieldInStep = 2; // Update field index to date of birth position
      });
      // Close keyboard and unfocus everything
      // Use a small delay to ensure the date picker dialog is fully closed
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).unfocus(); // Close keyboard and remove focus
        }
      });
    } else {
      // If user cancelled, keep focus on last name (where they were before)
      // Don't change _currentFieldInStep
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.racerProfile),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          StepProgressIndicator(currentStep: _currentStep + 1, totalSteps: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStep(_currentStep),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.personalInfo, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            // Profile Image Upload
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: theme.colorScheme.outline,
                              width: 2,
                            ),
                          ),
                          child: _profileImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    _profileImage!,
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 60,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _profileImage != null ? Icons.edit : Icons.add_a_photo,
                              size: 20,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: Icon(
                      _profileImage != null ? Icons.edit : Icons.add_a_photo,
                      size: 18,
                    ),
                    label: Text(_profileImage != null ? l10n.changePhoto : l10n.addPhoto),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _firstNameController,
              focusNode: _firstNameFocusNode,
              onTap: () => _currentFieldInStep = 0,
              decoration: InputDecoration(labelText: l10n.firstName),
              validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            focusNode: _lastNameFocusNode,
            onTap: () => _currentFieldInStep = 1,
            decoration: InputDecoration(labelText: l10n.lastName),
            validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              _currentFieldInStep = 2;
              _selectDate(context);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.dateOfBirth,
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(_selectedDate == null 
                  ? l10n.selectDate 
                  : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: InputDecoration(labelText: l10n.genderOptional),
            items: [
              DropdownMenuItem(value: 'Male', child: Text(l10n.male)),
              DropdownMenuItem(value: 'Female', child: Text(l10n.female)),
            ],
            onChanged: (value) {
              setState(() {
                _gender = value;
                _currentFieldInStep = 3;
              });
            },
            onTap: () => _currentFieldInStep = 3,
          ),
          ],
        ),
    );
  }

  Widget _buildStep2() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.contactInfo, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                PhoneNumberInputFormatter(),
              ],
              onTap: () => _currentFieldInStep = 0,
              onEditingComplete: () {
                // Format phone number when field loses focus
                final formatted = PhoneFormatter.formatPhoneNumber(_phoneController.text);
                if (formatted != _phoneController.text) {
                  _phoneController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
              decoration: InputDecoration(
                labelText: l10n.phoneNumber,
                hintText: l10n.phoneHint,
                prefixIcon: const Icon(Icons.phone),
              ),
              validator: PhoneFormatter.validatePhoneNumber,
            ),
          const SizedBox(height: 24),
          Text(l10n.emergencyContact, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyNameController,
            focusNode: _emergencyNameFocusNode,
            onTap: () => _currentFieldInStep = 1,
            decoration: InputDecoration(labelText: l10n.emergencyContactName),
            validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyPhoneController,
            focusNode: _emergencyPhoneFocusNode,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              PhoneNumberInputFormatter(),
            ],
            onTap: () => _currentFieldInStep = 2,
            onEditingComplete: () {
              // Format phone number when field loses focus
              final formatted = PhoneFormatter.formatPhoneNumber(_emergencyPhoneController.text);
              if (formatted != _emergencyPhoneController.text) {
                _emergencyPhoneController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
            decoration: InputDecoration(
              labelText: l10n.emergencyContactPhone,
              hintText: l10n.phoneHint,
              prefixIcon: const Icon(Icons.phone),
            ),
            validator: PhoneFormatter.validatePhoneNumber,
          ),
          ],
        ),
    );
  }

  Widget _buildStep3() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.address, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          // Street address
          TextFormField(
            controller: _streetController,
            focusNode: _streetFocusNode,
            onTap: () => _currentFieldInStep = 0,
            decoration: InputDecoration(
              labelText: l10n.street,
              hintText: l10n.streetHint,
            ),
            validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
          ),
          const SizedBox(height: 16),
          // City
          TextFormField(
            controller: _cityController,
            focusNode: _cityFocusNode,
            onTap: () => _currentFieldInStep = 1,
            decoration: InputDecoration(labelText: l10n.city),
            validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
          ),
          const SizedBox(height: 16),
          // State/Province
          TextFormField(
            controller: _stateController,
            focusNode: _stateFocusNode,
            onTap: () => _currentFieldInStep = 2,
            decoration: InputDecoration(labelText: l10n.stateProvince),
            validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
          ),
          const SizedBox(height: 16),
          // Zip/Postal Code
          TextFormField(
            controller: _zipController,
            focusNode: _zipFocusNode,
            onTap: () => _currentFieldInStep = 3,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.zipPostalCode,
              hintText: l10n.zipHint,
            ),
            validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
          ),
          const SizedBox(height: 16),
          // Country
          TextFormField(
            controller: _countryController,
            focusNode: _countryFocusNode,
            onTap: () => _currentFieldInStep = 4,
            decoration: InputDecoration(labelText: l10n.country),
            validator: (value) => value?.isEmpty ?? true ? l10n.required : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _step4FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.ihraMembership, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _membershipNumberController,
            focusNode: _membershipNumberFocusNode,
            onTap: () => _currentFieldInStep = 0,
            decoration: InputDecoration(labelText: l10n.ihraMembershipNumberOptional),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.ihraMembershipPurchasedAtOptional,
              style: theme.textTheme.bodyLarge,
            ),
            subtitle: Text(
              _membershipPurchasedAtDate != null
                  ? '${_membershipPurchasedAtDate!.month}/${_membershipPurchasedAtDate!.day}/${_membershipPurchasedAtDate!.year}'
                  : l10n.optional,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _membershipPurchasedAtDate != null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectMembershipPurchasedAtDate(context),
          ),
        ],
      ),
    );
  }

  Future<void> _selectMembershipPurchasedAtDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _membershipPurchasedAtDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: AppLocalizations.of(context)?.ihraMembershipPurchasedAtOptional ?? 'Membership purchased at',
    );
    if (picked != null) {
      setState(() => _membershipPurchasedAtDate = picked);
    }
  }

  Widget _buildNavigationButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                child: Text(l10n.previous),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _handleNext,
              child: Text(_currentStep == 3 ? l10n.complete : l10n.next),
            ),
          ],
        ),
      ),
    );
  }
}