import 'package:flutter/material.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';

class InventoryViewModel extends ChangeNotifier {
  final InventoryRepository _repo = InventoryRepository();

  List<InventoryItem> myItems = [];
  bool isLoading = false;

  Future<void> loadInventory() async {
    isLoading = true;
    notifyListeners(); // Tell UI to show loading spinner

    try {
      myItems = await _repo.fetchMyInventory();
    } catch (e) {
      debugPrint("Error loading inventory: $e");
    } finally {
      isLoading = false;
      notifyListeners(); // Tell UI to show the list
    }
  }
}