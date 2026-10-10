import 'package:flutter/foundation.dart';

/// Immutable model representing an ad-removal subscription plan.
/// Strictly adheres to mastui/AGENT.md rules (no Flutter widget imports, immutable).
@immutable
class SubscriptionPlan {
  final String id;
  final String title;
  final String price;
  final String billingPeriod;
  final String? badge;
  final bool isPopular;
  final String currencyCode;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.billingPeriod,
    this.badge,
    this.isPopular = false,
    this.currencyCode = 'INR',
  });

  SubscriptionPlan copyWith({
    String? id,
    String? title,
    String? price,
    String? billingPeriod,
    String? badge,
    bool? isPopular,
    String? currencyCode,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      badge: badge ?? this.badge,
      isPopular: isPopular ?? this.isPopular,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'billingPeriod': billingPeriod,
      'badge': badge,
      'isPopular': isPopular,
      'currencyCode': currencyCode,
    };
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      price: json['price'] as String? ?? '',
      billingPeriod: json['billingPeriod'] as String? ?? '',
      badge: json['badge'] as String?,
      isPopular: json['isPopular'] as bool? ?? false,
      currencyCode: json['currencyCode'] as String? ?? 'INR',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionPlan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          price == other.price &&
          billingPeriod == other.billingPeriod &&
          badge == other.badge &&
          isPopular == other.isPopular &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        price,
        billingPeriod,
        badge,
        isPopular,
        currencyCode,
      );
}
