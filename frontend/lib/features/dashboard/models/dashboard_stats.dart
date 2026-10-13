class DashboardStatsModel {
  final int totalPatients;
  final int totalVisits;
  final int activeDoctors;
  final int departments;
  final int waiting;
  final int triaged;
  final int completed;

  DashboardStatsModel({
    required this.totalPatients,
    required this.totalVisits,
    required this.activeDoctors,
    required this.departments,
    required this.waiting,
    required this.triaged,
    required this.completed,
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
