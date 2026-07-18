import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/reporting/dashboard_widget_entity.dart';

part 'dashboard_widget_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DashboardWidgetModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'user_id')
  final String? userId;
  @JsonKey(name: 'widget_type')
  final String widgetType;
  final String title;
  @JsonKey(fromJson: _stringToMap, toJson: _mapToString)
  final Map<String, dynamic> config;
  final int position;
  final int width;
  final int height;
  @JsonKey(name: 'is_visible')
  final bool isVisible;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const DashboardWidgetModel({
    required this.id,
    required this.organizationId,
    this.userId,
    required this.widgetType,
    required this.title,
    this.config = const {},
    this.position = 0,
    this.width = 1,
    this.height = 1,
    this.isVisible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  static Map<String, dynamic> _stringToMap(dynamic json) =>
      json is String
          ? Map<String, dynamic>.from(jsonDecode(json) as Map)
          : (json as Map<String, dynamic>);

  static String _mapToString(Map<String, dynamic> map) => jsonEncode(map);

  factory DashboardWidgetModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardWidgetModelFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardWidgetModelToJson(this);

  DashboardWidget toEntity() => DashboardWidget(
        id: id,
        organizationId: organizationId,
        userId: userId,
        widgetType: widgetType,
        title: title,
        config: config,
        position: position,
        width: width,
        height: height,
        isVisible: isVisible,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory DashboardWidgetModel.fromEntity(DashboardWidget entity) =>
      DashboardWidgetModel(
        id: entity.id,
        organizationId: entity.organizationId,
        userId: entity.userId,
        widgetType: entity.widgetType,
        title: entity.title,
        config: entity.config,
        position: entity.position,
        width: entity.width,
        height: entity.height,
        isVisible: entity.isVisible,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
