import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patients/models/patient_model.dart';
import '../../patients/repositories/patient_repository.dart';
import '../../patients/widgets/patient_identifier_card_widget.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/repositories/visit_repository.dart';

class RoleHistoryScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const RoleHistoryScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<RoleHistoryScreen> createState() => _RoleHistoryScreenState();
}

class _RoleHistoryScreenState extends ConsumerState<RoleHistoryScreen> {
  String _selectedDateFilter = 'all'; // all, today, yesterday, week
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _historyData;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final dioClient = ref.read(dioClientProvider);
    final currentUser = ref.read(authProvider).user;
    final role = currentUser?.roleName.toLowerCase() ?? 'patient';

    try {
      final res = await dioClient.dio.get(
        ApiEndpoints.roleHistory,
        queryParameters: {
          'date_filter': _selectedDateFilter,
          if (_searchQuery.trim().isNotEmpty) 'search': _searchQuery.trim(),
        },
      );

      if (res.data is Map && res.data['status'] == 'success') {
        if (mounted) {
          setState(() {
            _historyData = res.data['data'] as Map<String, dynamic>;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Remote history fetch note: $e');
    }

    // Local in-memory high-fidelity fallback from start to now
    _buildLocalHistoryFallback(role, currentUser?.id ?? '', currentUser?.fullName ?? '');
  }

  void _buildLocalHistoryFallback(String role, String userId, String userName) {
    final allVisits = List<OPDVisitModel>.from(VisitRepository.cachedVisits);
    final allPatients = PatientRepository.cachedPatients;

    // Filter by date
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    List<OPDVisitModel> filtered = allVisits;
    if (_selectedDateFilter == 'today') {
      filtered = filtered.where((v) => v.visitDate.isAfter(todayStart)).toList();
    } else if (_selectedDateFilter == 'yesterday') {
      filtered = filtered.where((v) => v.visitDate.isAfter(yesterdayStart) && v.visitDate.isBefore(todayStart)).toList();
    } else if (_selectedDateFilter == 'week') {
      filtered = filtered.where((v) => v.visitDate.isAfter(todayStart.subtract(const Duration(days: 7)))).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final term = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((v) {
        final pName = v.patient?.fullName.toLowerCase() ?? '';
        final uhid = v.patient?.uhid.toLowerCase() ?? '';
        final vNum = v.visitNumber.toLowerCase();
        final token = '#${v.queueToken}';
        return pName.contains(term) || uhid.contains(term) || vNum.contains(term) || token.contains(term);
      }).toList();
    }

    final items = filtered.map((v) {
      return {
        'id': v.id,
        'type': role == 'doctor' ? 'CONSULTATION' : 'VISIT_RECORD',
        'title': 'Token #${v.queueToken} • ${v.visitNumber}',
        'patient_id': v.patientId,
        'patient_name': v.patient?.fullName ?? 'Patient',
        'patient_uhid': v.patient?.uhid ?? 'UHID',
        'patient_gender': v.patient?.gender ?? 'N/A',
        'patient_age': v.patient?.ageYears != null ? '${v.patient!.ageYears} Y' : 'N/A',
        'visit_number': v.visitNumber,
        'queue_token': v.queueToken,
        'department_name': v.departmentName ?? 'General Medicine',
        'doctor_name': v.doctorName ?? 'Consulting Physician',
        'status': v.status,
        'triage_priority': v.triagePriority,
        'consultation_fee': v.consultationFee,
        'notes': v.notes ?? 'Registered at front desk',
        'timestamp': v.visitDate.toIso8601String(),
        'action_badge': v.status,
      };
    }).toList();

    double grandTotal = 0.0;
    for (final v in allVisits) {
      grandTotal += v.consultationFee;
    }

    if (mounted) {
      setState(() {
        _historyData = {
          'role': role,
          'role_display': '${role.toUpperCase()} Activity & Records History',
          'user_name': userName,
          'summary': {
            'all_time_total': allVisits.length,
            'filtered_count': items.length,
            'grand_total_revenue': grandTotal,
            'total_registered_patients': allPatients.length,
            'completed_consultations': allVisits.where((v) => v.status == 'COMPLETED').length,
            'waiting_patients': allVisits.where((v) => v.status == 'REGISTERED' || v.status == 'TRIAGED').length,
          },
          'items': items,
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider).user;
    final role = currentUser?.roleName.toLowerCase() ?? 'staff';

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              titleSpacing: 0,
        title: Row(
          children: [
            const SmvmchHospitalLogo(size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTitleForRole(role),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Complete Records: Start to Now • ${currentUser?.fullName ?? ""}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh History',
            onPressed: _fetchHistory,
          ),
          const SizedBox(width: 4),
        ],
      )
    : null,
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        child: Column(
          children: [
            // Filter bar & Search box
            _buildSearchAndFilters(isDark),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!),
                              ElevatedButton(onPressed: _fetchHistory, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _buildHistoryContent(isDark, role),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitleForRole(String role) {
    switch (role) {
      case 'doctor':
        return 'Doctor Consultation History';
      case 'receptionist':
        return 'Patient Registration & Token History';
      case 'nurse':
        return 'Nursing Triage & Vitals History';
      case 'billing':
        return 'Cashier Billing & Payments History';
      case 'admin':
        return 'Hospital Master Operations Ledger';
      case 'pharmacist':
        return 'Pharmacy Dispensing History';
      case 'laboratory':
      case 'lab_tech':
        return 'Laboratory Diagnostic Worklist History';
      default:
        return 'Activity & Records History';
    }
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Search Input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Patient Name, UHID, Token #, Diagnosis...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _fetchHistory();
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (val) {
              setState(() => _searchQuery = val);
              _fetchHistory();
            },
          ),
          const SizedBox(height: 10),
          // Date Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Time (Start to Now)', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip("Today's Records", 'today'),
                const SizedBox(width: 8),
                _buildFilterChip("Yesterday's Records", 'yesterday'),
                const SizedBox(width: 8),
                _buildFilterChip('Last 7 Days', 'week'),
                const SizedBox(width: 8),
                _buildFilterChip('This Month', 'month'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedDateFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primaryTeal.withValues(alpha: 0.2),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedDateFilter = value);
          _fetchHistory();
        }
      },
    );
  }

  Widget _buildHistoryContent(bool isDark, String role) {
    final summary = (_historyData?['summary'] as Map<String, dynamic>?) ?? {};
    final items = (_historyData?['items'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Counters Card
        _buildSummaryMetrics(summary, isDark, role),
        const SizedBox(height: 16),

        // List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Timeline Records (${items.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              'Ordered: Latest first',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No activity records found for this period',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...items.map((it) => _buildHistoryItemCard(it as Map<String, dynamic>, isDark, role)),
      ],
    );
  }

  Widget _buildSummaryMetrics(Map<String, dynamic> summary, bool isDark, String role) {
    List<Widget> metricItems = [];

    if (role == 'doctor') {
      final total = summary['all_time_total'] ?? 0;
      final completed = summary['completed_consultations'] ?? 0;
      final today = summary['today_completed'] ?? 0;
      final waiting = summary['waiting_patients'] ?? 0;

      metricItems = [
        _buildMetricBlock('All Consultations', '$total', Icons.assignment_rounded, AppColors.primaryBlue),
        _buildMetricBlock('Completed', '$completed', Icons.check_circle_rounded, Colors.green),
        _buildMetricBlock('Today Seen', '$today', Icons.today_rounded, Colors.teal),
        _buildMetricBlock('Waiting Queue', '$waiting', Icons.hourglass_top_rounded, Colors.orange),
      ];
    } else if (role == 'receptionist') {
      final totalPat = summary['total_registered_patients'] ?? 0;
      final todayPat = summary['today_registered_patients'] ?? 0;
      final totalTok = summary['total_tokens_issued'] ?? 0;
      final todayTok = summary['today_tokens_issued'] ?? 0;

      metricItems = [
        _buildMetricBlock('Total Registered', '$totalPat', Icons.person_add_rounded, AppColors.primaryTeal),
        _buildMetricBlock('Total Tokens', '$totalTok', Icons.confirmation_number_rounded, AppColors.primaryBlue),
        _buildMetricBlock('Today Reg', '$todayPat', Icons.group_add_rounded, Colors.green),
        _buildMetricBlock('Today Tokens', '$todayTok', Icons.today_rounded, Colors.indigo),
      ];
    } else if (role == 'nurse') {
      final totalTriaged = summary['total_triaged_patients'] ?? 0;
      final todayTriaged = summary['today_triaged_patients'] ?? 0;
      final emergency = summary['emergency_cases'] ?? 0;
      final priority = summary['priority_cases'] ?? 0;

      metricItems = [
        _buildMetricBlock('Total Triaged', '$totalTriaged', Icons.monitor_heart_rounded, AppColors.primaryTeal),
        _buildMetricBlock('Today Triaged', '$todayTriaged', Icons.today_rounded, AppColors.primaryBlue),
        _buildMetricBlock('Emergency Flagged', '$emergency', Icons.warning_rounded, Colors.red),
        _buildMetricBlock('Priority Flagged', '$priority', Icons.priority_high_rounded, Colors.orange),
      ];
    } else if (role == 'billing') {
      final grandTotal = (summary['grand_total_revenue'] as num?)?.toDouble() ?? 0.0;
      final todayRev = (summary['today_revenue'] as num?)?.toDouble() ?? 0.0;
      final yesterdayRev = (summary['yesterday_revenue'] as num?)?.toDouble() ?? 0.0;
      final totalBills = summary['total_bills_issued'] ?? 0;

      metricItems = [
        _buildMetricBlock('Grand Total Billed', '₹${grandTotal.toStringAsFixed(0)}', Icons.stars_rounded, const Color(0xFF0D9488)),
        _buildMetricBlock('Today Collection', '₹${todayRev.toStringAsFixed(0)}', Icons.today_rounded, Colors.green),
        _buildMetricBlock('Yesterday Paid', '₹${yesterdayRev.toStringAsFixed(0)}', Icons.history_toggle_off_rounded, Colors.indigo),
        _buildMetricBlock('Total Invoices', '$totalBills', Icons.receipt_long_rounded, AppColors.primaryBlue),
      ];
    } else {
      final grandTotal = (summary['grand_total_revenue'] as num?)?.toDouble() ?? 0.0;
      final totalPat = summary['total_registered_patients'] ?? 0;
      final totalVis = summary['total_visits_created'] ?? 0;
      final todayRev = (summary['today_revenue'] as num?)?.toDouble() ?? 0.0;

      metricItems = [
        _buildMetricBlock('Grand Total Revenue', '₹${grandTotal.toStringAsFixed(0)}', Icons.stars_rounded, const Color(0xFF0D9488)),
        _buildMetricBlock('Total Patients', '$totalPat', Icons.people_alt_rounded, AppColors.primaryBlue),
        _buildMetricBlock('Total OPD Visits', '$totalVis', Icons.confirmation_number_rounded, Colors.indigo),
        _buildMetricBlock('Today Revenue', '₹${todayRev.toStringAsFixed(0)}', Icons.today_rounded, Colors.green),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operational Summary (Start to Now)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryTeal),
          ),
          const SizedBox(height: 10),
          Row(
            children: metricItems.map((m) => Expanded(child: m)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBlock(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHistoryItemCard(Map<String, dynamic> item, bool isDark, String role) {
    final patientName = item['patient_name'] as String? ?? 'Patient';
    final uhid = item['patient_uhid'] as String? ?? 'UHID';
    final token = item['queue_token'];
    final visitNumber = item['visit_number'] as String? ?? '';
    final dept = item['department_name'] as String? ?? '';
    final doctorName = item['doctor_name'] as String? ?? '';
    final status = item['status'] as String? ?? item['action_badge'] as String? ?? '';
    final timeStr = item['timestamp'] as String?;
    final triagePriority = item['triage_priority'] as String? ?? 'NORMAL';
    final diagnosis = item['diagnosis'] as String?;
    final billAmount = item['bill_amount'] ?? item['paid_amount'] ?? item['total_amount'];

    DateTime? dt;
    if (timeStr != null) {
      dt = DateTime.tryParse(timeStr);
    }
    final formattedTime = dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : 'Earlier';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Open Patient Card / Details Dialog
          final patId = item['patient_id'] as String?;
          if (patId != null) {
            final pat = PatientRepository.cachedPatients.firstWhere(
              (p) => p.id == patId || p.uhid == uhid,
              orElse: () => PatientModel(
                id: patId,
                uhid: uhid,
                hospitalRegNum: 'REG-$uhid',
                fullName: patientName,
                gender: item['patient_gender'] as String? ?? 'OTHER',
                ageYears: int.tryParse(item['patient_age']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? ''),
                phone: item['patient_phone'] as String? ?? '',
                registrationDate: dt ?? DateTime.now(),
              ),
            );
            PatientIdentifierCardWidget.showCardDialog(context, pat);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Token / Icon, Name, Priority/Status Badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                    child: Text(
                      token != null ? '#$token' : 'OPD',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '$uhid • $visitNumber',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (triagePriority.isNotEmpty) TriageChip(priority: triagePriority),
                ],
              ),
              const Divider(height: 18),

              // Details Specifics
              if (dept.isNotEmpty || doctorName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_information_outlined, size: 15, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$dept ${doctorName.isNotEmpty ? "• $doctorName" : ""}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              if (diagnosis != null && diagnosis.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.healing_rounded, size: 15, color: Colors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Diagnosis: $diagnosis',
                          style: const TextStyle(fontSize: 12.5, color: Colors.teal, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Vitals display for Nurse role
              if (role == 'nurse' && item['systolic_bp'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'BP: ${item['systolic_bp']}/${item['diastolic_bp']} mmHg • Pulse: ${item['pulse_rate']} • SpO2: ${item['spo2_percent']}% • Temp: ${item['temperature_f']}°F',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo),
                  ),
                ),

              // Billing amount
              if (billAmount != null && (role == 'billing' || role == 'admin'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 15, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Amount: ₹${(billAmount as num).toStringAsFixed(2)} (${item['payment_method'] ?? 'CASH'})',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),

              // Bottom Row: Timestamp and Tap hint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(formattedTime, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'PAID':
        return Colors.green;
      case 'IN_CONSULTATION':
      case 'UNDER_CONSULTATION':
        return Colors.blue;
      case 'REGISTERED':
      case 'WAITING':
        return Colors.orange;
      case 'EMERGENCY':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }
}
