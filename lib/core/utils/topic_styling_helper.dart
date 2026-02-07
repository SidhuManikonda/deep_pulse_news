import 'package:flutter/material.dart';
import '../../data/models/topic.dart';

class TopicStylingHelper {
  // Predefined color palette for topics
  static const Map<String, Color> _topicColors = {
    'your-area': Color(0xFFFF6B6B),           // Red - Your Area
    'state-name': Color(0xFF4ECDC4),          // Teal - State
    'national-international': Color(0xFF45B7D1), // Blue - National/International
    'calendar': Color(0xFFF9CA24),           // Yellow - Calendar
    'my-journey': Color(0xFF6C5CE7),         // Purple - My Journey
    'poster': Color(0xFFA29BFE),             // Light Purple - Poster
    'status': Color(0xFF55EFC4),             // Mint - Status
    'quiz': Color(0xFFFDCB6E),               // Orange - Quiz
    'mobiles-other-electronics': Color(0xFF00B894), // Green - Electronics
    'jobs': Color(0xFFE17055),              // Coral - Jobs
    'education': Color(0xFF74B9FF),          // Light Blue - Education
    'weekly-ads': Color(0xFFFF7675),         // Pink - Weekly Ads
    'cinema': Color(0xFFFDCB6E),             // Orange - Cinema
    'sports': Color(0xFF00CEC9),             // Teal - Sports
    'special': Color(0xFFFFD700),            // Gold - Special
    'default': Color(0xFF636E72),            // Gray
  };

  // Predefined emojis for topics
  static const Map<String, String> _topicEmojis = {
    'your-area': '📍',                       // Location pin - Your Area
    'state-name': '🏛️',                      // Building - State
    'national-international': '🌍',          // Globe - National/International
    'calendar': '📅',                        // Calendar
    'my-journey': '🚗',                      // Car - My Journey
    'poster': '📄',                          // Document - Poster
    'status': '📱',                          // Phone - Status
    'quiz': '❓',                            // Question mark - Quiz
    'mobiles-other-electronics': '📱',       // Phone - Electronics
    'jobs': '💼',                            // Briefcase - Jobs
    'education': '📚',                       // Books - Education
    'weekly-ads': '📰',                      // Newspaper - Weekly Ads
    'cinema': '🎬',                          // Clapperboard - Cinema
    'sports': '⚽',                          // Soccer ball - Sports
    'special': '⭐',                         // Star - Special
    'default': '📋',                         // Clipboard
  };

  // Get color for a topic based on its name or ID
  static Color getTopicColor(Topic topic) {
    // Try to match by slug first (most reliable)
    String slugKey = topic.slug.toLowerCase();
    if (_topicColors.containsKey(slugKey)) {
      return _topicColors[slugKey]!;
    }

    // Try to match by name (lowercase, remove spaces/special chars)
    String key = topic.name.toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('/', '')
        .replaceAll('-', '')
        .replaceAll('other', '');

    // Handle specific known topics by name patterns
    if (key.contains('yourarea')) return _topicColors['your-area']!;
    if (key.contains('statename')) return _topicColors['state-name']!;
    if (key.contains('nationalinternational')) return _topicColors['national-international']!;
    if (key.contains('calendar')) return _topicColors['calendar']!;
    if (key.contains('myjourney')) return _topicColors['my-journey']!;
    if (key.contains('poster')) return _topicColors['poster']!;
    if (key.contains('status')) return _topicColors['status']!;
    if (key.contains('quiz')) return _topicColors['quiz']!;
    if (key.contains('mobileselectronics')) return _topicColors['mobiles-other-electronics']!;
    if (key.contains('jobs')) return _topicColors['jobs']!;
    if (key.contains('education')) return _topicColors['education']!;
    if (key.contains('weeklyads')) return _topicColors['weekly-ads']!;
    if (key.contains('cinema')) return _topicColors['cinema']!;
    if (key.contains('sports')) return _topicColors['sports']!;
    if (key.contains('special')) return _topicColors['special']!;

    // Use ID-based color assignment for consistency
    return _getColorById(topic.id);
  }

  // Get emoji for a topic based on its name or ID
  static String getTopicEmoji(Topic topic) {
    // Try to match by slug first (most reliable)
    String slugKey = topic.slug.toLowerCase();
    if (_topicEmojis.containsKey(slugKey)) {
      return _topicEmojis[slugKey]!;
    }

    // Try to match by name (lowercase, remove spaces/special chars)
    String key = topic.name.toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('/', '')
        .replaceAll('-', '')
        .replaceAll('other', '');

    // Handle specific known topics by name patterns
    if (key.contains('yourarea')) return _topicEmojis['your-area']!;
    if (key.contains('statename')) return _topicEmojis['state-name']!;
    if (key.contains('nationalinternational')) return _topicEmojis['national-international']!;
    if (key.contains('calendar')) return _topicEmojis['calendar']!;
    if (key.contains('myjourney')) return _topicEmojis['my-journey']!;
    if (key.contains('poster')) return _topicEmojis['poster']!;
    if (key.contains('status')) return _topicEmojis['status']!;
    if (key.contains('quiz')) return _topicEmojis['quiz']!;
    if (key.contains('mobileselectronics')) return _topicEmojis['mobiles-other-electronics']!;
    if (key.contains('jobs')) return _topicEmojis['jobs']!;
    if (key.contains('education')) return _topicEmojis['education']!;
    if (key.contains('weeklyads')) return _topicEmojis['weekly-ads']!;
    if (key.contains('cinema')) return _topicEmojis['cinema']!;
    if (key.contains('sports')) return _topicEmojis['sports']!;
    if (key.contains('special')) return _topicEmojis['special']!;

    // Use ID-based emoji assignment for consistency
    return _getEmojiById(topic.id);
  }

  // Get consistent color based on topic ID
  static Color _getColorById(int id) {
    final colors = _topicColors.values.toList();
    return colors[id % colors.length];
  }

  // Get consistent emoji based on topic ID
  static String _getEmojiById(int id) {
    final emojis = _topicEmojis.values.toList();
    return emojis[id % emojis.length];
  }

  // Get both emoji and color for a topic
  static ({String emoji, Color color}) getTopicStyling(Topic topic) {
    return (
      emoji: getTopicEmoji(topic),
      color: getTopicColor(topic),
    );
  }
}
