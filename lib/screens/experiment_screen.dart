import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'journal_screen.dart';
import 'data_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExperimentScreen extends StatefulWidget {
  final String experimentId;
  final String title;
  final String description;

  const ExperimentScreen({
    super.key,
    required this.experimentId,
    required this.title,
    required this.description,
  });

  @override
  State<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends State<ExperimentScreen> {
  late String title;
  late String description;

  @override
  void initState() {
    super.initState();
    title = widget.title;
    description = widget.description;
  }

  Future<void> _editExperimentField({
    required String field,
    required String currentValue,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("edit experiment $field"),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: "enter new $field",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newValue = ctrl.text.trim();
              if (newValue.isNotEmpty && newValue != currentValue) {
                try {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('experiments')
                        .doc(widget.experimentId)
                        .update({field: newValue});

                    setState(() {
                      if (field == 'title') title = newValue;
                      if (field == 'description') description = newValue;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("failed to update $field: $e")),
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text("save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExperiment() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('experiments')
          .doc(widget.experimentId)
          .delete();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: 28,
                width: 28,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title.toLowerCase() : 'untitled',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    GestureDetector(
                      onTap: () =>
                          _editExperimentField(field: 'description', currentValue: description),
                      child: Text(
                        description.isNotEmpty
                            ? description.toLowerCase()
                            : 'no description',
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _editExperimentField(field: 'title', currentValue: title),
                icon: const Icon(Icons.edit, color: Colors.black87),
                tooltip: 'edit title',
              ),
              IconButton(
                onPressed: _deleteExperiment,
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: 'delete experiment',
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEDEDED),
          foregroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          bottom: const TabBar(
            indicator: BoxDecoration(
              color: Color(0xFFB0E0E6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            tabs: [
              Tab(text: 'journal'),
              Tab(text: 'data'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            JournalScreen(experimentId: widget.experimentId),
            DataScreen(experimentId: widget.experimentId),
          ],
        ),
      ),
    );
  }
}
