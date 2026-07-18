// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_schedule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimeScheduleModel _$TimeScheduleModelFromJson(Map<String, dynamic> json) =>
    TimeScheduleModel(
      id: json['id'] as String,
      policyId: json['policy_id'] as String,
      dayOfWeek: (json['day_of_week'] as num).toInt(),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$TimeScheduleModelToJson(TimeScheduleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'policy_id': instance.policyId,
      'day_of_week': instance.dayOfWeek,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
