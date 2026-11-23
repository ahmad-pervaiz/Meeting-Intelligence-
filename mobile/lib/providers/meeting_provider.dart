import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/meeting.dart';
import '../services/api_service.dart';

class MeetingProvider extends ChangeNotifier {
  List<Meeting> _meetings = [];
  Meeting? _selectedMeeting;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  List<Meeting> get meetings => _meetings;
  Meeting? get selectedMeeting => _selectedMeeting;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  MeetingProvider() {
    loadMeetings();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      // If any meeting is in 'processing' status, refresh
      final hasProcessing = _meetings.any((m) => m.status == 'processing') ||
          (_selectedMeeting != null && _selectedMeeting!.status == 'processing');
      if (hasProcessing) {
        await refreshMeetingsSilently();
        if (_selectedMeeting != null && _selectedMeeting!.status == 'processing') {
          await refreshSelectedMeetingSilently();
        }
      }
    });
  }

  Future<void> loadMeetings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _meetings = await ApiService.getMeetings();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMeetingsSilently() async {
    try {
      _meetings = await ApiService.getMeetings();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadMeetingDetail(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedMeeting = await ApiService.getMeeting(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSelectedMeetingSilently() async {
    if (_selectedMeeting == null) return;
    try {
      final updated = await ApiService.getMeeting(_selectedMeeting!.id);
      _selectedMeeting = updated;
      notifyListeners();
    } catch (_) {}
  }

  Future<String> uploadMeeting({
    required String title,
    required List<Participant> participants,
    required String audioPath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.uploadMeeting(
        title: title,
        participants: participants,
        audioPath: audioPath,
      );
      final id = res['id'];
      await loadMeetings();
      return id;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> mapSpeakers(Map<String, String> mapping) async {
    if (_selectedMeeting == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await ApiService.mapSpeakers(_selectedMeeting!.id, mapping);
      _selectedMeeting = updated;
      await loadMeetings();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AskResponse> askQuestion(String question) async {
    if (_selectedMeeting == null) {
      throw Exception("No meeting selected");
    }
    return await ApiService.askQuestion(_selectedMeeting!.id, question);
  }

  Future<Map<String, dynamic>> distributeMeeting({String? customMessage}) async {
    if (_selectedMeeting == null) {
      throw Exception("No meeting selected");
    }
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.distributeMoM(_selectedMeeting!.id, customMessage: customMessage);
      await refreshSelectedMeetingSilently();
      await loadMeetings();
      return res;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
