import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LabReportsScreen extends StatelessWidget {
  const LabReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lab Reports')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 2,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.biotech)),
              title: Text('Blood Test - CBC', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              subtitle: const Text('Report ready: Feb 20, 2026'),
              trailing: const Icon(Icons.download),
            ),
          );
        },
      ),
    );
  }
}
