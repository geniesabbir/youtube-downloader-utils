class AutoRule {
  final String ruleId;
  final String name;
  final String channelId;
  final bool audioOnly;
  final bool wifiOnly;
  final int? maxDurationMinutes;
  final bool autoDeleteAfterWatch;
  final bool enabled;

  AutoRule({
    required this.ruleId,
    required this.name,
    required this.channelId,
    this.audioOnly = false,
    this.wifiOnly = true,
    this.maxDurationMinutes,
    this.autoDeleteAfterWatch = false,
    this.enabled = true,
  });

  factory AutoRule.fromJson(Map<String, dynamic> json) {
    return AutoRule(
      ruleId: json['ruleId'] as String,
      name: json['name'] as String,
      channelId: json['channelId'] as String,
      audioOnly: json['audioOnly'] as bool? ?? false,
      wifiOnly: json['wifiOnly'] as bool? ?? true,
      maxDurationMinutes: json['maxDurationMinutes'] as int?,
      autoDeleteAfterWatch: json['autoDeleteAfterWatch'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ruleId': ruleId,
      'name': name,
      'channelId': channelId,
      'audioOnly': audioOnly,
      'wifiOnly': wifiOnly,
      'maxDurationMinutes': maxDurationMinutes,
      'autoDeleteAfterWatch': autoDeleteAfterWatch,
      'enabled': enabled,
    };
  }

  AutoRule copyWith({
    String? name,
    String? channelId,
    bool? audioOnly,
    bool? wifiOnly,
    int? maxDurationMinutes,
    bool? autoDeleteAfterWatch,
    bool? enabled,
  }) {
    return AutoRule(
      ruleId: ruleId,
      name: name ?? this.name,
      channelId: channelId ?? this.channelId,
      audioOnly: audioOnly ?? this.audioOnly,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      autoDeleteAfterWatch: autoDeleteAfterWatch ?? this.autoDeleteAfterWatch,
      enabled: enabled ?? this.enabled,
    );
  }
}
