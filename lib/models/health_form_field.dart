// lib/models/health_form_field.dart
//
// Data model that powers the *dynamic* health form. A form is described as a
// plain list of [HealthFormField] definitions; the UI in
// `lib/widgets/dynamic_form.dart` renders whatever fields it is given, so the
// questionnaire can be changed by editing data alone — no widget code changes.

import 'package:flutter/material.dart';

/// The kinds of input a [HealthFormField] can render.
enum HealthFieldType {
  /// Single line of free text.
  text,

  /// Multi-line free text.
  multiline,

  /// Numeric entry (integers or decimals).
  number,

  /// Integer slider between [HealthFormField.min] and [HealthFormField.max].
  scale,

  /// On/off switch. Stored as a [bool].
  toggle,

  /// Single choice from [HealthFormField.options] (dropdown).
  choice,

  /// Any number of choices from [HealthFormField.options] (filter chips).
  multiChoice,
}

/// Declarative description of one question in a dynamic form.
///
/// Instances are immutable and contain everything the renderer needs: the input
/// type, label, validation rules, the options for choice fields and an optional
/// [visibleWhen] predicate that makes a field appear conditionally based on the
/// answers given to earlier fields.
class HealthFormField {
  /// Stable identifier used as the key in the answers map.
  final String key;

  final String label;
  final String? helperText;
  final HealthFieldType type;

  /// Whether an answer is required for the form to validate.
  final bool required;

  /// Bounds and default for [HealthFieldType.scale].
  final double min;
  final double max;
  final double? defaultValue;

  /// Options for [HealthFieldType.choice] / [HealthFieldType.multiChoice].
  final List<String> options;

  /// Optional unit suffix shown for numeric / scale fields (e.g. "hrs").
  final String? unit;

  /// Predicate controlling conditional visibility. Receives the current answers
  /// map and returns `true` when the field should be shown. When `null` the
  /// field is always visible.
  final bool Function(Map<String, dynamic> answers)? visibleWhen;

  const HealthFormField({
    required this.key,
    required this.label,
    required this.type,
    this.helperText,
    this.required = false,
    this.min = 0,
    this.max = 10,
    this.defaultValue,
    this.options = const [],
    this.unit,
    this.visibleWhen,
  });

  /// The value used to seed the answers map before the user interacts.
  dynamic get initialValue {
    switch (type) {
      case HealthFieldType.toggle:
        return false;
      case HealthFieldType.scale:
        return defaultValue ?? ((min + max) / 2).roundToDouble();
      case HealthFieldType.multiChoice:
        return <String>[];
      case HealthFieldType.text:
      case HealthFieldType.multiline:
      case HealthFieldType.number:
      case HealthFieldType.choice:
        return null;
    }
  }
}
