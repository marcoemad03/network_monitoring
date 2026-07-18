import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/time_schedule.dart';

part 'time_schedule_model.g.dart';

@JsonSerializable(explicitToJson: true)
class TimeScheduleModel {
  final String id;
  @JsonKey(name: 'policy_id')
  final String policyId;
  @JsonKey(name: 'day_of_week')
  final int dayOfWeek;
  @JsonKey(name: 'start_time')
  final String startTime;
  @JsonKey(name: 'end_time')
  final String endTime;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const TimeScheduleModel({
    required this.id,
    required this.policyId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TimeScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$TimeScheduleModelFromJson(json);

  Map<String, dynamic> toJson() => _$TimeScheduleModelToJson(this);

  TimeSchedule toEntity() => TimeSchedule(
        id: id,
        policyId: policyId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory TimeScheduleModel.fromEntity(TimeSchedule entity) =>
      TimeScheduleModel(
        id: entity.id,
        policyId: entity.policyId,
        dayOfWeek: entity.dayOfWeek,
        startTime: entity.startTime,
        endTime: entity.endTime,
        isActive: entity.isActive,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
