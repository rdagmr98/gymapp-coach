import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as scala;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'exercise_catalog.dart';
import 'gif_exercise_catalog.dart';

// MethodChannel per condivisione nativa e lettura file
const _gymFileChannel = MethodChannel('gym_file_reader');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GymCoachApp());
}

class GymCoachApp extends StatelessWidget {
  const GymCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFFFFD700),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      // Usiamo lo stesso AuthGuard dell'app client
      home: const AuthGuardPT(),
    );
  }
}

class AuthGuardPT extends StatefulWidget {
  const AuthGuardPT({super.key});
  @override
  State<AuthGuardPT> createState() => _AuthGuardPTState();
}

class _AuthGuardPTState extends State<AuthGuardPT> {
  bool _isAuthorized = false;
  String _deviceId = "";
  final TextEditingController _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    bool auth = prefs.getBool('is_authorized_pt') ?? false;

    // Recuperiamo l'ID salvato
    String? savedId = prefs.getString('saved_device_id');

    if (savedId == null) {
      // Se è il primo avvio in assoluto, generiamo un ID casuale di 4 cifre
      int randomId = scala.Random().nextInt(9000) + 1000; // Tra 1000 e 9999
      savedId = randomId.toString();
      // Lo salviamo per i futuri avvii
      await prefs.setString('saved_device_id', savedId);
    }

