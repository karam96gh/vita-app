import 'dart:math' show max;
import '../../../core/errors/api_failure.dart';
import '../../../core/network/patient_contract.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.status,
    this.notes,
  });
  final String id, type, status;
  final DateTime start, end;
  final String? notes;
  factory Appointment.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    try {
      return Appointment(
        id: json['id'] as String,
        type: json['appointmentType'] as String,
        start: DateTime.parse(json['startTime'] as String).toUtc(),
        end: DateTime.parse(json['endTime'] as String).toUtc(),
        status: json['status'] as String,
        notes: json['notes'] as String?,
      );
    } on Object {
      throw const ApiFailure('INVALID_RESPONSE');
    }
  }
}

class PatientProfile {
  const PatientProfile(this.name, this.phone);
  final String name;
  final String? phone;

  factory PatientProfile.fromJson(Object? value) {
    final patient = _object(_object(value)['erpPatient']);
    final name = [
      _text(patient, 'firstName').trim(),
      _text(patient, 'lastName').trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (name.isEmpty) throw const ApiFailure('INVALID_RESPONSE');
    return PatientProfile(name, _nullableText(patient, 'phone'));
  }
}

class PatientSession {
  const PatientSession(
    this.id,
    this.number,
    this.date,
    this.attendanceConfirmed,
    this.alreadyRated,
  );
  final String id;
  final int number;
  final DateTime date;
  final bool attendanceConfirmed;
  final bool? alreadyRated;

