class DashboardStatsModel {
  final int totalPatients;
  final int totalVisits;
  final int activeDoctors;
  final int departments;
  final int waiting;
  final int triaged;
  final int completed;
  final int totalSignups;
  final int totalSignins;
  final int activeSessions;

  const DashboardStatsModel({
    this.totalPatients = 0,
    this.totalVisits = 0,
    this.activeDoctors = 0,
    this.departments = 0,
    this.waiting = 0,
    this.triaged = 0,
    this.completed = 0,
    this.totalSignups = 0,
    this.totalSignins = 0,
    this.activeSessions = 0,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['queue_breakdown'] as Map<String, dynamic>? ?? {};

    final waitingVal = json['waiting'] as int? ??
        breakdown['waiting'] as int? ??
        breakdown['WAITING'] as int? ??
        0;
    final triagedVal = json['triaged'] as int? ??
        breakdown['triaged'] as int? ??
        breakdown['TRIAGED'] as int? ??
        breakdown['TRIAGE'] as int? ??
        0;
    final completedVal = json['completed'] as int? ??
        breakdown['completed'] as int? ??
        breakdown['COMPLETED'] as int? ??
        0;

    final patients = json['total_patients'] as int? ?? 0;
    final staff = json['total_staff_accounts'] as int? ?? json['staff_signups'] as int? ?? 0;
    final signupsVal = json['total_signups'] as int? ?? (patients + staff);

    final signinsVal = json['total_signins_today'] as int? ??
        json['total_signins'] as int? ??
        json['signins_today'] as int? ??
        0;

    final sessionsVal = json['active_sessions'] as int? ?? 0;

    return DashboardStatsModel(
      totalPatients: patients,
      totalVisits: json['total_visits'] as int? ?? 0,
      activeDoctors: json['active_doctors'] as int? ?? 0,
      departments: json['departments'] as int? ?? 0,
      waiting: waitingVal,
      triaged: triagedVal,
      completed: completedVal,
      totalSignups: signupsVal,
      totalSignins: signinsVal,
      activeSessions: sessionsVal,
    );
  }
}
