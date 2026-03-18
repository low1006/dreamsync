enum StoreItemType { AUDIO, VIDEO, ITEM, UNKNOWN }

class InventoryItem {
  final int id;
  final int quantity;
  final StoreItem details;

  InventoryItem({
    required this.id,
    required this.quantity,
    required this.details,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: _toInt(map['id']),
      quantity: _toInt(map['quantity'], fallback: 1),
      details: StoreItem.fromMap(
        Map<String, dynamic>.from(map['store_items'] ?? {}),
      ),
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class StoreItem {
  final int id;
  final String name;
  final int cost;
  final StoreItemType type;
  final Map<String, dynamic> metadata;

  StoreItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.type,
    required this.metadata,
  });

  factory StoreItem.fromMap(Map<String, dynamic> map) {
    return StoreItem(
      id: _toInt(map['id']),
      name: (map['name'] ?? 'Unknown Item').toString(),
      cost: _toInt(map['cost']),
      type: _parseType(map['type']?.toString()),
      metadata: _toMetadataMap(map['metadata']),
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, dynamic> _toMetadataMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static StoreItemType _parseType(String? typeStr) {
    switch ((typeStr ?? '').toUpperCase()) {
      case 'AUDIO':
        return StoreItemType.AUDIO;
      case 'VIDEO':
        return StoreItemType.VIDEO;
      case 'ITEM':
        return StoreItemType.ITEM;
      default:
        return StoreItemType.UNKNOWN;
    }
  }

  String get audioFile => metadata['file']?.toString() ?? 'classic.mp3';
  String get videoUrl => metadata['url']?.toString() ?? '';
  int get freezeDays => _toInt(metadata['days_protected']);
  String get iconName => metadata['icon']?.toString() ?? 'help_outline';
}