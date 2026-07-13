import 'package:flutter_test/flutter_test.dart';
import 'package:app_pt/exercise_catalog.dart';

ExerciseInfo _ex(String name) => ExerciseInfo(
  name: name,
  nameEn: name,
  category: 'altro',
  muscleImages: const [],
  primaryMuscle: '',
  secondaryMuscles: '',
  execution: '',
  tips: '',
);

void main() {
  test('exerciseEquipment classifica corpo libero/manubri/bilanciere', () {
    expect(exerciseEquipment(_ex('Push Up')), 'corpo_libero');
    expect(exerciseEquipment(_ex('Alternate Dumbbell Bench Press')), 'manubri');
    expect(exerciseEquipment(_ex('Barbell Curl')), 'bilanciere');
    expect(exerciseEquipment(_ex('Cable Crossover')), null);
    expect(exerciseEquipment(_ex('Leg Press')), null);
    expect(exerciseEquipment(_ex('45 Degree Incline Row')), null);
    expect(exerciseEquipment(_ex('Burpee')), 'corpo_libero');
  });
}
