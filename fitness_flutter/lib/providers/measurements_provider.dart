import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/measurement.dart';
import '../services/measurements_service.dart';

final measurementsProvider =
    FutureProvider.autoDispose<List<Measurement>>((ref) async {
  return MeasurementsService.getAll(limit: 100);
});

final measurementStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return MeasurementsService.getStats();
});
