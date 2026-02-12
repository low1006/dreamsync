enum StoreItemType { AUDIO, VIDEO, ITEM, UNKNOWN }

class InventoryItem {
  final int id;             // The ID in 'user_inventory' table
  final int quantity;       // How many the user owns
  final StoreItem details;  // The actual item details (Name, File, etc.)

  InventoryItem({
    required this.id,
    required this.quantity,
    required this.details,
  });

  // Factory to create from the 'user_inventory' JOIN query
  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'], // ID from user_inventory
      quantity: map['quantity'] ?? 1,
      // The 'store_items' field comes from the Supabase join
      details: StoreItem.fromMap(map['store_items'] ?? {}),
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
      id: map['id'] ?? 0,
      name: map['name'] ?? 'Unknown Item',
      cost: map['cost'] ?? 0,
      type: _parseType(map['type']),
      metadata: map['metadata'] ?? {},
    );
  }

  // --- Helper to read the 'type' string from database ---
  static StoreItemType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'AUDIO': return StoreItemType.AUDIO;
      case 'VIDEO': return StoreItemType.VIDEO;
      case 'ITEM':  return StoreItemType.ITEM;
      default:      return StoreItemType.UNKNOWN;
    }
  }

  // --- SMART GETTERS (The "Thinking" Logic) ---

  // 1. For Audio: Get the filename (e.g., "rain.mp3")
  String get audioFile => metadata['file'] ?? 'classic.mp3';

  // 2. For Video: Get the YouTube URL or file path
  String get videoUrl => metadata['url'] ?? '';

  // 3. For Items (Streak Freeze): Get protection days
  int get freezeDays => metadata['days_protected'] ?? 0;

  // 4. For Items: Get an icon name if you stored one
  String get iconName => metadata['icon'] ?? 'help_outline';



}