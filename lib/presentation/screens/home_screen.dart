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

  Future<String?> _showPasswordDialog(
    BuildContext context,
    String fileName, {
    bool isRetry = false,
  }) {
    final controller = TextEditingController();
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFFFC4C02), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Protected ZIP Archive',
                    style: TextStyle(
                      color: Color(0xFFF0F6FC),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"$fileName" is encrypted with a password.',
                    style: const TextStyle(
                      color: Color(0xFFF0F6FC),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Huawei sends this password to your email address or SMS upon generating your data export.',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.35),
                  ),
                  if (isRetry) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Incorrect password. Please verify and try again.',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscureText,
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'ZIP Password',
                      labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                      filled: true,
                      fillColor: const Color(0xFF0B0E14),
                      prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF00E5BE), size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: const Color(0xFF8B949E),
                          size: 20,
                        ),
                        onPressed: () => setState(() => obscureText = !obscureText),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00E5BE), width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        Navigator.pop(ctx, val.trim());
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFC4C02),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final pwd = controller.text.trim();
                  if (pwd.isNotEmpty) {
                    Navigator.pop(ctx, pwd);
                  }
                },
                child: const Text('Unlock & Import', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _importZip(BuildContext context, WorkoutProvider provider) async {
    await provider.pickAndImportFile(
      onPasswordPrompt: (fileName, {bool isRetry = false}) async {
        return await _showPasswordDialog(context, fileName, isRetry: isRetry);
      },
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
            backgroundColor: const Color(0xFF161B22),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF00E5BE)),
                SizedBox(width: 8),
                Text('Sync Completed', style: TextStyle(color: Color(0xFFF0F6FC))),
              ],
            ),
            content: Text(
              'Successfully uploaded/updated ${results['success']} activities on Strava.\n'
              '${results['duplicates']! > 0 ? "Skipped ${results['duplicates']} duplicates.\n" : ""}'
              '${results['failed']! > 0 ? "Failed to upload ${results['failed']} activities." : ""}',
              style: const TextStyle(color: Color(0xFF8B949E)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: Color(0xFFFC4C02), fontWeight: FontWeight.bold)),
              ),
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFC4C02).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_run_rounded, color: Color(0xFFFC4C02), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Huawei Exporter',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          // Select another ZIP if activities are already loaded
          if (provider.activities.isNotEmpty)
            IconButton(
              tooltip: 'Select new ZIP file',
              icon: const Icon(Icons.folder_open_rounded),
              onPressed: () => _importZip(context, provider),
            ),
          // Strava Status / Connect Action
          IconButton(
            tooltip: provider.isStravaConnected ? 'Strava (Connected)' : 'Connect Strava',
            icon: Icon(
              Icons.cloud_done_rounded,
              color: provider.isStravaConnected ? const Color(0xFFFC4C02) : const Color(0xFF8B949E),
            ),
            onPressed: () => _showStravaDialog(context, provider),
          ),
        ],
      ),
      body: Stack(
        children: [
          provider.isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFFC4C02)),
                      const SizedBox(height: 16),
                      Text(
                        provider.loadingMessage ?? 'Extracting workouts from Huawei ZIP...',
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : provider.activities.isEmpty
                  ? _buildEmptyState(context, provider)
                  : _buildLoadedState(context, provider),

          // Syncing Progress Overlay
          if (provider.isSyncing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFFFC4C02)),
                        const SizedBox(height: 16),
                        const Text(
                          'Syncing with Strava',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFFF0F6FC),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.syncProgressMessage ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E)),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: provider.syncProgressValue,
                            minHeight: 6,
                            backgroundColor: const Color(0xFF30363D),
                            color: const Color(0xFFFC4C02),
                          ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF30363D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFC4C02).withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.folder_zip_rounded,
                size: 46,
                color: Color(0xFFFC4C02),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Import Huawei Data',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Color(0xFFF0F6FC),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Select your Huawei Privacy Center ZIP export file to parse and sync past workouts.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8B949E),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: const Color(0xFFFC4C02),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.file_open_rounded, size: 22),
                label: const Text(
                  'Select Huawei Data ZIP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _importZip(context, provider),
              ),
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
        // Summary stats banner + Sync CTA
        _buildStatsBanner(context, provider),

        // Filter chips & Multi-select header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              // Row 1: Sync Status Filters (All, New, Synced) + Select All
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All (${provider.totalActivities})',
                            isSelected: provider.syncFilter == SyncFilterMode.all,
                            onSelected: () => provider.setSyncFilter(SyncFilterMode.all),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'New (${provider.unsyncedCount})',
                            isSelected: provider.syncFilter == SyncFilterMode.newOnly,
                            badgeColor: const Color(0xFF00E5BE),
                            onSelected: () => provider.setSyncFilter(SyncFilterMode.newOnly),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
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
                    child: Text(
                      provider.selectedIds.length == filtered.length ? 'Deselect' : 'Select All',
                      style: const TextStyle(color: Color(0xFF00E5BE), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Row 2: Sport Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSportChip(label: 'All Sports', isSelected: provider.selectedSportFilter == null, onSelected: () => provider.setSportFilter(null)),
                    const SizedBox(width: 6),
                    _buildSportChip(label: 'Runs', isSelected: provider.selectedSportFilter == ActivityType.outdoorRunning, onSelected: () => provider.setSportFilter(ActivityType.outdoorRunning)),
                    const SizedBox(width: 6),
                    _buildSportChip(label: 'Rides', isSelected: provider.selectedSportFilter == ActivityType.outdoorCycling, onSelected: () => provider.setSportFilter(ActivityType.outdoorCycling)),
                    const SizedBox(width: 6),
                    _buildSportChip(label: 'Walks', isSelected: provider.selectedSportFilter == ActivityType.walking, onSelected: () => provider.setSportFilter(ActivityType.walking)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Activity List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No activities match this filter.',
                    style: TextStyle(color: Color(0xFF8B949E)),
                  ),
                )
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
    final hours = (provider.totalDurationMinutes / 60.0).toStringAsFixed(1);
    final unsynced = provider.unsyncedCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatSummaryItem('${provider.totalActivities}', 'Activities', const Color(0xFFF0F6FC)),
              Container(width: 1, height: 28, color: const Color(0xFF30363D)),
              _buildStatSummaryItem('${provider.totalDistanceKm.toStringAsFixed(1)} km', 'Total Distance', const Color(0xFF00E5BE)),
              Container(width: 1, height: 28, color: const Color(0xFF30363D)),
              _buildStatSummaryItem('$hours hrs', 'Total Time', const Color(0xFFFC4C02)),
            ],
          ),
          if (unsynced > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFC4C02),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(
                  'Sync $unsynced New ${unsynced == 1 ? "Activity" : "Activities"} to Strava',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: provider.isSyncing ? null : () => _startStravaSync(context, provider),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatSummaryItem(String value, String label, Color accent) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8B949E),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? badgeColor,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? (badgeColor ?? const Color(0xFFFC4C02)) : const Color(0xFF8B949E),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: (badgeColor ?? const Color(0xFFFC4C02)).withValues(alpha: 0.18),
      backgroundColor: const Color(0xFF161B22),
      side: BorderSide(
        color: isSelected ? (badgeColor ?? const Color(0xFFFC4C02)) : const Color(0xFF30363D),
      ),
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }

  Widget _buildSportChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: isSelected ? const Color(0xFF00E5BE) : const Color(0xFF8B949E),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF00E5BE).withValues(alpha: 0.18),
      backgroundColor: const Color(0xFF161B22),
      side: BorderSide(
        color: isSelected ? const Color(0xFF00E5BE) : const Color(0xFF30363D),
      ),
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildBatchExportBar(BuildContext context, WorkoutProvider provider) {
    final count = provider.selectedIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '$count selected',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFF0F6FC)),
            ),
            const Spacer(),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E242C),
                foregroundColor: const Color(0xFFF0F6FC),
              ),
              onPressed: () => provider.exportBatch(ExportFormat.gpx),
              child: const Text('GPX'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E242C),
                foregroundColor: const Color(0xFFF0F6FC),
              ),
              onPressed: () => provider.exportBatch(ExportFormat.tcx),
              child: const Text('TCX'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFC4C02),
                foregroundColor: Colors.white,
              ),
              onPressed: () => provider.exportBatch(ExportFormat.fit),
              child: const Text('FIT'),
            ),
          ],
        ),
      ),
    );
  }
}

