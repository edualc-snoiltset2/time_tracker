// lib/widgets/dynamic_form.dart
//
// Renders a form dynamically from a list of [HealthFormField] definitions and
// reports answers back to the parent. The widget has no knowledge of what is
// being asked — it simply maps each field type to an appropriate input control,
// re-evaluates conditional visibility on every change and validates required
// fields. Reusable for any data-driven questionnaire, not just the health form.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:time_tracker/models/health_form_field.dart';

class DynamicForm extends StatefulWidget {
  /// The schema describing which questions to render and in what order.
  final List<HealthFormField> fields;

  /// Called whenever any answer changes, with a copy of the current answers.
  final ValueChanged<Map<String, dynamic>>? onChanged;

  /// Called with the validated answers when [submitLabel] is pressed.
  final ValueChanged<Map<String, dynamic>> onSubmit;

  final String submitLabel;

  const DynamicForm({
    super.key,
    required this.fields,
    required this.onSubmit,
    this.onChanged,
    this.submitLabel = 'Submit',
  });

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _answers[field.key] = field.initialValue;
      if (_needsController(field.type)) {
        _controllers[field.key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _needsController(HealthFieldType type) =>
      type == HealthFieldType.text ||
      type == HealthFieldType.multiline ||
      type == HealthFieldType.number;

  bool _isVisible(HealthFormField field) =>
      field.visibleWhen == null || field.visibleWhen!(_answers);

  void _setAnswer(String key, dynamic value) {
    setState(() => _answers[key] = value);
    widget.onChanged?.call(Map.of(_answers));
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required fields.')),
      );
      return;
    }
    // Only return answers for fields that are currently visible — hidden
    // conditional fields should not leak stale values into the result.
    final result = <String, dynamic>{};
    for (final field in widget.fields) {
      if (_isVisible(field)) result[field.key] = _answers[field.key];
    }
    widget.onSubmit(result);
  }

  @override
  Widget build(BuildContext context) {
    final visibleFields = widget.fields.where(_isVisible).toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          for (final field in visibleFields) ...[
            _buildField(field),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _handleSubmit,
            icon: const Icon(Icons.check),
            label: Text(widget.submitLabel),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(HealthFormField field) {
    switch (field.type) {
      case HealthFieldType.text:
      case HealthFieldType.multiline:
        return _buildText(field);
      case HealthFieldType.number:
        return _buildNumber(field);
      case HealthFieldType.scale:
        return _buildScale(field);
      case HealthFieldType.toggle:
        return _buildToggle(field);
      case HealthFieldType.choice:
        return _buildChoice(field);
      case HealthFieldType.multiChoice:
        return _buildMultiChoice(field);
    }
  }

  String? _requiredValidator(HealthFormField field, String? value) {
    if (field.required && (value == null || value.trim().isEmpty)) {
      return 'Required';
    }
    return null;
  }

  Widget _buildText(HealthFormField field) {
    return TextFormField(
      controller: _controllers[field.key],
      maxLines: field.type == HealthFieldType.multiline ? 4 : 1,
      decoration: InputDecoration(
        labelText: _labelFor(field),
        helperText: field.helperText,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => _requiredValidator(field, value),
      onChanged: (value) => _setAnswer(field.key, value),
    );
  }

  Widget _buildNumber(HealthFormField field) {
    return TextFormField(
      controller: _controllers[field.key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: _labelFor(field),
        helperText: field.helperText,
        suffixText: field.unit,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final base = _requiredValidator(field, value);
        if (base != null) return base;
        if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
          return 'Enter a valid number';
        }
        return null;
      },
      onChanged: (value) => _setAnswer(field.key, double.tryParse(value)),
    );
  }

  Widget _buildScale(HealthFormField field) {
    final value = (_answers[field.key] as double?) ?? field.min;
    final divisions = (field.max - field.min).round();
    final suffix = field.unit != null ? ' ${field.unit}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_labelFor(field), style: Theme.of(context).textTheme.titleMedium),
        if (field.helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              field.helperText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(field.min, field.max).toDouble(),
                min: field.min,
                max: field.max,
                divisions: divisions > 0 ? divisions : null,
                label: '${value.round()}$suffix',
                onChanged: (v) => _setAnswer(field.key, v),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${value.round()}$suffix',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggle(HealthFormField field) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(field.label),
      subtitle: field.helperText != null ? Text(field.helperText!) : null,
      value: (_answers[field.key] as bool?) ?? false,
      onChanged: (v) => _setAnswer(field.key, v),
    );
  }

  Widget _buildChoice(HealthFormField field) {
    return DropdownButtonFormField<String>(
      initialValue: _answers[field.key] as String?,
      decoration: InputDecoration(
        labelText: _labelFor(field),
        helperText: field.helperText,
        border: const OutlineInputBorder(),
      ),
      items: field.options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      validator: (value) =>
          field.required && value == null ? 'Required' : null,
      onChanged: (v) => _setAnswer(field.key, v),
    );
  }

  Widget _buildMultiChoice(HealthFormField field) {
    final selected = (_answers[field.key] as List).cast<String>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_labelFor(field), style: Theme.of(context).textTheme.titleMedium),
        if (field.helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              field.helperText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: field.options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (value) {
                final next = List<String>.from(selected);
                value ? next.add(option) : next.remove(option);
                _setAnswer(field.key, next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  String _labelFor(HealthFormField field) =>
      field.required ? '${field.label} *' : field.label;
}
