import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/coach_service.dart';

final dailyInsightProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return CoachService.getDailyInsight();
});

final knowledgeProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return CoachService.getKnowledge();
});