    setState(() {
      _isAuthorized = auth;
      _deviceId = savedId!;
    });
  }

  void _verifyKey() async {
    int idNum = int.parse(_deviceId);
    // STESSA FORMULA DEL CLIENT
    int expectedKey = (idNum * 2) + 566;

    if (_keyController.text == expectedKey.toString()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authorized_pt', true);
      setState(() => _isAuthorized = true);
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("CHIAVE ERRATA"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorized) return const PTDashboard();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Colors.amber,
              ),
              const SizedBox(height: 30),
              const Text(
                "COACH DASHBOARD",
                style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "DEVICE ID: $_deviceId",
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _keyController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
                decoration: const InputDecoration(
                  hintText: "••••",
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _verifyKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("SBLOCCA ACCESSO"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- RICERCA ITALIANA ---
const Map<String, List<String>> kItalianKeywords = {
  'panca': ['bench'],
  'petto': ['chest', 'pec', 'bench', 'fly', 'push'],
  'dorsale': ['lat', 'pulldown', 'pull', 'row'],
  'rematore': ['row'],
  'tirate': ['pulldown', 'pull'],
  'bicipite': ['curl', 'bicep'],
  'tricipite': ['tricep', 'extension', 'pushdown', 'dip'],
  'spalla': ['shoulder', 'press', 'raise', 'delt', 'arnold'],
  'squat': ['squat'],
  'affondi': ['lunge'],
  'stacco': ['deadlift'],
  'curl': ['curl'],
  'croci': ['fly', 'flye', 'crossover'],
  'pressa': ['press', 'leg press'],
  'gambe': ['leg', 'squat', 'lunge'],
  'glutei': ['glute', 'hip', 'bridge'],
  'addome': ['ab', 'crunch', 'plank', 'core'],
  'plank': ['plank'],
  'polpaccio': ['calf', 'raise'],
  'pull': ['pull', 'pulldown', 'pullup'],
  'push': ['push', 'press'],
  'dip': ['dip'],
  'manubri': ['dumbbell'],
  'bilanciere': ['barbell'],
  'cavo': ['cable'],
  'corda': ['rope'],
  'kettlebell': ['kettlebell'],
  'alzate': ['raise', 'lateral', 'front'],
  'lat': ['lat', 'pulldown'],
  'lombari': ['back extension', 'hyperextension', 'deadlift'],
  'adduttori': ['adductor'],
  'abduttori': ['abductor'],
};

List<ExerciseInfo> searchExercisesWithItalian(String query, {int limit = 8}) {
  if (query.length < 2) return [];
  final q = query.toLowerCase().trim();
  final results = <ExerciseInfo>[];
  final seen = <String>{};

  void tryAdd(ExerciseInfo ex) {
    if (seen.add(ex.name) && results.length < limit) results.add(ex);
  }

  // 1. Match diretto nel catalogo italiano (kExerciseCatalog) — nomi IT come "Trazioni"
  for (final ex in kExerciseCatalog) {
    if (ex.name.toLowerCase().contains(q) ||
        ex.nameEn.toLowerCase().contains(q) ||
        ex.aliases.any((a) => a.toLowerCase().contains(q))) {
      tryAdd(ex);
    }
  }

  // 2. Match diretto nel catalogo GIF (nomi EN)
  for (final ex in kGifCatalog) {
    if (ex.name.toLowerCase().contains(q) || ex.nameEn.toLowerCase().contains(q)) {
      tryAdd(ex);
    }
  }

  // 3. Match tramite parole chiave italiane → inglese
  if (results.length < limit) {
    for (final entry in kItalianKeywords.entries) {
      if (entry.key.contains(q) || q.contains(entry.key)) {
        for (final eng in entry.value) {
          for (final ex in kGifCatalog) {
            if (ex.name.toLowerCase().contains(eng) || ex.nameEn.toLowerCase().contains(eng)) {
              tryAdd(ex);
              if (results.length >= limit) return results;
            }
          }
        }
      }
    }
  }

  return results;
}

// --- MODELLI DATI ---
class ExerciseConfig {
  String name;
  int targetSets;
  List<int> repsList;
  int recoveryTime;
  int interExercisePause;
  String notePT;
  String noteCliente;
  // 0 = normale, 1+ = gruppo superserie
  int supersetGroup;

  /// GIF slug personalizzato per esercizi non in catalogo (es. 'barbell-curl').
  String? gifFilename;

  ExerciseConfig({
    required this.name,
    required this.targetSets,
    required this.repsList,
    required this.recoveryTime,
    this.interExercisePause = 120,
    this.notePT = "",
    this.noteCliente = "",
    this.supersetGroup = 0,
    this.gifFilename,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'targetSets': targetSets,
    'repsList': repsList,
    'recoveryTime': recoveryTime,
    'interExercisePause': interExercisePause,
    'notePT': notePT,
    'noteCliente': noteCliente,
    'supersetGroup': supersetGroup,
    if (gifFilename != null) 'gifFilename': gifFilename,
  };

  factory ExerciseConfig.fromJson(Map<String, dynamic> json) => ExerciseConfig(
    name: json['name'],
    targetSets: json['targetSets'],
    repsList: List<int>.from(json['repsList']),
    recoveryTime: json['recoveryTime'],
    interExercisePause: json['interExercisePause'] ?? 120,
    notePT: json['notePT'] ?? "",
    noteCliente: json['noteCliente'] ?? "",
    supersetGroup: (json['supersetGroup'] as num?)?.toInt() ?? 0,
    gifFilename: json['gifFilename'] as String?,
  );
}

class WorkoutDay {
  String dayName;
  List<String> bodyParts;
  String? muscleImage; // nome file es. 'petto.png'
  List<ExerciseConfig> exercises;
  WorkoutDay({
    required this.dayName,
    List<String>? bodyParts,
    this.muscleImage,
    required this.exercises,
  }) : bodyParts = bodyParts ?? [];
  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'bodyParts': bodyParts,
    'muscleImage': muscleImage,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    dayName: json['dayName'] ?? 'Giorno',
    bodyParts: json['bodyParts'] != null
        ? List<String>.from(json['bodyParts'])
        : (json['bodyPart'] != null &&
                  json['bodyPart'] != 'altro' &&
                  json['bodyPart'] != 'nessuno'
              ? [json['bodyPart'] as String]
              : []),
    muscleImage: json['muscleImage'] as String?,
    exercises: (json['exercises'] as List? ?? [])
        .map((e) => ExerciseConfig.fromJson(e))
        .toList(),
  );
}

const Map<String, String> kBodyPartIcons = {
  'nessuno': '',
  'petto': '🦍',
  'schiena': '🔙',
  'gambe': '🦵',
  'spalle': '🏋️',
  'braccia': '💪',
  'core': '🔥',
  'full_body': '🏃',
  'cardio': '❤️',
  'glutei': '🍑',
  'altro': '⚡',
};
const Map<String, String> kBodyPartNames = {
  'nessuno': 'Nessuna',
  'petto': 'Petto',
  'schiena': 'Schiena',
  'gambe': 'Gambe',
  'spalle': 'Spalle',
  'braccia': 'Braccia',
  'core': 'Core',
  'full_body': 'Full Body',
  'cardio': 'Cardio',
  'glutei': 'Glutei',
  'altro': 'Altro',
};

const List<Map<String, String>> kMuscleImages = [
  {'file': 'petto.png', 'label': 'Petto'},
  {'file': 'dorso.png', 'label': 'Dorso'},
  {'file': 'spalle.png', 'label': 'Spalle'},
  {'file': 'braccia.png', 'label': 'Braccia'},
  {'file': 'bicipiti.png', 'label': 'Bicipiti'},
  {'file': 'tricipiti.png', 'label': 'Tricipiti'},
  {'file': 'gambe.png', 'label': 'Gambe'},
  {'file': 'quadricipiti.png', 'label': 'Quadricipiti'},
  {'file': 'femorali.png', 'label': 'Femorali'},
  {'file': 'glutei.png', 'label': 'Glutei'},
  {'file': 'push.png', 'label': 'Push'},
  {'file': 'pull.png', 'label': 'Pull'},
];

// --- TEMPLATE SCHEDE PRE-IMPOSTATE ---
final List<Map<String, dynamic>> kWorkoutTemplates = [
  {
    'name': 'Push Pull Legs',
    'desc': '3 giorni · split classico',
    'icon': '🔄',
    'days': [
      {
        'dayName': 'Push',
        'exercises': [
          {
            'name': 'Panca piana / Chest Press',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Croci ai cavi',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Shoulder Press',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Alzate laterali',
            'targetSets': 4,
            'repsList': [12, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pushdown corda',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Pull',
        'exercises': [
          {
            'name': 'Lat Machine / Pulldown',
            'targetSets': 4,
            'repsList': [8, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Row Machine',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pulley',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Curl bilanciere',
            'targetSets': 4,
            'repsList': [8, 8, 8, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Curl hammer',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Legs',
        'exercises': [
          {
            'name': 'Leg Press / Squat',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 120,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Hip Thrust / Stacco Rumeno',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Calf Raises',
            'targetSets': 4,
            'repsList': [15, 15, 12, 12],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
    ],
  },
  {
    'name': 'Full Body A/B',
    'desc': '2 giorni · alternati',
    'icon': '⚡',
    'days': [
      {
        'dayName': 'Full Body A',
        'exercises': [
          {
            'name': 'Panca piana',
            'targetSets': 4,
            'repsList': [12, 10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Lat Machine',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Shoulder Press',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Curl',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pushdown',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Full Body B',
        'exercises': [
          {
            'name': 'Leg Press',
            'targetSets': 3,
            'repsList': [15, 12, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Extension',
            'targetSets': 2,
            'repsList': [12, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Shoulder Press',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Alzate laterali',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
    ],
  },
  {
    'name': 'Upper Lower',
    'desc': '4 giorni · upper/lower split',
    'icon': '↕️',
    'days': [
      {
        'dayName': 'Upper A',
        'exercises': [
          {
            'name': 'Panca piana',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Lat Machine',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Shoulder Press',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Curl bilanciere',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pushdown corda',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Lower A',
        'exercises': [
          {
            'name': 'Squat / Leg Press',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 120,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Stacco Rumeno',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Calf Raises',
            'targetSets': 3,
            'repsList': [15, 15, 15],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Upper B',
        'exercises': [
          {
            'name': 'Croci ai cavi / Pectoral Machine',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pulley / Row Machine',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Alzate laterali',
            'targetSets': 4,
            'repsList': [12, 12, 12, 12],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Curl hammer',
            'targetSets': 3,
            'repsList': [12, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Spaccacranio',
            'targetSets': 3,
            'repsList': [12, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Lower B',
        'exercises': [
          {
            'name': 'Hack Squat / Leg Press',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Hip Thrust',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [12, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Glutes Machine / Abductor',
            'targetSets': 3,
            'repsList': [12, 12, 12],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
    ],
  },
  {
    'name': 'Petto / Dorso / Gambe / Spalle / Braccia',
    'desc': '5 giorni · split avanzato',
    'icon': '🏆',
    'days': [
      {
        'dayName': 'Petto',
        'exercises': [
          {
            'name': 'Panca piana',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Distensioni manubri',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Croci ai cavi',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pectoral machine',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Dorso',
        'exercises': [
          {
            'name': 'Lat Machine',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Row Machine',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pulley',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pulldown barra',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Gambe',
        'exercises': [
          {
            'name': 'Squat / Leg Press',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 120,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Leg Curl',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Hip Thrust / Glutes Machine',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Spalle',
        'exercises': [
          {
            'name': 'Shoulder Press / Lento avanti',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Alzate laterali',
            'targetSets': 4,
            'repsList': [12, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Alzate frontali',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Alzate laterali posteriori',
            'targetSets': 3,
            'repsList': [12, 12, 12],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
      {
        'dayName': 'Braccia',
        'exercises': [
          {
            'name': 'Curl bilanciere',
            'targetSets': 4,
            'repsList': [8, 8, 8, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Curl hammer',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Curl cavi dal basso',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Pushdown corda',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
          {
            'name': 'Spaccacranio / French Press',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
          },
        ],
      },
    ],
  },
];

class Client {
  String id, name;
  List<WorkoutDay> routine;
  List<Map<String, dynamic>>
  performanceLogs; // Restano in memoria, ma non salvati

  Client({
    required this.id,
    required this.name,
    required this.routine,
    List<Map<String, dynamic>>? logs,
  }) : performanceLogs = logs ?? [];

  // Escludiamo performanceLogs dal JSON di salvataggio
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'routine': routine.map((e) => e.toJson()).toList(),
    // 'performanceLogs' NON viene incluso qui!
  };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id'],
    name: json['name'],
    routine: (json['routine'] as List)
        .map((e) => WorkoutDay.fromJson(e))
        .toList(),
    logs: [], // All'avvio dell'app, la lista log sarà sempre vuota
  );
}

class PTDashboard extends StatefulWidget {
  const PTDashboard({super.key});

  @override
  State<PTDashboard> createState() => _PTDashboardState();
}

class _PTDashboardState extends State<PTDashboard> with WidgetsBindingObserver {
  // 1. Aggiunto Observer
  List<Client> clients = [];
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(
      this,
    ); // 2. Registra l'ascolto per il "resume"
    _loadData();
    _initDeepLinks();
    _checkClipboardForLog(); // 3. Controllo immediato all'avvio
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Rimuove l'ascolto
    _linkSubscription?.cancel();
    super.dispose();
  }

  // QUESTO FA SCATTARE L'INCOLLA QUANDO TORNI NELL'APP (da WhatsApp ad esempio)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForLog();
    }
  }

  // --- LOGICA IDENTICA AL CLIENTE ---
  Future<void> _checkClipboardForLog() async {
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        String text = data.text!.trim();
        if (text.startsWith("TIPO:PROGRESSI_GYM")) {
          // Puliamo la clipboard subito per evitare loop
          await Clipboard.setData(const ClipboardData(text: ""));

          final (logs, clientName) = _validaEParseLogs(text);
          if (mounted) _autoAssegnaOChiedi(logs, clientName);
        }
      }
    } catch (e) {
      debugPrint("Errore clipboard: $e");
    }
  }

  // ─── VALIDAZIONE JSON LOG ─────────────────────────────────────────────────

  /// Valida e parsa un file/testo progressi (.gymlog). Lancia un'eccezione con
  /// messaggio chiaro. Restituisce (logs, clientName).
  (List<Map<String, dynamic>>, String?) _validaEParseLogs(String input) {
    input = input.trim();
    if (input.isEmpty) throw "Il testo è vuoto.";

    // Tipo sbagliato?
    if (input.startsWith("TIPO:SCHEDA_GYM")) {
      throw "Questo è un file scheda (.workout) per l'atleta, non un file progressi.\n\nL'atleta deve usare 'Invia progressi' nell'app Gym Logbook e inviarti il file .gymlog.";
    }

    // Rimuovi header
    if (input.startsWith("TIPO:PROGRESSI_GYM")) {
      input = input.substring(input.indexOf('\n') + 1).trim();
    }
    if (input.isEmpty) throw "Il file è vuoto dopo l'intestazione.";

    // Parsa JSON
    dynamic decoded;
    try {
      decoded = jsonDecode(input);
    } catch (_) {
      throw "Il testo non è un JSON valido.\n\nAssicurati di copiare l'intero contenuto senza modifiche.";
    }

    List<Map<String, dynamic>> logs;
    String? clientName;

    if (decoded is List) {
      if (decoded.isEmpty) throw "Nessuna sessione trovata nel file.";
      logs = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (decoded is Map) {
      if (decoded.containsKey('logs')) {
        final raw = decoded['logs'];
        if (raw is! List || raw.isEmpty)
          throw "Nessuna sessione trovata nel file.";
        clientName = decoded['clientName'] as String?;
        logs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (decoded.containsKey('routine')) {
        throw "Questo sembra una scheda allenamento (.workout), non un file progressi.\n\nL'atleta deve inviarti un file .gymlog tramite 'Invia progressi'.";
      } else {
        throw "Struttura JSON non riconosciuta.\nManca la chiave 'logs' o l'elenco sessioni.";
      }
    } else {
      throw "Formato non riconosciuto. Atteso un array o oggetto JSON.";
    }

    return (logs, clientName);
  }

  /// Mostra un dialog di errore con messaggio dettagliato.
  void _mostraErroreImportazione(String messaggio) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text(
              "Importazione fallita",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          messaggio,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "OK",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _initDeepLinks() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _gestisciFileInEntrata(uri),
    );

    // CORRETTO: getInitialLink() risolve l'errore "undefined"
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _gestisciFileInEntrata(initialUri);
  }

  void _gestisciFileInEntrata(Uri uri) async {
    try {
      String content;
      if (uri.scheme == 'content') {
        final bytes = await _gymFileChannel.invokeMethod<List<int>>(
          'readBytes',
          uri.toString(),
        );
        content = utf8.decode(bytes!);
      } else {
        content = await File(uri.toFilePath()).readAsString();
      }

      final (logs, clientName) = _validaEParseLogs(content);
      _autoAssegnaOChiedi(logs, clientName);
    } catch (e) {
      debugPrint("Errore file in entrata: $e");
      if (mounted) _mostraErroreImportazione(e.toString());
    }
  }

  // POPUP PER ASSEGNARE I DATI ALL'ATLETA GIUSTO
  /// Auto-assegna i log all'atleta con nome corrispondente.
  /// Se il nome non matcha nessun cliente, mostra il dialog manuale.
  void _autoAssegnaOChiedi(
    List<Map<String, dynamic>> logs,
    String? clientName,
  ) {
    if (clientName != null && clientName.trim().isNotEmpty) {
      final match = clients.where(
        (c) => c.name.trim().toLowerCase() == clientName.trim().toLowerCase(),
      );
      if (match.isNotEmpty) {
        final atleta = match.first;
        setState(() => atleta.performanceLogs = logs);
        _saveData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Progressi di ${atleta.name} aggiornati!"),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
    }
    // Fallback: nessun match → dialog manuale
    _mostraDialogoAssociazione(logs, suggestedName: clientName);
  }

  void _mostraDialogoAssociazione(
    List<Map<String, dynamic>> logs, {
    String? suggestedName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Assegna progressi",
              style: TextStyle(color: Colors.amber),
            ),
            if (suggestedName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Atleta nel file: $suggestedName",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
          ],
        ),
        content: const Text("A quale atleta vuoi assegnare questi dati?"),
        actions: [
          ...clients.map(
            (atleta) => TextButton(
              onPressed: () {
                setState(() => atleta.performanceLogs = logs);
                _saveData();
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Dati di ${atleta.name} aggiornati!")),
                );
              },
              child: Text(atleta.name.toUpperCase()),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- MANTIENI I TUOI METODI DI CARICAMENTO SOTTO ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('clients_data');
    if (data != null) {
      setState(() {
        clients = (jsonDecode(data) as List)
            .map((e) => Client.fromJson(e))
            .toList();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'clients_data',
      jsonEncode(clients.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("COACH DASHBOARD")),
      body: ListView.builder(
        itemCount: clients.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(
            clients[i].name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
                tooltip: "Rinomina",
                onPressed: () => _renameClient(i),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDeleteClient(i),
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) =>
                  ClientDetailView(client: clients[i], onUpdate: _saveData),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClient,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _renameClient(int index) {
    final ctrl = TextEditingController(text: clients[index].name);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Rinomina atleta"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Nuovo nome"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => clients[index].name = ctrl.text.trim());
                _saveData();
                Navigator.pop(c);
              }
            },
            child: const Text("SALVA"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClient(int index) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Elimina atleta"),
        content: Text(
          "Sei sicuro di voler eliminare ${clients[index].name}?\n\nTutti i dati e la scheda verranno persi.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() => clients.removeAt(index));
              _saveData();
              Navigator.pop(c);
            },
            child: const Text("ELIMINA"),
          ),
        ],
      ),
    );
  }

  void _addClient() {
    String n = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nuovo Atleta"),
        content: TextField(onChanged: (v) => n = v),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (n.isNotEmpty) {
                setState(
                  () => clients.add(
                    Client(id: DateTime.now().toString(), name: n, routine: []),
                  ),
                );
                _saveData();
              }
              Navigator.pop(c);
            },
            child: const Text("SALVA"),
          ),
        ],
      ),
    );
  }
}

// --- DETTAGLIO CLIENTE E ANALISI ---
class ClientDetailView extends StatefulWidget {
  final Client client;
  final VoidCallback onUpdate;
  const ClientDetailView({
    super.key,
    required this.client,
    required this.onUpdate,
  });

  @override
  State<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends State<ClientDetailView> {
  // [label da mostrare, nome esatto nel catalogo]
  final List<MapEntry<String, String>> exSuggestions = const [
    MapEntry("Panca piana", "Panca Piana"),
    MapEntry("Pectoral machine", "Peck Deck"),
    MapEntry("Distensioni manubri", "Distensioni con Manubri"),
    MapEntry("Croci ai cavi", "High Cable Crossover"),
    MapEntry("Pulldown", "Cable Straight Arm Pulldown"),
    MapEntry("Lat machine", "Lat Machine"),
    MapEntry("Pulley", "Pulley Basso"),
    MapEntry("Rematore", "Rematore con Bilanciere"),
    MapEntry("Shoulder Press", "Lento Avanti"),
    MapEntry("Alzate laterali", "Alzate Laterali"),
    MapEntry("Curl", "Curl con Bilanciere"),
    MapEntry("Curl hammer", "Curl Martello"),
    MapEntry("Pushdown corda", "Rope Pushdown"),
    MapEntry("Pushdown barra", "V Bar Pushdown"),
    MapEntry("Stacchi rumeni", "Romanian Deadlift"),
    MapEntry("Squat", "Squat con Bilanciere"),
    MapEntry("Leg press", "Leg Press"),
    MapEntry("Leg extension", "Leg Extension"),
    MapEntry("Leg curl", "Leg Curl"),
    MapEntry("Hip thrust", "Hip Thrust"),
    MapEntry("Stacchi", "Stacchi da Terra"),
  ];
  final List<Color> lineColors = [
    Colors.amber,
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
  ];

  final List<Map<String, dynamic>> setSuggestions = [
    {"label": "4x6", "sets": 4, "reps": 6},
    {"label": "4x8", "sets": 4, "reps": 8},
    {"label": "4x10", "sets": 4, "reps": 10},
    {"label": "4x12", "sets": 4, "reps": 12},
    {"label": "3x8", "sets": 3, "reps": 8},
    {"label": "3x10", "sets": 3, "reps": 10},
    {"label": "3x12", "sets": 3, "reps": 12},
    {"label": "3x15", "sets": 3, "reps": 15},
    {
      "label": "12-10-8-6",
      "sets": 4,
      "repsList": [12, 10, 8, 6],
    },
    {
      "label": "10-8-8-6",
      "sets": 4,
      "repsList": [10, 8, 8, 6],
    },
    {
      "label": "12-10-10-8",
      "sets": 4,
      "repsList": [12, 10, 10, 8],
    },
    {
      "label": "12-10-8",
      "sets": 3,
      "repsList": [12, 10, 8],
    },
    {
      "label": "10-8-6",
      "sets": 3,
      "repsList": [10, 8, 6],
    },
    {
      "label": "6-8-10",
      "sets": 3,
      "repsList": [6, 8, 10],
    },
    {
      "label": "6-8-8-10",
      "sets": 4,
      "repsList": [6, 8, 8, 10],
    },
  ];

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); // <--- Fondamentale per ricevere i progressi!
  }

  void _initDeepLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingProgressFile(uri);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _handleIncomingProgressFile(Uri uri) async {
    try {
      String content;
      if (uri.scheme == 'content') {
        final fileData = File.fromUri(uri);
        content = utf8.decode(await fileData.readAsBytes());
      } else {
        content = await File(uri.toFilePath()).readAsString();
      }

      final (logs, clientName) = _validaEParseLogs(content);
      setState(() {
        widget.client.performanceLogs = logs;
      });
      widget.onUpdate();
      HapticFeedback.mediumImpact();
      if (mounted) {
        final nome = clientName != null ? " di $clientName" : "";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${logs.length} sessioni$nome sincronizzate!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Errore ricezione progressi: $e");
      if (mounted) _mostraErroreImportazione(e.toString());
    }
  }

  // ─── VALIDAZIONE JSON LOG (duplicato in questa view) ────────────────────

  (List<Map<String, dynamic>>, String?) _validaEParseLogs(String input) {
    input = input.trim();
    if (input.isEmpty) throw "Il testo è vuoto.";
    if (input.startsWith("TIPO:SCHEDA_GYM")) {
      throw "Questo è un file scheda (.workout) per l'atleta, non un file progressi.\n\nL'atleta deve usare 'Invia progressi' e inviarti il file .gymlog.";
    }
    if (input.startsWith("TIPO:PROGRESSI_GYM")) {
      input = input.substring(input.indexOf('\n') + 1).trim();
    }
    if (input.isEmpty) throw "Il file è vuoto dopo l'intestazione.";
    dynamic decoded;
    try {
      decoded = jsonDecode(input);
    } catch (_) {
      throw "Il testo non è un JSON valido.\n\nAssicurati di copiare l'intero contenuto senza modifiche.";
    }
    List<Map<String, dynamic>> logs;
    String? clientName;
    if (decoded is List) {
      if (decoded.isEmpty) throw "Nessuna sessione trovata nel file.";
      logs = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (decoded is Map) {
      if (decoded.containsKey('logs')) {
        final raw = decoded['logs'];
        if (raw is! List || raw.isEmpty)
          throw "Nessuna sessione trovata nel file.";
        clientName = decoded['clientName'] as String?;
        logs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (decoded.containsKey('routine')) {
        throw "Questo sembra una scheda (.workout), non un file progressi.\n\nL'atleta deve inviarti un file .gymlog.";
      } else {
        throw "Struttura JSON non riconosciuta. Manca la chiave 'logs'.";
      }
    } else {
      throw "Formato non riconosciuto. Atteso un array o oggetto JSON.";
    }
    return (logs, clientName);
  }

  void _mostraErroreImportazione(String messaggio) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text(
              "Importazione fallita",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          messaggio,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "OK",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.client.name.toUpperCase()),
          bottom: const TabBar(
            tabs: [
              Tab(text: "PROTOCOLLO"),
              Tab(text: "PROGRESSI"),
            ],
          ),
        ),
        body: TabBarView(children: [_buildRoutineList(), _buildAnalytics()]),
      ),
    );
  }

  Widget _buildRoutineList() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _addSession,
              icon: const Icon(Icons.add),
              label: const Text("NUOVA SESSIONE"),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _mostraTemplateDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A2A),
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.library_books_outlined, size: 16),
                SizedBox(width: 6),
                Text("TEMPLATE"),
              ],
            ),
          ),
        ],
      ),
      ...widget.client.routine.asMap().entries.map(
        (entry) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => _changeBodyPartDialog(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      entry.value.bodyParts
                              .map((k) => kBodyPartIcons[k] ?? '')
                              .where((e) => e.isNotEmpty)
                              .join(' ')
                              .isNotEmpty
                          ? entry.value.bodyParts
                                .map((k) => kBodyPartIcons[k] ?? '')
                                .where((e) => e.isNotEmpty)
                                .join(' ')
                          : '—',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value.dayName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Bottone immagine muscolare
                GestureDetector(
                  onTap: () => _changeMuscleImageDialog(entry.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                      image: entry.value.muscleImage != null
                          ? DecorationImage(
                              image: AssetImage(
                                'assets/muscle/${entry.value.muscleImage}',
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: entry.value.muscleImage == null
                        ? const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Colors.white38,
                            size: 20,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            children: [
              ...entry.value.exercises.asMap().entries.map(
                (exEntry) => ListTile(
                  title: Row(
                    children: [
                      if (exEntry.value.supersetGroup > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'S${exEntry.value.supersetGroup}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Flexible(child: Text(exEntry.value.name, overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                  ),
                  subtitle: Text(
                    "${exEntry.value.targetSets}s | ${exEntry.value.repsList.join('-')} reps",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () =>
                            _addExDialog(entry.key, editIndex: exEntry.key),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(
                            () => entry.value.exercises.removeAt(exEntry.key),
                          );
                          widget.onUpdate();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _addExDialog(entry.key),
                child: const Text("+ AGGIUNGI ESERCIZIO"),
              ),
              const Divider(height: 1, color: Colors.white10),
              // Azioni sessione
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Rinomina
                    TextButton.icon(
                      icon: const Icon(
                        Icons.drive_file_rename_outline,
                        size: 16,
                        color: Colors.blueAccent,
                      ),
                      label: const Text(
                        'Rinomina',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        final ctrl = TextEditingController(
                          text: entry.value.dayName,
                        );
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF1C1C1E),
                            title: const Text(
                              'Rinomina sessione',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: TextField(
                              controller: ctrl,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('ANNULLA'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (ctrl.text.trim().isNotEmpty) {
                                    setState(
                                      () => entry.value.dayName = ctrl.text
                                          .trim(),
                                    );
                                    widget.onUpdate();
                                  }
                                  Navigator.pop(c);
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    // Elimina sessione
                    TextButton.icon(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Elimina sessione',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF1C1C1E),
                            title: const Text(
                              'Elimina sessione?',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: Text(
                              'Vuoi eliminare "${entry.value.dayName}" e tutti i suoi esercizi?',
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('ANNULLA'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                onPressed: () {
                                  setState(
                                    () => widget.client.routine.removeAt(
                                      entry.key,
                                    ),
                                  );
                                  widget.onUpdate();
                                  Navigator.pop(c);
                                },
                                child: const Text(
                                  'ELIMINA',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _condividiSchedaFile,
        icon: const Icon(Icons.send),
        label: const Text("INVIA SCHEDA ALL'ATLETA"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    ],
  );

  Widget _buildAnalytics() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        // TASTO PER IMPORTARE I DATI (Se sparito, è questo il pezzo che manca)
        ElevatedButton.icon(
          onPressed: _importLogDialog,
          icon: const Icon(Icons.download),
          label: const Text("AGGIORNA STORICO / IMPORTA LOG"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
        ),
        const SizedBox(height: 20),

        if (widget.client.performanceLogs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                "Nessun dato presente. Clicca su Aggiorna per caricare i log dell'atleta.",
              ),
            ),
          )
        else
          // Mappa dei grafici per esercizio
          ..._groupLogsByExercise().entries
              .map(
                (entry) => Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  color: const Color(0xFF1E1E1E),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: MultiLineChartPainter(
                              entry.value,
                              lineColors,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildLegend(entry.value),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
      ],
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupLogsByExercise() {
    Map<String, List<Map<String, dynamic>>> logsByEx = {};

    for (var log in widget.client.performanceLogs) {
      String ex = log['exercise'] ?? "Esercizio";
      if (!logsByEx.containsKey(ex)) logsByEx[ex] = [];
      logsByEx[ex]!.add(log);
    }

    // Normalizzazione score = kg × reps per serie
    logsByEx.forEach((exName, logs) {
      Map<int, double> minScore = {};
      Map<int, double> maxScore = {};
      for (var log in logs) {
        var series = log['series'] as List;
        for (int i = 0; i < series.length; i++) {
          double w = (series[i]['w'] ?? 0.0).toDouble();
          double r = (series[i]['r'] ?? 0.0).toDouble();
          double sc =
              w * (1 + r / 300.0); // peso dominante, reps come tiebreaker
          minScore[i] = sc < (minScore[i] ?? sc) ? sc : (minScore[i] ?? sc);
          maxScore[i] = sc > (maxScore[i] ?? sc) ? sc : (maxScore[i] ?? sc);
        }
      }
      for (var log in logs) {
        var series = log['series'] as List;
        for (int i = 0; i < series.length; i++) {
          double w = (series[i]['w'] ?? 0.0).toDouble();
          double r = (series[i]['r'] ?? 0.0).toDouble();
          double sc =
              w * (1 + r / 300.0); // peso dominante, reps come tiebreaker
          double lo = minScore[i] ?? 0;
          double hi = maxScore[i] ?? 1;
          double range = hi - lo;
          series[i]['s_norm'] = range > 0.5 ? (sc - lo) / range : 0.5;
          series[i]['s_min'] = lo;
          series[i]['s_max'] = hi;
        }
      }
    });

    return logsByEx;
  }

  Widget _buildLegend(List<Map<String, dynamic>> logs) {
    int maxSets = 0;
    for (var log in logs) {
      if ((log['series'] as List).length > maxSets)
        maxSets = (log['series'] as List).length;
    }
    return Wrap(
      spacing: 8,
      children: List.generate(
        maxSets,
        (i) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              color: lineColors[i % lineColors.length],
            ),
            const SizedBox(width: 4),
            Text("S${i + 1}", style: const TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  void _addExDialog(int dayIdx, {int? editIndex}) {
    ExerciseConfig? ex = editIndex != null
        ? widget.client.routine[dayIdx].exercises[editIndex]
        : null;
    String name = ex?.name ?? "";
    int sets = ex?.targetSets ?? 3;
    int rec = ex?.recoveryTime ?? 90;
    int pause = ex?.interExercisePause ?? 120;
    String notePT = ex?.notePT ?? "";
    int supersetGroup = ex?.supersetGroup ?? 0;
    String? gifFilename = ex?.gifFilename;

    final setsCtrl = TextEditingController(text: sets.toString());
    final recCtrl = TextEditingController(text: rec.toString());
    final pauseCtrl = TextEditingController(text: pause.toString());
    // Holder per il controller dell'Autocomplete (assegnato in fieldViewBuilder)
    final List<TextEditingController?> nameCtrlHolder = [null];

    List<TextEditingController> ctrls = List.generate(
      10,
      (i) => TextEditingController(
        text: (ex != null && i < ex.repsList.length)
            ? ex.repsList[i].toString()
            : "10",
      ),
    );
    List<FocusNode> nodes = List.generate(10, (i) => FocusNode());

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(editIndex == null ? "Nuovo Esercizio" : "Modifica"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 5,
                  children: setSuggestions
                      .map(
                        (s) => ActionChip(
                          backgroundColor: Colors.blueGrey.shade900,
                          label: Text(
                            s['label'],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.amber,
                            ),
                          ),
                          onPressed: () => setS(() {
                            sets = s['sets'];
                            setsCtrl.text = sets.toString();
                            if (s.containsKey('repsList')) {
                              List<int> reps = s['repsList'];
                              for (int i = 0; i < ctrls.length; i++) {
                                if (i < reps.length) {
                                  ctrls[i].text = reps[i].toString();
                                }
                              }
                            } else {
                              for (var ct in ctrls) {
                                ct.text = s['reps'].toString();
                              }
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                // SUGGERIMENTI ESERCIZI — decommentare il blocco per riattivarli
                // const Divider(),
                // Wrap(
                //   spacing: 6,
                //   runSpacing: 6,
                //   children: exSuggestions.map((entry) {
                //     return ActionChip(
                //       label: Text(
                //         entry.key,
                //         overflow: TextOverflow.ellipsis,
                //         maxLines: 1,
                //         style: const TextStyle(fontSize: 10),
                //       ),
                //       onPressed: () {
                //         nameCtrlHolder[0]?.text = entry.key;
                //         setS(() => name = entry.key);
                //       },
                //     );
                //   }).toList(),
                // ),

                Autocomplete<ExerciseInfo>(
                  initialValue: TextEditingValue(text: name),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty)
                      return const Iterable<ExerciseInfo>.empty();
                    return searchExercisesWithItalian(textEditingValue.text, limit: 8);
                  },
                  displayStringForOption: (e) => e.name,
                  onSelected: (e) {
                    setS(() {
                      name = e.name;
                      // Imposta gifFilename solo se viene dal catalogo GIF
                      gifFilename = e.gifFilename;
                    });
                  },
                  fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
                    nameCtrlHolder[0] = ctrl;
                    return TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      decoration: const InputDecoration(labelText: "Nome"),
                      onChanged: (v) => name = v,
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 340,
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: options
                              .map(
                                (e) => InkWell(
                                  onTap: () => onSelected(e),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.asset(
                                            'assets/gif/${e.gifSlug}.gif',
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withAlpha(10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .fitness_center_rounded,
                                                    color: Colors.white24,
                                                    size: 22,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e.name,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                e.primaryMuscle,
                                                style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottone GIF picker — seleziona manualmente la GIF per esercizi custom
                StatefulBuilder(
                  builder: (ctx2, setGif) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (gifFilename != null ||
                              findAnyExercise(name) != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/gif/${gifFilename ?? findAnyExercise(name)!.gifSlug}.gif',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.fitness_center,
                                  color: Colors.white38,
                                  size: 32,
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.image_search_rounded,
                                size: 18,
                              ),
                              label: Text(
                                gifFilename != null
                                    ? gifFilename!.replaceAll('-', ' ')
                                    : 'Scegli GIF',
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                              ),
                              onPressed: () async {
                                final picked =
                                    await showModalBottomSheet<String>(
                                      context: ctx,
                                      backgroundColor: const Color(0xFF0E0E10),
                                      isScrollControlled: true,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24),
                                        ),
                                      ),
                                      builder: (_) => _GifPickerSheet(
                                        initialQuery: name,
                                        currentSlug: gifFilename,
                                      ),
                                    );
                                if (picked != null) {
                                  setS(() {
                                    gifFilename = picked;
                                  });
                                  setGif(() {});
                                }
                              },
                            ),
                          ),
                          if (gifFilename != null)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: Colors.white38,
                              tooltip: 'Rimuovi GIF personalizzata',
                              onPressed: () {
                                setS(() => gifFilename = null);
                                setGif(() {});
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Bottone sfoglia archivio per gruppo muscolare
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _apriArchivioEserciziPT(context, setS, (ex) {
                    nameCtrlHolder[0]?.text = ex.name;
                    setS(() {
                      name = ex.name;
                      gifFilename = ex.gifFilename;
                    });
                  }),
                  icon: const Icon(Icons.library_books_rounded, size: 16),
                  label: const Text('Sfoglia archivio per muscolo', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Color(0x42FFC107)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: setsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Set"),
                        onChanged: (v) =>
                            setS(() => sets = int.tryParse(v) ?? 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: recCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Recupero (s)",
                        ),
                        onChanged: (v) =>
                            setS(() => rec = int.tryParse(v) ?? 90),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: pauseCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Pausa (s)"),
                  onChanged: (v) => setS(() => pause = int.tryParse(v) ?? 120),
                ),
                // Sotto il TextField di "Pausa Cambio (s)"
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(text: notePT),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Note per l'atleta (PT)",
                    hintText: "es: Focus sulla fase eccentrica",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => notePT = v,
                ),
                const SizedBox(height: 14),
                // --- SUPERSERIE / CIRCUITO ---
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🔗 Superserie / Circuito",
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Assegna lo stesso numero a esercizi consecutivi per farli senza riposo (superset). 0 = normale.",
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          6,
                          (i) => GestureDetector(
                            onTap: () => setS(() => supersetGroup = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: supersetGroup == i
                                    ? Colors.purpleAccent
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: supersetGroup == i
                                      ? Colors.purpleAccent
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                i == 0 ? '✗' : '$i',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: supersetGroup == i
                                      ? Colors.black
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text("Target Reps:"),
                Wrap(
                  spacing: 5,
                  children: List.generate(
                    sets,
                    (i) => SizedBox(
                      width: 45,
                      child: TextField(
                        controller: ctrls[i],
                        focusNode: nodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        onTap: () => ctrls[i].clear(),
                        onChanged: (v) {
                          if (v.isNotEmpty) {
                            int val = int.tryParse(v) ?? 0;
                            if ((val > 3 || v.length >= 2) && i < sets - 1) {
                              ctrls[i + 1]
                                  .clear(); // FIX: cancella il quadratino successivo
                              nodes[i + 1]
                                  .requestFocus(); // FIX: salta al quadratino successivo
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (name.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Il nome dell'esercizio non può essere vuoto",
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (sets < 1 || sets > 10) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text("Le serie devono essere tra 1 e 10"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                var newEx = ExerciseConfig(
                  name: name.trim(),
                  targetSets: sets,
                  recoveryTime: rec,
                  interExercisePause: pause,
                  notePT: notePT,
                  noteCliente: ex?.noteCliente ?? "",
                  supersetGroup: supersetGroup,
                  repsList: ctrls
                      .take(sets)
                      .map((e) => int.tryParse(e.text) ?? 10)
                      .toList(),
                  gifFilename: gifFilename,
                );
                setState(() {
                  if (editIndex == null)
                    widget.client.routine[dayIdx].exercises.add(newEx);
                  else
                    widget.client.routine[dayIdx].exercises[editIndex] = newEx;
                });
                widget.onUpdate();
                Navigator.pop(c);
              },
              child: const Text("SALVA"),
            ),
          ],
        ),
      ),
    );
  }

  void _mostraTemplateDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Scegli un template',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: () => Navigator.pop(c),
                ),
              ],
            ),
            const Text(
              'Carica una scheda pre-impostata come punto di partenza. '
              'Puoi modificarla dopo il caricamento.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...kWorkoutTemplates.map(
              (t) => ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withAlpha(60)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t['icon'] as String,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  t['name'] as String,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  t['desc'] as String,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white24,
                ),
                onTap: () {
                  Navigator.pop(c);
                  _confermaCaricaTemplate(t);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confermaCaricaTemplate(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Carica "${template['name']}"?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Verranno aggiunte ${(template['days'] as List).length} sessioni alla scheda. '
          'Le sessioni esistenti verranno mantenute.',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              'ANNULLA',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              setState(() {
                for (final dayData in template['days'] as List) {
                  final day = WorkoutDay.fromJson(
                    Map<String, dynamic>.from(dayData as Map),
                  );
                  widget.client.routine.add(day);
                }
              });
              widget.onUpdate();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Template "${template['name']}" caricato! Modifica gli esercizi secondo le esigenze dell\'atleta.',
                  ),
                  backgroundColor: Colors.amber.shade800,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('CARICA'),
          ),
        ],
      ),
    );
  }

  void _addSession() {
    String n = "";
    final Set<String> selectedParts = {};
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("Nome Workout"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (v) => n = v,
                autofocus: true,
                decoration: const InputDecoration(hintText: "es. Push Day"),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kBodyPartIcons.entries
                    .where((e) => e.key != 'nessuno')
                    .map((entry) {
                      final bool sel = selectedParts.contains(entry.key);
                      return GestureDetector(
                        onTap: () => setS(() {
                          if (sel)
                            selectedParts.remove(entry.key);
                          else
                            selectedParts.add(entry.key);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF00F2FF).withAlpha(40)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? const Color(0xFF00F2FF)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${entry.value} ${kBodyPartNames[entry.key]}',
                            style: TextStyle(
                              color: sel
                                  ? const Color(0xFF00F2FF)
                                  : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (n.isNotEmpty) {
                  setState(
                    () => widget.client.routine.add(
                      WorkoutDay(
                        dayName: n,
                        bodyParts: selectedParts.toList(),
                        exercises: [],
                      ),
                    ),
                  );
                }
                widget.onUpdate();
                Navigator.pop(c);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      ),
    );
  }

  void _changeBodyPartDialog(int dayIdx) {
    final Set<String> selected = Set<String>.from(
      widget.client.routine[dayIdx].bodyParts,
    );
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Parti del corpo',
            style: TextStyle(color: Colors.amber, fontSize: 16),
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kBodyPartIcons.entries
                .where((e) => e.key != 'nessuno')
                .map((entry) {
                  final bool sel = selected.contains(entry.key);
                  return GestureDetector(
                    onTap: () => setS(() {
                      if (sel)
                        selected.remove(entry.key);
                      else
                        selected.add(entry.key);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF00F2FF).withAlpha(40)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF00F2FF)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${entry.value} ${kBodyPartNames[entry.key]}',
                        style: TextStyle(
                          color: sel ? const Color(0xFF00F2FF) : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                })
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('ANNULLA'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(
                  () => widget.client.routine[dayIdx].bodyParts = selected
                      .toList(),
                );
                widget.onUpdate();
                Navigator.pop(c);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _changeMuscleImageDialog(int dayIdx) {
    final current = widget.client.routine[dayIdx].muscleImage;
    String? selected =
        current; // fuori dal builder — non si resetta ad ogni rebuild
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Immagine allenamento',
              style: TextStyle(color: Colors.amber, fontSize: 16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: kMuscleImages.length + 1, // +1 per "Nessuna"
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    // Opzione "Nessuna"
                    final bool sel = selected == null;
                    return GestureDetector(
                      onTap: () => setS(() => selected = null),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00F2FF).withAlpha(40)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF00F2FF)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hide_image_outlined,
                              color: sel
                                  ? const Color(0xFF00F2FF)
                                  : Colors.white38,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nessuna',
                              style: TextStyle(
                                color: sel
                                    ? const Color(0xFF00F2FF)
                                    : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final img = kMuscleImages[i - 1];
                  final bool sel = selected == img['file'];
                  return GestureDetector(
                    onTap: () => setS(() => selected = img['file']),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF00F2FF)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/muscle/${img['file']}',
                              fit: BoxFit.cover,
                            ),
                            // Overlay scuro + label
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  img['label']!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: sel
                                        ? const Color(0xFF00F2FF)
                                        : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('ANNULLA'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(
                    () => widget.client.routine[dayIdx].muscleImage = selected,
                  );
                  widget.onUpdate();
                  Navigator.pop(c);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _importLogDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Importa Dati Atleta",
          style: TextStyle(color: Colors.amber, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opzione 1: Apri file .gymlog
            ListTile(
              leading: const Icon(
                Icons.folder_open_rounded,
                color: Colors.greenAccent,
                size: 30,
              ),
              title: const Text(
                "Apri file .gymlog",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "L'atleta ti ha inviato un file .gymlog via WhatsApp o Telegram.\nSelezionalo qui.",
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              onTap: () async {
                Navigator.pop(c);
                await _importaFileProgressi();
              },
            ),
            const Divider(color: Colors.white12),
            // Opzione 2: Incolla JSON manuale (fallback)
            ListTile(
              leading: const Icon(
                Icons.content_paste_rounded,
                color: Colors.cyanAccent,
                size: 30,
              ),
              title: const Text(
                "Incolla codice",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Alternativa: incolla il JSON copiato dall'app dell'atleta.",
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              onTap: () {
                Navigator.pop(c);
                _importLogManuale();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importaFileProgressi() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final fileName = result.files.first.name.toLowerCase();
      final fileBytes = result.files.first.bytes;
      final filePath = result.files.first.path;

      // Controllo estensione
      if (!fileName.endsWith('.gymlog')) {
        _mostraErroreImportazione(
          "Il file selezionato non è un file progressi valido.\n\n"
          "Seleziona un file con estensione .gymlog inviato dall'atleta.\n\n"
          "File selezionato: ${result.files.first.name}",
        );
        return;
      }

      String content;
      if (fileBytes != null) {
        content = utf8.decode(fileBytes);
      } else if (filePath != null) {
        content = await File(filePath).readAsString();
      } else {
        throw "Impossibile leggere il file";
      }

      final (newLogs, clientName) = _validaEParseLogs(content);

      setState(() {
        widget.client.performanceLogs
          ..clear()
          ..addAll(newLogs);
      });
      widget.onUpdate();

      if (mounted) {
        final nome = clientName != null ? " di $clientName" : "";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${newLogs.length} sessioni$nome importate!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _mostraErroreImportazione(e.toString());
    }
  }

  void _importLogManuale() {
    String rawData = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Incolla JSON atleta",
          style: TextStyle(color: Colors.amber),
        ),
        content: FutureBuilder<ClipboardData?>(
          future: Clipboard.getData(Clipboard.kTextPlain),
          builder: (ctx, snap) {
            final clipText = snap.data?.text ?? '';
            // Auto-incolla sempre il contenuto degli appunti
            final pasteCtrl = TextEditingController(text: clipText);
            if (rawData.isEmpty && clipText.isNotEmpty) rawData = clipText;
            // Avvisa se il formato non sembra valido
            final bool formatoValido =
                clipText.trimLeft().startsWith('[') ||
                clipText.trimLeft().startsWith('{') ||
                clipText.startsWith("TIPO:PROGRESSI_GYM");
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (clipText.isNotEmpty && !formatoValido)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "⚠️ Il testo negli appunti non sembra un log valido.",
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                TextField(
                  controller: pasteCtrl,
                  maxLines: 8,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: const InputDecoration(
                    hintText:
                        "Incolla qui il JSON generato dall'app dell'atleta...",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                  onChanged: (v) => rawData = v,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "ANNULLA",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              try {
                final (logs, clientName) = _validaEParseLogs(rawData.trim());
                setState(() {
                  widget.client.performanceLogs
                    ..clear()
                    ..addAll(logs);
                });
                widget.onUpdate();
                Navigator.pop(c);
                final nome = clientName != null ? " di $clientName" : "";
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("✅ ${logs.length} sessioni$nome importate!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                _mostraErroreImportazione(e.toString());
              }
            },
            child: const Text("IMPORTA"),
          ),
        ],
      ),
    );
  }

  void _condividiSchedaFile() async {
    final routineList = widget.client.routine.map((e) => e.toJson()).toList();
    final envelope = {'clientName': widget.client.name, 'routine': routineList};
    final String jsonScheda = jsonEncode(envelope);
    final String contenutoFile = "TIPO:SCHEDA_GYM\n$jsonScheda";

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final tempDir = await getTemporaryDirectory();
        final fileName =
            '${widget.client.name.replaceAll(' ', '_')}_scheda.workout';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(contenutoFile, flush: true);
        await _gymFileChannel.invokeMethod('shareFile', {
          'path': file.path,
          'name': fileName,
        });
      } catch (e) {
        debugPrint("Errore condivisione file: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Errore condivisione. Usa 'Copia codice'."),
            ),
          );
        }
      }
    }
    // Sempre copia anche il JSON negli appunti come fallback web/Apple
    await Clipboard.setData(ClipboardData(text: jsonScheda));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "File .workout pronto! Codice anche copiato negli appunti.",
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  void _apriArchivioEserciziPT(BuildContext context, StateSetter setS, Function(ExerciseInfo) onSelect) {
    String? selectedCategory;

    const Map<String, String> muscleIcons = {
      'petto': '🦍', 'dorso': '🔙', 'gambe': '🦵', 'spalle': '🏋️',
      'braccia': '💪', 'core': '🔥', 'glutei': '🍑', 'cardio': '❤️',
      'altro': '⚡',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setA) {
          final cats = kGifCatalog.map((e) => e.category).toSet().where((c) => c.isNotEmpty).toList()..sort();
          final exercisesInCat = selectedCategory != null
              ? kGifCatalog.where((e) => e.category == selectedCategory).toList()
              : <ExerciseInfo>[];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.78,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                if (selectedCategory != null)
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      onPressed: () => setA(() => selectedCategory = null),
                    ),
                    Text(selectedCategory!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ])
                else
                  const Text('Gruppo muscolare', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (selectedCategory == null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: cats.map((cat) => ActionChip(
                          avatar: Text(muscleIcons[cat] ?? '⚡', style: const TextStyle(fontSize: 18)),
                          label: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          backgroundColor: Colors.white10,
                          side: const BorderSide(color: Colors.white12),
                          onPressed: () => setA(() => selectedCategory = cat),
                        )).toList(),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.85,
                        mainAxisSpacing: 8, crossAxisSpacing: 8,
                      ),
                      itemCount: exercisesInCat.length,
                      itemBuilder: (_, i) {
                        final ex = exercisesInCat[i];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(c);
                            setS(() => onSelect(ex));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: ex.gifFilename != null
                                      ? Image.asset(
                                          'assets/gif/${ex.gifFilename}.gif',
                                          fit: BoxFit.cover, width: double.infinity,
                                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.fitness_center, color: Colors.white30, size: 32)),
                                        )
                                      : const Center(child: Icon(Icons.fitness_center, color: Colors.white30, size: 32)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  ex.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                  maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MultiLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> logs;
  final List<Color> colors;
  MultiLineChartPainter(this.logs, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    int maxSets = 0;
    for (var log in logs) {
      if ((log['series'] as List).length > maxSets)
        maxSets = (log['series'] as List).length;
    }

    for (int sIdx = 0; sIdx < maxSets; sIdx++) {
      final color = colors[sIdx % colors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      bool first = true;
      final double xScale =
          size.width / (logs.length > 1 ? logs.length - 1 : 1);

      for (int i = 0; i < logs.length; i++) {
        var series = logs[i]['series'] as List;
        if (sIdx < series.length) {
          double x = logs.length == 1 ? size.width / 2 : xScale * i;
          double sNorm = ((series[sIdx]['s_norm'] ?? 0.5) as double).clamp(
            0.0,
            1.0,
          );
          double y = size.height * (1.0 - sNorm);
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else
            path.lineTo(x, y);
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── GIF Picker Bottom Sheet ────────────────────────────────────────────────────
class _GifPickerSheet extends StatefulWidget {
  final String initialQuery;
  final String? currentSlug;
  const _GifPickerSheet({required this.initialQuery, this.currentSlug});

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  late final TextEditingController _searchCtrl;
  List<ExerciseInfo> _results = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _filter(widget.initialQuery);
  }

  void _filter(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _results = kGifCatalog.take(60).toList();
      } else {
        _results = kGifCatalog
            .where((e) => e.name.toLowerCase().contains(query))
            .take(80)
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cerca GIF esercizio...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter('');
                        },
                      )
                    : null,
              ),
              onChanged: _filter,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_results.length} risultati',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final e = _results[i];
                final isSelected = e.gifSlug == widget.currentSlug;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, e.gifSlug),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: Colors.amber, width: 2)
                                  : null,
                            ),
                            child: Image.asset(
                              'assets/gif/${e.gifSlug}.gif',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.fitness_center_rounded,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.amber : Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