  factory PatientSession.fromJson(Object? value) {
    final data = _object(value);
    final number = data['sessionNumber'];
    final attendance = data['attendanceConfirmed'];
    if (number is! int || number < 0 || attendance is! bool) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    return PatientSession(
      _text(data, 'id'),
      number,
      _date(_text(data, 'sessionDate')),
      attendance,
      // The session list does not expose rating history.
      null,
    );
  }
}

class AssignedExercise {
  AssignedExercise(Object? json, PatientContract c)
    : this._(
        id: c.text(json, 'exercise.id'),
        name: c.text(json, 'exercise.name'),
        status: c.text(json, 'exercise.assignmentStatus'),
        instructions: c.optionalText(json, 'exercise.instructions'),
        mediaUrl: c.optionalText(json, 'exercise.mediaUrl'),
        mediaType: c.optionalText(json, 'exercise.mediaType'),
        canStart: c.flag(json, 'exercise.canStart'),
        canComplete: c.flag(json, 'exercise.canComplete'),
        canSkip: c.flag(json, 'exercise.canSkip'),
      );
  AssignedExercise._({
    required this.id,
    required this.name,
    required this.status,
    this.instructions,
    this.mediaUrl,
    this.mediaType,
    this.nameEn,
    this.instructionsEn,
    this.description,
    this.descriptionEn,
    this.method,
    this.methodEn,
    this.warnings,
    this.warningsEn,
    this.mistakes,
    this.mistakesEn,
    this.frequency,
    this.frequencyEn,
    this.sortOrder = 0,
    this.durationSeconds,
    this.sets,
    this.reps,
    this.holdSeconds,
    this.restSeconds,
    this.canStart,
    this.canComplete,
    this.canSkip,
    this.executed = false,
    this.executionStatus,
    this.finishedAt,
    this.startedAt,
    this.elapsedSeconds,
    this.skipReasonId,
    this.completionNote,
    this.sessionId,
    this.sessionNumber,
    this.timesPerDay,
    this.daysPerWeek,
    this.todayCompletedCount,
    this.lastActivityAt,
  });
  factory AssignedExercise.fromJson(Object? value, PatientContract contract) {
    final data = _object(value);
    final exercise = _object(data['exercise']);
    int? count(String key) {
      final v = data[key];
      if (v == null) return null;
      if (v is! int || v < 0) throw const ApiFailure('INVALID_RESPONSE');
      return v;
    }

    bool? permission(String action) =>
        contract.paths.containsKey('exercise.$action')
        ? contract.flag(data, 'exercise.$action')
        : null;
    final execution = data['execution'];
    if (execution != null && execution is! Map<String, dynamic>) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    // Observed execution: startedAt, completedAt, elapsedSeconds, status,
    // skipReasonId, skipReasonText, completionNote (plus ids/audit stamps).
    DateTime? stamp(String key) {
      final value = execution == null ? null : _nullableText(execution, key);
      return value == null ? null : _date(value);
    }

    final elapsed = execution?['elapsedSeconds'];
    if (elapsed != null && (elapsed is! int || elapsed < 0)) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    // Only the all-exercises endpoint embeds the owning session.
    final session = data['session'];
    if (session != null && session is! Map<String, dynamic>) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    final sessionNumber = session?['sessionNumber'];
    if (sessionNumber != null && sessionNumber is! int) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    return AssignedExercise._(
      id: _text(data, 'id'),
      name: _text(exercise, 'nameAr'),
      nameEn: _nullableText(exercise, 'nameEn'),
      status: _text(data, 'status'),
      instructions: _nullableText(data, 'customInstructionAr'),
      instructionsEn: _nullableText(data, 'customInstructionEn'),
      description: _nullableText(exercise, 'descriptionAr'),
      descriptionEn: _nullableText(exercise, 'descriptionEn'),
      method: _nullableText(exercise, 'executionMethodAr'),
      methodEn: _nullableText(exercise, 'executionMethodEn'),
      warnings: _nullableText(exercise, 'warningsAr'),
      warningsEn: _nullableText(exercise, 'warningsEn'),
      mistakes: _nullableText(exercise, 'commonMistakesAr'),
      mistakesEn: _nullableText(exercise, 'commonMistakesEn'),
      frequency: _nullableText(data, 'frequencyTextAr'),
      frequencyEn: _nullableText(data, 'frequencyTextEn'),
      mediaUrl: _nullableText(exercise, 'mediaUrl'),
      mediaType: _nullableText(exercise, 'mediaType'),
      sortOrder: count('sortOrder') ?? 0,
      durationSeconds: count('durationSeconds'),
      sets: count('sets'),
      reps: count('reps'),
      holdSeconds: count('holdSeconds'),
      restSeconds: count('restSeconds'),
      canStart: permission('canStart'),
      canComplete: permission('canComplete'),
      canSkip: permission('canSkip'),
      executed: execution != null,
      executionStatus: execution == null
          ? null
          : _nullableText(execution, 'status'),
      finishedAt: stamp('completedAt'),
      startedAt: stamp('startedAt'),
      elapsedSeconds: elapsed as int?,
      skipReasonId: execution == null
          ? null
          : _nullableText(execution, 'skipReasonId'),
      completionNote: execution == null
          ? null
          : _nullableText(execution, 'completionNote'),
      sessionId: _nullableText(data, 'erpSessionId'),
      sessionNumber: sessionNumber as int?,
      timesPerDay: count('timesPerDay'),
      daysPerWeek: count('daysPerWeek'),
      // Only /me/exercises carries it (computed in the clinic's timezone).
      todayCompletedCount: count('todayCompletedCount'),
      lastActivityAt: stamp('updatedAt') ?? stamp('completedAt'),
    );
  }

  /// Prescribed repetitions per day; null means "not specified" (text only).
  final int? timesPerDay, daysPerWeek;
  final int? todayCompletedCount;
  final DateTime? lastActivityAt;

  int get dailyTarget => max(timesPerDay ?? 1, 1);

  /// Server count when present; otherwise inferred from the latest execution.
  int completedToday(DateTime now) =>
      todayCompletedCount ??
      (finishedAt != null && !skipped && _sameDay(finishedAt!, now) ? 1 : 0);

  bool doneToday(DateTime now) => completedToday(now) >= dailyTarget;
  bool skippedToday(DateTime now) =>
      skipped && lastActivityAt != null && _sameDay(lastActivityAt!, now);

