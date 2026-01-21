import 'package:flutter/material.dart';
import '../models/racer_profile.dart';
import '../widgets/language_toggle.dart';

class RacerProfileDetailScreen extends StatelessWidget {
  final RacerProfile racer;

  const RacerProfileDetailScreen({super.key, required this.racer});

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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(
                      racer.fullName.isNotEmpty ? racer.fullName[0].toUpperCase() : '?',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    racer.fullName.isNotEmpty ? racer.fullName : 'Unknown Racer',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (racer.classCategory != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        racer.classCategory!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information
                  if (racer.firstName != null || racer.lastName != null || racer.dateOfBirth != null || racer.gender != null || racer.nationality != null)
                    _buildSection(
                      context,
                      title: 'Personal Information',
                      icon: Icons.person,
                      children: [
                        if (racer.firstName != null)
                          _buildInfoRow(context, 'First Name', racer.firstName!),
                        if (racer.lastName != null)
                          _buildInfoRow(context, 'Last Name', racer.lastName!),
                        if (racer.dateOfBirth != null)
                          _buildInfoRow(context, 'Date of Birth', _formatDate(racer.dateOfBirth!)),
                        if (racer.gender != null)
                          _buildInfoRow(context, 'Gender', racer.gender!),
                        if (racer.nationality != null)
                          _buildInfoRow(context, 'Nationality', racer.nationality!),
                      ],
                    ),

                  // Contact Information
                  if (racer.phoneNumber != null || racer.email != null)
                    _buildSection(
                      context,
                      title: 'Contact Information',
                      icon: Icons.contact_mail,
                      children: [
                        if (racer.phoneNumber != null)
                          _buildInfoRow(context, 'Phone', racer.phoneNumber!),
                        if (racer.email != null)
                          _buildInfoRow(context, 'Email', racer.email!),
                        if (racer.emergencyContactName != null)
                          _buildInfoRow(context, 'Emergency Contact', racer.emergencyContactName!),
                      ],
                    ),

                  // Location
                  if (racer.city != null || racer.stateProvince != null || racer.country != null)
                    _buildSection(
                      context,
                      title: 'Location',
                      icon: Icons.location_on,
                      children: [
                        if (racer.city != null)
                          _buildInfoRow(context, 'City', racer.city!),
                        if (racer.stateProvince != null)
                          _buildInfoRow(context, 'State/Province', racer.stateProvince!),
                        if (racer.country != null)
                          _buildInfoRow(context, 'Country', racer.country!),
                        if (racer.zipPostalCode != null)
                          _buildInfoRow(context, 'ZIP/Postal Code', racer.zipPostalCode!),
                      ],
                    ),

                  // Competition Details
                  if (racer.classCategory != null || racer.organization != null || racer.membershipNumber != null)
                    _buildSection(
                      context,
                      title: 'Competition Details',
                      icon: Icons.emoji_events,
                      children: [
                        if (racer.classCategory != null)
                          _buildInfoRow(context, 'Class/Category', racer.classCategory!),
                        if (racer.organization != null)
                          _buildInfoRow(context, 'Organization', racer.organization!),
                        if (racer.membershipNumber != null)
                          _buildInfoRow(context, 'Membership Number', racer.membershipNumber!),
                      ],
                    ),

                  // PWC Information
                  _buildSection(
                    context,
                    title: 'PWC Information',
                    icon: Icons.speed,
                    children: [
                      _buildInfoRow(context, 'Craft Type', 'Coming soon...', isPlaceholder: true),
                      _buildInfoRow(context, 'Make & Model', 'Coming soon...', isPlaceholder: true),
                      _buildInfoRow(context, 'Engine Class', 'Coming soon...', isPlaceholder: true),
                    ],
                  ),

                  // Results
                  _buildSection(
                    context,
                    title: 'Race Results',
                    icon: Icons.bar_chart,
                    children: [
                      Text(
                        'No results available yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isPlaceholder = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                color: isPlaceholder
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
