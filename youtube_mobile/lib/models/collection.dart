class CollectionRule {
  final String field;    // 'duration' (seconds), 'author', 'tags', 'isAudio', 'watchedPercent', 'isFavorited'
  final String operator; // 'gt', 'lt', 'eq', 'contains'
  final dynamic value;

  CollectionRule({required this.field, required this.operator, required this.value});

  factory CollectionRule.fromJson(Map<String, dynamic> json) {
    return CollectionRule(
      field: json['field'] as String,
      operator: json['operator'] as String,
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'operator': operator,
      'value': value,
    };
  }
}

class MediaCollection {
  final String id;
  final String name;
  final String iconName; // e.g. "favorite", "video_library", "music_note", "history"
  final int colorHex;    // e.g. 0xff00ff88
  final List<CollectionRule> rules;
  final bool isSmart;

  MediaCollection({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.rules,
    this.isSmart = false,
  });

  factory MediaCollection.fromJson(Map<String, dynamic> json) {
    return MediaCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String,
      colorHex: json['colorHex'] as int,
      rules: (json['rules'] as List<dynamic>?)
              ?.map((e) => CollectionRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isSmart: json['isSmart'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'colorHex': colorHex,
      'rules': rules.map((e) => e.toJson()).toList(),
      'isSmart': isSmart,
    };
  }
}
