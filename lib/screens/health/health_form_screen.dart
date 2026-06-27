// lib/screens/health/health_form_screen.dart
//
// Daily wellness check-in for the freelancer using the app. The questionnaire
// is defined entirely as data (`_healthSchema`) and rendered by the reusable
// [DynamicForm] engine, so questions can be added, removed or reordered without
// touching any widget code. Some questions appear conditionally based on earlier
// answers (e.g. follow-ups only show when stress is high), demonstrating the
// "dynamic" nature of the form.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker/models/health_form_field.dart';
import 'package:time_tracker/widgets/dynamic_form.dart';

/// One saved wellness check-in, kept in memory for the current session.
class HealthCheckIn {
  final DateTime timestamp;
  final Map<String, dynamic> answers;
  final int score;

  HealthCheckIn({
    required this.timestamp,
    required this.answers,
    required this.score,
  });
}

class HealthFormScreen extends StatefulWidget {
  const HealthFormScreen({super.key});

  @override
  State<HealthFormScreen> createState() => _HealthFormScreenState();
}

class _HealthFormScreenState extends State<HealthFormScreen> {
  // Check-ins recorded this session. In-memory only — there is no Drift table
  // for wellness data, so this intentionally does not survive an app restart.
  final List<HealthCheckIn> _history = [];

  /// The dynamic schema. Edit this list to change the questionnaire.
  static final List<HealthFormField> _healthSchema = [
    const HealthFormField(
      key: 'energy',
      label: 'Energy level',
      helperText: 'How energised do you feel today?',
      type: HealthFieldType.scale,
      min: 1,
      max: 10,
      defaultValue: 5,
      required: true,
    ),
    const HealthFormField(
      key: 'mood',
      label: 'Mood',
      type: HealthFieldType.choice,
      options: ['Great', 'Good', 'Okay', 'Low', 'Stressed'],
      required: true,
    ),
    const HealthFormField(
      key: 'sleepHours',
      label: 'Hours of sleep last night',
      type: HealthFieldType.number,
      unit: 'hrs',
      required: true,
    ),
    const HealthFormField(
      key: 'stress',
      label: 'Stress level',
      helperText: '1 = relaxed, 10 = overwhelmed',
      type: HealthFieldType.scale,
      min: 1,
      max: 10,
      defaultValue: 4,
      required: true,
    ),
    // Conditional: only asked when the user reports high stress.
    HealthFormField(
      key: 'stressFactors',
      label: 'What is driving the stress?',
      type: HealthFieldType.multiChoice,
      options: const [
        'Workload',
        'Deadlines',
        'Clients',
        'Finances',
        'Health',
        'Personal',
      ],
      visibleWhen: (answers) => ((answers['stress'] as double?) ?? 0) >= 7,
    ),
    const HealthFormField(
      key: 'exercised',
      label: 'Did you move / exercise today?',
      type: HealthFieldType.toggle,
    ),
    HealthFormField(
      key: 'activityMinutes',
      label: 'Active minutes',
      type: HealthFieldType.number,
      unit: 'min',
      // Conditional: only ask for minutes if they exercised.
      visibleWhen: (answers) => answers['exercised'] == true,
    ),
    const HealthFormField(
      key: 'tookBreaks',
      label: 'Took regular breaks from work',
      type: HealthFieldType.toggle,
    ),
    const HealthFormField(
      key: 'notes',
      label: 'Notes',
      helperText: 'Anything else worth remembering about today?',
      type: HealthFieldType.multiline,
    ),
  ];

