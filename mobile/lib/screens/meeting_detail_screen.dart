import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../models/meeting.dart';
import '../providers/meeting_provider.dart';
import '../services/api_service.dart';
import '../widgets/speaker_remap_dialog.dart';

class MeetingDetailScreen extends StatefulWidget {
  final String meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  bool _isAsking = false;
  bool _isDistributing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MeetingProvider>().loadMeetingDetail(widget.meetingId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _handleRemapSpeakers(Meeting meeting) async {
    showDialog(
      context: context,
      builder: (ctx) => SpeakerRemapDialog(
        meeting: meeting,
        onSave: (mapping) async {
          final provider = context.read<MeetingProvider>();
          try {
            await provider.mapSpeakers(mapping);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Speakers mapped and English PDF regenerated!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to map speakers: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleSendQuestion() async {
    final q = _chatController.text.trim();
    if (q.isEmpty) return;

    _chatController.clear();
    setState(() {
      _chatMessages.add({'role': 'user', 'text': q});
      _isAsking = true;
    });

    try {
      final provider = context.read<MeetingProvider>();
      final resp = await provider.askQuestion(q);
      setState(() {
        _chatMessages.add({
          'role': 'assistant',
          'text': resp.answer,
          'citations': resp.citations,
        });
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'role': 'assistant',
          'text': 'Sorry, could not answer the question: $e',
          'citations': [],
        });
      });
    } finally {
      if (mounted) setState(() => _isAsking = false);
    }
  }

  Future<void> _handleDistributeEmails() async {
    final customMsgController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send MoM to Participants'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will send tailored English emails with the official PDF attached:\n'
              '• Attended: Assigned tasks & deadlines\n'
              '• Absent: Catch-up briefing & decisions',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: customMsgController,
              decoration: const InputDecoration(
                labelText: 'Optional note from organizer',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Send Emails')),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isDistributing = true);
      try {
        final provider = context.read<MeetingProvider>();
        final res = await provider.distributeMeeting(customMessage: customMsgController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Emails dispatched! ${res["attended_sent"]} attended, ${res["absent_sent"]} absent.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Email distribution failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isDistributing = false);
      }
    }
  }

  Future<void> _handleNativeSharePdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final localPdfPath = '${dir.path}/Minutes_of_Meeting_${widget.meetingId}.pdf';
      await ApiService.downloadPdf(widget.meetingId, localPdfPath);

      if (File(localPdfPath).existsSync()) {
        await Share.shareXFiles(
          [XFile(localPdfPath)],
          text: 'Minutes of Meeting (MoM) — Generated by Bilingual Meeting Intelligence',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }

  Future<void> _handleOpenPdfDirectly() async {
    try {
      final dir = await getTemporaryDirectory();
      final localPdfPath = '${dir.path}/Minutes_of_Meeting_${widget.meetingId}.pdf';
      await ApiService.downloadPdf(widget.meetingId, localPdfPath);

      final result = await OpenFilex.open(localPdfPath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeetingProvider>();
    final meeting = provider.selectedMeeting;

    return Scaffold(
      appBar: AppBar(
        title: Text(meeting?.title ?? 'Meeting Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined), text: 'Summary'),
            Tab(icon: Icon(Icons.record_voice_over_outlined), text: 'Transcript'),
            Tab(icon: Icon(Icons.forum_outlined), text: 'RAG Q&A'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF & Share'),
          ],
        ),
      ),
      body: meeting == null
          ? const Center(child: CircularProgressIndicator())
          : meeting.status == 'processing'
              ? _buildProcessingState(meeting)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(meeting),
                    _buildTranscriptTab(meeting),
                    _buildRagChatTab(meeting),
                    _buildPdfShareTab(meeting),
                  ],
                ),
    );
  }

  Widget _buildProcessingState(Meeting meeting) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Pipeline In Progress...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Normalizing audio to 16kHz mono via FFmpeg\n'
              '2. Transcribing Urdu & English with faster-whisper CPU\n'
              '3. Segmenting speaker turns (SPEAKER_00, SPEAKER_01)\n'
              '4. Indexing multilingual vectors into ChromaDB\n'
              '5. Synthesizing 100% English Executive Minutes & Actions\n'
              '6. Compiling executive MoM PDF via WeasyPrint',
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Text(
              'Polling every 4 seconds. You may keep this screen open.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.indigo.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(Meeting meeting) {
    final summary = meeting.summary;
    if (summary == null) {
      return const Center(child: Text('No summary data available yet.'));
    }

    final attendedCount = meeting.participants.where((p) => p.status == 'Attended').length;
    final absentCount = meeting.participants.where((p) => p.status == 'Absent').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attendance summary row
          Row(
            children: [
              Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                label: Text('$attendedCount Attended'),
                backgroundColor: Colors.green.shade50,
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.cancel, color: Colors.red, size: 16),
                label: Text('$absentCount Absent'),
                backgroundColor: Colors.red.shade50,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Executive Summary
          const Text('Executive Summary (English)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Text(
              summary.executiveSummary,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 20),

          // Topics
          if (summary.topicsDiscussed.isNotEmpty) ...[
            const Text('Topics Discussed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: summary.topicsDiscussed.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey.shade100,
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Decisions
          const Text('Agreed Decisions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...summary.decisions.map((d) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.gavel_rounded, color: Colors.indigo),
              title: Text(d.decision, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                child: Text(d.timestamp, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
            ),
          )),
          const SizedBox(height: 20),

          // Action Items
          const Text('Action Items & Deadlines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...summary.actionItems.map((a) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.task, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('Owner: ${a.owner}', style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text('Due: ${a.deadline}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('[${a.timestamp}]', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          )),

          // Open questions
          if (summary.openQuestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Open Questions & Unresolved Issues', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...summary.openQuestions.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(q, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptTab(Meeting meeting) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.indigo.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${meeting.segments.length} Bilingual Segments',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.record_voice_over_rounded, size: 16),
                label: const Text('Remap Voices', style: TextStyle(fontSize: 12)),
                onPressed: () => _handleRemapSpeakers(meeting),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: meeting.segments.length,
            itemBuilder: (ctx, idx) {
              final seg = meeting.segments[idx];
              final isSpeaker0 = seg.speakerLabel.contains('00');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSpeaker0 ? Colors.indigo.shade100 : Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              seg.speakerLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isSpeaker0 ? Colors.indigo.shade900 : Colors.teal.shade900,
                              ),
                            ),
                          ),
                          Text(
                            seg.timeFormatted,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        seg.text,
                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRagChatTab(Meeting meeting) {
    return Column(
      children: [
        // Suggestion chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ActionChip(
                label: const Text('What were the decisions?'),
                onPressed: () {
                  _chatController.text = 'What were the decisions made in the meeting?';
                  _handleSendQuestion();
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('Who has action items?'),
                onPressed: () {
                  _chatController.text = 'Who has assigned action items and what are their deadlines?';
                  _handleSendQuestion();
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('What was the timeline?'),
                onPressed: () {
                  _chatController.text = 'What timeline or release date was mentioned?';
                  _handleSendQuestion();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Chat message list
        Expanded(
          child: _chatMessages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Ask any question in Urdu or English about this meeting. The AI retrieves grounded transcript chunks and responds in professional English with exact timestamps.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _chatMessages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = _chatMessages[idx];
                    final isUser = msg['role'] == 'user';
                    final citations = msg['citations'] as List<Citation>? ?? [];

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.indigo : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['text'],
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            if (citations.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Source Citations:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo),
                              ),
                              const SizedBox(height: 4),
                              ...citations.map((c) => Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  '[${c.timestampStr}] ${c.speaker}: "${c.text}"',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        if (_isAsking)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    hintText: 'Ask about decisions, deadlines, or topics...',
                    hintStyle: TextStyle(fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => _handleSendQuestion(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.indigo),
                onPressed: _isAsking ? null : _handleSendQuestion,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfShareTab(Meeting meeting) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 72, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text(
            'Executive Minutes of Meeting (MoM) PDF',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Formatted in high-quality executive print layout via WeasyPrint. Contains participant attendance, English executive summary, agreed decisions, and action item tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Action 1: View PDF
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview PDF on Device'),
              onPressed: _handleOpenPdfDirectly,
            ),
          ),
          const SizedBox(height: 12),

          // Action 2: Send Tailored Emails
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              icon: _isDistributing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(_isDistributing ? 'Sending Emails...' : 'Send to All Participants (Email)'),
              onPressed: _isDistributing ? null : _handleDistributeEmails,
            ),
          ),
          const SizedBox(height: 12),

          // Action 3: Android Native Share Sheet
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Android Share Sheet (WhatsApp / Gmail)'),
              onPressed: _handleNativeSharePdf,
            ),
          ),
        ],
      ),
    );
  }
}
