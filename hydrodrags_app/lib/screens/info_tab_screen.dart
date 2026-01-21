import 'package:flutter/material.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';

class InfoTabScreen extends StatelessWidget {
  const InfoTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hydrodragsInfo),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section
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
                  Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.eventTitle2026,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.itsTimeToSendIt,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // About Section
            _buildSection(
              context,
              title: l10n.aboutHydrodrags,
              icon: Icons.info,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.aboutParagraph1,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.aboutParagraph2,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  icon: Icons.speed,
                  title: l10n.worldRecordSpeed,
                  description: l10n.worldRecordDescription,
                ),
                _buildInfoCard(
                  context,
                  icon: Icons.people,
                  title: l10n.ageRequirement,
                  description: l10n.ageRequirementDescription,
                ),
                _buildInfoCard(
                  context,
                  icon: Icons.badge,
                  title: l10n.isjbaMembershipRequired,
                  description: l10n.isjbaMembershipDescription,
                ),
              ],
            ),

            // Location & Venue
            _buildSection(
              context,
              title: l10n.locationVenue,
              icon: Icons.location_on,
              children: [
                const SizedBox(height: 8),
                _buildVenueCard(
                  context,
                  title: l10n.venueName,
                  subtitle: l10n.venueSubtitle,
                  address: l10n.venueAddress,
                  details: [
                    l10n.venueDetailNoBleachers,
                    l10n.venueDetailEarlyArrival,
                    l10n.venueDetailNoGlass,
                    l10n.venueDetailFreeParking,
                  ],
                ),
              ],
            ),

            // Rules & Regulations
            _buildSection(
              context,
              title: l10n.rulesRegulations,
              icon: Icons.rule,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.rulesIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  icon: Icons.warning,
                  title: l10n.keyRules,
                  description: l10n.keyRulesDescription,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    // Could navigate to detailed rules screen
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.viewFullRules),
                ),
              ],
            ),

            // Sponsors
            _buildSection(
              context,
              title: l10n.ourSponsors,
              icon: Icons.star,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.sponsorsIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    l10n.sponsorFuelTech,
                    l10n.sponsorFloridaSkiRiders,
                    l10n.sponsorRacerH2O,
                    l10n.sponsorBrowardMotorsports,
                    l10n.sponsorAngelicaRacing,
                    l10n.sponsorFizzleRacing,
                    l10n.sponsorJLPerformance,
                    l10n.sponsorHydroTurf,
                    l10n.sponsorRivaRacing,
                    l10n.sponsorProVRacing,
                    l10n.sponsorJetTribeRacing,
                    l10n.sponsorISJBA,
                  ].map((sponsor) => Chip(
                        label: Text(sponsor),
                        avatar: const Icon(Icons.business, size: 18),
                      )).toList(),
                ),
              ],
            ),

            // Media Partners
            _buildSection(
              context,
              title: l10n.mediaPartners,
              icon: Icons.video_library,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.mediaPartnersIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildMediaCard(
                  context,
                  title: l10n.mediaRacerH2O,
                  description: l10n.mediaRacerH2ODescription,
                ),
                _buildMediaCard(
                  context,
                  title: l10n.mediaFloridaSkiRiders,
                  description: l10n.mediaFloridaSkiRidersDescription,
                ),
                _buildMediaCard(
                  context,
                  title: l10n.mediaMVPProductions,
                  description: l10n.mediaMVPProductionsDescription,
                ),
                _buildMediaCard(
                  context,
                  title: l10n.mediaProRiderMagazine,
                  description: l10n.mediaProRiderMagazineDescription,
                ),
              ],
            ),

            // Contact
            _buildSection(
              context,
              title: l10n.contactUs,
              icon: Icons.contact_mail,
              children: [
                const SizedBox(height: 8),
                _buildContactCard(
                  context,
                  icon: Icons.phone,
                  title: l10n.contactPhone,
                  value: l10n.contactPhoneNumber,
                  onTap: () {
                    // Could open phone dialer
                  },
                ),
                _buildContactCard(
                  context,
                  icon: Icons.email,
                  title: l10n.contactEmail,
                  value: l10n.contactEmailAddress,
                  onTap: () {
                    // Could open email client
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
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
    return Padding(
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String address,
    required List<String> details,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...details.map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.video_library, color: theme.colorScheme.primary),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
