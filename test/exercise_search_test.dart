import 'package:flutter_test/flutter_test.dart';
import 'package:app_pt/exercise_catalog.dart';

void main() {
  String first(String q) => searchExercises(q).first.name;

  test('nomi italiani in testa', () {
    expect(first('panca piana'), 'Panca Piana');
    expect(first('lat machine'), 'Lat Machine');
    expect(first('trazioni'), 'Trazioni alla Sbarra');
    expect(first('alzate laterali'), 'Alzate Laterali');
    expect(first('stacco rumeno'), 'Romanian Deadlift');
    expect(first('curl martello'), 'Curl Martello');
    expect(first('scrollate'), 'Alzate di Spalle');
  });

  test('italiano tradotto sui nomi GIF inglesi', () {
    final n = first('panca inclinata manubri').toLowerCase();
    expect(n, allOf(contains('incline'), contains('dumbbell'), contains('bench')));
    expect(first('rematore manubrio'), 'Rematore con Manubrio');
    expect(first('leg curl sdraiato').toLowerCase(), contains('lying'));
    expect(first('croci cavi'), 'Croci ai Cavi');
  });

  test('niente doppioni, refusi e query vuote', () {
    final names = searchExercises('bench press').map((e) => e.name).toList();
    expect(names, contains('Panca Piana'));
    expect(names, isNot(contains('Bench Press')));
    expect(searchExercises('xqzw'), isEmpty);
    expect(searchExercises('p'), isEmpty);
    expect(searchExercises('panca inclinata manubrj'), isNotEmpty);
    expect(searchExercises('curl', limit: 3).length, 3);
    expect(first('pressa'), 'Leg Press');
  });

  test('parola completa = parola intera, ultima = prefisso', () {
    List<String> names(String q) => searchExercises(q).map((e) => e.name).toList();
    expect(names('lat machine presa inversa'), isNot(contains('Lateral Raise Machine')));
    expect(names('addominali'), isNot(contains('Hip Abductor')));
    expect(names('lat'), contains('Lateral Raise Machine'));
    expect(first('alzate laterali man').toLowerCase(), contains('lateral'));
  });
}
