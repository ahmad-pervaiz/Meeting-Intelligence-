import 'package:flutter/material.dart';
import '../models/meeting.dart';

class RosterDialog extends StatefulWidget {
  final Participant? initialParticipant;
  final Function(Participant) onSave;

  const RosterDialog({
    super.key,
    this.initialParticipant,
    required this.onSave,
  });

  @override
  State<RosterDialog> createState() => _RosterDialogState();
}

class _RosterDialogState extends State<RosterDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String _status = 'Attended';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialParticipant?.name ?? '');
    _emailController = TextEditingController(text: widget.initialParticipant?.email ?? '');
    _status = widget.initialParticipant?.status ?? 'Attended';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.initialParticipant == null ? 'Add Participant' : 'Edit Participant',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter email';
                  if (!val.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Meeting Attendance Status:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Attended')),
                      selected: _status == 'Attended',
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color: _status == 'Attended' ? Colors.green.shade900 : Colors.black87,
                        fontWeight: _status == 'Attended' ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _status = 'Attended');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Absent')),
                      selected: _status == 'Absent',
                      selectedColor: Colors.red.shade100,
                      labelStyle: TextStyle(
                        color: _status == 'Absent' ? Colors.red.shade900 : Colors.black87,
                        fontWeight: _status == 'Absent' ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _status = 'Absent');
                      },
                    ),
                  ),
                ],
              ),
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
            if (_formKey.currentState!.validate()) {
              final participant = Participant(
                id: widget.initialParticipant?.id,
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                status: _status,
                speakerLabel: widget.initialParticipant?.speakerLabel,
              );
              widget.onSave(participant);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
