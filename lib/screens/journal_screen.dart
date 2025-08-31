import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class JournalScreen extends StatefulWidget {
  final String experimentId;
  const JournalScreen({super.key, required this.experimentId});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _addEntry() async {
    final controller = TextEditingController();
    bool priority = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("new journal entry"),
        content: StatefulBuilder(builder: (context, setStateSB) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: "write your thoughts here...",
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  const Text("priority? "),
                  Checkbox(
                    value: priority,
                    onChanged: (val) {
                      setStateSB(() => priority = val ?? false);
                    },
                  ),
                ],
              ),
            ],
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users/$uid/experiments/${widget.experimentId}/journal')
                    .add({
                  'content': controller.text.trim(),
                  'highlighted': false,
                  'priority': priority,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(context);
            },
            child: const Text("add"),
          ),
        ],
      ),
    );
  }

  Future<void> _editEntry(DocumentSnapshot entry) async {
    final data = entry.data() as Map<String, dynamic>? ?? {};
    final controller = TextEditingController(text: data['content'] as String? ?? '');
    bool priority = data['priority'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("edit entry"),
        content: StatefulBuilder(builder: (context, setStateSB) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              Row(
                children: [
                  const Text("priority? "),
                  Checkbox(
                    value: priority,
                    onChanged: (val) {
                      setStateSB(() => priority = val ?? false);
                    },
                  ),
                ],
              ),
            ],
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
          TextButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                entry.reference.update({
                  'content': newText,
                  'priority': priority,
                });
              }
              Navigator.pop(context);
            },
            child: const Text("save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journalRef = FirebaseFirestore.instance
        .collection('users/$uid/experiments/${widget.experimentId}/journal')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: journalRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final entries = snapshot.data!.docs;

          Map<String, List<DocumentSnapshot>> grouped = {};
          for (var entry in entries) {
            final ts = entry['createdAt'] as Timestamp?;
            final date = ts != null ? DateFormat('EEEE, MMM d, yyyy').format(ts.toDate()) : 'unknown';
            grouped.putIfAbsent(date, () => []).add(entry);
          }

          final dates = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final dayEntries = grouped[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ...dayEntries.map((entry) {
                    final data = entry.data() as Map<String, dynamic>? ?? {};
                    final content = data['content'] as String? ?? '';
                    final highlighted = data['highlighted'] as bool? ?? false;
                    final priority = data['priority'] ?? false;

                    Color bgColor = highlighted ? const Color(0xFFFFF59D) : Colors.white;
                    if (priority) bgColor = const Color(0xFFFFCDD2); // pink for priority

                    return Card(
  margin: const EdgeInsets.symmetric(vertical: 6),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  color: bgColor,
  child: ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    title: Text(
      // show only first 30 chars + ellipsis if longer
      content.length > 30 ? content.substring(0, 30) + "..." : content,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Checkbox(
                  value: priority,
                  onChanged: (val) {
                    entry.reference.update({'priority': val ?? false});
                  },
                ),
                const Text("priority"),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editEntry(entry),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => entry.reference.delete(),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);
                  }).toList(),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.note_add),
      ),
    );
  }
}
