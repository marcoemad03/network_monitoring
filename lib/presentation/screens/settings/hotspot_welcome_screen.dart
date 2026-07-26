import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/hotspot_welcome_config.dart';
import '../../providers/hotspot/hotspot_welcome_provider.dart';

class HotspotWelcomeScreen extends ConsumerWidget {
  const HotspotWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(hotspotWelcomeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hotspot Welcome Page')),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load the welcome page: $error'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(hotspotWelcomeProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (value) => _HotspotEditor(
          key: ValueKey('${value.hospitalName}-${value.primaryColor}'),
          initial: value,
        ),
      ),
    );
  }
}

class _HotspotEditor extends ConsumerStatefulWidget {
  final HotspotWelcomeConfig initial;

  const _HotspotEditor({super.key, required this.initial});

  @override
  ConsumerState<_HotspotEditor> createState() => _HotspotEditorState();
}

class _HotspotEditorState extends ConsumerState<_HotspotEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hospital;
  late final TextEditingController _logo;
  late final TextEditingController _primary;
  late final TextEditingController _accent;
  late final TextEditingController _message;
  late final TextEditingController _announcements;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _hospital = TextEditingController(text: value.hospitalName);
    _logo = TextEditingController(text: value.logoUrl);
    _primary = TextEditingController(text: value.primaryColor);
    _accent = TextEditingController(text: value.accentColor);
    _message = TextEditingController(text: value.welcomeMessage);
    _announcements = TextEditingController(
      text: value.announcements.join('\n'),
    );
    _enabled = value.enabled;
  }

  HotspotWelcomeConfig get _value => HotspotWelcomeConfig(
    hospitalName: _hospital.text.trim(),
    logoUrl: _logo.text.trim(),
    primaryColor: _primary.text.trim(),
    accentColor: _accent.text.trim(),
    welcomeMessage: _message.text.trim(),
    announcements: _announcements.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(),
    enabled: _enabled,
  );

  @override
  void dispose() {
    for (final controller in [
      _hospital,
      _logo,
      _primary,
      _accent,
      _message,
      _announcements,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final editor = _buildEditor(context);
        final preview = _WelcomePreview(config: _value);
        if (constraints.maxWidth < 900) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [editor, const SizedBox(height: 24), preview],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: editor,
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: preview,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditor(BuildContext context) {
    String? colorValidator(String? value) =>
        RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value ?? '')
        ? null
        : 'Use #RRGGBB';
    return Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Brand and content', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hospital,
            decoration: const InputDecoration(labelText: 'Hospital name'),
            maxLength: 200,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Hospital name is required'
                : null,
          ),
          TextFormField(
            controller: _logo,
            decoration: const InputDecoration(
              labelText: 'Logo URL or hotspot-relative path',
              hintText: 'https://example.org/logo.png or images/logo.png',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _primary,
                  decoration: const InputDecoration(labelText: 'Primary color'),
                  validator: colorValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _accent,
                  decoration: const InputDecoration(labelText: 'Accent color'),
                  validator: colorValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _message,
            decoration: const InputDecoration(labelText: 'Welcome message'),
            minLines: 2,
            maxLines: 4,
          ),
          TextFormField(
            controller: _announcements,
            decoration: const InputDecoration(
              labelText: 'Announcements',
              helperText: 'One announcement per line',
            ),
            minLines: 3,
            maxLines: 6,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Welcome page enabled'),
            subtitle: const Text('Disabled pages show an unavailable message instead of login fields.'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save configuration'),
              ),
              OutlinedButton.icon(
                onPressed: _showGeneratedHtml,
                icon: const Icon(Icons.code),
                label: const Text('Generate login.html'),
              ),
              OutlinedButton.icon(
                onPressed: _showRouterSetup,
                icon: const Icon(Icons.router_outlined),
                label: const Text('Configure RouterOS profile'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'RouterOS v6 note: profile setup can change html-directory through the native API, but it cannot safely upload this file. Transfer the generated login.html to that RouterOS Files directory separately.',
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(hotspotWelcomeProvider.notifier).save(_value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Welcome page saved' : 'Could not save welcome page')),
    );
  }

  Future<void> _showGeneratedHtml() async {
    try {
      final html = await ref.read(hotspotWelcomeProvider.notifier).generateLoginHtml();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generated login.html'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(child: SelectableText(html)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showRouterSetup() async {
    final endpoint = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final profile = TextEditingController(text: 'default');
    final directory = TextEditingController(text: 'hotspot');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Configure RouterOS hotspot profile'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: endpoint, decoration: const InputDecoration(labelText: 'API endpoint', hintText: '192.168.88.1:8728')),
              TextField(controller: username, decoration: const InputDecoration(labelText: 'RouterOS username')),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'RouterOS password')),
              TextField(controller: profile, decoration: const InputDecoration(labelText: 'Hotspot profile name')),
              TextField(controller: directory, decoration: const InputDecoration(labelText: 'HTML directory')),
              const SizedBox(height: 12),
              const Text('This changes only html-directory. It does not upload login.html.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                final result = await ref.read(hotspotWelcomeProvider.notifier).configureProfile(
                  endpoint: endpoint.text,
                  username: username.text,
                  password: password.text,
                  profile: profile.text,
                  htmlDirectory: directory.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
              } catch (error) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error')));
              }
            },
            child: const Text('Configure profile'),
          ),
        ],
      ),
    );
    endpoint.dispose(); username.dispose(); password.dispose(); profile.dispose(); directory.dispose();
  }
}

class _WelcomePreview extends StatelessWidget {
  final HotspotWelcomeConfig config;

  const _WelcomePreview({required this.config});

  Color _color(String value, Color fallback) {
    final hex = value.replaceFirst('#', '');
    return hex.length == 6 ? Color(int.parse('FF$hex', radix: 16)) : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final primary = _color(config.primaryColor, Colors.teal);
    final accent = _color(config.accentColor, Colors.amber);
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 28)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (config.logoUrl.isNotEmpty && Uri.tryParse(config.logoUrl)?.isAbsolute == true)
            Image.network(config.logoUrl, height: 64, errorBuilder: (_, _, _) => const Icon(Icons.local_hospital, size: 54)),
          Text(config.hospitalName, textAlign: TextAlign.center, style: TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${DateTime.now().toLocal()}'.split('.').first, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          const SizedBox(height: 16),
          const Text('Good afternoon, Guest', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(config.welcomeMessage, style: const TextStyle(color: Color(0xFF17324D))),
          if (config.announcements.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), border: Border(left: BorderSide(color: accent, width: 4))),
              child: Text(config.announcements.join('\n'), style: const TextStyle(color: Color(0xFF17324D))),
            ),
          ],
          const SizedBox(height: 16),
          if (config.enabled) ...[
            const TextField(enabled: false, decoration: InputDecoration(labelText: 'Username')),
            const SizedBox(height: 10),
            const TextField(enabled: false, obscureText: true, decoration: InputDecoration(labelText: 'Password')),
            const SizedBox(height: 16),
            FilledButton(onPressed: null, style: FilledButton.styleFrom(disabledBackgroundColor: accent, disabledForegroundColor: Colors.black87), child: const Text('Connect securely')),
          ] else
            const Text('Guest Wi-Fi access is currently unavailable.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
