class DashboardStatsModel {
  final int totalPatients;
  final int todayRegisteredPatients;
  final int yesterdayRegisteredPatients;
  final int todayTriagedVitals;
  final int yesterdayTriagedVitals;
  final int totalTriagedVitals;
  final int totalVisits;
  final int activeDoctors;
  final int departments;
  final int waiting;
  final int triaged;
  final int completed;

  const DashboardStatsModel({
    this.totalPatients = 0,
    this.todayRegisteredPatients = 0,
    this.yesterdayRegisteredPatients = 0,
    this.todayTriagedVitals = 0,
    this.yesterdayTriagedVitals = 0,
    this.totalTriagedVitals = 0,
    this.totalVisits = 0,
    this.activeDoctors = 0,
    this.departments = 0,
    this.waiting = 0,
    this.triaged = 0,
    this.completed = 0,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['queue_breakdown'] as Map<String, dynamic>? ?? {};

    return DashboardStatsModel(
      totalPatients: (json['total_patients'] as num?)?.toInt() ??
          (json['total_patients_registered'] as num?)?.toInt() ??
          0,
      todayRegisteredPatients: (json['today_registered_patients'] as num?)?.toInt() ?? 0,
      yesterdayRegisteredPatients: (json['yesterday_registered_patients'] as num?)?.toInt() ?? 0,
      todayTriagedVitals: (json['today_triaged_vitals'] as num?)?.toInt() ?? 0,
      yesterdayTriagedVitals: (json['yesterday_triaged_vitals'] as num?)?.toInt() ?? 0,
      totalTriagedVitals: (json['total_triaged_vitals'] as num?)?.toInt() ?? 0,
      totalVisits: (json['total_visits'] as num?)?.toInt() ??
          (json['visits_today_count'] as num?)?.toInt() ??
          0,
      activeDoctors: (json['active_doctors'] as num?)?.toInt() ?? 0,
      departments: (json['departments'] as num?)?.toInt() ??
          (json['active_clinics'] as num?)?.toInt() ??
          0,
      waiting: (json['waiting'] as num?)?.toInt() ??
          (breakdown['waiting'] as num?)?.toInt() ??
          (breakdown['WAITING'] as num?)?.toInt() ??
          0,
      triaged: (json['triaged'] as num?)?.toInt() ??
          (breakdown['triaged'] as num?)?.toInt() ??
          (breakdown['TRIAGED'] as num?)?.toInt() ??
          0,
      completed: (json['completed'] as num?)?.toInt() ??
          (breakdown['completed'] as num?)?.toInt() ??
          (breakdown['COMPLETED'] as num?)?.toInt() ??
          0,
    );
  }
}