  /// Derives a 0–100 wellness score from the answers. Higher is better.
  int _computeScore(Map<String, dynamic> answers) {
    double score = 0;

    // Energy (0–25): scaled from the 1–10 slider.
    final energy = (answers['energy'] as double?) ?? 5;
    score += (energy / 10) * 25;

    // Mood (0–25): mapped from the chosen label.
    const moodPoints = {
      'Great': 25.0,
      'Good': 20.0,
      'Okay': 14.0,
      'Low': 7.0,
      'Stressed': 3.0,
    };
    score += moodPoints[answers['mood']] ?? 12;

    // Sleep (0–25): peaks at 7–9 hours.
    final sleep = (answers['sleepHours'] as double?) ?? 0;
    if (sleep >= 7 && sleep <= 9) {
      score += 25;
    } else if (sleep >= 6 && sleep <= 10) {
      score += 18;
    } else if (sleep >= 5) {
      score += 10;
    } else {
      score += 4;
    }

    // Stress (0–15): inverse of the stress slider.
    final stress = (answers['stress'] as double?) ?? 5;
    score += ((10 - stress) / 10) * 15;

    // Healthy habits (0–10): bonus points for movement and breaks.
    if (answers['exercised'] == true) score += 6;
    if (answers['tookBreaks'] == true) score += 4;

    return score.round().clamp(0, 100);
  }

  void _handleSubmit(Map<String, dynamic> answers) {
    final score = _computeScore(answers);
    setState(() {
      _history.insert(
        0,
        HealthCheckIn(
          timestamp: DateTime.now(),
          answers: answers,
          score: score,
        ),
      );
    });
    _showResultDialog(score);
  }

  void _showResultDialog(int score) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check-in saved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: Theme.of(dialogContext)
                  .textTheme
                  .displayMedium
                  ?.copyWith(
                    color: _scoreColor(score),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Text('Wellness score'),
            const SizedBox(height: 12),
            Text(
              _scoreMessage(score),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return Colors.greenAccent;
    if (score >= 50) return Colors.amberAccent;
    return Colors.redAccent;
  }

  String _scoreMessage(int score) {
    if (score >= 75) return 'Looking strong — keep it up!';
    if (score >= 50) return 'Doing okay. Watch your rest and breaks.';
    return 'Take it easy today and prioritise recovery.';
  }

  void _startNewCheckIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Daily Check-in')),
          body: DynamicForm(
            fields: _healthSchema,
            submitLabel: 'Save Check-in',
            onSubmit: (answers) {
              Navigator.of(context).pop();
              _handleSubmit(answers);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _history.isEmpty
          ? _buildEmptyState()
          : _buildHistory(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewCheckIn,
        icon: const Icon(Icons.add),
        label: const Text('New Check-in'),
        heroTag: 'add_health_checkin',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No check-ins yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Log how you are feeling to track your wellbeing '
              'alongside your work.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final entry = _history[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _scoreColor(entry.score).withValues(alpha: 0.2),
              child: Text(
                '${entry.score}',
                style: TextStyle(
                  color: _scoreColor(entry.score),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '${entry.answers['mood'] ?? '—'} · '
              '${_formatNum(entry.answers['energy'])}/10 energy',
            ),
            subtitle: Text(
              DateFormat.yMMMEd().add_jm().format(entry.timestamp),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDetails(entry),
          ),
        );
      },
    );
  }

  void _showDetails(HealthCheckIn entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final rows = <Widget>[];
        for (final field in _healthSchema) {
          if (!entry.answers.containsKey(field.key)) continue;
          final value = entry.answers[field.key];
          if (value == null || (value is String && value.isEmpty)) continue;
          if (value is List && value.isEmpty) continue;
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      field.label,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(_formatValue(value)),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check-in · score ${entry.score}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              Text(
                DateFormat.yMMMEd().add_jm().format(entry.timestamp),
                style: const TextStyle(color: Colors.grey),
              ),
              const Divider(height: 24),
              ...rows,
            ],
          ),
        );
      },
    );
  }

  String _formatNum(dynamic value) {
    if (value is double) {
      return value == value.roundToDouble()
          ? value.round().toString()
          : value.toString();
    }
    return value?.toString() ?? '—';
  }

  String _formatValue(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) return value.join(', ');
    if (value is double) return _formatNum(value);
    return value.toString();
  }
}
