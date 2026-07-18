// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_widget_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardWidgetModel _$DashboardWidgetModelFromJson(
  Map<String, dynamic> json,
) => DashboardWidgetModel(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  userId: json['user_id'] as String?,
  widgetType: json['widget_type'] as String,
  title: json['title'] as String,
  config:
      json['config'] == null
          ? const {}
          : DashboardWidgetModel._stringToMap(json['config']),
  position: (json['position'] as num?)?.toInt() ?? 0,
  width: (json['width'] as num?)?.toInt() ?? 1,
  height: (json['height'] as num?)?.toInt() ?? 1,
  isVisible: json['is_visible'] as bool? ?? true,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$DashboardWidgetModelToJson(
  DashboardWidgetModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'organization_id': instance.organizationId,
  'user_id': instance.userId,
  'widget_type': instance.widgetType,
  'title': instance.title,
  'config': DashboardWidgetModel._mapToString(instance.config),
  'position': instance.position,
  'width': instance.width,
  'height': instance.height,
  'is_visible': instance.isVisible,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};
