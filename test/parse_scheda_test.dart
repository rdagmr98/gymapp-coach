import 'dart:convert';

import 'package:app_pt/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = {
    'dayName': 'A',
    'bodyParts': ['dorso'],
    'exercises': [
      {'name': 'Rematore', 'targetSets': 3, 'repsList': [10, 10, 10], 'recoveryTime': 90, 'cardioSeconds': 600},
    ],
  };

  test('file .workout esportato dal coach: giorni + nome atleta', () {
    final text = '﻿TIPO:SCHEDA_GYM\n${jsonEncode({'clientName': ' Mario ', 'routine': [day]})}';
    final (days, name) = parseSchedaFile(text);
    expect(days.length, 1);
    expect(name, 'Mario');
    final wd = workoutDayFromTemplate(days.first as Map);
    expect(wd.bodyParts, ['schiena']);
    expect(wd.exercises.single.cardioSeconds, 600);
  });

  test('lista nuda senza nome, e rifiuto di altri TIPO:', () {
    final (days, name) = parseSchedaFile(jsonEncode([day]));
    expect(days.length, 1);
    expect(name, isNull);
    expect(() => parseSchedaFile('TIPO:PROGRESSI_GYM\n[]'), throwsFormatException);
    expect(() => parseSchedaFile(jsonEncode({'routine': []})), throwsFormatException);
  });
}
