import 'package:equatable/equatable.dart';

class TimeSchedule extends Equatable {
  final String id;
  final String policyId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TimeSchedule({
    required this.id,
    required this.policyId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  TimeSchedule copyWith({
    String? id,
    String? policyId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeSchedule(
      id: id ?? this.id,
      policyId: policyId ?? this.policyId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        policyId,
        dayOfWeek,
        startTime,
        endTime,
        isActive,
        createdAt,
        updatedAt,
      ];
}
