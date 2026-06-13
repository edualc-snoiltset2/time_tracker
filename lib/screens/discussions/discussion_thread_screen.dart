// lib/screens/discussions/discussion_thread_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

/// Shows a single discussion topic and its posts (oldest first), with an inline
/// composer to reply. Teacher posts are visually highlighted.
class DiscussionThreadScreen extends StatefulWidget {
  final Discussion discussion;
  const DiscussionThreadScreen({super.key, required this.discussion});

  @override
  State<DiscussionThreadScreen> createState() => _DiscussionThreadScreenState();
}

class _DiscussionThreadScreenState extends State<DiscussionThreadScreen> {
  final _replyFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  final List<String> _roles = ['Student', 'Teacher'];
  String? _selectedRole;

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_replyFormKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);

      await db.into(db.discussionPosts).insert(
            DiscussionPostsCompanion(
              discussionId: drift.Value(widget.discussion.id),
              authorName: drift.Value(_nameController.text),
              authorRole: drift.Value(_selectedRole!),
              content: drift.Value(_messageController.text),
              createdAt: drift.Value(DateTime.now()),
            ),
          );

      // Keep the name/role for convenience, clear just the message.
      _messageController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.discussion.title)),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.forum),
              title: Text(widget.discussion.title),
              subtitle: Text(
                  'Started by ${widget.discussion.createdBy} (${widget.discussion.authorRole})'),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DiscussionPost>>(
              stream: (db.select(db.discussionPosts)
                    ..where((p) =>
                        p.discussionId.equals(widget.discussion.id))
                    ..orderBy([(p) => drift.OrderingTerm.asc(p.createdAt)]))
                  .watch(),
              builder: (context, snapshot) {
                final posts = snapshot.data ?? [];
                if (posts.isEmpty &&
                    snapshot.connectionState == ConnectionState.active) {
                  return const Center(child: Text('No replies yet.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isTeacher = post.authorRole == 'Teacher';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      color: isTeacher
                          ? Colors.tealAccent.withAlpha(38)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${post.authorName} • ${post.authorRole}',
                              style: TextStyle(
                                fontWeight: isTeacher
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isTeacher ? Colors.tealAccent : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(post.content),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat.yMd().add_jm().format(post.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                key: _replyFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration:
                                const InputDecoration(labelText: 'Your Name'),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration:
                                const InputDecoration(labelText: 'Role'),
                            items: _roles
                                .map((r) => DropdownMenuItem(
                                    value: r, child: Text(r)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedRole = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                                labelText: 'Write a reply…'),
                            maxLines: 2,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.send),
                          onPressed: _sendReply,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
