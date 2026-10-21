import 'package:flutter/material.dart';

/// Icons are stored by key (not code point) so release builds can
/// tree-shake the icon font.
const Map<String, IconData> kCategoryIcons = {
  'restaurant': Icons.restaurant_rounded,
  'fastfood': Icons.fastfood_rounded,
  'coffee': Icons.coffee_rounded,
  'basket': Icons.shopping_basket_rounded,
  'cart': Icons.shopping_cart_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'car': Icons.directions_car_rounded,
  'bus': Icons.directions_bus_rounded,
  'bike': Icons.two_wheeler_rounded,
  'flight': Icons.flight_rounded,
  'bill': Icons.receipt_long_rounded,
  'bolt': Icons.bolt_rounded,
  'wifi': Icons.wifi_rounded,
  'phone': Icons.phone_android_rounded,
  'bag': Icons.shopping_bag_rounded,
  'checkroom': Icons.checkroom_rounded,
  'health': Icons.medical_services_rounded,
  'medication': Icons.medication_rounded,
  'school': Icons.school_rounded,
  'book': Icons.menu_book_rounded,
  'home': Icons.home_rounded,
  'apartment': Icons.apartment_rounded,
  'movie': Icons.movie_rounded,
  'game': Icons.sports_esports_rounded,
  'music': Icons.music_note_rounded,
  'spa': Icons.spa_rounded,
  'gift': Icons.card_giftcard_rounded,
  'redeem': Icons.redeem_rounded,
  'charity': Icons.volunteer_activism_rounded,
  'build': Icons.build_rounded,
  'pets': Icons.pets_rounded,
  'child': Icons.child_care_rounded,
  'fitness': Icons.fitness_center_rounded,
  'travel': Icons.luggage_rounded,
  'salary': Icons.payments_rounded,
  'store': Icons.storefront_rounded,
  'laptop': Icons.laptop_mac_rounded,
  'trending': Icons.trending_up_rounded,
  'savings': Icons.savings_rounded,
  'refund': Icons.replay_rounded,
  'work': Icons.work_rounded,
  'more': Icons.more_horiz_rounded,
  'category': Icons.category_rounded,
};

const Map<String, IconData> kWalletIcons = {
  'cash': Icons.payments_rounded,
  'bank': Icons.account_balance_rounded,
  'card': Icons.credit_card_rounded,
  'mobile': Icons.phone_iphone_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'savings': Icons.savings_rounded,
};

IconData categoryIcon(String key) =>
    kCategoryIcons[key] ?? Icons.category_rounded;

IconData walletIcon(String key) =>
    kWalletIcons[key] ?? kCategoryIcons[key] ?? Icons.account_balance_wallet_rounded;

const List<int> kColorChoices = [
  0xFFFF8A3D,
  0xFFF59E0B,
  0xFFE5484D,
  0xFFF43F5E,
  0xFFEC4899,
  0xFFA855F7,
  0xFF8B5CF6,
  0xFF6366F1,
  0xFF5B4CF0,
  0xFF3B82F6,
  0xFF0EA5E9,
  0xFF06B6D4,
  0xFF14B8A6,
  0xFF10B981,
  0xFF22C55E,
  0xFF84CC16,
  0xFFA16207,
  0xFF64748B,
];
