import 'package:flutter/material.dart';
import '../providers/app_state.dart';

/// Central emoji → Material icon resolver.
///
/// The app stores user-chosen icons as emoji strings (categories, group icons,
/// saving-goal icons, subscription icons). To render an icons-only UI WITHOUT a
/// data migration, every display site passes the stored emoji through this
/// function and draws the returned [IconData]. Old records keep working; unknown
/// emojis fall back to a neutral icon.
/// Color to tint an emoji-derived icon. Category emojis use their defined
/// palette color; everything else uses [fallback].
Color colorForEmoji(String? e, {required Color fallback}) {
  if (e == null) return fallback;
  final s = e.trim();
  if (s.startsWith('sub:')) {
    final sub = AppState.subByKey(s);
    if (sub != null) return _hex(sub.color, fallback);
    return fallback;
  }
  for (final c in AppState.expenseCategories) {
    if (c.icon == s) return _hex(c.color, fallback);
  }
  for (final c in AppState.incomeCategories) {
    if (c.icon == s) return _hex(c.color, fallback);
  }
  return fallback;
}

Color _hex(String hex, Color fallback) {
  try {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return fallback;
  }
}

IconData iconForEmoji(String? e,
    {IconData fallback = Icons.label_outline_rounded}) {
  if (e == null) return fallback;
  final s = e.trim();
  if (s.isEmpty) return fallback;

  // 0) Sub-category keys (sub:group:name) carry their own Material icon.
  if (s.startsWith('sub:')) {
    final sub = AppState.subByKey(s);
    if (sub?.materialIcon != null) return sub!.materialIcon!;
    return fallback;
  }

  // 1) Categories already define their own Material icon.
  for (final c in AppState.expenseCategories) {
    if (c.icon == s && c.materialIcon != null) return c.materialIcon!;
  }
  for (final c in AppState.incomeCategories) {
    if (c.icon == s && c.materialIcon != null) return c.materialIcon!;
  }

  // 2) Group / goal / subscription / decorative emojis.
  switch (s) {
    // Places & things
    case '🏠': return Icons.home_rounded;
    case '🍽️': case '🍽': return Icons.restaurant_rounded;
    case '🍔': return Icons.lunch_dining_rounded;
    case '☕': return Icons.local_cafe_rounded;
    case '✈️': case '✈': return Icons.flight_rounded;
    case '🚗': return Icons.directions_car_rounded;
    case '🚌': return Icons.directions_bus_rounded;
    case '🛒': return Icons.shopping_cart_rounded;
    case '🛍️': case '🛍': return Icons.shopping_bag_rounded;
    case '🎁': return Icons.card_giftcard_rounded;
    case '🎉': return Icons.celebration_rounded;
    case '🎫': return Icons.local_activity_rounded;
    case '🏖️': case '🏖': return Icons.beach_access_rounded;
    case '🏕️': case '🏕': return Icons.cabin_rounded;
    case '🧳': return Icons.luggage_rounded;
    case '🎓': return Icons.school_rounded;
    case '📚': return Icons.menu_book_rounded;
    case '💼': return Icons.work_rounded;
    case '💻': return Icons.laptop_mac_rounded;
    case '📱': return Icons.smartphone_rounded;
    case '📺': return Icons.tv_rounded;
    case '🎬': return Icons.movie_rounded;
    case '🎵': case '🎶': return Icons.music_note_rounded;
    case '🎮': return Icons.sports_esports_rounded;
    case '⚽': return Icons.sports_soccer_rounded;
    case '💪': return Icons.fitness_center_rounded;
    case '💊': return Icons.medication_rounded;
    case '🐾': return Icons.pets_rounded;
    case '❤️': case '❤': case '💚': case '💙': case '💜':
      return Icons.favorite_rounded;
    case '💍': return Icons.diamond_rounded;
    case '🎯': return Icons.track_changes_rounded;
    case '🏆': return Icons.emoji_events_rounded;
    case '🏦': return Icons.account_balance_rounded;
    case '🏧': return Icons.account_balance_wallet_rounded;
    // Money
    case '💰': case '🪙': return Icons.savings_rounded;
    case '💵': case '💸': return Icons.payments_rounded;
    case '💳': return Icons.credit_card_rounded;
    case '💱': return Icons.currency_exchange_rounded;
    case '📈': return Icons.trending_up_rounded;
    case '📉': return Icons.trending_down_rounded;
    case '📊': return Icons.bar_chart_rounded;
    // People
    case '👤': return Icons.person_rounded;
    case '👥': return Icons.group_rounded;
    case '🤝': return Icons.handshake_rounded;
    // UI / status / decorative
    case '💡': return Icons.lightbulb_outline_rounded;
    case '📭': return Icons.inbox_rounded;
    case '📬': return Icons.markunread_mailbox_rounded;
    case '🧾': return Icons.receipt_long_rounded;
    case '📄': return Icons.description_rounded;
    case '🔗': return Icons.link_rounded;
    case '🔔': return Icons.notifications_rounded;
    case '📅': return Icons.event_rounded;
    case '✓': case '✅': return Icons.check_circle_rounded;
    case '⏸️': case '⏸': return Icons.pause_circle_outline_rounded;
    case '▶️': case '▶': return Icons.play_circle_outline_rounded;
    case '✏️': case '✏': return Icons.edit_rounded;
    case '🗑️': case '🗑': return Icons.delete_outline_rounded;
    case '🔄': return Icons.autorenew_rounded;
    case '📦': return Icons.inventory_2_rounded;
    case '⏰': case '⏱️': return Icons.alarm_rounded;
    case '✨': return Icons.auto_awesome_rounded;
    case '⭐': case '🌟': return Icons.star_rounded;
    case '🔥': return Icons.local_fire_department_rounded;
    case '🚀': return Icons.rocket_launch_rounded;
    case '👋': return Icons.waving_hand_rounded;
    case '🙌': case '🎊': return Icons.celebration_rounded;
    case '←': return Icons.arrow_back_rounded;
    case '→': return Icons.arrow_forward_rounded;
    default:
      return fallback;
  }
}
