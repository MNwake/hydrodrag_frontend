import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../widgets/language_toggle.dart';
import '../widgets/step_progress_indicator.dart';
import '../models/event.dart';
import '../models/event_registration.dart';

class EventRegistrationScreen extends StatefulWidget {
  final Event? event;

  const EventRegistrationScreen({super.key, this.event});

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  int _currentStep = 0;
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  // Step 1 controllers
  String? _craftType;
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  String? _engineClass;
  final List<String> _modifications = [];
  String? _classSelection;

  // Step 2 controllers
  final _numberOfEntriesController = TextEditingController(text: '1');
  String? _heatPreferences;
  final _transponderIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeEvent = ModalRoute.of(context)?.settings.arguments;
      final event = widget.event ?? (routeEvent is Event ? routeEvent : null);
      if (event != null) {
        Provider.of<AppStateService>(context, listen: false).setSelectedEvent(event);
      }
    });
    _loadExistingData();
  }

  void _loadExistingData() {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final registration = appState.eventRegistration;
    if (registration != null) {
      _craftType = registration.craftType;
      _makeController.text = registration.make ?? '';
      _modelController.text = registration.model ?? '';
      _engineClass = registration.engineClass;
      _modifications.addAll(registration.modifications);
      _classSelection = registration.classSelection;
      _numberOfEntriesController.text = registration.numberOfEntries?.toString() ?? '1';
      _heatPreferences = registration.heatPreferences;
      _transponderIdController.text = registration.transponderId ?? '';
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _numberOfEntriesController.dispose();
    _transponderIdController.dispose();
    super.dispose();
  }

  void _saveStep1() {
    if (_step1FormKey.currentState!.validate()) {
      final registration = EventRegistration(
        craftType: _craftType,
        make: _makeController.text,
        model: _modelController.text,
        engineClass: _engineClass,
        modifications: List.from(_modifications),
        classSelection: _classSelection,
      );
      Provider.of<AppStateService>(context, listen: false).setEventRegistration(registration);
      setState(() => _currentStep = 1);
    }
  }

  void _completeRegistration() {
    if (_step2FormKey.currentState!.validate()) {
      final appState = Provider.of<AppStateService>(context, listen: false);
      final registration = EventRegistration(
        craftType: _craftType,
        make: _makeController.text,
        model: _modelController.text,
        engineClass: _engineClass,
        modifications: List.from(_modifications),
        classSelection: _classSelection,
        numberOfEntries: int.tryParse(_numberOfEntriesController.text) ?? 1,
        heatPreferences: _heatPreferences,
        transponderId: _transponderIdController.text.isEmpty ? null : _transponderIdController.text,
      );
      appState.setEventRegistration(registration);
      Navigator.of(context).pushReplacementNamed('/waiver-overview');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event ?? Provider.of<AppStateService>(context).selectedEvent;

    return Scaffold(
      appBar: AppBar(
        title: Text(event?.name ?? 'Event Registration'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          StepProgressIndicator(currentStep: _currentStep + 1, totalSteps: 3),
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
          Text('Vehicle / Craft Information', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _craftType,
            decoration: const InputDecoration(labelText: 'Craft Type'),
            items: ['Jet Ski', 'Boat', 'Hydroplane', 'Other']
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _craftType = value),
            validator: (value) => value == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _makeController,
            decoration: const InputDecoration(labelText: 'Make'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Model'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _engineClass,
            decoration: const InputDecoration(labelText: 'Engine Class'),
            items: ['250cc', '500cc', '750cc', '1000cc', 'Open']
                .map((cls) => DropdownMenuItem(value: cls, child: Text(cls)))
                .toList(),
            onChanged: (value) => setState(() => _engineClass = value),
            validator: (value) => value == null ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          Text('Modifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...[
            'Turbocharger',
            'Supercharger',
            'Nitrous Oxide',
            'Custom Exhaust',
            'ECU Tune',
          ].map((mod) => CheckboxListTile(
                title: Text(mod),
                value: _modifications.contains(mod),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _modifications.add(mod);
                    } else {
                      _modifications.remove(mod);
                    }
                  });
                },
              )),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _classSelection,
            decoration: const InputDecoration(labelText: 'Class Selection'),
            items: ['Pro Stock', 'Pro Mod', 'Top Alcohol', 'Competition Eliminator']
                .map((cls) => DropdownMenuItem(value: cls, child: Text(cls)))
                .toList(),
            onChanged: (value) => setState(() => _classSelection = value),
            validator: (value) => value == null ? 'Required' : null,
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
          Text('Race Options', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextFormField(
            controller: _numberOfEntriesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of Entries'),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              final num = int.tryParse(value);
              if (num == null || num < 1) return 'Must be at least 1';
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _heatPreferences,
            decoration: const InputDecoration(labelText: 'Heat Preferences (Optional)'),
            items: ['Morning', 'Afternoon', 'Evening', 'No Preference']
                .map((pref) => DropdownMenuItem(value: pref, child: Text(pref)))
                .toList(),
            onChanged: (value) => setState(() => _heatPreferences = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _transponderIdController,
            decoration: const InputDecoration(labelText: 'Transponder / ID Number (Optional)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateService>(context);
    final registration = appState.eventRegistration;
    final event = appState.selectedEvent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Confirm', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Event', style: theme.textTheme.titleMedium),
                Text(event?.name ?? 'N/A', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                Text('Vehicle', style: theme.textTheme.titleMedium),
                Text('${registration?.make ?? ''} ${registration?.model ?? ''}', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text('Class: ${registration?.classSelection ?? 'N/A'}', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text('Entries', style: theme.textTheme.titleMedium),
                Text('${registration?.numberOfEntries ?? 1}', style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ],
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
                    setState(() => _currentStep = 2);
                    break;
                  case 2:
                    _completeRegistration();
                    break;
                }
              },
              child: Text(_currentStep == 2 ? 'Continue to Waiver' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}