import 'dart:async';

/// Simple in-memory cache with TTL for stale-while-revalidate pattern.
class ApiCache<T> {
  final Duration ttl;
  T? _data;
  DateTime? _fetchedAt;
  Future<T>? _inflight;

  ApiCache({required this.ttl});

  /// Returns cached data if fresh, otherwise fetches.
  /// Stale data is returned immediately while refresh happens in background.
  Future<T> get(Future<T> Function() fetcher) async {
    if (_data != null && _fetchedAt != null) {
      final age = DateTime.now().difference(_fetchedAt!);
      if (age < ttl) return _data as T;
      // Stale — return cached but refresh in background
      _refreshInBackground(fetcher);
      return _data as T;
    }
    // No cache — must await
    return _fetch(fetcher);
  }

  /// Force refresh, returns new data.
  Future<T> refresh(Future<T> Function() fetcher) => _fetch(fetcher);

  /// Invalidate cache so next get() fetches fresh.
  void invalidate() {
    _data = null;
    _fetchedAt = null;
  }

  bool get hasCachedData => _data != null;

  Future<T> _fetch(Future<T> Function() fetcher) async {
    if (_inflight != null) return _inflight!;
    _inflight = fetcher();
    try {
      _data = await _inflight!;
      _fetchedAt = DateTime.now();
      return _data as T;
    } finally {
      _inflight = null;
    }
  }

  void _refreshInBackground(Future<T> Function() fetcher) {
    if (_inflight != null) return;
    _inflight = fetcher();
    _inflight!.then((val) {
      _data = val;
      _fetchedAt = DateTime.now();
    }).whenComplete(() => _inflight = null);
  }
}
