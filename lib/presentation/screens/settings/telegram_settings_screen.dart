import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/telegram_config.dart';
import '../../providers/telegram/telegram_provider.dart';

class TelegramSettingsScreen extends ConsumerWidget {
  const TelegramSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(telegramConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Telegram Notifications')),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load Telegram config: $error'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(telegramConfigProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (value) => _TelegramEditor(
          key: ValueKey('${value.botToken}-${value.chatId}'),
          initial: value,
        ),
      ),
    );
  }
}

class _TelegramEditor extends ConsumerStatefulWidget {
  final TelegramConfig initial;

  const _TelegramEditor({super.key, required this.initial});

  @override
  ConsumerState<_TelegramEditor> createState() => _TelegramEditorState();
}

class _TelegramEditorState extends ConsumerState<_TelegramEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _botToken;
  late final TextEditingController _chatId;
  late int _gracePeriod;
  late bool _oncePerDay;
  late bool _notifyConnect;
  late bool _notifyDisconnect;
  late bool _notifyNewDevice;
  late bool _notifyPolicyViolation;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _botToken = TextEditingController(text: value.botToken);
    _chatId = TextEditingController(text: value.chatId);
    _gracePeriod = value.gracePeriodMinutes;
    _oncePerDay = value.oncePerDay;
    _notifyConnect = value.notifyConnect;
    _notifyDisconnect = value.notifyDisconnect;
    _notifyNewDevice = value.notifyNewDevice;
    _notifyPolicyViolation = value.notifyPolicyViolation;
    _enabled = value.enabled;
  }

  TelegramConfig get _value => TelegramConfig(
    botToken: _botToken.text.trim(),
    chatId: _chatId.text.trim(),
    gracePeriodMinutes: _gracePeriod,
    oncePerDay: _oncePerDay,
    notifyConnect: _notifyConnect,
    notifyDisconnect: _notifyDisconnect,
    notifyNewDevice: _notifyNewDevice,
    notifyPolicyViolation: _notifyPolicyViolation,
    enabled: _enabled,
  );

  @override
  void dispose() {
    _botToken.dispose();
    _chatId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bot Configuration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: _botToken,
            decoration: const InputDecoration(
              labelText: 'Bot Token',
              hintText: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
              helperText: 'From @BotFather on Telegram',
            ),
            obscureText: true,
            maxLength: 64,
          ),
          TextFormField(
            controller: _chatId,
            decoration: const InputDecoration(
              labelText: 'Chat ID',
              hintText: '-1001234567890',
              helperText: 'Group chat ID or user ID',
            ),
            maxLength: 32,
          ),
          const SizedBox(height: 16),
          Text('Notification Rules', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Device connected to WiFi'),
            value: _notifyConnect,
            onChanged: (v) => setState(() => _notifyConnect = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Device disconnected'),
            value: _notifyDisconnect,
            onChanged: (v) => setState(() => _notifyDisconnect = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unknown device joined'),
            value: _notifyNewDevice,
            onChanged: (v) => setState(() => _notifyNewDevice = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Policy violation'),
            value: _notifyPolicyViolation,
            onChanged: (v) => setState(() => _notifyPolicyViolation = v),
          ),
          const SizedBox(height: 16),
          Text('Deduplication', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Once per day (per device)'),
            subtitle: const Text('Send only the first notification per device each day'),
            value: _oncePerDay,
            onChanged: (v) => setState(() => _oncePerDay = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Grace period (minutes)'),
            subtitle: Text('Skip duplicate notifications within $_gracePeriod min of the last one'),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                controller: TextEditingController(text: '$_gracePeriod'),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  suffixText: 'min',
                  isDense: true,
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) setState(() => _gracePeriod = parsed);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Enable', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Telegram notifications'),
            subtitle: const Text('Requires a valid bot token and chat ID'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              OutlinedButton.icon(
                onPressed: _enabled ? _test : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send test notification'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(telegramConfigProvider.notifier).save(_value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Telegram config saved' : 'Could not save configuration')),
    );
  }

  Future<void> _test() async {
    final error = await ref.read(telegramConfigProvider.notifier).test(
      botToken: _botToken.text.trim(),
      chatId: _chatId.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Test notification sent to Telegram!')),
    );
  }
}
