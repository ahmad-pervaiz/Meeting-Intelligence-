import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioConsentDialog extends StatelessWidget {
  const AudioConsentDialog({super.key});

  static Future<bool> showConsentAndRequestPermission(BuildContext context) async {
    // Check if permission is already granted
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    // Show Google Play Prominent Disclosure Dialog
    if (!context.mounted) return false;
    final consented = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AudioConsentDialog(),
    );

    if (consented == true) {
      final reqStatus = await Permission.microphone.request();
      return reqStatus.isGranted;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.mic_rounded, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Microphone Consent & Data Notice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Google Play Store Policy & Privacy Disclosure:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bilingual Meeting Intelligence requires access to your device\'s microphone to record live meeting discussions in Urdu, English, or code-switched bilingual speech.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Purpose: Speech-to-text, speaker diarization, and English Minutes of Meeting (MoM) synthesis.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('• Security: Audio is processed securely and is never sold to third parties.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('• Control: You can stop recording or revoke microphone permissions at any time.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'By tapping "Agree & Continue", you consent to microphone recording for the sole purpose of meeting intelligence processing.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Agree & Continue'),
        ),
      ],
    );
  }
}
