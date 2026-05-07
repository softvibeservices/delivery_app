// lib/features/orders/models/order_model.dart

import 'package:flutter/material.dart';

class OrderModel {
  final String id;
  final String userId;
  final String orderId;
  final String? serialNumber;
  final String? shopName;
  
  // Customer Details
  final String? customerId;
  final String customerName;
  final String customerAddress;
  final String? customerContact;
  final double? customerLat;
  final double? customerLng;
  
  // Items
  final List<OrderItem> items;
  final List<OrderItem>? freeItems;
  final Map<String, dynamic>? quantitySummary;
  
  // Pricing
  final double subtotal;
  final double discountPercentage;
  final double total;
  final String? remarks;
  
  // Settlement
  final String status; // "Unsettled" | "settled"
  final String? settlementMethod;
  final double settlementAmount;
  
  // Delivery
  final String? deliveryPartnerId;
  final String deliveryStatus; // "Pending" | "On the Way" | "Delivered"
  final DateTime? deliveryAssignedAt;
  final DateTime? deliveryOnTheWayAt;
  final DateTime? deliveryCompletedAt;
  final String? deliveryNotes;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.orderId,
    this.serialNumber,
    this.shopName,
    this.customerId,
    required this.customerName,
    required this.customerAddress,
    this.customerContact,
    this.customerLat,
    this.customerLng,
    required this.items,
    this.freeItems,
    this.quantitySummary,
    required this.subtotal,
    required this.discountPercentage,
    required this.total,
    this.remarks,
    required this.status,
    this.settlementMethod,
    required this.settlementAmount,
    this.deliveryPartnerId,
    required this.deliveryStatus,
    this.deliveryAssignedAt,
    this.deliveryOnTheWayAt,
    this.deliveryCompletedAt,
    this.deliveryNotes,
    required this.createdAt,
    this.updatedAt,
  });

  // ─── copyWith ─────────────────────────────────────────────────────────────
  // FIX (Bug 4B): Used in _updateStatus() on OrderDetailsScreen when the order
  // disappears from the provider list after being marked Delivered — we still
  // need to update local state so the slide button hides correctly.
  OrderModel copyWith({
    String? id,
    String? userId,
    String? orderId,
    String? serialNumber,
    String? shopName,
    String? customerId,
    String? customerName,
    String? customerAddress,
    String? customerContact,
    double? customerLat,
    double? customerLng,
    List<OrderItem>? items,
    List<OrderItem>? freeItems,
    Map<String, dynamic>? quantitySummary,
    double? subtotal,
    double? discountPercentage,
    double? total,
    String? remarks,
    String? status,
    String? settlementMethod,
    double? settlementAmount,
    String? deliveryPartnerId,
    String? deliveryStatus,
    DateTime? deliveryAssignedAt,
    DateTime? deliveryOnTheWayAt,
    DateTime? deliveryCompletedAt,
    String? deliveryNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      serialNumber: serialNumber ?? this.serialNumber,
      shopName: shopName ?? this.shopName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerContact: customerContact ?? this.customerContact,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      items: items ?? this.items,
      freeItems: freeItems ?? this.freeItems,
      quantitySummary: quantitySummary ?? this.quantitySummary,
      subtotal: subtotal ?? this.subtotal,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      total: total ?? this.total,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      settlementMethod: settlementMethod ?? this.settlementMethod,
      settlementAmount: settlementAmount ?? this.settlementAmount,
      deliveryPartnerId: deliveryPartnerId ?? this.deliveryPartnerId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryAssignedAt: deliveryAssignedAt ?? this.deliveryAssignedAt,
      deliveryOnTheWayAt: deliveryOnTheWayAt ?? this.deliveryOnTheWayAt,
      deliveryCompletedAt: deliveryCompletedAt ?? this.deliveryCompletedAt,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ✅ FIXED: Helper method to parse UTC and convert to local time (IST)
  static DateTime _parseUtcToLocal(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    
    try {
      DateTime utcDate;
      if (dateValue is String) {
        // Parse as UTC
        utcDate = DateTime.parse(dateValue).toUtc();
      } else if (dateValue is DateTime) {
        utcDate = dateValue.toUtc();
      } else {
        debugPrint('⚠️ Unexpected date type: ${dateValue.runtimeType}');
        return DateTime.now();
      }
      
      // Convert to local time (IST on Indian devices)
      return utcDate.toLocal();
    } catch (e) {
      debugPrint('❌ Error parsing date: $e');
      return DateTime.now();
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      serialNumber: json['serialNumber']?.toString(),
      shopName: json['shopName']?.toString(),
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString() ?? 'Unknown',
      customerAddress: json['customerAddress']?.toString() ?? '',
      customerContact: json['customerContact']?.toString(),
      customerLat: json['customerLat']?.toDouble(),
      customerLng: json['customerLng']?.toDouble(),
      items: (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      freeItems: (json['freeItems'] as List?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList(),
      quantitySummary: json['quantitySummary'] as Map<String, dynamic>?,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      discountPercentage: (json['discountPercentage'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      remarks: json['remarks']?.toString(),
      status: json['status']?.toString() ?? 'Unsettled',
      settlementMethod: json['settlementMethod']?.toString(),
      settlementAmount: (json['settlementAmount'] ?? 0).toDouble(),
      deliveryPartnerId: json['deliveryPartnerId']?.toString(),
      deliveryStatus: json['deliveryStatus']?.toString() ?? 'Pending',
      // ✅ FIXED: All dates are now converted from UTC to local time
      deliveryAssignedAt: json['deliveryAssignedAt'] != null
          ? _parseUtcToLocal(json['deliveryAssignedAt'])
          : null,
      deliveryOnTheWayAt: json['deliveryOnTheWayAt'] != null
          ? _parseUtcToLocal(json['deliveryOnTheWayAt'])
          : null,
      deliveryCompletedAt: json['deliveryCompletedAt'] != null
          ? _parseUtcToLocal(json['deliveryCompletedAt'])
          : null,
      deliveryNotes: json['deliveryNotes']?.toString(),
      createdAt: json['createdAt'] != null
          ? _parseUtcToLocal(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? _parseUtcToLocal(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'orderId': orderId,
      'serialNumber': serialNumber,
      'shopName': shopName,
      'customerId': customerId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerContact': customerContact,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'items': items.map((item) => item.toJson()).toList(),
      'freeItems': freeItems?.map((item) => item.toJson()).toList(),
      'quantitySummary': quantitySummary,
      'subtotal': subtotal,
      'discountPercentage': discountPercentage,
      'total': total,
      'remarks': remarks,
      'status': status,
      'settlementMethod': settlementMethod,
      'settlementAmount': settlementAmount,
      'deliveryPartnerId': deliveryPartnerId,
      'deliveryStatus': deliveryStatus,
      'deliveryAssignedAt': deliveryAssignedAt?.toUtc().toIso8601String(),
      'deliveryOnTheWayAt': deliveryOnTheWayAt?.toUtc().toIso8601String(),
      'deliveryCompletedAt': deliveryCompletedAt?.toUtc().toIso8601String(),
      'deliveryNotes': deliveryNotes,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  int get totalItems {
    int count = items.fold(0, (sum, item) => sum + (item.quantity ?? 0));
    if (freeItems != null) {
      count += freeItems!.fold(0, (sum, item) => sum + (item.quantity ?? 0));
    }
    return count;
  }

  bool get canUpdateStatus {
    return deliveryStatus != 'Delivered';
  }

  String get nextStatus {
    switch (deliveryStatus) {
      case 'Pending':
        return 'On the Way';
      case 'On the Way':
        return 'Delivered';
      default:
        return deliveryStatus;
    }
  }
}

class OrderItem {
  final String? productId;
  final String productName;
  final int? quantity;
  final String? unit;
  final double? price;
  final double? total;

  OrderItem({
    this.productId,
    required this.productName,
    this.quantity,
    this.unit,
    this.price,
    this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId']?.toString(),
      productName: json['productName']?.toString() ?? 'Unknown',
      quantity: json['quantity']?.toInt(),
      unit: json['unit']?.toString(),
      price: json['price']?.toDouble(),
      total: json['total']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'total': total,
    };
  }
}