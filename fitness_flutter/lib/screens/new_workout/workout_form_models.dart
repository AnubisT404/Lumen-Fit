// Data models and constants for the New Workout screen.

const cardioTypes = [
  'Running',
  'Cycling',
  'Swimming',
  'Rowing',
  'Elliptical',
  'Walking',
  'HIIT',
  'Jump Rope',
  'Stair Climber',
  'Sprints',
];

const elevationActivities = {
  'Running',
  'Cycling',
  'Walking',
  'HIIT',
  'Stair Climber',
};

class SetData {
  int setNumber;
  double? weightKg;
  int? reps;
  SetData({required this.setNumber, this.weightKg, this.reps});
}

class ExerciseData {
  String name;
  String category;
  List<SetData> sets;
  List<Map<String, dynamic>>? previousSets;
  int? durationMinutes;
  List<String>? alternatives;

  ExerciseData({
    required this.name,
    required this.category,
    required this.sets,
    this.previousSets,
    this.durationMinutes,
    this.alternatives,
  });
}
