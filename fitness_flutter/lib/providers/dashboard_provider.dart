import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_data.dart';
import '../services/dashboard_service.dart';
import '../services/api_cache.dart';
import '../providers/meals_provider.dart';

final _dashboardCache = <String, ApiCache<DashboardData>>{};

ApiCache<DashboardData> _cacheFor(String date) =>
    _dashboardCache.putIfAbsent(date, () => ApiCache(ttl: const Duration(seconds: 30)));

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final date = ref.watch(selectedDateProvider);
  final cache = _cacheFor(date);
  // Clear cache when provider is invalidated so fresh data is fetched
  ref.onDispose(() => cache.invalidate());
  return cache.get(() => DashboardService.getByDate(date));
});

/// Call after mutations (log food, water, workout) to refresh dashboard.
void invalidateDashboardCache(String date) {
  _dashboardCache[date]?.invalidate();
}

/// Clears all cached dashboard data.
void clearDashboardCache() {
  _dashboardCache.clear();
}
