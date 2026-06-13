// lib/screens/discussions/new_discussion_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

/// Form to start a new class discussion topic. The opening message is saved as
/// the thread's first post so the topic and its first message share a timestamp.
class NewDiscussionScreen extends StatefulWidget {
  const NewDiscussionScreen({super.key});

  @override
  State<NewDiscussionScreen> createState() => _NewDiscussionScreenState();
}

class _NewDiscussionScreenState extends State<NewDiscussionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorNameController = TextEditingController();
  final _messageController = TextEditingController();

  final List<String> _roles = ['Student', 'Teacher'];
  String? _selectedRole;

  @override
  void dispose() {
    _titleController.dispose();
    _authorNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final navigator = Navigator.of(context);
      final db = Provider.of<AppDatabase>(context, listen: false);

      // Reuse one timestamp so the topic and its opening post line up.
      final now = DateTime.now();
      final name = _authorNameController.text;
      final role = _selectedRole!;

      final discussionId = await db.into(db.discussions).insert(
            DiscussionsCompanion(
              title: drift.Value(_titleController.text),
              createdBy: drift.Value(name),
              authorRole: drift.Value(role),
              createdAt: drift.Value(now),
            ),
          );

      await db.into(db.discussionPosts).insert(
            DiscussionPostsCompanion(
              discussionId: drift.Value(discussionId),
              authorName: drift.Value(name),
              authorRole: drift.Value(role),
              content: drift.Value(_messageController.text),
              createdAt: drift.Value(now),
            ),
          );

      if (mounted) {
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Discussion'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Topic Title'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter a title.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _authorNameController,
              decoration: const InputDecoration(labelText: 'Your Name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter your name.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedRole = v),
              validator: (v) => v == null ? 'Please select a role.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 4,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter a message.' : null,
            ),
          ],
        ),
      ),
    );
  }
}
