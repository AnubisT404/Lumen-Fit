import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings.dart';
import '../services/settings_service.dart';
import '../services/api_cache.dart';

final _settingsCache = ApiCache<AppSettings>(ttl: const Duration(minutes: 5));

final settingsProvider = FutureProvider.autoDispose<AppSettings>((ref) async {
  // Clear cache when provider is invalidated so fresh data is fetched
  ref.onDispose(() => _settingsCache.invalidate());
  return _settingsCache.get(() => SettingsService.get());
});

/// Call after updating settings to refresh.
void invalidateSettingsCache() {
  _settingsCache.invalidate();
}
