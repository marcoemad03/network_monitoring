import 'package:flutter/material.dart';
import 'marco_style.dart';

/// What the create or edit dialog returns.
class GroupFormResult {
  final String name;
  final String description;
  final String color;
  final String icon;
  final Map<String, dynamic>? policy;
  const GroupFormResult({required this.name, required this.description, required this.color, required this.icon, this.policy});
}

/// Create a group (with a starting template) or edit its name, color and icon.
Future<GroupFormResult?> showGroupFormDialog(
  BuildContext context, {
  bool creating = true,
  String name = '',
  String description = '',
  String color = 'blue',
  String icon = 'group',
  Set<String> existingNames = const {},
  String initialTemplate = 'blank',
}) {
  return showDialog<GroupFormResult>(
    context: context,
    builder: (_) => _GroupForm(creating: creating, name: name, description: description, color: color, icon: icon, existingNames: existingNames, initialTemplate: initialTemplate),
  );
}

class _GroupForm extends StatefulWidget {
  const _GroupForm({required this.creating, required this.name, required this.description, required this.color, required this.icon, required this.existingNames, this.initialTemplate = 'blank'});
  final bool creating;
  final String name;
  final String description;
  final String color;
  final String icon;
  final Set<String> existingNames;
  final String initialTemplate;

  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  late final TextEditingController _name = TextEditingController(text: widget.name);
  late final TextEditingController _description = TextEditingController(text: widget.description);
  late String _color = widget.color;
  late String _icon = widget.icon;
  late String _template = widget.initialTemplate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = groupTemplates.firstWhere((t) => t.key == widget.initialTemplate, orElse: () => groupTemplates.first);
    if (widget.creating && t.key != 'blank') {
      _color = t.color;
      _icon = t.groupIcon;
      if (_name.text.isEmpty) _name.text = t.label;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _pickTemplate(GroupTemplate t) {
    setState(() {
      _template = t.key;
      _color = t.color;
      _icon = t.groupIcon;
      if (_name.text.trim().isEmpty && t.key != 'blank') _name.text = t.label;
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the group a name');
      return;
    }
    if (widget.existingNames.contains(name.toLowerCase())) {
      setState(() => _error = 'A group with this name already exists');
      return;
    }
    final template = groupTemplates.firstWhere((t) => t.key == _template);
    Navigator.pop(
      context,
      GroupFormResult(
        name: name,
        description: _description.text.trim(),
        color: _color,
        icon: _icon,
        policy: widget.creating && template.policy.isNotEmpty ? Map<String, dynamic>.from(template.policy) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.creating ? 'New group' : 'Edit group'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.creating) ...[
                Text('Start from', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in groupTemplates)
                      ChoiceChip(
                        avatar: Icon(t.icon, size: 18),
                        label: Text(t.label),
                        selected: _template == t.key,
                        onSelected: (_) => _pickTemplate(t),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(groupTemplates.firstWhere((t) => t.key == _template).description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 60,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Group name', hintText: 'For example: Emergency ward', errorText: _error, border: const OutlineInputBorder()),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Text('Color', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in marcoColorNames)
                    Semantics(
                      button: true,
                      selected: _color == c,
                      label: c,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: marcoColor(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: _color == c ? theme.colorScheme.onSurface : Colors.transparent, width: 2.5),
                          ),
                          child: _color == c ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Icon', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in marcoIconNames)
                    ChoiceChip(
                      avatar: Icon(marcoIcon(i), size: 18),
                      label: Text(marcoIconLabel(i)),
                      selected: _icon == i,
                      onSelected: (_) => setState(() => _icon = i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.creating ? 'Create group' : 'Save')),
      ],
    );
  }
}
