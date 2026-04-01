import 'dart:convert';

import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:workspace_fs/workspace_fs.dart';

import '../../services/agents_repository_factory.dart';

/// Screen for viewing and managing sub-agents.
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _promptController = TextEditingController();

  AgentsRepository? _repository;
  bool _loading = true;
  bool _saving = false;
  String _model = AgentDefinition.allowedModels.first;

  @override
  void initState() {
    super.initState();
    _loadRepository();
  }

  Future<void> _loadRepository() async {
    final repo = await createAgentsRepository();
    if (!mounted) return;
    setState(() {
      _repository = repo;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Name is required';
    final pattern = RegExp(r'^[a-z][a-z0-9\-]*$');
    if (!pattern.hasMatch(value)) {
      return 'Use lowercase letters, digits, and hyphens';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if (value == null || value.isEmpty) return 'Description is required';
    if (value.length > 100) return 'Description must be ≤ 100 characters';
    return null;
  }

  Future<void> _saveAgent() async {
    final repo = _repository;
    if (repo == null) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final agent = AgentDefinition(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      model: _model,
      systemPrompt: _promptController.text.trim(),
    );
    final errors = agent.validate();
    if (errors.isNotEmpty) {
      _showSnack(errors.join('\n'));
      return;
    }

    setState(() => _saving = true);
    try {
      if (await repo.exists(agent.name)) {
        _showSnack('Agent "${agent.name}" already exists.');
        return;
      }
      final content = AgentFileCodec.encode(agent);
      await repo.saveAgent(agent.name, content);
      _onAgentPersisted(agent);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importAgent() async {
    final repo = _repository;
    if (repo == null || _saving) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null) {
      _showSnack('Unable to read selected file.');
      return;
    }

    final content = utf8.decode(file.bytes!);
    try {
      final definition = AgentFileCodec.decode(content);
      final errors = definition.validate();
      if (errors.isNotEmpty) {
        _showSnack(errors.join('\n'));
        return;
      }
      if (await repo.exists(definition.name)) {
        _showSnack('Agent "${definition.name}" already exists.');
        return;
      }
      await repo.saveAgent(definition.name, content);
      _onAgentPersisted(definition);
    } catch (e) {
      _showSnack('Invalid agent file: $e');
    }
  }

  void _onAgentPersisted(AgentDefinition agent) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved @${agent.name}')),
    );
    Navigator.pop(context, agent);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      body: Padding(
        padding: const EdgeInsets.all(BricksSpacing.md),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. research-analyst',
                ),
                validator: _validateName,
                enabled: !_saving,
              ),
              const SizedBox(height: BricksSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Short summary (≤ 100 characters)',
                ),
                maxLength: 100,
                validator: _validateDescription,
                enabled: !_saving,
              ),
              const SizedBox(height: BricksSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _model,
                decoration: const InputDecoration(
                  labelText: 'Model',
                ),
                items: AgentDefinition.allowedModels
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _model = value ?? _model),
              ),
              const SizedBox(height: BricksSpacing.md),
              TextFormField(
                controller: _promptController,
                decoration: const InputDecoration(
                  labelText: 'System Prompt',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                minLines: 4,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Prompt is required'
                    : null,
                enabled: !_saving,
              ),
              const SizedBox(height: BricksSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _saving ? null : _saveAgent,
                      label: Text(_saving ? 'Saving…' : 'Save Agent'),
                    ),
                  ),
                  const SizedBox(width: BricksSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined),
                    onPressed: _saving ? null : _importAgent,
                    label: const Text('Import .md'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
