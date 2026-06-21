import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api/supabase_client.dart';
import '../../../core/di/injection.dart';
import '../../../core/api/offline_store_manager.dart';
import '../../../core/api/offline_queue_manager.dart';
import '../../../core/api/sync_engine.dart';

class AttendanceRepository {
  final SupabaseClient _client;

  AttendanceRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  String _getDayName(int dayIndex) {
    const days = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"];
    if (dayIndex < 0 || dayIndex >= days.length) {
      return "Lundi";
    }
    return days[dayIndex];
  }

  // Record presence check-in from scanning QR Code
  Future<Map<String, dynamic>> recordTeacherSessionScan({
    required int classId,
    required int employeeId,
  }) async {
    try {
      final now = DateTime.now();
      final todayDayName = _getDayName(now.weekday % 7); // Dart weekday: 1 (Mon) to 7 (Sun)

      // 1. Get today's timetable entries for this class and teacher
      final List<dynamic> todayEntries = await _client
          .from('timetable_entries')
          .select('id, period_number, subject_id, room_name, school_subjects(subject_name), school_classes(class_name)')
          .eq('class_id', classId)
          .eq('employee_id', employeeId)
          .eq('day_name', todayDayName);

      if (todayEntries.isEmpty) {
        return {
          'success': false,
          'error': 'Aucune séance de cours n\'est programmée pour vous dans cette classe aujourd\'hui ($todayDayName).',
        };
      }

      // 2. Get classroom settings to evaluate period times
      final List<dynamic> settingsList = await _client
          .from('timetable_settings')
          .select('*')
          .isFilter('class_id', null);

      Map<String, dynamic>? settings;
      if (settingsList.isNotEmpty) {
        settings = settingsList.first as Map<String, dynamic>;
      }

      final String dayStartStr = settings?['day_start'] ?? "08:00";
      final int periodDuration = settings?['period_duration'] ?? 60;
      final int recessAfter = settings?['recess_after'] ?? 3;
      final int recessDuration = settings?['recess_duration'] ?? 30;

      // Parse day start
      final parts = dayStartStr.split(':');
      final startH = int.parse(parts[0]);
      final startM = int.parse(parts[1]);
      final startMinutes = startH * 60 + startM;

      int getPeriodStartMinutes(int period) {
        int offset = (period - 1) * periodDuration;
        if (period > recessAfter) {
          offset += recessDuration;
        }
        return startMinutes + offset;
      }

      // Determine current time in minutes from midnight
      final currentMinutes = now.hour * 60 + now.minute;

      // Find if there is a session active right now, or near right now
      Map<String, dynamic> resolvedEntry = todayEntries.first as Map<String, dynamic>;
      int minDiff = 999999;

      for (var entry in todayEntries) {
        final period = entry['period_number'] as int;
        final start = getPeriodStartMinutes(period);
        final end = start + periodDuration;

        if (currentMinutes >= start - 20 && currentMinutes <= end + 20) {
          resolvedEntry = entry as Map<String, dynamic>;
          minDiff = 0;
          break;
        } else {
          final diff = (currentMinutes - start).abs();
          if (diff < minDiff) {
            minDiff = diff;
            resolvedEntry = entry as Map<String, dynamic>;
          }
        }
      }

      final resolvedPeriod = resolvedEntry['period_number'] as int;

      // 3. Check if attendance already recorded for this slot today
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final List<dynamic> existingScans = await _client
          .from('teacher_session_attendance')
          .select('*')
          .eq('employee_id', employeeId)
          .eq('class_id', classId)
          .eq('period_number', resolvedPeriod)
          .gte('date', '$todayStr 00:00:00')
          .lte('date', '$todayStr 23:59:59');

      if (existingScans.isNotEmpty) {
        final existing = existingScans.first;
        return {
          'success': true,
          'alreadyRecorded': true,
          'entry': {
            'periodNumber': resolvedPeriod,
            'subjectName': resolvedEntry['school_subjects']?['subject_name'] ?? 'Matière',
            'className': resolvedEntry['school_classes']?['class_name'] ?? 'Classe',
            'scannedAt': existing['scanned_at'],
          },
        };
      }

      // Fetch teacher's school ID
      final List<dynamic> empInfo = await _client
          .from('employees')
          .select('school_id')
          .eq('id', employeeId);
      final int? schoolId = empInfo.isNotEmpty ? empInfo.first['school_id'] as int? : null;

      // 4. Insert new attendance record
      final insertData = {
        'school_id': schoolId,
        'employee_id': employeeId,
        'class_id': classId,
        'subject_id': resolvedEntry['subject_id'],
        'timetable_entry_id': resolvedEntry['id'],
        'date': now.toIso8601String(),
        'period_number': resolvedPeriod,
        'status': 'Présent',
        'scan_method': 'QR_CODE',
        'scanned_at': now.toIso8601String(),
      };

      await _client.from('teacher_session_attendance').insert(insertData);

      return {
        'success': true,
        'entry': {
          'periodNumber': resolvedPeriod,
          'subjectName': resolvedEntry['school_subjects']?['subject_name'] ?? 'Matière',
          'className': resolvedEntry['school_classes']?['class_name'] ?? 'Classe',
          'scannedAt': now.toIso8601String(),
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion à la base de données: $e',
      };
    }
  }

  // Get schedule attendance for a teacher
  Future<Map<String, dynamic>> getTeacherScheduleAttendance({
    required int employeeId,
    required String filterType, // "day" | "week" | "month" | "year"
    required String dateStr,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "teacher_schedule_${employeeId}_${filterType}_$dateStr";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching teacher schedule from local cache.");
      final cachedData = cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
      if (cachedData.isNotEmpty) {
        final firstItem = cachedData.first;
        final slots = firstItem['slots'] as List?;
        final stats = firstItem['stats'] as Map?;
        if (slots != null && stats != null) {
          return {
            'success': true,
            'slots': List<Map<String, dynamic>>.from(slots.map((e) => Map<String, dynamic>.from(e as Map))),
            'stats': Map<String, dynamic>.from(stats),
          };
        }
      }
      return {
        'success': false,
        'error': 'Pas de connexion internet et aucune donnée en cache.',
      };
    }

    try {
      final baseDate = DateTime.parse(dateStr);
      DateTime startDate = DateTime(baseDate.year, baseDate.month, baseDate.day, 0, 0, 0);
      DateTime endDate = DateTime(baseDate.year, baseDate.month, baseDate.day, 23, 59, 59);

      if (filterType == "week") {
        final weekday = baseDate.weekday;
        startDate = baseDate.subtract(Duration(days: weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
        endDate = startDate.add(const Duration(days: 6));
        endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      } else if (filterType == "month") {
        startDate = DateTime(baseDate.year, baseDate.month, 1, 0, 0, 0);
        endDate = DateTime(baseDate.year, baseDate.month + 1, 0, 23, 59, 59);
      } else if (filterType == "year") {
        startDate = DateTime(baseDate.year, 1, 1, 0, 0, 0);
        endDate = DateTime(baseDate.year, 12, 31, 23, 59, 59);
      }

      // 1. Fetch timetable entries
      final List<dynamic> timetableList = await _client
          .from('timetable_entries')
          .select('id, period_number, day_name, class_id, room_name, subject_id, school_classes(class_name), school_subjects(subject_name, subject_code)')
          .eq('employee_id', employeeId);

      // 2. Fetch attendance scans in date range
      final List<dynamic> scansList = await _client
          .from('teacher_session_attendance')
          .select('*')
          .eq('employee_id', employeeId)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String());

      // Create lookup map
      final Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var scan in scansList) {
        if (scan['date'] != null) {
          final scanDate = DateTime.parse(scan['date'] as String);
          final dStr = "${scanDate.year}-${scanDate.month.toString().padLeft(2, '0')}-${scanDate.day.toString().padLeft(2, '0')}";
          final key = "${dStr}_${scan['period_number']}_${scan['class_id']}";
          attendanceMap[key] = scan as Map<String, dynamic>;
        }
      }

      // 3. Generate all dates in range
      final List<DateTime> dates = [];
      DateTime curr = startDate;
      while (curr.isBefore(endDate) || curr.isAtSameMomentAs(endDate)) {
        dates.add(curr);
        curr = curr.add(const Duration(days: 1));
      }

      final List<Map<String, dynamic>> slots = [];

      for (var date in dates) {
        final dayName = _getDayName(date.weekday % 7);
        final dailyTimetable = timetableList.where((t) => t['day_name'] == dayName).toList();

        for (var entry in dailyTimetable) {
          final dStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          final key = "${dStr}_${entry['period_number']}_${entry['class_id']}";
          final match = attendanceMap[key];

          String status = "Absent";
          String? scannedAt;
          String? scanMethod;
          String? remarques;
          int? attendanceRecordId;

          if (match != null) {
            status = match['status'] ?? 'Présent';
            scannedAt = match['scanned_at'];
            scanMethod = match['scan_method'];
            remarques = match['remarques'];
            attendanceRecordId = match['id'] as int?;
          } else {
            final now = DateTime.now();
            final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
            if (dStr.compareTo(todayStr) > 0) {
              status = "Planifié";
            } else if (dStr == todayStr) {
              status = "Planifié";
            }
          }

          slots.push({
            'date': date.toIso8601String(),
            'dateStr': dStr,
            'dayName': dayName,
            'periodNumber': entry['period_number'],
            'classId': entry['class_id'],
            'className': entry['school_classes']?['class_name'] ?? 'Classe',
            'subjectName': entry['school_subjects']?['subject_name'] ?? 'Matière',
            'subjectCode': entry['school_subjects']?['subject_code'] ?? '',
            'roomName': entry['room_name'] ?? 'Non spécifiée',
            'timetableEntryId': entry['id'],
            'status': status,
            'scannedAt': scannedAt,
            'scanMethod': scanMethod,
            'remarques': remarques,
            'attendanceRecordId': attendanceRecordId,
          });
        }
      }

      // Sort slots chronologically
      slots.sort((a, b) {
        final comp = (a['dateStr'] as String).compareTo(b['dateStr'] as String);
        if (comp != 0) return comp;
        return (a['periodNumber'] as int).compareTo(b['periodNumber'] as int);
      });

      // Calculate stats
      final total = slots.length;
      final attended = slots.where((s) => s['status'] == 'Présent' || s['status'] == 'En Retard').length;
      final absent = slots.where((s) => s['status'] == 'Absent').length;
      final late = slots.where((s) => s['status'] == 'En Retard').length;
      final rate = total > 0 ? ((attended / total) * 100).round() : 100;

      final stats = {
        'total': total,
        'attended': attended,
        'absent': absent,
        'late': late,
        'rate': rate,
      };

      final res = {
        'success': true,
        'slots': slots,
        'stats': stats,
      };

      // Cache the result
      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: [
          {
            'slots': slots,
            'stats': stats,
          }
        ],
      );

      return res;
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur lors de la récupération du calendrier: $e',
      };
    }
  }

  // Fetch active students for a class name
  Future<List<Map<String, dynamic>>> getStudentsByClass(String className, int? employeeId) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "students_${employeeId}_$className";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching students for $className from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }

    try {
      var query = _client
          .from('students')
          .select('id, num_admission, nom_etudiant, photo_path, mobile, whatsapp')
          .eq('classe', className)
          .eq('statut', 'Actif');

      if (employeeId != null) {
        final List<dynamic> empInfo = await _client
            .from('employees')
            .select('school_id')
            .eq('id', employeeId);
        if (empInfo.isNotEmpty && empInfo.first['school_id'] != null) {
          final int schoolId = empInfo.first['school_id'] as int;
          query = query.eq('school_id', schoolId);
        }
      }

      final List<dynamic> response = await query.order('nom_etudiant');
      final list = List<Map<String, dynamic>>.from(response);

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: list,
      );

      return list;
    } catch (e) {
      debugPrint("Error fetching students by class: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }
  }

  // Fetch student attendance records for a class on a specific date (and subject if applicable)
  Future<List<Map<String, dynamic>>> getStudentAttendanceRecords({
    required int classId,
    required String dateStr,
    int? subjectId,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "attendance_${classId}_${dateStr}_$subjectId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Fetching attendance records from local cache.");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }

    try {
      var query = _client
          .from('student_attendance')
          .select('id, student_id, status, remark')
          .eq('class_id', classId)
          .eq('date', dateStr);
      
      if (subjectId != null) {
        query = query.eq('subject_id', subjectId);
      } else {
        query = query.isFilter('subject_id', null);
      }

      final List<dynamic> response = await query;
      final list = List<Map<String, dynamic>>.from(response);

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: list,
      );

      return list;
    } catch (e) {
      debugPrint("Error fetching student attendance: $e");
      return cacheManager.getDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
      );
    }
  }

  // Save batch student attendance records
  Future<Map<String, dynamic>> saveStudentBatchAttendance({
    required int classId,
    required String dateStr,
    int? subjectId,
    required int? employeeId,
    required List<Map<String, dynamic>> records,
    bool sendSMS = false,
    bool sendWhatsApp = false,
  }) async {
    final syncEngine = locator<SyncEngine>();
    final queueManager = locator<OfflineQueueManager>();
    final cacheManager = locator<OfflineStoreManager>();
    final cacheKey = "attendance_${classId}_${dateStr}_$subjectId";

    if (!syncEngine.isOnlineNotifier.value) {
      debugPrint("📶 Offline Mode: Queueing batch attendance save locally.");
      
      await queueManager.enqueue(
        table: 'student_attendance',
        action: 'batch_attendance',
        data: {
          'classId': classId,
          'dateStr': dateStr,
          'subjectId': subjectId,
          'employeeId': employeeId,
          'records': records,
          'sendSMS': sendSMS,
          'sendWhatsApp': sendWhatsApp,
        },
      );

      final List<Map<String, dynamic>> cachedRecords = records.map((r) {
        return {
          'id': null,
          'student_id': r['student_id'],
          'status': r['status'],
          'remark': r['remark'],
        };
      }).toList();

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: cachedRecords,
      );

      return {'success': true};
    }

    try {
      // 1. Fetch existing attendance records
      var query = _client
          .from('student_attendance')
          .select('id, student_id')
          .eq('class_id', classId)
          .eq('date', dateStr);

      if (subjectId != null) {
        query = query.eq('subject_id', subjectId);
      } else {
        query = query.isFilter('subject_id', null);
      }

      final List<dynamic> existingList = await query;
      final Map<int, int> existingMap = {
        for (var item in existingList)
          (item['student_id'] as num).toInt(): (item['id'] as num).toInt()
      };

      // 2. Perform updates or inserts
      final List<Future> operations = [];
      for (var record in records) {
        final studentId = (record['student_id'] as num).toInt();
        final status = record['status'] as String;
        final remark = record['remark'] as String?;
        final existingId = existingMap[studentId];

        if (existingId != null) {
          operations.add(
            _client.from('student_attendance').update({
              'status': status,
              'remark': remark,
              'employee_id': employeeId,
            }).eq('id', existingId)
          );
        } else {
          operations.add(
            _client.from('student_attendance').insert({
              'student_id': studentId,
              'class_id': classId,
              'subject_id': subjectId,
              'employee_id': employeeId,
              'date': dateStr,
              'status': status,
              'remark': remark,
            })
          );
        }
      }

      await Future.wait(operations);

      // 3. Process SMS/WhatsApp alerts if flagged
      if ((sendSMS || sendWhatsApp) && records.isNotEmpty) {
        try {
          final List<dynamic> studentsList = await _client
              .from('students')
              .select('id, nom_etudiant, mobile, whatsapp')
              .inFilter('id', records.map((r) => r['student_id'] as int).toList());

          String subjectName = "Général";
          if (subjectId != null) {
            final List<dynamic> subInfo = await _client
                .from('school_subjects')
                .select('subject_name')
                .eq('id', subjectId);
            if (subInfo.isNotEmpty) {
              subjectName = subInfo.first['subject_name'] ?? "Général";
            }
          }

          String formattedDate = dateStr;
          try {
            final parsedDate = DateTime.parse(dateStr);
            formattedDate = "${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}";
          } catch (_) {}

          for (var record in records) {
            final status = record['status'] as String;
            if (status == "Absent" || status == "En Retard") {
              final sId = record['student_id'] as int;
              final student = studentsList.firstWhere((s) => s['id'] == sId, orElse: () => null);
              if (student != null) {
                final studentName = student['nom_etudiant'] as String? ?? '';
                final phone = student['mobile'] as String? ?? '';
                final whatsappNumber = student['whatsapp'] as String? ?? '';

                await _sendAttendanceAlert(
                  phone: phone,
                  studentName: studentName,
                  status: status,
                  subjectName: subjectName,
                  dateStr: formattedDate,
                  whatsappNumber: whatsappNumber,
                  sendSMS: sendSMS,
                  sendWhatsApp: sendWhatsApp,
                );
              }
            }
          }
        } catch (err) {
          debugPrint("Failed to process smart alerts: $err");
        }
      }

      // Read updated records and cache them
      final List<Map<String, dynamic>> freshMapped = records.map((r) {
        final stId = r['student_id'] as int;
        return {
          'id': existingMap[stId],
          'student_id': stId,
          'status': r['status'],
          'remark': r['remark'],
        };
      }).toList();

      await cacheManager.saveDataList(
        boxName: OfflineStoreManager.boxStudents,
        key: cacheKey,
        data: freshMapped,
      );

      return {'success': true};
    } catch (e) {
      debugPrint("Error saving student batch attendance: $e");
      return {
        'success': false,
        'error': 'Erreur lors de la sauvegarde des présences: $e',
      };
    }
  }

  // Send SMS & WhatsApp alert helper
  Future<void> _sendAttendanceAlert({
    required String phone,
    required String studentName,
    required String status,
    required String subjectName,
    required String dateStr,
    required String whatsappNumber,
    required bool sendSMS,
    required bool sendWhatsApp,
  }) async {
    final subText = subjectName.isNotEmpty && subjectName != "Général" ? " ($subjectName)" : "";
    
    String messageFr = "";
    String messageAr = "";

    if (status == "Absent") {
      messageFr = "Cher Parent, nous vous informons que $studentName est ABSENT le $dateStr$subText. Veuillez justifier cette absence. - Edut Pro";
      messageAr = "عزيزي ولي الأمر، نحيطكم علماً بأن الطالب $studentName كان غائباً يوم $dateStr$subText. يرجى توضيح سبب الغياب. - Edut Pro";
    } else if (status == "En Retard") {
      messageFr = "Cher Parent, $studentName est arrivé EN RETARD le $dateStr$subText. Merci de veiller à la ponctualité. - Edut Pro";
      messageAr = "عزيزي ولي الأمر، لقد وصل الطالب $studentName متأخراً يوم $dateStr$subText. يرجى الحرص على المواعيد. - Edut Pro";
    } else {
      return;
    }

    final fullMessage = "$messageFr\n\n$messageAr";

    // 1. Send SMS
    if (sendSMS && phone.isNotEmpty && phone != "N/A") {
      bool success = false;
      try {
        final dio = Dio();
        final response = await dio.post(
          "http://192.168.1.100:8080/send",
          data: {
            "to": phone,
            "message": fullMessage,
            "key": ""
          },
          options: Options(
            headers: {"Content-Type": "application/json"},
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        );
        success = response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint("SMS Gateway Error: $e");
      }

      await _logMessage("SMS", "$studentName ($phone)", fullMessage, success ? "Envoyé" : "Échec");
    }

    // 2. Send WhatsApp (simulated by logging to database, matching Next.js backend)
    final wNumber = whatsappNumber.isNotEmpty && whatsappNumber != "N/A" ? whatsappNumber : phone;
    if (sendWhatsApp && wNumber.isNotEmpty && wNumber != "N/A") {
      await _logMessage("WHATSAPP", "$studentName ($wNumber)", fullMessage, "Envoyé");
    }
  }

  Future<void> _logMessage(String type, String target, String content, String status) async {
    try {
      await _client.from('message_logs').insert({
        'msg_type': type,
        'target_audience': target,
        'content': content,
        'sent_by': "Système Alerte Automatique",
        'status': status,
        'recipient_count': 1,
      });
    } catch (e) {
      debugPrint("Failed to log message: $e");
    }
  }

  // Fetch classes and subjects taught by a specific teacher
  Future<List<Map<String, dynamic>>> getTeacherClassesAndSubjects(int employeeId) async {
    try {
      final List<dynamic> response = await _client
          .from('class_subjects')
          .select('class_id, subject_id, school_classes(class_name), school_subjects(subject_name)')
          .eq('employee_id', employeeId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching teacher classes and subjects: $e");
      return [];
    }
  }
}

extension ListPush<T> on List<T> {
  void push(T element) => add(element);
}
