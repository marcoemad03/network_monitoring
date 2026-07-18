import 'package:equatable/equatable.dart';

class DashboardWidget extends Equatable {
  final String id;
  final String organizationId;
  final String? userId;
  final String widgetType;
  final String title;
  final Map<String, dynamic> config;
  final int position;
  final int width;
  final int height;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DashboardWidget({
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

  DashboardWidget copyWith({
    String? id,
    String? organizationId,
    String? userId,
    String? widgetType,
    String? title,
    Map<String, dynamic>? config,
    int? position,
    int? width,
    int? height,
    bool? isVisible,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DashboardWidget(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      widgetType: widgetType ?? this.widgetType,
      title: title ?? this.title,
      config: config ?? this.config,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        userId,
        widgetType,
        title,
        config,
        position,
        width,
        height,
        isVisible,
        createdAt,
        updatedAt,
      ];
}
