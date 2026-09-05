import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/activity_type.dart';
import '../../data/services/export_service.dart';
import '../controllers/workout_provider.dart';
import '../widgets/workout_card.dart';
import 'activity_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          if (provider.activities.isEmpty)
            TextButton.icon(
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Load Demo'),
              onPressed: () => provider.loadSampleData(),
            ),
          if (provider.activities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import Another File',
              onPressed: provider.isLoading ? null : () => provider.pickAndImportFile(),
            ),
        ],
      ),
      body: provider.isLoading
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
        // Summary stats bar
        _buildStatsBanner(context, provider),

        // Filter chips & Multi-select header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(context, label: 'All (${provider.totalActivities})', isSelected: provider.selectedFilter == null, onSelected: () => provider.setFilter(null)),
                      const SizedBox(width: 8),
                      _buildFilterChip(context, label: 'Runs', isSelected: provider.selectedFilter == ActivityType.outdoorRunning, onSelected: () => provider.setFilter(ActivityType.outdoorRunning)),
                      const SizedBox(width: 8),
                      _buildFilterChip(context, label: 'Rides', isSelected: provider.selectedFilter == ActivityType.outdoorCycling, onSelected: () => provider.setFilter(ActivityType.outdoorCycling)),
                      const SizedBox(width: 8),
                      _buildFilterChip(context, label: 'Walks', isSelected: provider.selectedFilter == ActivityType.walking, onSelected: () => provider.setFilter(ActivityType.walking)),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: provider.selectedIds.length == filtered.length
                    ? () => provider.clearSelection()
                    : () => provider.selectAll(),
                child: Text(provider.selectedIds.length == filtered.length ? 'Deselect All' : 'Select All'),
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
                    return WorkoutCard(
                      activity: activity,
                      isSelected: provider.isSelected(activity.id),
                      onSelectChanged: (_) => provider.toggleSelection(activity.id),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatSummaryItem(context, '${provider.totalActivities}', 'Activities'),
          Container(width: 1, height: 28, color: theme.colorScheme.outlineVariant),
          _buildStatSummaryItem(context, '${provider.totalDistanceKm.toStringAsFixed(1)} km', 'Total Distance'),
          Container(width: 1, height: 28, color: theme.colorScheme.outlineVariant),
          _buildStatSummaryItem(context, '$hours hrs', 'Total Time'),
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

  Widget _buildFilterChip(BuildContext context, {required String label, required bool isSelected, required VoidCallback onSelected}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
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
