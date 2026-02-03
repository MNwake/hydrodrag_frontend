import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/language_toggle.dart';
import '../models/racer_profile.dart';
import '../services/auth_service.dart';
import '../services/racer_service.dart';
import '../services/error_handler_service.dart';
import '../services/image_cache_service.dart';
import 'racer_profile_detail_screen.dart';

class RacersListTabScreen extends StatefulWidget {
  const RacersListTabScreen({super.key});

  @override
  State<RacersListTabScreen> createState() => _RacersListTabScreenState();
}

class _RacersListTabScreenState extends State<RacersListTabScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<RacerProfile> _allRacers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ImageCacheService _imageCache = ImageCacheService();

  List<RacerProfile> get _filteredRacers {
    if (_searchQuery.isEmpty) {
      return _allRacers;
    }
    final query = _searchQuery.toLowerCase();
    return _allRacers.where((racer) {
      final fullName = racer.fullName.toLowerCase();
      final city = (racer.city ?? '').toLowerCase();
      final state = (racer.stateProvince ?? '').toLowerCase();
      final category = (racer.classCategory ?? '').toLowerCase();
      return fullName.contains(query) ||
          city.contains(query) ||
          state.contains(query) ||
          category.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRacers();
  }

  Future<void> _loadRacers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final racerService = RacerService(authService);
      final racers = await racerService.getAllRacers();

      if (mounted) {
        setState(() {
          _allRacers = racers;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load Racers');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandlerService.getErrorMessage(context, e);
        });
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Racers'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search racers by name, location, or class...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Racers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? RefreshIndicator(
                        onRefresh: _loadRacers,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading racers',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _errorMessage!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _loadRacers,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : _filteredRacers.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _loadRacers,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_off, size: 64, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isEmpty ? 'No racers registered yet' : 'No racers found',
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      if (_searchQuery.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Try a different search term',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRacers,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredRacers.length,
                              itemBuilder: (context, index) {
                                final racer = _filteredRacers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: _buildRacerAvatar(context, racer),
                                    title: Text(
                                      racer.fullName.isNotEmpty ? racer.fullName : 'Unknown Racer',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (racer.city != null || racer.stateProvince != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${racer.city ?? ''}, ${racer.stateProvince ?? ''}'.trim(),
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (racer.classCategory != null) ...[
                                          const SizedBox(height: 4),
                                          Chip(
                                            label: Text(
                                              racer.classCategory!,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            backgroundColor: theme.colorScheme.secondaryContainer,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => RacerProfileDetailScreen(racer: racer),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRacerAvatar(BuildContext context, RacerProfile racer) {
    final theme = Theme.of(context);
    final initials = racer.fullName.isNotEmpty
        ? racer.fullName[0].toUpperCase()
        : '?';

    if (racer.profileImagePath == null || racer.profileImagePath!.isEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          initials,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return FutureBuilder<File?>(
      future: _imageCache.getCachedImage(
        racer.profileImagePath,
        updatedAt: racer.profileImageUpdatedAt,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: FileImage(snapshot.data!),
            onBackgroundImageError: (exception, stackTrace) {
              // Fall back to initials on error
            },
            child: snapshot.data == null
                ? Text(
                    initials,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          );
        }
        return CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            initials,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
