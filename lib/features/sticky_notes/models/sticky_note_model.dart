// lib/features/sticky_notes/models/sticky_note_model.dart

class StickyNoteModel {
  final String id;
  final String userId;
  final String? deliveryPartnerId;
  final String? customerId;
  final String customerName;
  final String shopName;
  final List<StickyNoteItem> items;
  final int totalQuantity;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StickyNoteModel({
    required this.id,
    required this.userId,
    this.deliveryPartnerId,
    this.customerId,
    required this.customerName,
    required this.shopName,
    required this.items,
    required this.totalQuantity,
    required this.createdAt,
    this.updatedAt,
  });

  factory StickyNoteModel.fromJson(Map<String, dynamic> json) {
    return StickyNoteModel(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      deliveryPartnerId: json['deliveryPartnerId']?.toString(),
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      items: (json['items'] as List?)
              ?.map((item) => StickyNoteItem.fromJson(item))
              .toList() ??
          [],
      totalQuantity: json['totalQuantity']?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'deliveryPartnerId': deliveryPartnerId,
      'customerId': customerId,
      'customerName': customerName,
      'shopName': shopName,
      'items': items.map((item) => item.toJson()).toList(),
      'totalQuantity': totalQuantity,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  int get totalBoxes {
    return items
        .where((item) => item.unit == 'box')
        .fold(0, (sum, item) => sum + item.quantity);
  }

  String getRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}

class StickyNoteItem {
  final String? productId;
  final String productName;
  final int quantity;
  final String? unit;

  StickyNoteItem({
    this.productId,
    required this.productName,
    required this.quantity,
    this.unit,
  });

  factory StickyNoteItem.fromJson(Map<String, dynamic> json) {
    return StickyNoteItem(
      productId: json['productId']?.toString(),
      productName: json['productName']?.toString() ?? '',
      quantity: json['quantity']?.toInt() ?? 0,
      unit: json['unit']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

// ✅ Customer Model for Autocomplete
class CustomerSuggestion {
  final String id;
  final String name;
  final String shopName;
  final String shopAddress;
  final List<String> contacts;

  CustomerSuggestion({
    required this.id,
    required this.name,
    required this.shopName,
    required this.shopAddress,
    required this.contacts,
  });

  factory CustomerSuggestion.fromJson(Map<String, dynamic> json) {
    return CustomerSuggestion(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? '',
      shopAddress: json['shopAddress']?.toString() ?? '',
      contacts: (json['contacts'] as List?)
              ?.map((c) => c.toString())
              .toList() ??
          [],
    );
  }

  String get displayName => '$name - $shopName';
  String? get primaryContact => contacts.isNotEmpty ? contacts.first : null;
}

// ✅ Product Model for Autocomplete
class ProductSuggestion {
  final String id;
  final String name;
  final String? category;
  final double? price;
  final String? unit;
  final int? currentStock;

  ProductSuggestion({
    required this.id,
    required this.name,
    this.category,
    this.price,
    this.unit,
    this.currentStock,
  });

  factory ProductSuggestion.fromJson(Map<String, dynamic> json) {
    return ProductSuggestion(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString(),
      price: json['price']?.toDouble(),
      unit: json['unit']?.toString(),
      currentStock: json['quantity']?.toInt(),
    );
  }

  String get displayName {
    if (category != null && category!.isNotEmpty) {
      return '$name ($category)';
    }
    return name;
  }

  String get stockInfo {
    if (currentStock != null && unit != null) {
      return '$currentStock $unit';
    }
    return '--';
  }
}