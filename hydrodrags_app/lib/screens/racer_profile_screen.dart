import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../widgets/language_toggle.dart';
import '../widgets/step_progress_indicator.dart';
import '../models/racer_profile.dart';

class RacerProfileScreen extends StatefulWidget {
  const RacerProfileScreen({super.key});

  @override
  State<RacerProfileScreen> createState() => _RacerProfileScreenState();
}

class _RacerProfileScreenState extends State<RacerProfileScreen> {
  int _currentStep = 0;
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();
  final _step4FormKey = GlobalKey<FormState>();

  // Step 1 controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _selectedDate;
  String? _gender;
  final _nationalityController = TextEditingController();

  // Step 2 controllers
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Step 3 controllers
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _zipController = TextEditingController();

  // Step 4 controllers
  final _organizationController = TextEditingController();
  final _membershipNumberController = TextEditingController();
  String? _classCategory;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final profile = appState.racerProfile;
    if (profile != null) {
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _selectedDate = profile.dateOfBirth;
      _gender = profile.gender;
      _nationalityController.text = profile.nationality ?? '';
      _phoneController.text = profile.phoneNumber ?? '';
      _emailController.text = profile.email ?? '';
      _emergencyNameController.text = profile.emergencyContactName ?? '';
      _emergencyPhoneController.text = profile.emergencyContactPhone ?? '';
      _streetController.text = profile.street ?? '';
      _cityController.text = profile.city ?? '';
      _stateController.text = profile.stateProvince ?? '';
      _countryController.text = profile.country ?? '';
      _zipController.text = profile.zipPostalCode ?? '';
      _organizationController.text = profile.organization ?? '';
      _membershipNumberController.text = profile.membershipNumber ?? '';
      _classCategory = profile.classCategory;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nationalityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipController.dispose();
    _organizationController.dispose();
    _membershipNumberController.dispose();
    super.dispose();
  }

  void _saveStep1() {
    if (_step1FormKey.currentState!.validate()) {
      Provider.of<AppStateService>(context, listen: false).updateRacerProfileStep1(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        dateOfBirth: _selectedDate,
        gender: _gender,
        nationality: _nationalityController.text.isEmpty ? null : _nationalityController.text,
      );
      setState(() => _currentStep = 1);
    }
  }

  void _saveStep2() {
    if (_step2FormKey.currentState!.validate()) {
      Provider.of<AppStateService>(context, listen: false).updateRacerProfileStep2(
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: _emergencyPhoneController.text,
      );
      setState(() => _currentStep = 2);
    }
  }

  void _saveStep3() {
    if (_step3FormKey.currentState!.validate()) {
      Provider.of<AppStateService>(context, listen: false).updateRacerProfileStep3(
        street: _streetController.text,
        city: _cityController.text,
        stateProvince: _stateController.text,
        country: _countryController.text,
        zipPostalCode: _zipController.text,
      );
      setState(() => _currentStep = 3);
    }
  }

  void _completeProfile() {
    if (_step4FormKey.currentState!.validate()) {
      Provider.of<AppStateService>(context, listen: false).updateRacerProfileStep4(
        organization: _organizationController.text.isEmpty ? null : _organizationController.text,
        membershipNumber: _membershipNumberController.text.isEmpty ? null : _membershipNumberController.text,
        classCategory: _classCategory,
      );
      Navigator.of(context).pushReplacementNamed('/events');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Racer Profile'),
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
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First Name'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date of Birth',
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(_selectedDate == null 
                  ? 'Select date' 
                  : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender (Optional)'),
            items: ['Male', 'Female', 'Other', 'Prefer not to say']
                .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                .toList(),
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nationalityController,
            decoration: const InputDecoration(labelText: 'Nationality (Optional)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final theme = Theme.of(context);
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact Information', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          Text('Emergency Contact', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyNameController,
            decoration: const InputDecoration(labelText: 'Emergency Contact Name'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Emergency Contact Phone', prefixIcon: Icon(Icons.phone)),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final theme = Theme.of(context);
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Address', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _streetController,
            decoration: const InputDecoration(labelText: 'Street'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stateController,
            decoration: const InputDecoration(labelText: 'State / Province'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: const InputDecoration(labelText: 'Country'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _zipController,
            decoration: const InputDecoration(labelText: 'ZIP / Postal Code'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    final theme = Theme.of(context);
    return Form(
      key: _step4FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Membership Details', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _organizationController,
            decoration: const InputDecoration(labelText: 'Organization / Association (Optional)'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _membershipNumberController,
            decoration: const InputDecoration(labelText: 'Membership Number (Optional)'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _classCategory,
            decoration: const InputDecoration(labelText: 'Class / Category *'),
            items: ['Pro Stock', 'Pro Mod', 'Top Alcohol', 'Competition Eliminator', 'Super Comp']
                .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                .toList(),
            onChanged: (value) => setState(() => _classCategory = value),
            validator: (value) => value == null ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
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
                child: const Text('Previous'),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                switch (_currentStep) {
                  case 0:
                    _saveStep1();
                    break;
                  case 1:
                    _saveStep2();
                    break;
                  case 2:
                    _saveStep3();
                    break;
                  case 3:
                    _completeProfile();
                    break;
                }
              },
              child: Text(_currentStep == 3 ? 'Complete' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}