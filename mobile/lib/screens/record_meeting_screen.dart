import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/meeting.dart';
import '../providers/meeting_provider.dart';
import '../services/audio_recorder_service.dart';
import '../widgets/consent_dialog.dart';
import '../widgets/roster_dialog.dart';
import 'meeting_detail_screen.dart';

class RecordMeetingScreen extends StatefulWidget {
  final String? importedAudioPath;

  const RecordMeetingScreen({super.key, this.importedAudioPath});

  @override
  State<RecordMeetingScreen> createState() => _RecordMeetingScreenState();
}

class _RecordMeetingScreenState extends State<RecordMeetingScreen> {
  final _titleController = TextEditingController(text: 'Meeting - ${DateTime.now().month}/${DateTime.now().day}');
  final List<Participant> _roster = [];
  String? _audioFilePath;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _audioFilePath = widget.importedAudioPath;
    // Add sample host participant
    _roster.add(Participant(
      name: 'Organizer',
      email: 'organizer@company.com',
      status: 'Attended',
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleStartRecording(AudioRecorderService recorder) async {
    final granted = await AudioConsentDialog.showConsentAndRequestPermission(context);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record audio.')),
        );
      }
      return;
    }

    try {
      await recorder.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _handleStopRecording(AudioRecorderService recorder) async {
    final path = await recorder.stopRecording();
    if (path != null) {
      setState(() => _audioFilePath = path);
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg', 'webm'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _audioFilePath = result.files.single.path);
    }
  }

  Future<void> _submitMeeting() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting title.')),
      );
      return;
    }

    if (_audioFilePath == null || !File(_audioFilePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record or import an audio file.')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final provider = context.read<MeetingProvider>();
      final meetingId = await provider.uploadMeeting(
        title: title,
        participants: _roster,
        audioPath: _audioFilePath!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting uploaded! AI transcription running in background.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MeetingDetailScreen(meetingId: meetingId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider(
      create: (_) => AudioRecorderService(),
      child: Consumer<AudioRecorderService>(
        builder: (context, recorder, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Capture Meeting', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Input
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Meeting Title',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Audio Capture Card
                  _buildAudioCaptureCard(recorder, theme),
                  const SizedBox(height: 24),

                  // Participants Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Participant Roster',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_roster.length} participants (${_roster.where((p) => p.status == 'Attended').length} Attended)',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Add Member'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => RosterDialog(
                              onSave: (newP) {
                                setState(() => _roster.add(newP));
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Roster List
                  if (_roster.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No participants added. Add attendees to ensure they receive customized follow-up emails and the final PDF.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._roster.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      final isAttended = p.status == 'Attended';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAttended ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(
                              isAttended ? Icons.check : Icons.close,
                              color: isAttended ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(p.email.isNotEmpty ? p.email : 'No email entered'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilterChip(
                                label: Text(
                                  p.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isAttended ? Colors.green.shade900 : Colors.red.shade900,
                                  ),
                                ),
                                selected: isAttended,
                                selectedColor: Colors.green.shade100,
                                backgroundColor: Colors.red.shade100,
                                onSelected: (_) {
                                  setState(() {
                                    p.status = isAttended ? 'Absent' : 'Attended';
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                onPressed: () {
                                  setState(() => _roster.removeAt(idx));
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _isUploading ? 'Uploading & Starting AI...' : 'Process Meeting with AI',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isUploading || recorder.isRecording ? null : _submitMeeting,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioCaptureCard(AudioRecorderService recorder, ThemeData theme) {
    final hasAudio = _audioFilePath != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (recorder.isRecording) ...[
              const Icon(Icons.fiber_manual_record_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 8),
              Text(
                recorder.formattedDuration,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              const Text('Recording Live Audio (Urdu & English)...', style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: 28,
                    icon: Icon(recorder.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                    onPressed: () {
                      if (recorder.isPaused) {
                        recorder.resumeRecording();
                      } else {
                        recorder.pauseRecording();
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
                    iconSize: 32,
                    icon: const Icon(Icons.stop_rounded, color: Colors.white),
                    onPressed: () => _handleStopRecording(recorder),
                  ),
                ],
              ),
            ] else ...[
              Icon(
                hasAudio ? Icons.check_circle_rounded : Icons.mic_none_rounded,
                size: 48,
                color: hasAudio ? Colors.green : theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                hasAudio ? 'Audio Ready for AI Processing' : 'Record or Import Audio',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (hasAudio)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    _audioFilePath!.split('/').last,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(hasAudio ? 'Re-Record' : 'Record Live'),
                    onPressed: () => _handleStartRecording(recorder),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import File'),
                    onPressed: _pickAudioFile,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
