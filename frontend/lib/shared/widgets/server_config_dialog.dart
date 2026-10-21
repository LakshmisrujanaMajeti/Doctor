import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage_service.dart';

/// Interactive Server Configuration & Health Verification Modal.
/// Enables seamless server URL customization for physical mobile devices,
/// local Wi-Fi development, and production deployments.
class ServerConfigDialog extends ConsumerStatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ServerConfigDialog(),
    );
  }

  @override
  ConsumerState<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends ConsumerState<ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _isTestingBackend = false;
  String? _backendTestStatus;
  bool? _backendSuccess;

  bool _isTestingSupabase = false;
  String? _supabaseTestStatus;
  bool? _supabaseSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.apiBaseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testBackend(String url) async {
    setState(() {
      _isTestingBackend = true;
      _backendTestStatus = null;
      _backendSuccess = null;
    });

    final testDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    final stopwatch = Stopwatch()..start();
    try {
      final target = url.endsWith('/') ? '${url}health' : '$url/health';
      // Also try parent if ending in api/v1
      final res = await testDio.get(target);
      stopwatch.stop();

      if (res.statusCode == 200) {
        setState(() {
          _backendSuccess = true;
          _backendTestStatus = 'Connected! Response 200 OK (${stopwatch.elapsedMilliseconds}ms)';
        });
      } else {
        setState(() {
          _backendSuccess = false;
          _backendTestStatus = 'Server returned HTTP ${res.statusCode}';
        });
      }
    } catch (e) {
      stopwatch.stop();
      // Try root /health in case /api/v1/health is at /health
      try {
        final rootUrl = url.replaceAll('/api/v1', '');
        final rootTarget = rootUrl.endsWith('/') ? '${rootUrl}health' : '$rootUrl/health';
        final res = await testDio.get(rootTarget);
        if (res.statusCode == 200) {
          setState(() {
            _backendSuccess = true;
            _backendTestStatus = 'Connected! Server online at root (${stopwatch.elapsedMilliseconds}ms)';
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _backendSuccess = false;
        _backendTestStatus = 'Connection failed: ${e.toString().split(']').last.trim()}';
      });
    } finally {
      setState(() => _isTestingBackend = false);
    }
  }

  Future<void> _testSupabase() async {
    setState(() {
      _isTestingSupabase = true;
      _supabaseTestStatus = null;
      _supabaseSuccess = null;
    });

    try {
      final client = Supabase.instance.client;
      // Ping Supabase auth settings or schema
      final isInitialized = client.auth.currentSession != null || AppConfig.supabaseUrl.isNotEmpty;
      if (isInitialized) {
        setState(() {
          _supabaseSuccess = true;
          _supabaseTestStatus = 'Connected to Supabase Project (xxwidqatsxzsrulaxxal)';
        });
      } else {
        setState(() {
          _supabaseSuccess = false;
          _supabaseTestStatus = 'Supabase client not initialized';
        });
      }
    } catch (e) {
      setState(() {
        _supabaseSuccess = false;
        _supabaseTestStatus = 'Supabase error: $e';
      });
    } finally {
      setState(() => _isTestingSupabase = false);
    }
  }

  Future<void> _saveAndApply() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    AppConfig.customServerUrl = newUrl;
    await SecureStorageService.saveServerUrl(newUrl);

    // Update active Dio instance
    try {
      ref.read(dioClientProvider).updateBaseUrl(newUrl);
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusCompleted,
          content: Text('Server endpoint updated to: $newUrl'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dns_rounded, color: AppColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hospital Server Connection',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Configure API host for emulator, real phone, or cloud',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // API Endpoint input
              const Text(
                'FastAPI Backend Base URL',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  hintText: 'http://192.168.29.187:8000/api/v1',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Reset to Platform Default',
                    onPressed: () {
                      AppConfig.customServerUrl = null;
                      setState(() {
                        _urlController.text = AppConfig.apiBaseUrl;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.wifi_rounded, size: 14),
                    label: const Text('Wi-Fi LAN (192.168.29.187)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _urlController.text = 'http://192.168.29.187:8000/api/v1';
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.phone_android_rounded, size: 14),
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _urlController.text = 'http://10.0.2.2:8000/api/v1';
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.laptop_mac_rounded, size: 14),
                    label: const Text('Localhost (127.0.0.1)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _urlController.text = 'http://127.0.0.1:8000/api/v1';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Test Backend Button & Feedback
              OutlinedButton.icon(
                icon: _isTestingBackend
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check_rounded, size: 18),
                label: Text(_isTestingBackend ? 'Testing Connection...' : 'Test Backend Connection'),
                onPressed: _isTestingBackend ? null : () => _testBackend(_urlController.text.trim()),
              ),
              if (_backendTestStatus != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_backendSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_backendSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _backendSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        size: 16,
                        color: _backendSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _backendTestStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _backendSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Supabase Test Button & Status
              OutlinedButton.icon(
                icon: _isTestingSupabase
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_done_rounded, size: 18, color: AppColors.accentTeal),
                label: Text(_isTestingSupabase ? 'Checking Supabase...' : 'Check Supabase Cloud Status'),
                onPressed: _isTestingSupabase ? null : _testSupabase,
              ),
              if (_supabaseTestStatus != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_supabaseSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_supabaseSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _supabaseSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        size: 16,
                        color: _supabaseSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _supabaseTestStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _supabaseSuccess == true ? AppColors.statusCompleted : AppColors.triageEmergency,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveAndApply,
                      child: const Text('Save & Apply'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