  /// Nothing left to do for this exercise today.
  bool handledToday(DateTime now) => doneToday(now) || skippedToday(now);

  static bool _sameDay(DateTime utc, DateTime now) {
    final local = utc.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  final String? sessionId;
  final int? sessionNumber;
  final String? nameEn,
      instructionsEn,
      description,
      descriptionEn,
      method,
      methodEn,
      warnings,
      warningsEn,
      mistakes,
      mistakesEn,
      frequency,
      frequencyEn;
  final int sortOrder;
  final int? durationSeconds, sets, reps, holdSeconds, restSeconds;
  String? localized(String? ar, String? en, String language) {
    final preferred = language == 'en' ? en : ar;
    final fallback = language == 'en' ? ar : en;
    return preferred?.trim().isNotEmpty == true
        ? preferred
        : fallback?.trim().isNotEmpty == true
        ? fallback
        : null;
  }

  final String id, name, status;
  final String? instructions, mediaUrl, mediaType;

  /// Explicit server permissions; null means "derive from execution state".
  final bool? canStart, canComplete, canSkip;
  final bool executed;
  final String? executionStatus;
  final DateTime? finishedAt, startedAt;
  final int? elapsedSeconds;
  final String? skipReasonId, completionNote;
  bool get cancelled => status == 'CANCELLED';
  // Only COMPLETED is observed so far; a recorded skip reason is authoritative.
  bool get skipped => executionStatus == 'SKIPPED' || skipReasonId != null;
  bool get done =>
      finishedAt != null || executionStatus == 'COMPLETED' || skipped;
  bool get inProgress => executed && !done;

  // Backend confirmed: only CANCELLED blocks actions, and start/skip after a
  // finished execution open a new one, so exercises repeat without limit.
  // An in-progress execution must be completed (or skipped) first.
  bool allows(String action) {
    if (cancelled) return false;
    final explicit = switch (action) {
      'start' => canStart,
      'complete' => canComplete,
      'skip' => canSkip,
      _ => false,
    };
    if (explicit != null) return explicit;
    return switch (action) {
      'start' => !inProgress,
      'complete' => inProgress,
      'skip' => true,
      _ => false,
    };
  }
}

class SkipReason {
  const SkipReason(this.id, this.label, this.isOther, {this.labelEn});
  final String id, label;
  final String? labelEn;
  final bool isOther;
  String localizedLabel(String language) =>
      language == 'en' && labelEn?.trim().isNotEmpty == true ? labelEn! : label;

  /// A plain list of {id, nameAr, nameEn, sortOrder, active, requiresText};
  /// requiresText is true only for "Other".
  static List<SkipReason> listFrom(Object? data, PatientContract contract) {
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    final reasons = <(int, SkipReason)>[];
    for (final item in data) {
      final json = _object(item);
      if (json['active'] == false) continue;
      final order = json['sortOrder'];
      if (order != null && order is! int) {
        throw const ApiFailure('INVALID_RESPONSE');
      }
      reasons.add((
        order as int? ?? 0,
        SkipReason(
          _text(json, 'id'),
          _text(json, 'nameAr'),
          contract.paths.containsKey('skipReason.isOther')
              ? contract.flag(json, 'skipReason.isOther')
              : _optionalFlag(json, 'requiresText'),
          labelEn: _nullableText(json, 'nameEn'),
        ),
      ));
    }
    reasons.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final reason in reasons) reason.$2];
  }
}

class ProgressSummary {
  const ProgressSummary(
    this.active,
    this.completed,
    this.skipped,
    this.running,
  );
  final int active, completed, skipped, running;

  factory ProgressSummary.fromJson(Object? value) {
    final data = _object(value);
    int count(String key) {
      final value = data[key];
      if (value is! int || value < 0) {
        throw const ApiFailure('INVALID_RESPONSE');
      }
      return value;
    }

    return ProgressSummary(
      count('totalActiveAssignments'),
      count('completed'),
      count('skipped'),
      count('inProgress'),
    );
  }
}

