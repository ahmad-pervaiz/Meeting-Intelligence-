import 'package:flutter/material.dart';
import '../models/meeting.dart';

class SpeakerRemapDialog extends StatefulWidget {
  final Meeting meeting;
  final Function(Map<String, String>) onSave;

  const SpeakerRemapDialog({
    super.key,
    required this.meeting,
    required this.onSave,
  });

  @override
  State<SpeakerRemapDialog> createState() => _SpeakerRemapDialogState();
}

class _SpeakerRemapDialogState extends State<SpeakerRemapDialog> {
  final Map<String, String> _mapping = {};

  @override
  void initState() {
    super.initState();
    // Collect all unique speaker labels from segments
    final labels = widget.meeting.segments.map((s) => s.speakerLabel).toSet();
    for (var label in labels) {
      // Find if already mapped
      final existing = widget.meeting.participants.firstWhere(
        (p) => p.speakerLabel == label,
        orElse: () => Participant(name: '', email: ''),
      );
      if (existing.name.isNotEmpty) {
        _mapping[label] = existing.name;
      } else {
        _mapping[label] = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.meeting.participants;
    final labels = _mapping.keys.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.record_voice_over_rounded, color: Colors.indigo),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Map Voices to Participants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Human-in-the-Loop Review: Align anonymous voice tags with verified participants. The English MoM PDF will be regenerated automatically.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ...labels.map((label) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _mapping[label]?.isNotEmpty == true ? _mapping[label] : null,
                          hint: const Text('Select participant', style: TextStyle(fontSize: 13)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: participants.map((p) {
                            return DropdownMenuItem<String>(
                              value: p.name,
                              child: Text(p.name, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _mapping[label] = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Filter non-empty mappings
            final cleanMapping = Map<String, String>.fromEntries(
              _mapping.entries.where((e) => e.value.trim().isNotEmpty),
            );
            widget.onSave(cleanMapping);
            Navigator.of(context).pop();
          },
          child: const Text('Update & Regenerate PDF'),
        ),
      ],
    );
  }
}
