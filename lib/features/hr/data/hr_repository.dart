import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/supabase_client.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';

class HrRepository {
  final SupabaseClient _client;

  HrRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  Future<int?> _schoolId() async {
    return int.tryParse(await locator<SessionManager>().getSchoolId() ?? '');
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final schoolId = await _schoolId();
      final query = _client.from('employees').select(
            'id, school_id, emp_id, nom, poste, departement, mobile, email, '
            'date_embauche, salaire_base, sexe, date_naissance, cnic, adresse, '
            'banque_nom, banque_compte, statut, photo_path, educational_level, created_at',
          );
      final rows = schoolId == null
          ? await query.order('created_at', ascending: false)
          : await query.eq('school_id', schoolId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveEmployee({
    int? employeeId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final schoolId = await _schoolId();
      final data = Map<String, dynamic>.from(payload);
      if (schoolId != null) {
        data['school_id'] = schoolId;
      }

      if (employeeId == null) {
        await _client.from('employees').insert(data);
      } else {
        await _client.from('employees').update(data).eq('id', employeeId);
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error saving employee: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> deleteEmployee(int employeeId) async {
    try {
      await _client.from('employees').delete().eq('id', employeeId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error deleting employee: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeeAttendance(String dateStr) async {
    try {
      final schoolId = await _schoolId();
      final rows = await _client
          .from('employee_attendance')
          .select(
            'id, school_id, employee_id, date, period_number, status, '
            'heure_entree, heure_sortie, remarques',
          )
          .eq('school_id', schoolId ?? -1)
          .gte('date', '${dateStr}T00:00:00')
          .lt('date', '${dateStr}T23:59:59');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching employee attendance: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveEmployeeAttendance({
    required String dateStr,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final schoolId = await _schoolId();
      if (schoolId == null) {
        return {
          'success': false,
          'error': 'School ID introuvable pour enregistrer le pointage.',
        };
      }

      final existing = await getEmployeeAttendance(dateStr);
      final existingByEmployee = {
        for (final row in existing) row['employee_id'] as int: row,
      };

      for (final record in records) {
        final employeeId = record['employee_id'] as int?;
        if (employeeId == null) continue;
        final existingRow = existingByEmployee[employeeId];
        final values = {
          'school_id': schoolId,
          'employee_id': employeeId,
          'date': '${dateStr}T08:00:00',
          'period_number': record['period_number'] ?? 1,
          'status': _normalizeAttendanceStatus(
            record['status']?.toString() ?? 'Present',
          ),
          'remarques': record['remarques'] ?? '',
        };

        if (existingRow != null) {
          await _client
              .from('employee_attendance')
              .update(values)
              .eq('id', existingRow['id']);
        } else {
          await _client.from('employee_attendance').insert(values);
        }
      }

      return {'success': true};
    } catch (e) {
      debugPrint('Error saving employee attendance: $e');
      final message = e.toString();
      if (message.contains('row-level security policy') ||
          message.contains('42501')) {
        return {
          'success': false,
          'error':
              'Le pointage du personnel est refuse par la politique de securite de la base. Verifiez la politique RLS de employee_attendance ou autorisez school_id pour cet utilisateur.',
        };
      }
      return {'success': false, 'error': message};
    }
  }

  Future<Map<String, dynamic>> getPayrollRules() async {
    try {
      final row = await _client
          .from('payroll_rules')
          .select('id, leave_allow_per_month, late_penalty, half_day_penalty')
          .limit(1)
          .maybeSingle();
      if (row != null) {
        return row;
      }

      final created = await _client
          .from('payroll_rules')
          .insert({
            'leave_allow_per_month': 1,
            'late_penalty': 0.5,
            'half_day_penalty': 0.5,
          })
          .select('id, leave_allow_per_month, late_penalty, half_day_penalty')
          .single();
      return created;
    } catch (e) {
      debugPrint('Error fetching payroll rules: $e');
      return {
        'leave_allow_per_month': 1,
        'late_penalty': 0.5,
        'half_day_penalty': 0.5,
      };
    }
  }

  Future<Map<String, dynamic>> savePayrollRules(Map<String, dynamic> payload) async {
    try {
      final existing = await _client
          .from('payroll_rules')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (existing == null) {
        await _client.from('payroll_rules').insert(payload);
      } else {
        await _client.from('payroll_rules').update(payload).eq('id', existing['id']);
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error saving payroll rules: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<List<Map<String, dynamic>>> getSalaryRecords({
    int? employeeId,
    String? monthYear,
  }) async {
    try {
      dynamic query = _client.from('salary_records').select(
            'id, employee_id, month_year, absent_days, leave_taken, late_days, '
            'half_days, basic_salary, calculated_basic, total_allowance, '
            'total_deduction, net_salary, status, payment_date, payment_mode, remark, created_at, '
            'employees(id, nom, poste, emp_id)',
          );
      if (employeeId != null) {
        query = query.eq('employee_id', employeeId);
      }
      if (monthYear != null && monthYear.isNotEmpty) {
        query = query.eq('month_year', monthYear);
      }
      final rows = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching salary records: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> saveSalaryRecord({
    int? recordId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final data = Map<String, dynamic>.from(payload);
      data['status'] = _normalizeSalaryStatus(
        data['status']?.toString() ?? 'Unpaid',
      );
      if (recordId == null) {
        await _client.from('salary_records').insert(data);
      } else {
        await _client.from('salary_records').update(data).eq('id', recordId);
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error saving salary record: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> markSalaryAsPaid(int recordId) async {
    try {
      await _client.from('salary_records').update({
        'status': 'Paid',
        'payment_date': DateTime.now().toIso8601String(),
      }).eq('id', recordId);
      return {'success': true};
    } catch (e) {
      debugPrint('Error marking salary as paid: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, int>> getEmployeeAttendanceSummary({
    required int employeeId,
    required String monthYear,
  }) async {
    try {
      final range = _monthRange(monthYear);
      final rows = await _client
          .from('employee_attendance')
          .select('status')
          .eq('employee_id', employeeId)
          .gte('date', range['start']!)
          .lt('date', range['end']!);

      var presents = 0;
      var absents = 0;
      var conges = 0;
      var retards = 0;

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final status = _normalizeAttendanceStatus(
          (row['status'] ?? '').toString(),
        );
        if (status == 'Present') {
          presents++;
        } else if (status == 'Absent') {
          absents++;
        } else if (status == 'Conge') {
          conges++;
        } else if (status == 'En Retard') {
          retards++;
        }
      }

      return {
        'presents': presents,
        'absents': absents,
        'conges': conges,
        'retards': retards,
      };
    } catch (e) {
      debugPrint('Error fetching employee attendance summary: $e');
      return {
        'presents': 0,
        'absents': 0,
        'conges': 0,
        'retards': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getHrDashboardData() async {
    try {
      final employees = await getEmployees();
      final salaryRecords = await getSalaryRecords();
      final today = DateTime.now().toIso8601String().split('T').first;
      final attendance = await getEmployeeAttendance(today);

      final activeEmployees = employees
          .where((e) => (e['statut'] ?? '').toString().toLowerCase().contains('actif'))
          .length;
      final presentToday = attendance
          .where(
            (e) => _normalizeAttendanceStatus(
              (e['status'] ?? '').toString(),
            ) ==
            'Present',
          )
          .length;
      final paid = salaryRecords
          .where(
            (e) => _normalizeSalaryStatus((e['status'] ?? '').toString()) ==
                'Paid',
          )
          .fold<double>(0, (sum, row) => sum + ((row['net_salary'] as num?)?.toDouble() ?? 0));
      final unpaid = salaryRecords
          .where(
            (e) => _normalizeSalaryStatus((e['status'] ?? '').toString()) !=
                'Paid',
          )
          .fold<double>(0, (sum, row) => sum + ((row['net_salary'] as num?)?.toDouble() ?? 0));

      return {
        'employees': employees,
        'salaryRecords': salaryRecords,
        'attendance': attendance,
        'stats': {
          'activeEmployees': activeEmployees,
          'presentToday': presentToday,
          'paidAmount': paid,
          'unpaidAmount': unpaid,
        },
      };
    } catch (e) {
      debugPrint('Error fetching HR dashboard data: $e');
      return {
        'employees': <Map<String, dynamic>>[],
        'salaryRecords': <Map<String, dynamic>>[],
        'attendance': <Map<String, dynamic>>[],
        'stats': {
          'activeEmployees': 0,
          'presentToday': 0,
          'paidAmount': 0.0,
          'unpaidAmount': 0.0,
        },
      };
    }
  }

  Map<String, String> _monthRange(String monthYear) {
    const months = {
      'janvier': 1,
      'fevrier': 2,
      'février': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'aout': 8,
      'août': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'decembre': 12,
      'décembre': 12,
    };

    final parts = monthYear.trim().split(RegExp(r'\s+'));
    final monthName = parts.isNotEmpty ? parts.first.toLowerCase() : '';
    final year = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final month = months[monthName] ?? DateTime.now().month;
    final safeYear = year ?? DateTime.now().year;
    final start = DateTime(safeYear, month, 1);
    final end = DateTime(safeYear, month + 1, 1);
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }

  String _normalizeAttendanceStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('present') || normalized.contains('présent')) {
      return 'Present';
    }
    if (normalized.contains('absent')) {
      return 'Absent';
    }
    if (normalized.contains('retard') || normalized.contains('late')) {
      return 'En Retard';
    }
    if (normalized.contains('conge') || normalized.contains('congé')) {
      return 'Conge';
    }
    return value.trim().isEmpty ? 'Absent' : value.trim();
  }

  String _normalizeSalaryStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'paid' || normalized == 'paye' || normalized == 'payé') {
      return 'Paid';
    }
    return 'Unpaid';
  }
}
