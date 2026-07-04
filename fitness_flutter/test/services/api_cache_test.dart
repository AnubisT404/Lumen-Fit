import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/services/api_cache.dart';

void main() {
  group('ApiCache', () {
    test('first call fetches from fetcher', () async {
      int callCount = 0;
      final cache = ApiCache<String>(ttl: const Duration(seconds: 30));
      final result = await cache.get(() async {
        callCount++;
        return 'hello';
      });
      expect(result, 'hello');
      expect(callCount, 1);
    });

    test('second call within TTL returns cached data', () async {
      int callCount = 0;
      final cache = ApiCache<String>(ttl: const Duration(seconds: 30));
      await cache.get(() async {
        callCount++;
        return 'first';
      });
      final result = await cache.get(() async {
        callCount++;
        return 'second';
      });
      expect(result, 'first');
      expect(callCount, 1);
    });

    test('invalidate forces refetch', () async {
      int callCount = 0;
      final cache = ApiCache<String>(ttl: const Duration(seconds: 30));
      await cache.get(() async {
        callCount++;
        return 'first';
      });
      cache.invalidate();
      final result = await cache.get(() async {
        callCount++;
        return 'second';
      });
      expect(result, 'second');
      expect(callCount, 2);
    });

    test('refresh always fetches new data', () async {
      int callCount = 0;
      final cache = ApiCache<int>(ttl: const Duration(seconds: 30));
      await cache.get(() async {
        callCount++;
        return 1;
      });
      final result = await cache.refresh(() async {
        callCount++;
        return 2;
      });
      expect(result, 2);
      expect(callCount, 2);
    });

    test('deduplicates concurrent fetches', () async {
      int callCount = 0;
      final cache = ApiCache<String>(ttl: const Duration(seconds: 30));
      final futures = List.generate(
        5,
        (_) => cache.get(() async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return 'result';
        }),
      );
      final results = await Future.wait(futures);
      expect(results.every((r) => r == 'result'), true);
      expect(callCount, 1);
    });

    test('hasCachedData reports correctly', () async {
      final cache = ApiCache<int>(ttl: const Duration(seconds: 30));
      expect(cache.hasCachedData, false);
      await cache.get(() async => 42);
      expect(cache.hasCachedData, true);
      cache.invalidate();
      expect(cache.hasCachedData, false);
    });

    test('fetcher exception propagates', () async {
      final cache = ApiCache<String>(ttl: const Duration(seconds: 30));
      expect(
        () => cache.get(() async => throw Exception('network error')),
        throwsA(isA<Exception>()),
      );
    });

    test('after exception, cache remains empty', () async {
      final cache = ApiCache<String>(ttl: const Duration(seconds: 30));
      try {
        await cache.get(() async => throw Exception('fail'));
      } catch (_) {}
      expect(cache.hasCachedData, false);
      final result = await cache.get(() async => 'recovered');
      expect(result, 'recovered');
    });
  });
}
