class DashboardStatsModel {
  final int totalPatients;
  final int totalVisits;
  final int activeDoctors;
  final int departments;
  final int waiting;
  final int triaged;
  final int completed;

  const DashboardStatsModel({
    this.totalPatients = 0,
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
      totalPatients: json['total_patients'] as int? ?? 0,
      totalVisits: json['total_visits'] as int? ?? 0,
      activeDoctors: json['active_doctors'] as int? ?? 0,
      departments: json['departments'] as int? ?? 0,
      waiting: breakdown['waiting'] as int? ?? 0,
      triaged: breakdown['triaged'] as int? ?? 0,
      completed: breakdown['completed'] as int? ?? 0,
    );
  }
}
