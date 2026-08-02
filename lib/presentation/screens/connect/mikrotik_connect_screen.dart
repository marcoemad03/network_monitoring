import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_container.dart';
import '../../providers/device/device_provider.dart';
import '../../router/route_names.dart';

class MikroTikConnectScreen extends ConsumerStatefulWidget {
  const MikroTikConnectScreen({super.key});

  @override
  ConsumerState<MikroTikConnectScreen> createState() =>
      _MikroTikConnectScreenState();
}

class _MikroTikConnectScreenState extends ConsumerState<MikroTikConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _routerIPController = TextEditingController();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  int _apiPort = 8728;
  bool _connecting = false;
  bool _obscurePassword = true;
  bool _buttonEnabled = false;
  String? _statusCode;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _loadSavedCredentials();
    if (mounted) {
      setState(() {
        _statusCode = null;
        _statusMessage = null;
      });
    }
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _buttonEnabled = true);
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final secureStorage = ref.read(secureStorageProvider);
    final savedRouterIp = prefs.getString('mikrotik_router_ip') ?? '';
    final savedUsername = prefs.getString('mikrotik_username') ?? 'admin';
    final savedPort = prefs.getInt('mikrotik_api_port') ?? 8728;
    final savedPassword = await secureStorage.read('mikrotik_password');

    if (!mounted) return;
    setState(() {
      _routerIPController.text = savedRouterIp;
      _usernameController.text = savedUsername;
      _apiPort = savedPort;
      if (savedPassword != null && savedPassword.isNotEmpty) {
        _passwordController.text = savedPassword;
      }
    });
  }

  @override
  void dispose() {
    _routerIPController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _connecting = true;
      _statusCode = 'CONNECTING';
      _statusMessage = 'Connecting to the MikroTik RouterOS API...';
    });

    try {
      final result = await ref
          .read(deviceRemoteDataSourceProvider)
          .connectDevelopmentMikroTik(
            routerIP: _routerIPController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            apiPort: _apiPort,
          );
      final connection = result.connectionEntity;
      if (!mounted) return;
      setState(() {
        _statusCode = connection.code;
        _statusMessage = connection.message;
      });
      if (!connection.reachable) return;

      final prefs = ref.read(sharedPreferencesProvider);
      final secureStorage = ref.read(secureStorageProvider);
      await prefs.setString(
        'mikrotik_router_ip',
        _routerIPController.text.trim(),
      );
      await prefs.setString(
        'mikrotik_username',
        _usernameController.text.trim(),
      );
      await prefs.setInt('mikrotik_api_port', _apiPort);
      await secureStorage.write('mikrotik_password', _passwordController.text);
      ref.invalidate(connectedDevicesProvider);
      if (mounted) context.go(RouteNames.connectedDevices);
    } on DioException catch (error) {
      final data = error.response?.data;
      final message =
          data is Map
              ? data['message']?.toString()
              : 'Hospital NMS server is unreachable on the local network';
      if (mounted) {
        setState(() {
          _statusCode = 'LOCAL_SERVER_UNREACHABLE';
          _statusMessage =
              message ??
              'Hospital NMS server is unreachable on the local network';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusCode = 'ROUTER_ERROR';
          _statusMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed =
        _statusCode != null &&
        _statusCode != 'CONNECTING' &&
        _statusCode != 'CONNECTED';
    return Scaffold(
      body: LayoutBuilder(
        builder:
            (context, constraints) => Row(
              children: [
                if (constraints.maxWidth >= 850)
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: const Color(0xFF102A2A),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.router,
                                size: 64,
                                color: Color(0xFF72D6C9),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Hospital Network\nCommand Center',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Development mode connects through the local Hospital NMS server directly to RouterOS. No Internet service or user login is required.',
                                style: TextStyle(
                                  color: Color(0xFFB5CECA),
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const _Feature(
                                icon: Icons.lock_open,
                                text: 'JWT disabled locally',
                              ),
                              const _Feature(
                                icon: Icons.lan,
                                text: 'LAN RouterOS connection',
                              ),
                              const _Feature(
                                icon: Icons.filter_alt,
                                text: '172.16.0.0/24 devices only',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 600 ? 20 : 40,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Connect to MikroTik',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter the RouterOS API credentials configured on the hospital LAN.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 32),
                              TextFormField(
                                controller: _routerIPController,

                                decoration: const InputDecoration(
                                  labelText: 'Router IP',
                                  hintText: '172.16.0.1',
                                  prefixIcon: Icon(Icons.router_outlined),
                                ),
                                validator:
                                    (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Router IP is required'
                                            : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator:
                                    (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Username is required'
                                            : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(
                                    Icons.password_outlined,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed:
                                        () => setState(
                                          () =>
                                              _obscurePassword =
                                                  !_obscurePassword,
                                        ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _loadSavedCredentials,
                                icon: const Icon(Icons.restore),
                                label: const Text('Reload saved credentials'),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _apiPort,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'API Port',
                                  prefixIcon: Icon(Icons.settings_ethernet),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 8728,
                                    child: Text('8728 - RouterOS API'),
                                  ),
                                  DropdownMenuItem(
                                    value: 8729,
                                    child: Text('8729 - RouterOS API TLS'),
                                  ),
                                ],
                                onChanged:
                                    _connecting
                                        ? null
                                        : (value) => _apiPort = value ?? 8728,
                              ),
                              if (_statusMessage != null) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: (failed ? Colors.red : Colors.teal)
                                        .withValues(alpha: .08),
                                    border: Border.all(
                                      color: (failed ? Colors.red : Colors.teal)
                                          .withValues(alpha: .35),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      if (_connecting)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Icon(
                                          failed
                                              ? Icons.router_outlined
                                              : Icons.router,
                                          color:
                                              failed ? Colors.red : Colors.teal,
                                        ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _statusMessage!,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              _statusCode!.replaceAll('_', ' '),
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed:
                                    _connecting || !_buttonEnabled
                                        ? null
                                        : () {
                                          _connect();
                                        },
                                icon: const Icon(Icons.cable),
                                label: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    _connecting
                                        ? 'Testing RouterOS API...'
                                        : 'Test and Connect',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF72D6C9), size: 20),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );
}
