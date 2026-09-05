import 'package:flutter/material.dart';
import '../../data/services/strava_service.dart';

class StravaAuthDialog extends StatefulWidget {
  final VoidCallback onConnectionChanged;

  const StravaAuthDialog({super.key, required this.onConnectionChanged});

  @override
  State<StravaAuthDialog> createState() => _StravaAuthDialogState();
}

class _StravaAuthDialogState extends State<StravaAuthDialog> {
  final _stravaService = StravaService.instance;
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  late final TextEditingController _authCodeController;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final creds = _stravaService.credentials;
    _clientIdController = TextEditingController(text: creds?.clientId ?? '');
    _clientSecretController = TextEditingController(text: creds?.clientSecret ?? '');
    _authCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _authCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAndLaunchOAuth() async {
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      setState(() => _errorMessage = 'Please provide both Client ID and Client Secret.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _stravaService.saveClientCredentials(clientId, clientSecret);
      await _stravaService.launchAuthInBrowser(redirectUri: 'http://localhost');
      setState(() {
        _isLoading = false;
        _successMessage = 'Browser opened! Log into Strava, click Authorize, then copy the "code=" parameter from the resulting URL into the box below.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _submitAuthCode() async {
    String rawCode = _authCodeController.text.trim();
    if (rawCode.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste the authorization code.');
      return;
    }

    // Extract code if user pasted entire URL (e.g. http://localhost/?code=xyz&scope=...)
    if (rawCode.contains('code=')) {
      final uri = Uri.tryParse(rawCode);
      if (uri != null && uri.queryParameters.containsKey('code')) {
        rawCode = uri.queryParameters['code']!;
      } else {
        final match = RegExp(r'code=([^&]+)').firstMatch(rawCode);
        if (match != null) rawCode = match.group(1)!;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _stravaService.authenticateWithCode(rawCode);
      widget.onConnectionChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to Strava as ${_stravaService.credentials?.athleteName ?? "Athlete"}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication failed: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await _stravaService.disconnect();
    widget.onConnectionChanged();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from Strava.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _stravaService.isConnected;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFC4C02).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFFFC4C02)),
          ),
          const SizedBox(width: 10),
          const Text('Strava Integration'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isConnected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Connected Account', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _stravaService.credentials?.athleteName ?? 'Strava Athlete',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account is connected. You can now use 1-tap background syncing for new Huawei workouts.',
                style: TextStyle(fontSize: 13),
              ),
            ] else ...[
              const Text(
                'Connect your Strava account to enable 1-tap bulk uploads and automatic deduplication.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Strava Client ID',
                  hintText: 'e.g. 123456',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientSecretController,
                decoration: const InputDecoration(
                  labelText: 'Strava Client Secret',
                  hintText: 'e.g. 789abc...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('1. Authorize in Browser'),
                  onPressed: _isLoading ? null : _saveAndLaunchOAuth,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _authCodeController,
                decoration: const InputDecoration(
                  labelText: '2. Authorization Code or Redirect URL',
                  hintText: 'Paste code or redirect URL here',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFC4C02)),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('3. Complete Connection'),
                  onPressed: _isLoading ? null : _submitAuthCode,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              Text(_successMessage!, style: const TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        if (isConnected)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _disconnect,
            child: const Text('Disconnect'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
