import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'experiment_screen.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});
  final uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _createExperiment(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("new experiment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: "experiment name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: "description",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
          TextButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('users/$uid/experiments')
                    .add({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(context);
            },
            child: const Text("create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final experimentsRef = FirebaseFirestore.instance
        .collection('users/$uid/experiments')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 8),
            const Text('labbit'),
          ],
        ),
        backgroundColor: const Color(0xFFEDEDED),
        foregroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: experimentsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final experiments = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: experiments.length,
            itemBuilder: (context, index) {
              final exp = experiments[index];
              final data = exp.data() as Map<String, dynamic>? ?? {};
              final title = data['title'] ?? 'untitled';
              final description = data['description'] ?? '';
              final createdAt = data['createdAt'] != null
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.now();

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(description),
                      const SizedBox(height: 4),
                      Text(
                        "created: ${createdAt.month}/${createdAt.day}/${createdAt.year}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExperimentScreen(
                          experimentId: exp.id,
                          title: title,
                          description: description,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('users/$uid/experiments')
                          .doc(exp.id)
                          .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createExperiment(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
