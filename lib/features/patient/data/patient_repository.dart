import '../../../core/errors/api_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/patient_contract.dart';
import '../domain/models.dart';

class PatientRepository {
  const PatientRepository(this.api, this.contract);
  final ApiClient api;
  final PatientContract contract;
  String _id(String id) => Uri.encodeComponent(id);

  Future<List<Appointment>> appointments() async {
    final data = await api.get('/me/appointments');
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    return data.map(Appointment.fromJson).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<PatientProfile> profile() async {
    final data = await api.get('/me/profile');
    return PatientProfile.fromJson(data);
  }

  Future<List<PatientSession>> sessions() async {
    final data = await api.get('/me/sessions');
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    return data.map(PatientSession.fromJson).toList();
  }

  Future<List<AssignedExercise>> exercises(String session) async {
    final data = await api.get('/me/sessions/${_id(session)}/exercises');
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    return data
        .map((item) => AssignedExercise.fromJson(item, contract))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Every assignment across all sessions, oldest session first.
  Future<List<AssignedExercise>> program() async {
    final data = await api.get('/me/exercises');
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    return data
        .map((item) => AssignedExercise.fromJson(item, contract))
        .toList()
      ..sort((a, b) {
        final bySession = (a.sessionNumber ?? 0).compareTo(
          b.sessionNumber ?? 0,
        );
        return bySession != 0 ? bySession : a.sortOrder.compareTo(b.sortOrder);
      });
  }

  Future<List<DailyCompletion>> daily({int days = 14}) async =>
      DailyCompletion.listFrom(
        await api.get('/me/progress/daily', query: {'days': '$days'}),
      );

  Future<List<SkipReason>> skipReasons() async =>
      SkipReason.listFrom(await api.get('/me/skip-reasons'), contract);

  Future<void> exerciseAction(
    AssignedExercise exercise,
    String action, {
    SkipReason? reason,
    String note = '',
  }) async {
    if (!exercise.allows(action)) {
      throw ApiFailure(
        exercise.cancelled ? 'ASSIGNMENT_CANCELLED' : 'INVALID_ACTION',
      );
    }
    if (action == 'skip') {
      final error = Validation.skip(reason, note);
      if (error != null) throw ApiFailure(error);
    }
    await api.post(
      '/me/exercises/${_id(exercise.id)}/$action',
      body: {
        if (action == 'complete' && note.trim().isNotEmpty)
          'completionNote': note.trim(),
        if (action == 'skip') 'skipReasonId': reason!.id,
        if (action == 'skip' && note.trim().isNotEmpty)
          'skipReasonText': note.trim(),
      },
    );
  }

  ChatMessage _message(Object? item) => ChatMessage.fromJson(item);

  /// Observed: {conversation: {id, erpPatientId, erpTherapistId, active, …},
  /// messages: [...]}.
  Future<Conversation> conversation() async {
    final data = await api.get('/me/chat');
    final conversation = data is Map<String, dynamic>
        ? data['conversation']
        : null;
    final messages = data is Map<String, dynamic> ? data['messages'] : null;
    final unreadCount = data is Map<String, dynamic>
        ? data['unreadCount']
        : null;
    if (conversation is! Map<String, dynamic> ||
        conversation['id'] is! String ||
        messages is! List ||
        unreadCount is! int ||
        unreadCount < 0) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    return Conversation(
      conversation['id'] as String,
      messages.map(_message).toList(),
      unreadCount,
    );
  }

  /// Observed: a plain list.
  Future<List<ChatMessage>> messages(DateTime? after) async {
    final data = await api.get(
      '/me/chat/messages',
      query: {if (after != null) 'after': after.toUtc().toIso8601String()},
    );
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    return data.map(_message).toList();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) throw const ApiFailure('REQUIRED');
    await api.post('/me/chat/messages', body: {'messageText': text.trim()});
  }

  Future<void> readChat() async {
    await api.post('/me/chat/read');
  }

  Future<void> rate(PatientSession session, int score, String note) async {
    if (!Validation.rating(score, session.attendanceConfirmed)) {
      throw const ApiFailure('SESSION_NOT_COMPLETED');
    }
    if (session.alreadyRated == true) {
      throw const ApiFailure('RATING_ALREADY_EXISTS');
    }
    await api.post(
      '/me/sessions/${_id(session.id)}/rating',
      body: {
        'score': score,
        if (note.trim().isNotEmpty) 'privateNote': note.trim(),
      },
    );
  }

  Future<List<PatientNotification>> notifications() async {
    final data = await api.get('/me/notifications');
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    return data.map(PatientNotification.fromJson).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
  }

  Future<void> readNotification(String id) async {
    await api.post('/me/notifications/${_id(id)}/read');
  }

  Future<void> registerDevice(String token, String platform) async {
    await api.post('/me/devices', body: {'token': token, 'platform': platform});
  }
}
