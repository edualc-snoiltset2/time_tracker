// lib/screens/discussions/discussions_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:time_tracker/screens/discussions/discussion_thread_screen.dart';
import 'package:time_tracker/screens/discussions/new_discussion_screen.dart';
import 'package:drift/drift.dart' as drift;

/// Lists the class discussion topics (newest first). Tapping a topic opens its
/// thread; the FAB starts a new topic. Built in the app's inline-CRUD style.
class DiscussionsScreen extends StatelessWidget {
  const DiscussionsScreen({super.key});

  void _deleteDiscussion(BuildContext context, Discussion discussion) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Discussion'),
          content: Text(
              'Are you sure you want to delete "${discussion.title}" and all of its replies? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                // Cascade delete removes the discussion's posts automatically.
                (db.delete(db.discussions)
                      ..where((d) => d.id.equals(discussion.id)))
                    .go();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      body: StreamBuilder<List<Discussion>>(
        stream: (db.select(db.discussions)
              ..orderBy([(d) => drift.OrderingTerm.desc(d.createdAt)]))
            .watch(),
        builder: (context, snapshot) {
          final discussions = snapshot.data ?? [];
          if (discussions.isEmpty &&
              snapshot.connectionState == ConnectionState.active) {
            return const Center(
                child: Text("No discussions yet. Tap '+' to start one!"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: discussions.length,
            itemBuilder: (context, index) {
              final discussion = discussions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Dismissible(
                  key: Key(discussion.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _deleteDiscussion(context, discussion);
                  },
                  child: ListTile(
                    leading: const Icon(Icons.forum),
                    title: Text(discussion.title),
                    subtitle: Text(
                        '${discussion.createdBy} (${discussion.authorRole}) • ${DateFormat.yMd().add_jm().format(discussion.createdAt)}'),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            DiscussionThreadScreen(discussion: discussion),
                      ));
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const NewDiscussionScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
