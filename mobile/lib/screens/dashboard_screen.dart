import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/meeting_provider.dart';
import '../services/api_service.dart';
import 'record_meeting_screen.dart';
import 'meeting_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _serverOnline = false;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    final online = await ApiService.checkHealth();
    if (mounted) {
      setState(() => _serverOnline = online);
    }
  }

  void _showServerSettings() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Backend Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the backend API base URL (e.g. http://10.0.2.2:8000 for Android emulator, or your computer\'s local IP).',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                prefixIcon: Icon(Icons.dns_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              ApiService.updateBaseUrl(controller.text.trim());
              Navigator.of(ctx).pop();
              await _checkServer();
              if (mounted) {
                context.read<MeetingProvider>().loadMeetings();
              }
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg', 'webm'],
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordMeetingScreen(importedAudioPath: result.files.single.path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<MeetingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meeting Intelligence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Bilingual (Urdu & English) Follow-Up', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          // Server status pill
          GestureDetector(
            onTap: _showServerSettings,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _serverOnline ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _serverOnline ? Colors.greenAccent : Colors.redAccent, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: _serverOnline ? Colors.greenAccent : Colors.redAccent),
                  const SizedBox(width: 6),
                  Text(
                    _serverOnline ? 'Connected' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      color: _serverOnline ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
            onPressed: _showServerSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkServer();
          await provider.loadMeetings();
        },
        child: provider.isLoading && provider.meetings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.meetings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.meetings.length,
                    itemBuilder: (ctx, index) {
                      final meeting = provider.meetings[index];
                      return _buildMeetingCard(meeting, theme);
                    },
                  ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'upload_fab',
            backgroundColor: Colors.white,
            foregroundColor: theme.colorScheme.primary,
            tooltip: 'Upload Audio File',
            onPressed: _pickAudioFile,
            child: const Icon(Icons.upload_file_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'record_fab',
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('New Meeting'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordMeetingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.record_voice_over_outlined, size: 72, color: Colors.indigo.shade200),
            const SizedBox(height: 16),
            const Text(
              'No Meetings Captured Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Record live conversations or import audio files in Urdu, English, or code-switched speech. The system will transcribe, diarize, and produce English executive minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Record First Meeting'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecordMeetingScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingCard(dynamic meeting, ThemeData theme) {
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(meeting.createdAt);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (meeting.status) {
      case 'ready':
        statusColor = Colors.green;
        statusLabel = 'Ready';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'sent':
        statusColor = Colors.blue;
        statusLabel = 'Distributed';
        statusIcon = Icons.mark_email_read_outlined;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusLabel = 'Failed';
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Processing AI...';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingDetailScreen(meetingId: meeting.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (meeting.status == 'processing')
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                          )
                        else
                          Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (meeting.summary != null && meeting.summary!.executiveSummary.isNotEmpty)
                Text(
                  meeting.summary!.executiveSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.3),
                )
              else if (meeting.status == 'processing')
                const Text(
                  'Transcribing bilingual audio, extracting decisions, and generating English minutes...',
                  style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic, fontSize: 12),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people_alt_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${meeting.participants.length} participants',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const Text(
                    'View Details',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.indigo),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
