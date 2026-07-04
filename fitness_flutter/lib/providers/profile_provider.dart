import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

final profileProvider = FutureProvider.autoDispose<Profile>((ref) async {
  return ProfileService.get();
});

final goalsProvider = FutureProvider.autoDispose<Goals>((ref) async {
  return ProfileService.getGoals();
});
