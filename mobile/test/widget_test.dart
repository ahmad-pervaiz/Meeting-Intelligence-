import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/meeting.dart';
import 'package:mobile/widgets/consent_dialog.dart';
import 'package:flutter/material.dart';

void main() {
  test('Participant and Meeting models JSON parsing test', () {
    final json = {
      'id': 'test-123',
      'title': 'Sprint Sync',
      'status': 'ready',
      'created_at': '2026-11-24T10:00:00Z',
      'participants': [
        {'name': 'Ali Khan', 'email': 'ali@example.com', 'status': 'Attended', 'speaker_label': 'SPEAKER_00'}
      ],
      'segments': [
        {'speaker_label': 'SPEAKER_00', 'start_time': 0.0, 'end_time': 2.5, 'text': 'Agenda discussed.'}
      ],
      'summary_json': {
        'executive_summary': 'Sprint sync concluded successfully.',
        'topics_discussed': ['Architecture', 'Deployment'],
        'decisions': [{'decision': 'Ship by Friday', 'timestamp': '01:00'}],
        'action_items': [{'task': 'Test on Linux', 'owner': 'Ali Khan', 'deadline': 'Friday', 'timestamp': '01:20'}],
        'open_questions': ['Need beta testers?']
      }
    };

    final meeting = Meeting.fromJson(json);
    expect(meeting.id, 'test-123');
    expect(meeting.title, 'Sprint Sync');
    expect(meeting.participants.length, 1);
    expect(meeting.participants.first.status, 'Attended');
    expect(meeting.segments.length, 1);
    expect(meeting.segments.first.timeFormatted, '00:00 - 00:02');
    expect(meeting.summary?.actionItems.first.owner, 'Ali Khan');
  });

  testWidgets('AudioConsentDialog renders Google Play disclosures', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudioConsentDialog(),
        ),
      ),
    );

    expect(find.text('Microphone Consent & Data Notice'), findsOneWidget);
    expect(find.text('Google Play Store Policy & Privacy Disclosure:'), findsOneWidget);
    expect(find.text('Agree & Continue'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });
}
