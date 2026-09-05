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
          // Strava Status Button
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: provider.isStravaConnected ? const Color(0xFFFC4C02) : Colors.grey,
            ),
            icon: Icon(
              Icons.cloud_done_rounded,
              size: 20,
              color: provider.isStravaConnected ? const Color(0xFFFC4C02) : Colors.grey,
            ),
            label: Text(
              provider.isStravaConnected 
                  ? (provider.stravaAthleteName != null ? provider.stravaAthleteName!.split(' ').first : 'Strava')
                  : 'Connect Strava',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showStravaDialog(context, provider),
          ),
          if (provider.activities.isEmpty)
            IconButton(
              icon: const Icon(Icons.science_outlined),
              tooltip: 'Load Demo Data',
              onPressed: () => provider.loadSampleData(),
            ),
          if (provider.activities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import Another File',
              onPressed: provider.isLoading || provider.isSyncing ? null : () => provider.pickAndImportFile(),
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
                      Text('Parsing Huawei workout records...'),
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
              'Import Huawei Health Data',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Select the .zip file from your Huawei Privacy Data export or motion path detail data.json',
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
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.file_open_rounded),
              label: const Text('Browse ZIP or JSON File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () => provider.pickAndImportFile(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.science_rounded),
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
