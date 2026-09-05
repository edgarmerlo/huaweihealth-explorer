import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/activity_type.dart';
import '../../data/services/export_service.dart';
import '../controllers/workout_provider.dart';
import '../widgets/workout_card.dart';
import '../widgets/strava_auth_dialog.dart';
import 'activity_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showStravaDialog(BuildContext context, WorkoutProvider provider) {
    showDialog(
      context: context,
      builder: (_) => StravaAuthDialog(
        onConnectionChanged: () => provider.refresh(),
      ),
    );
  }

  void _showBackupGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.deepOrange, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instant Local Backup',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Extract 100% past history in ~30 seconds',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildGuideStep(
              step: '1',
              title: 'Open Huawei Backup App',
              description: 'Open the native "Backup" (Copia de seguridad) app on your phone, or connect your phone to your computer with Huawei HiSuite.',
            ),
            const SizedBox(height: 16),
            _buildGuideStep(
              step: '2',
              title: 'Choose Internal Storage or PC',
              description: 'Tap Backup -> Select "Internal Storage" (Almacenamiento interno) or "External USB / PC".',
            ),
            const SizedBox(height: 16),
            _buildGuideStep(
              step: '3',
              title: 'Select Huawei Health Data only',
              description: 'Under the Apps list, select "Huawei Health" (Data only). Tap "Back Up".',
            ),
            const SizedBox(height: 16),
            _buildGuideStep(
              step: '4',
              title: 'Pick File in this App',
              description: 'Tap "Select Backup / ZIP" in this app and pick the created .tar / .zip archive from your storage.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.file_open_rounded),
              label: const Text('Browse Files Now'),
              onPressed: () {
                Navigator.pop(ctx);
                context.read<WorkoutProvider>().pickAndImportFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildGuideStep({
    required String step,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.deepOrange,
          child: Text(
            step,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startStravaSync(BuildContext context, WorkoutProvider provider) async {
    if (!provider.isStravaConnected) {
      _showStravaDialog(context, provider);
      return;
    }

    final toSyncCount = provider.unsyncedCount;
    if (toSyncCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All activities are already synced with Strava!')),
      );
      return;
    }

    try {
      final results = await provider.syncNewToStrava();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 8),
                Text('Sync Completed'),
              ],
            ),
            content: Text(
              'Successfully synced ${results['success']} new activities.\n'
              '${results['duplicates']! > 0 ? "Skipped ${results['duplicates']} duplicates.\n" : ""}'
              '${results['failed']! > 0 ? "Failed to upload ${results['failed']} activities." : ""}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.directions_run_rounded, color: Colors.deepOrangeAccent),
            SizedBox(width: 8),
            Text('Huawei Exporter', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // Backup Guide Action
          IconButton(
            tooltip: 'How to backup',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showBackupGuide(context),
          ),
          // Strava Status Action
          IconButton(
            tooltip: provider.isStravaConnected ? 'Strava Connected' : 'Connect Strava',
            icon: Icon(
              Icons.cloud_done_rounded,
              color: provider.isStravaConnected ? const Color(0xFFFC4C02) : null,
            ),
            onPressed: () => _showStravaDialog(context, provider),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'import') {
                provider.pickAndImportFile();
              } else if (val == 'guide') {
                _showBackupGuide(context);
              } else if (val == 'demo') {
                provider.loadSampleData();
              } else if (val == 'strava_login') {
                _showStravaDialog(context, provider);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_open_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Select Backup / ZIP File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'guide',
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('How to create Backup'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'demo',
                child: Row(
                  children: [
                    Icon(Icons.science_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Load Demo Workouts'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          provider.isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Parsing Huawei backup & workout records...'),
                    ],
                  ),
                )
              : provider.activities.isEmpty
                  ? _buildEmptyState(context, provider)
                  : _buildLoadedState(context, provider),

          // Syncing Progress Overlay
          if (provider.isSyncing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFFFC4C02)),
                        const SizedBox(height: 16),
                        Text(
                          'Syncing with Strava...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.syncProgressMessage ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: provider.syncProgressValue,
                          backgroundColor: Colors.grey.shade200,
                          color: const Color(0xFFFC4C02),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: provider.selectedIds.isNotEmpty
          ? _buildBatchExportBar(context, provider)
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context, WorkoutProvider provider) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_zip_rounded,
                size: 54,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Import Huawei Workout Data',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Select a Huawei Local Backup (.tar / .zip) or Huawei Privacy Data ZIP file',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 28),
            // Primary Option: Pick Backup / ZIP File
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.file_open_rounded, size: 22),
                label: const Text(
                  'Select Backup / ZIP / JSON File',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () => provider.pickAndImportFile(),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary Option: Backup Guide
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.flash_on_rounded, color: Colors.deepOrange),
                label: const Text('How to create Instant Local Backup (30s)'),
                onPressed: () => _showBackupGuide(context),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.science_rounded, size: 18),
              label: const Text('Try with Demo Workouts'),
              onPressed: () => provider.loadSampleData(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, WorkoutProvider provider) {
    final filtered = provider.filteredActivities;

    return Column(
      children: [
        // Summary stats banner + Sync New CTA
        _buildStatsBanner(context, provider),

        // Filter chips & Multi-select header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              // Row 1: Sync Status Filters (All, New, Synced) + Sync CTA
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            context,
                            label: 'All (${provider.totalActivities})',
                            isSelected: provider.syncFilter == SyncFilterMode.all,
                            onSelected: () => provider.setSyncFilter(SyncFilterMode.all),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context,
                            label: 'New (${provider.unsyncedCount})',
                            isSelected: provider.syncFilter == SyncFilterMode.newOnly,
                            badgeColor: Colors.green,
                            onSelected: () => provider.setSyncFilter(SyncFilterMode.newOnly),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context,
                            label: 'Synced (${provider.syncedCount})',
                            isSelected: provider.syncFilter == SyncFilterMode.syncedOnly,
                            badgeColor: const Color(0xFFFC4C02),
                            onSelected: () => provider.setSyncFilter(SyncFilterMode.syncedOnly),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: provider.selectedIds.length == filtered.length
                        ? () => provider.clearSelection()
                        : () => provider.selectAll(),
                    child: Text(provider.selectedIds.length == filtered.length ? 'Deselect' : 'Select All'),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Row 2: Sport Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSportChip(context, label: 'All Sports', isSelected: provider.selectedSportFilter == null, onSelected: () => provider.setSportFilter(null)),
                    const SizedBox(width: 6),
                    _buildSportChip(context, label: 'Runs', isSelected: provider.selectedSportFilter == ActivityType.outdoorRunning, onSelected: () => provider.setSportFilter(ActivityType.outdoorRunning)),
                    const SizedBox(width: 6),
                    _buildSportChip(context, label: 'Rides', isSelected: provider.selectedSportFilter == ActivityType.outdoorCycling, onSelected: () => provider.setSportFilter(ActivityType.outdoorCycling)),
                    const SizedBox(width: 6),
                    _buildSportChip(context, label: 'Walks', isSelected: provider.selectedSportFilter == ActivityType.walking, onSelected: () => provider.setSportFilter(ActivityType.walking)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Activity List
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No activities match this filter.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final activity = filtered[index];
                    final syncStatus = provider.getSyncStatus(activity);
                    return WorkoutCard(
                      activity: activity,
                      syncStatus: syncStatus,
                      isSelected: provider.isSelected(activity.permanentId),
                      onSelectChanged: (_) => provider.toggleSelection(activity.permanentId),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityDetailScreen(activity: activity),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsBanner(BuildContext context, WorkoutProvider provider) {
    final theme = Theme.of(context);
    final hours = (provider.totalDurationMinutes / 60.0).toStringAsFixed(1);
    final unsynced = provider.unsyncedCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatSummaryItem(context, '${provider.totalActivities}', 'Activities'),
              Container(width: 1, height: 28, color: theme.colorScheme.outlineVariant),
              _buildStatSummaryItem(context, '${provider.totalDistanceKm.toStringAsFixed(1)} km', 'Total Distance'),
              Container(width: 1, height: 28, color: theme.colorScheme.outlineVariant),
              _buildStatSummaryItem(context, '$hours hrs', 'Total Time'),
            ],
          ),
          if (unsynced > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFC4C02),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(
                  'Sync $unsynced New ${unsynced == 1 ? "Activity" : "Activities"} to Strava',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: provider.isSyncing ? null : () => _startStravaSync(context, provider),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatSummaryItem(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    Color? badgeColor,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: badgeColor?.withValues(alpha: 0.2),
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }

  Widget _buildSportChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildBatchExportBar(BuildContext context, WorkoutProvider provider) {
    final count = provider.selectedIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '$count selected',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            FilledButton.tonal(
              onPressed: () => provider.exportBatch(ExportFormat.gpx),
              child: const Text('GPX'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () => provider.exportBatch(ExportFormat.tcx),
              child: const Text('TCX'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () => provider.exportBatch(ExportFormat.fit),
              child: const Text('FIT'),
            ),
          ],
        ),
      ),
    );
  }
}
