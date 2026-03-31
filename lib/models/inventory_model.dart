import "package:dreamsync/util/parsers.dart";
enum StoreItemType { avatar, audio, item, unknown }

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
      id: Parsers.toInt(map['id']),
      quantity: Parsers.toInt(map['quantity'], fallback: 1),
      details: StoreItem.fromMap(
        Map<String, dynamic>.from(map['store_items'] ?? {}),
      ),
    );
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
      id: Parsers.toInt(map['id']),
      name: (map['name'] ?? 'Unknown Item').toString(),
      cost: Parsers.toInt(map['cost']),
      type: _parseType(map['type']?.toString()),
      metadata: _toMetadataMap(map['metadata']),
    );
  }

  static Map<String, dynamic> _toMetadataMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static StoreItemType _parseType(String? typeStr) {
    switch ((typeStr ?? '').toLowerCase()) {
      case 'avatar':
        return StoreItemType.avatar;
      case 'audio':
        return StoreItemType.audio;
      case 'item':
        return StoreItemType.item;
      default:
        return StoreItemType.unknown;
    }
  }

  bool get isAvatar => type == StoreItemType.avatar;
  bool get isConsumableShield => protectDays > 0;

  String get audioFile => metadata['file']?.toString() ?? 'classic.mp3';
  int get protectDays => Parsers.toInt(metadata['days_protected']);
  String get assetPath => metadata['file']?.toString() ?? '';
}