/// One day of completions from /me/progress/daily (clinic calendar date).
class DailyCompletion {
  const DailyCompletion(this.date, this.completed);
  final DateTime date;
  final int completed;

  /// [{date: "2026-09-22", completed: 5}], oldest first, empty days = 0.
  static List<DailyCompletion> listFrom(Object? data) {
    if (data is! List) throw const ApiFailure('INVALID_RESPONSE');
    return [
      for (final item in data)
        () {
          final json = _object(item);
          final date = DateTime.tryParse(_text(json, 'date'));
          final completed = json['completed'];
          if (date == null || completed is! int || completed < 0) {
            throw const ApiFailure('INVALID_RESPONSE');
          }
          return DailyCompletion(
            DateTime(date.year, date.month, date.day),
            completed,
          );
        }(),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }
}

class ChatMessage {
  const ChatMessage(this.id, this.text, this.at, this.mine);
  final String id, text;
  final DateTime at;
  final bool mine;

  /// Confirmed by the backend: {id, messageText, sentAt, senderType, senderId}
  /// where senderType is exactly "PATIENT" or "THERAPIST".
  factory ChatMessage.fromJson(Object? value) {
    final json = _object(value);
    final sender = _text(json, 'senderType');
    if (sender != 'PATIENT' && sender != 'THERAPIST') {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    return ChatMessage(
      _text(json, 'id'),
      _text(json, 'messageText'),
      _date(_text(json, 'sentAt')),
      sender == 'PATIENT',
    );
  }
}

class Conversation {
  const Conversation(this.id, this.messages);
  final String id;
  final List<ChatMessage> messages;
}

class PatientNotification {
  const PatientNotification(
    this.id,
    this.title,
    this.body,
    this.read,
    this.at, {
    this.titleEn,
    this.bodyEn,
  });
  final String id, title, body;
  final String? titleEn, bodyEn;
  final bool read;
  final DateTime at;

  String localizedTitle(String language) =>
      language == 'en' && titleEn?.trim().isNotEmpty == true ? titleEn! : title;
  String localizedBody(String language) =>
      language == 'en' && bodyEn?.trim().isNotEmpty == true ? bodyEn! : body;

  factory PatientNotification.fromJson(Object? value) {
    final data = _object(value);
    final sentAt = _date(_text(data, 'sentAt'));
    // An absent readAt is malformed; null explicitly means unread.
    if (!data.containsKey('readAt')) throw const ApiFailure('INVALID_RESPONSE');
    final readAt = _nullableText(data, 'readAt');
    if (readAt != null) _date(readAt);
    return PatientNotification(
      _text(data, 'id'),
      _text(data, 'titleAr'),
      _text(data, 'bodyAr'),
      readAt != null,
      sentAt,
      titleEn: _nullableText(data, 'titleEn'),
      bodyEn: _nullableText(data, 'bodyEn'),
    );
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const ApiFailure('INVALID_RESPONSE');
  }
  return value;
}

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String) throw const ApiFailure('INVALID_RESPONSE');
  return value;
}

String? _nullableText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) {
    throw const ApiFailure('INVALID_RESPONSE');
  }
  return value as String?;
}

bool _optionalFlag(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! bool) {
    throw const ApiFailure('INVALID_RESPONSE');
  }
  return value == true;
}

DateTime _date(String value) {
  final result = DateTime.tryParse(value);
  if (result == null) throw const ApiFailure('INVALID_RESPONSE');
  return result.toUtc();
}

class Validation {
  static bool requiredText(String value) => value.trim().isNotEmpty;
  static String? skip(SkipReason? reason, String text) {
    if (reason == null) return 'SKIP_REASON_REQUIRED';
    if (reason.isOther && text.trim().isEmpty) {
      return 'SKIP_REASON_TEXT_REQUIRED';
    }
    return null;
  }

  static bool rating(int score, bool completed) =>
      completed && score >= 1 && score <= 5;
}
