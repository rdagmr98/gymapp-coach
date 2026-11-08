import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as scala;
import 'package:archive/archive.dart' as arc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'exercise_catalog.dart';
import 'gif_exercise_catalog.dart';
import 'workout_templates.dart';

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

ExerciseInfo? resolveTemplateExerciseInfo(String rawName) {
  final cleaned = rawName.trim();
  final direct = findAnyExercise(cleaned);
  if (direct != null) return direct;
  for (final part in cleaned.split('/')) {
    final normalizedPart = part.trim();
    final info = findAnyExercise(normalizedPart);
    if (info != null) return info;
  }
  final normalized = normalizeExerciseLookup(cleaned);
  for (final ex in [...kGifCatalog, ...kExerciseCatalog]) {
    final candidates = <String>{ex.name, ex.nameEn, ...ex.aliases, ex.gifSlug};
    for (final candidate in candidates) {
      if (normalizeExerciseLookup(candidate) == normalized) {
        return ex;
      }
    }
  }
  return null;
}

// --- MODELLI DATI ---
const String kExerciseAnimationExtension = 'webp';

String exerciseAnimationAssetPath(String slug) =>
    'assets/gif/$slug.$kExerciseAnimationExtension';

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
  bool useQuarterStep;

  /// Esercizio a tempo (cardio): durata in secondi, 0 = serie x reps.
  int cardioSeconds;
  bool get isCardio => cardioSeconds > 0;

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
    this.useQuarterStep = false,
    this.cardioSeconds = 0,
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
    if (useQuarterStep) 'useQuarterStep': useQuarterStep,
    if (cardioSeconds > 0) 'cardioSeconds': cardioSeconds,
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
    useQuarterStep: json['useQuarterStep'] == true,
    cardioSeconds: (json['cardioSeconds'] as num?)?.toInt() ?? 0,
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

const Map<String, IconData> kBodyPartIcons = {
  'petto': Icons.fitness_center_rounded,
  'schiena': Icons.rowing_rounded,
  'gambe': Icons.directions_walk_rounded,
  'spalle': Icons.accessibility_new_rounded,
  'braccia': Icons.sports_gymnastics_rounded,
  'core': Icons.self_improvement_rounded,
  'full_body': Icons.accessibility_new_rounded,
  'cardio': Icons.favorite_border_rounded,
  'glutei': Icons.directions_run_rounded,
  'altro': Icons.bolt_rounded,
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

/// JSON di una scheda, in chiaro o come codice `GYM1:` (gzip + base64url).
dynamic _decodePayload(String payload) {
  var raw = payload.trim();
  if (raw.startsWith('GYM1:')) {
    final b64 = raw.substring(5).replaceAll(RegExp(r'\s'), '');
    final padded = b64.padRight(b64.length + (4 - b64.length % 4) % 4, '=');
    final bytes = base64Url.decode(padded);
    raw = utf8.decode(arc.GZipDecoder().decodeBytes(bytes));
  }
  return jsonDecode(raw);
}

List<dynamic> _templateDays(Map<String, dynamic> template) {
  final directDays = template['days'];
  if (directDays is List) return directDays;
  final payload = template['payload'] as String?;
  if (payload == null || payload.isEmpty) return const [];
  final decoded = _decodePayload(payload);
  if (decoded is Map<String, dynamic>) {
    final routine = decoded['routine'];
    if (routine is List) return routine;
  }
  return decoded is List ? decoded : const [];
}

/// File `.workout` (o codice copiato) → (giorni, nome atleta se il file lo contiene).
/// Lancia FormatException se non è una scheda.
(List<dynamic>, String?) parseSchedaFile(String text) {
  var t = text.replaceFirst('\uFEFF', '').trim();
  if (t.startsWith('TIPO:SCHEDA_GYM')) t = t.substring(15).trim();
  if (t.startsWith('TIPO:')) throw const FormatException('non è una scheda');
  final decoded = _decodePayload(t);
  final days = decoded is Map ? decoded['routine'] : decoded;
  if (days is! List ||
      days.isEmpty ||
      days.any((d) => d is! Map || d['exercises'] is! List)) {
    throw const FormatException('non è una scheda');
  }
  final name = decoded is Map ? '${decoded['clientName'] ?? ''}'.trim() : '';
  return (days, name.isEmpty ? null : name);
}

/// Giorno di un template o di un file importato → WorkoutDay del coach.
WorkoutDay workoutDayFromTemplate(Map dayData) {
  final rawDay = Map<String, dynamic>.from(dayData);
  // i template di gym_app chiamano 'dorso' quello che il coach chiama 'schiena'
  rawDay['bodyParts'] = [
    for (final p in (rawDay['bodyParts'] as List? ?? const []))
      p == 'dorso' ? 'schiena' : p,
  ];
  rawDay['exercises'] = (rawDay['exercises'] as List? ?? const []).map((e) {
    final rawEx = Map<String, dynamic>.from(e as Map);
    // i template di gym_app hanno già nome e gif giusti
    if (rawEx['gifFilename'] != null) return rawEx;
    final rawName = rawEx['name'] as String? ?? 'Esercizio';
    final resolved = resolveTemplateExerciseInfo(rawName);
    rawEx['name'] = resolved?.name ?? rawName.trim();
    rawEx['gifFilename'] ??= resolved?.gifSlug;
    return rawEx;
  }).toList();
  return WorkoutDay.fromJson(rawDay);
}

final List<Map<String, dynamic>> kCuratedWorkoutTemplates = [
  {
    'name': 'Gianmarco Signature',
    'desc': '5 giorni · petto / dorso / gambe / spalle / braccia',
    'payload':
        'GYM1:H4sIAApl5WkC_81XXU_bMBT9K1ae4wnYQGxvtHxsEkwRZU9THxznklhz7Mx2KAXx33cdp12bhCJNootaVdW1Y5_j43vuzXPEpQDlvrMSoi_RlWCqZIbrKI6Mrp1QGP35HGVs2c5IwDk_mupsmTDjLI5HVROcx1FZWy7hW8lyP7cJf6hUjvPhEQwXFmyzngqLzUrhCnLDeIEbkQkoXpDEgLX4gGMmBzcDv8MnRAOVvRbW4eOncfOZ-yDXD2CWd8Iv9_kgjoRyYC7avRJWW4wfHuGA0g6SO9zzhxNSPD0xA-Smlk5UegEmChOmzVl4ZBiwdQXGgrvCg6iiL7hGLu4vhYQWvPXgaRnA09SDp1UD_iVeM_wq8oJMWSqBTI221sN9R3L_wqNAiJR7iJSvIW5QOEdgoKzQSpCSqTo1YmQMsrpMU5Cyf_wJcKcNk6SVaWTAK-A0A_6L3stl9DL3wP9m2rk2tpdpFmng0_1cy_zsXbl2zdwq00Z2CpI5WtVSZnqhNsVb-cKtXowMsQXmIKNGL1b5v3XpkAssyYTZRr8RAg_ZjvA3YQeXmjnD0BAcOTMlSVaq7GJxeBCvvntkEijYFi1lpty4Q51MumJlCt1MyptgL4-a8K48moB0xP6umeucyumQtvH-NUYndDQA3FD3GnJy8dgaeQf5x209j-PDo_2KKSGnsAbXQT2tjSQzyGo30mzy6DmCHAI-NqtdQ-2kyKxiaFq9ahOivSQJ8Z2dXaFrmYEJ7ZwvPN4m2dgE3GrhbIu530acySdUmlwarRyTYnf6vOaFJ-_f_9x7gBQt0W4VJCz94JugWz_wShOw7V6NAcS93z1ykgFzIDNUZVtNWm7irRJ1uncGa1W2qAxQSDQ22EboN_rqVoeDgQw5ecdighfK79Rl0fGPicEMF6xrIGkb7jlIO7Cz0AqO5F_p3I-Hi-0-Lyg8BKtAfPinWwCaqsXZgyAZZl460Av-fwqhh3IL3bRPngHVigrF5fqNtkepYGXZe4UdCxWjK6ABYU-QpLYF8e2hV2V8Wmg8ca-C8dcKHa9CuLT7RrTBQZuMjY5Ec_4eeRc4thecM26YEuM7-raNWymw9m1nGgfa7Ezn-PkDop31-TMTAAA',
  },
  {
    'name': 'Ivan A/B',
    'desc': '2 giorni · upper / lower',
    'payload':
        'GYM1:H4sIAApl5WkC_82VUWvbMBDHv4rQsw1Nuo2tb03WjUG6GZq3EcJZvsXHZElIctqs7LvvZJs2c9Y-ZsYgzJ18-p3811-PUmlCE79Cg_JKftmDkZn0to1kOPD9UVZwGJLXnMEH9IoChi5n-kQBRoEoCAzwlAh-h_EOI895w7XQhRWFyB_M5tnsInufvduksLJ79Ic1pRIfLjJJJqK_GeoX0AaOz-acMDZiseZ1ZP--7IixD4TWoQ8YPzOzk1c8fUc_PpHGga1Eo-rceQxB_s6ekVH9FB95GAFf_gv4jLiOkbZV4jqCXUEUt6Dq9Eumhash5q7VurL35q_t5RgexAJCsJOTRECIWOUKSo25t_fH4MvWa6GsEQvSrGpCP7UtL8GXqHWumPSE_BZ85KSdGHMNTYN-QN4k6GdXWbzkKivciaI7t6828zbr-jmn6HF3aiiJ9uYhoglkzYh4frr9Z8bFJ7IRclLN1DyFecfivqttqyv0vSCSGSY3hImRh4ZinTe9U-dhYD7VyrX-xQ4k2NbRg6aJdVG1Tdk5jO75cg9c_ph_7UmRo0gCSCxhP7UOvHXI11Kox9fSN169RqhE6gDdiwf2fzdgB85t7Di3R8d3w88fY9uharUJAAA',
  },
  {
    'name': 'Angela 3 Day',
    'desc': '3 giorni · split personalizzata',
    'payload':
        'GYM1:H4sIAApl5WkC_82Wb2_aMBDGv0qU11gCtkms7ygr2ws6ocFeTVXlOAc54diZ_7RlVb_7ziR0WdKiVZpClAghX-z8zr7nyT3GQiIo95XnEF_EU7UFyeNBbLR3qGjox2Oc8n0VXnqbURAewAi0YA9hVcW4EjxaIldhvuNmC24Fjp55T8tBYRdoHU2YDA7XTRgU-g7Mfo1hgY_DQYzKgbmqVl9yb2l8NKaA0g6Wa3pLXP6fHaChHLC-AGPBfSboIr6gx7e4maOEiiwBJTJWGLA2fhr8AfZSwj665NbqnhFb4A5SJngigRl9X8f-pnOuaJejT8BTiRvXYH_XZu-Q3FR0LD3S1dC_YBGtM-Ntv5gzLG5diVWDXRsUWKDDiGM043d4skZGwwHdXe91AawgSab6XtXR5yZUfLQ8VHzfqFOfJwlIyeyOBMgE7XsGJn66CQnUrUbKV62GprDvxenUJoPj3WFy4TQYReo2A2JHWhW7nnlMQUi3aeBqKHSapF44bU5qtKyc0bBjmfIj29td5UzEbWOZeSMjoVV0zZVPDEZTSS9X3GF_tSqIuZXDNTeOgrp32BnPczAVdMNXFrB9zVZWPz13h5O5REndDIKBvjUGAbF-EJTOiz5_3i-qhG273wqoVw8OlEWt_kGqXQPDM1sDOhR7g3fc5O0atinIVaa9TMGUxUDSFCLDVid-3qqwObqM5TyQAbMVcbtQpvIXtb_R3GjluMSelcqzJ24CHzOcFn-BfkE_pk3_4W_6cWmOb0th8t9SkCXkMYkbun4D0U-glBEOAAA',
  },
  {
    'name': 'Elisa PPL',
    'desc': '3 giorni · pull / push / legs',
    'payload':
        'GYM1:H4sIAApl5WkC_9WWwW7bMAyGX0Xw2QKabgO23lY33Q7dFjS5DUGgyExMTJY8Sm6aFX33UbFbGE2Q9ZRqsA-2RMuf6Z8_9ZBpg2DDd1VDdpGNDXqV5Rm5NqDlkZ8PWam2_eykNUbwLQfAPZBGD34XYrv5b0pX_JS4dRsOCYrWEKYQOOY9LwmNv0Ef-IGP-e6Yx0Ht7oC2M4wLfDrLM7QBaNyvPlGt5_HROU9YF2Ay47dk3XWx44ZuwLcNkIfwhcGb7ILD17i6RgM9mQcVoJTkNrLuILPH_Jn7RgXRs7_gfrfPfUJqo4JsOOel29ghb9GSEcqIQt05cam8d0lha7U0IDVDDqFvXa0sKiuuQJUGV-GfEhmd8XlCbuoJZflEONQIrEXMe2LCNrDuMz2PsMNa9dWxWi0q8EFMCLyP2o_iV2mpKALKJgIeqtmCnEahnWV62y4Jk4Iv23q5BGPkymyH1D_45RWrS8wINTRifB_AenQ2KXrXUy7CjnIBz5SDT7kmsLrqFJRm7v0v9k6piSsBaIg-rVxrSqCU5e9rDNWT8KXvibt6GH7LZ_OHW5vgFgakDB61p9GHfHQebfVNfofpECUpXn7Pr6K_HrGrOH1Iain4794_mf5ueUcRvekSjbIagdLaWPgI-LK7vc6Ldk35tH055vigBX3FRswqru-QmCoqbBahA_u_thDzx79h3fVZEQwAAA',
  },
  {
    'name': 'Gaetano PPL',
    'desc': '3 giorni · pull / push / legs',
    'payload':
        'GYM1:H4sIAApl5WkC_82Wb2-bMBDGvwry6zCl3R9tfbdmbTUp2dCSd1UUHeYKVo3NbNOUVf3uOwONUkqjvAooURTZ5vy788NzfmJcClTuF-TILtgNoAOl2YQZXTqhaOz2iSVQtfNRKSVNxjqpIjDO0jSLDXAugK0nLC8tl_gzh9QvLmjxh0Kl9AA-ouHCoq3jqSbYAnhGWwR_9JaWODApuiX6oJ9pfyzsXFhHD3yZfK0_Z9O1H-f6AU21Ej7Gt-mECeXQXLUbRFBaGj87pwmlHUYr2og1_2d1ptgM2LJAY9HdUKIFu6Dlqbi7FhJbOIvgMAmN3oZ5w8meJzt0XwesgkuwVnfYP_WwD0HOIZbo-fe55-CCtuwHsc-mk5fvCckluNCLJtFbtU89K40MuFbBpZCguECDYyt6DCZGKUNOqG_QQQYzeNBHyGWYujdS6UVf0FtOeXWpP_ZSnxA5gzxH0zKvPfW-Sdmsa1K2AHpj-zzKZoc8amY0F7X2FqDK2IixCS8p87hW3p2sXp1eDQ7CK0-M8V2vhEpbk-qgR8jvgx_0c1B0dU84IXBBQJvEU-2hLjNdygRNEBm01lur91YYXUvIhcte-lhoW-iw8ND76XyX_6h3BNQl0IA8RjanPYOd2GVDGBqg8MdnMLhtvZdAx8HmmNqug6WQxz0GVg8fcjCK1ahzbKKUmL5V4PJvSVeUg71-8EO0nvHVrYpKfPXoUFmhVYf2vGtaJ64w7rg6wL69j8pgPW33DrIygotCuOM62QAiNrrA0F8iunfW37R7hpAEPgUs3tXHGHqxblk3rmbd9Grm2qDiWa-VDKubnafa-9LfwA2dBhrvqevn_68FreTfDgAA',
  },
  {
    'name': 'Valentina 4/4',
    'desc': '4 giorni · split completa',
    'payload':
        'GYM1:H4sIAApl5WkC_82Y0U7bMBSGX8XKzW6SDWiZgDsosE2CrYJuu5gQOnFOU6uOndkO0CHeZ--xF9txUlhpSmGlrSJFVZs48Xdi-_9_9zbgUqBynyHDYC_4BpJ-CAVBGBhd0Dc6--M2SGA0bvFdmyFdYJvv2tQm1smoC8ZZanURBllhucRPGaS-aV5I-TZXKbXDGzRcWLTl01T1qBNw7BT4wHcSBg5Miu4c_bNa1Dvm9kRYRzdsboQ74fsLf47rKzSjnvD3726EgVAOzdH44V0oLJ3f3KILSjvs9qiToPreKavE6oQtcjQW3QcqMQ_2qHkq-seCSq_AJLjIwyf6WgV34QPwGWbgtEHGtWIHQoLiAk3D4GMwMUoZxXRL5HuMjL6erKJLleGIHYC1ulnoFsFhEnGIJU5TP3r3p6CK2IgV4p9TR2_-_GaFBSaBXRVyiGqRmpIii8vxmKqnZwQXuXCCgWAduBLNGgqjc6Q1YAfTa-AL9T5ASJgvAHN2dONQWaFVs_j1GPPSlZiX-IA5UcuxQcUHrGvQ2in8rRr-gvBLmDl2SCs24oZGA80kf8cUxD__xW-H5VGjb72IvsVuWAY3i-DzCu7uwgPX_WPref_4WUByv0rm-cg5NXTzNbldn41rljbPODl2J5jOnHhTpFshwb5i-i1kf5hGeYk2xdvQte55Z67vjyJn-3FScDKOZiEPRH4J92QTxPv9vlbJs15QHmvEfZAiWShampMSBLLPzqBcknMn8k6pQzuzpGh13JzoIuPpHkWJwloBivWuPdtC6rm7avU0FWPkSsanRLT1khBuB_PEs4t8yA7po2mKmRPTZeLBHjme5mtITF996qMESJ2kcmwn_y9LI6HScZjty9GjCE4uBaxLAwwNLyL2CanuBvvyF0V1dmy0ciBXqldLCFB9j1nXgXERtA1FUy9i-wkjXqsV_xPeCrJexMwMWNfe8bEgentVKbD9vIClsnA4N_95m-8NSDFd80zeVVyT7qMzUN5-Dml7IkXfNW3jV-FFyT3eVAjsFEY2L_9xT7Vg9Ft3mnoq_Pk3y0B6b9Mz_55ZqicvxR4qd5t--WUhp7SgSbl003LFALIMTZ35BXvp14noUvbSF3d_AeQpIbSyFQAA',
  },
  {
    'name': 'Andrea 4/4',
    'desc': '4 giorni · split completa',
    'payload':
        'GYM1:H4sIAApl5WkC_9WXX0_bMBDAv4qV50RraZEYb6WDDQmmCvo2VdPFuTbWHDuzHWiH-O47JwGytupQ2cBIfajs2P7d_7u7iEuByn2FAqPjaKQygxDFkdGVE4qWvt1FGaza7f6HIe2lOltNwDhLu7M4KirLJZ4XsKBPVCVlHOESDRcWbX1eNYcvged0JbvSt3SJA7NAd43-lgG9h6W9ENbRgf5B3O_FRzO_yPUNmtVU-As-9uJIKIfmtL19ApWl9f4BbSjtcDKlV6Lm_7iWCpsFW5VoLLrPJFUZHdPnCzE_ExJbMovgMEuMvk2KBjK6jx-5L8Cxlj0wbgkuKUnhmb5VXeIrLMBpg4xrxU6EBMUFmtDoUzApSpmkdCTxL3oDvG_FT43gohROMBBsDDciMG6jSyRwm6-DnxlUPGcTg9YGxpxVRVr7if1BGk-4IXw0XfhxZeRuVz_YlOENHJ0TZ3Q_8-RPKfXgJSn1-mdFMbJT9OGG6LUFX1UB1mN2LfZFlGyakyXdX2l7r-1vuSi_u4atm1J1AUqAYp8QMinmAYKbFjHJHhDXND5Ks4pTXQgswL3C4QGtG9Yg5-wKap_fqeyj2P8OybNfkZoTXWI83R_MpqI8ulvBhzXr4Z6sA7ZkBSz3Qm7g1jPQ4CUZaGw0F3UGugRVpUY8Iy6O3qZ-zOWqa6oJ5UtgEwoYCK0x8rU4Keta3PWtHK1rSrRvi3xfFBo594gN-bZO-jrXlczQhC2ELYTLH_AT2zJv2mMkf9HYwKhLRQNShFcQHj1fNoib6aqJgXNFM6ACB7tFaPPW_qlruH_qEjUiJp2Z4SlE1vLZ8D93VIOtln3rduqdFfcLXLDTpUNlhVahTXe4SPCRbQ3aDxsB8jazxZaZqC3LbCTpaQpyEep4t1UCkH6M1uwErNWhFTtIJW7HvqTEQzLpoMbQHIqC6tgG8DNa1t6Lctw_aVln978BapFsfKsUAAA',
  },
];

List<Map<String, dynamic>> get kAllWorkoutTemplates => [
  ...kCuratedWorkoutTemplates,
  ...kWorkoutTemplates,
];

String _limitToOneEmoji(String s) {
  final RegExp emojiRe = RegExp(
    r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FE0F}]',
    unicode: true,
  );
  final matches = emojiRe.allMatches(s).toList();
  if (matches.length <= 1) return s;
  String result = s;
  for (int i = matches.length - 1; i >= 1; i--) {
    result = result.replaceRange(matches[i].start, matches[i].end, '');
  }
  return result.trim();
}

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

      if (content.replaceFirst('﻿', '').trimLeft().startsWith('TIPO:SCHEDA_GYM')) {
        _importaSchedaDaTesto(content);
        return;
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
              content: Text("Progressi di ${atleta.name} aggiornati!"),
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

  // ─── IMPORT SCHEDA (.workout) ────────────────────────────────────────────

  static String _normName(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Carica un file .workout: crea l'atleta se non esiste, altrimenti chiede
  /// se sostituirgli la scheda (gli altri dati dell'atleta restano).
  Future<void> _importaSchedaWorkout() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final text = f.bytes != null
        ? utf8.decode(f.bytes!, allowMalformed: true)
        : (!kIsWeb && f.path != null ? await File(f.path!).readAsString() : '');
    await _importaSchedaDaTesto(text);
  }

  /// Usato anche da "Apri con" (file .workout in entrata).
  Future<void> _importaSchedaDaTesto(String text) async {
    final List<WorkoutDay> routine;
    String? nome;
    try {
      final (days, fileName) = parseSchedaFile(text);
      routine = [for (final d in days) workoutDayFromTemplate(d as Map)];
      nome = fileName;
    } catch (e) {
      debugPrint('Import scheda: $e');
      _mostraErroreImportazione(
        "Il file selezionato non è una scheda valida.\n\n"
        "Seleziona un file .workout (creato con GymCoach).",
      );
      return;
    }
    if (!mounted) return;
    nome ??= await _chiediNomeAtleta();
    if (nome == null || nome.trim().isEmpty || !mounted) return;
    final key = _normName(nome);
    final esistente = clients.where((c) => _normName(c.name) == key).firstOrNull;

    void fatto(String msg) {
      _saveData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
    }

    if (esistente == null) {
      final n = nome.trim();
      setState(
        () => clients.add(
          Client(id: DateTime.now().toString(), name: n, routine: routine),
        ),
      );
      fatto("Atleta $n creato con ${routine.length} sessioni");
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("${esistente.name} esiste già"),
        content: Text(
          "Sostituire la sua scheda con quella del file (${routine.length} sessioni)? "
          "Progressi e nome restano invariati.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("SOSTITUISCI"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => esistente.routine = routine);
    fatto("Scheda di ${esistente.name} sostituita");
  }

  Future<String?> _chiediNomeAtleta() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nome atleta"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Il file non contiene il nome",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text("IMPORTA"),
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
      appBar: AppBar(
        title: const Text("COACH DASHBOARD"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Importa scheda (.workout)",
            onPressed: _importaSchedaWorkout,
          ),
        ],
      ),
      body: clients.isEmpty
          ? const Center(
              child: Text(
                "Nessun atleta.\nTocca + per aggiungerne uno\no importa un file .workout dall'icona in alto.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38),
              ),
            )
          : ListView.builder(
        // spazio sotto per il FAB, che altrimenti copre l'ultimo atleta
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: clients.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(ctx).colorScheme.primary.withAlpha(40),
            foregroundColor: Theme.of(ctx).colorScheme.primary,
            child: Text(
              clients[i].name.trim().isEmpty ? '?' : clients[i].name.trim()[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            clients[i].name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            clients[i].routine.isEmpty
                ? "Nessuna scheda"
                : "${clients[i].routine.length} ${clients[i].routine.length == 1 ? 'sessione' : 'sessioni'}",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.copy_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
                tooltip: "Duplica scheda",
                onPressed: () => _duplicateClient(i),
              ),
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

  // ponytail: deep-clone via JSON roundtrip — same path as persist
  void _duplicateClient(int index) {
    final ctrl = TextEditingController(text: "${clients[index].name} (copia)");
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Duplica scheda"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Nome nuovo cliente"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final copy = Client.fromJson(clients[index].toJson());
              copy.id = DateTime.now().toString();
              copy.name = name;
              setState(() => clients.add(copy));
              _saveData();
              Navigator.pop(c);
            },
            child: const Text("DUPLICA"),
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

class _ClientDetailViewState extends State<ClientDetailView>
    with SingleTickerProviderStateMixin {
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
  late final AnimationController _wiggleCtrl;
  late final TabController _tabController;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _tabController = TabController(length: 2, vsync: this);
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
    _wiggleCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _setReordering(bool value) {
    if (_isReordering == value) return;
    setState(() => _isReordering = value);
    if (value) {
      _wiggleCtrl.repeat(reverse: true);
    } else {
      _wiggleCtrl.stop();
      _wiggleCtrl.value = 0.5;
    }
  }

  Widget _reorderCue({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _wiggleCtrl,
      child: child,
      builder: (_, wiggleChild) {
        final direction = index.isEven ? -1.0 : 1.0;
        final angle = _isReordering
            ? direction * (0.008 + (_wiggleCtrl.value * 0.01))
            : 0.0;
        return Transform.rotate(angle: angle, child: wiggleChild);
      },
    );
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
            content: Text("${logs.length} sessioni$nome sincronizzate!"),
            backgroundColor: Colors.green,
          ),
        );
        _tabController.animateTo(1);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.name.toUpperCase()),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "PROTOCOLLO"),
            Tab(text: "PROGRESSI"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRoutineList(), _buildAnalytics()],
      ),
    );
  }

  void _reorderSessions(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final day = widget.client.routine.removeAt(oldIndex);
      widget.client.routine.insert(newIndex, day);
    });
    widget.onUpdate();
  }

  void _reorderExercises(int dayIdx, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final ex = widget.client.routine[dayIdx].exercises.removeAt(oldIndex);
      widget.client.routine[dayIdx].exercises.insert(newIndex, ex);
    });
    widget.onUpdate();
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
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: widget.client.routine.length,
        onReorderStart: (_) => _setReordering(true),
        onReorderEnd: (_) => _setReordering(false),
        onReorder: _reorderSessions,
        itemBuilder: (ctx, dayIdx) {
          final day = widget.client.routine[dayIdx];
          final dayCard = Card(
            key: ObjectKey(day),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => _changeBodyPartDialog(dayIdx),
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
                      child: Icon(
                        kBodyPartIcons[day.bodyParts.firstOrNull] ??
                            Icons.fitness_center_rounded,
                        size: 22,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      day.dayName,
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
                    onTap: () => _changeMuscleImageDialog(dayIdx),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                        image: day.muscleImage != null
                            ? DecorationImage(
                                image: AssetImage(
                                  'assets/muscle/${day.muscleImage}',
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: day.muscleImage == null
                          ? const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white38,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.drag_indicator_rounded,
                    color: _isReordering ? Colors.amber : Colors.white38,
                    size: 20,
                  ),
                ],
              ),
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: day.exercises.length,
                  onReorderStart: (_) => _setReordering(true),
                  onReorderEnd: (_) => _setReordering(false),
                  onReorder: (oldIndex, newIndex) =>
                      _reorderExercises(dayIdx, oldIndex, newIndex),
                  itemBuilder: (_, exIdx) {
                    final ex = day.exercises[exIdx];
                    final exerciseTile = Container(
                      key: ObjectKey(ex),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ex.supersetGroup > 0 ? Colors.deepPurple.withAlpha(120) : Colors.white10,
                          width: ex.supersetGroup > 0 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // GIF thumbnail
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                            ),
                            child: ex.gifFilename != null
                                ? Image.asset(
                                    exerciseAnimationAssetPath(ex.gifFilename!),
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => _noGifPlaceholder(),
                                  )
                                : (() {
                                    final found = findAnyExercise(ex.name);
                                    return found?.gifSlug != null
                                        ? Image.asset(
                                            exerciseAnimationAssetPath(found!.gifSlug),
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                            errorBuilder: (_, __, ___) => _noGifPlaceholder(),
                                          )
                                        : _noGifPlaceholder();
                                  })(),
                          ),
                          const SizedBox(width: 10),
                          // Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (ex.supersetGroup > 0)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'S${ex.supersetGroup}',
                                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          ex.name,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ex.isCardio
                                        ? '${(ex.cardioSeconds / 60).toStringAsFixed(ex.cardioSeconds % 60 == 0 ? 0 : 1)} min a tempo'
                                        : '${ex.targetSets} serie · ${ex.repsList.join('-')} reps · ${ex.recoveryTime}s riposo',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                  if (ex.notePT.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${ex.notePT}',
                                      style: const TextStyle(color: Colors.amber, fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Actions
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.white38, size: 18),
                                onPressed: () => _addExDialog(dayIdx, editIndex: exIdx),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                onPressed: () {
                                  setState(() => day.exercises.removeAt(exIdx));
                                  widget.onUpdate();
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.drag_indicator_rounded,
                                color: _isReordering ? Colors.amber : Colors.white24,
                                size: 18,
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    );
                    return ReorderableDelayedDragStartListener(
                      key: ObjectKey(ex),
                      index: exIdx,
                      child: _reorderCue(index: exIdx, child: exerciseTile),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _addExDialog(dayIdx),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Aggiungi esercizio'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),
                // Azioni sessione
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                          final ctrl = TextEditingController(text: day.dayName);
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
                                    borderSide: BorderSide(
                                      color: Colors.white24,
                                    ),
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
                                        () => day.dayName = ctrl.text.trim(),
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
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
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
                                'Vuoi eliminare "${day.dayName}" e tutti i suoi esercizi?',
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
                                        dayIdx,
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
          );
          return ReorderableDelayedDragStartListener(
            key: ObjectKey(day),
            index: dayIdx,
            child: _reorderCue(index: dayIdx, child: dayCard),
          );
        },
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

  Widget _noGifPlaceholder() => Container(
    width: 70,
    height: 70,
    color: Colors.white10,
    child: const Icon(Icons.fitness_center_rounded, color: Colors.white24, size: 28),
  );

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
    bool cardio = ex?.isCardio ?? false;
    final cardioCtrl = TextEditingController(
      text: '${(ex?.cardioSeconds ?? 0) > 0 ? ex!.cardioSeconds : 300}',
    );

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
          title: Center(
            child: Text(editIndex == null ? "Nuovo Esercizio" : "Modifica"),
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: 5,
                    alignment: WrapAlignment.center,
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
                      return searchExercises(textEditingValue.text, limit: 8);
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
                                              exerciseAnimationAssetPath(
                                                e.gifSlug,
                                              ),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                  exerciseAnimationAssetPath(
                                    gifFilename ??
                                        findAnyExercise(name)!.gifSlug,
                                  ),
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
                                        backgroundColor: const Color(
                                          0xFF0E0E10,
                                        ),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _apriArchivioEserciziPT(context, setS, (ex) {
                          nameCtrlHolder[0]?.text = ex.name;
                          setS(() {
                            name = ex.name;
                            gifFilename = ex.gifFilename;
                          });
                        }),
                    icon: const Icon(Icons.library_books_rounded, size: 16),
                    label: const Text(
                      'Sfoglia archivio per muscolo',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Color(0x42FFC107)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  // Selezione multipla: aggiunge tutti con set/reps/recupero del modulo
                  if (editIndex == null)
                    OutlinedButton.icon(
                      onPressed: () => _apriArchivioEserciziPT(
                        context,
                        setS,
                        (_) {},
                        onSelectMany: (list) {
                          final n = sets.clamp(1, 10);
                          setState(() => widget.client.routine[dayIdx].exercises.addAll([
                            for (final e in list)
                              ExerciseConfig(
                                name: e.name,
                                targetSets: n,
                                recoveryTime: rec,
                                interExercisePause: pause,
                                notePT: notePT,
                                noteCliente: '',
                                supersetGroup: supersetGroup,
                                repsList: ctrls.take(n).map((c) => int.tryParse(c.text) ?? 10).toList(),
                                gifFilename: e.gifFilename,
                              ),
                          ]));
                          widget.onUpdate();
                          Navigator.pop(c);
                        },
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 16),
                      label: const Text('Più esercizi', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Color(0x42FFC107)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("A tempo (cardio)"),
                    value: cardio,
                    onChanged: (v) => setS(() => cardio = v),
                  ),
                  if (cardio)
                    TextField(
                      controller: cardioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Durata (s)"),
                    ),
                  if (!cardio) ...[
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final v in const [60, 90, 120, 180])
                        ActionChip(
                          backgroundColor: rec == v ? Colors.amber.withAlpha(60) : Colors.blueGrey.shade900,
                          label: Text(
                            '$v s',
                            style: const TextStyle(fontSize: 10, color: Colors.amber),
                          ),
                          onPressed: () => setS(() {
                            rec = v;
                            recCtrl.text = '$v';
                          }),
                        ),
                    ],
                  ),
                  ],
                  TextField(
                    controller: pauseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Pausa (s)"),
                    onChanged: (v) =>
                        setS(() => pause = int.tryParse(v) ?? 120),
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
                      border: Border.all(
                        color: Colors.deepPurple.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(
                          child: const Text(
                            "Superserie / Circuito",
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: const Text(
                            "Assegna lo stesso numero a esercizi consecutivi per farli senza riposo (superset). 0 = normale.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white38,
                            ),
                          ),
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
                                  '$i',
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
                  if (!cardio) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Target Reps:",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 10),
                      // imposta tutte le serie insieme
                      SizedBox(
                        width: 70,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: 'tutte',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            if (int.tryParse(v) == null) return;
                            setS(() {
                              for (final ct in ctrls) {
                                ct.text = v;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Wrap(
                      spacing: 5,
                      alignment: WrapAlignment.center,
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
                                if ((val > 3 || v.length >= 2) &&
                                    i < sets - 1) {
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
                  ),
                  ],
                ],
              ),
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
                if (!cardio && (sets < 1 || sets > 10)) {
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
                  targetSets: cardio ? 1 : sets,
                  recoveryTime: rec,
                  interExercisePause: pause,
                  notePT: notePT,
                  noteCliente: ex?.noteCliente ?? "",
                  supersetGroup: supersetGroup,
                  repsList: cardio
                      ? [1]
                      : ctrls
                          .take(sets)
                          .map((e) => int.tryParse(e.text) ?? 10)
                          .toList(),
                  gifFilename: gifFilename,
                  useQuarterStep: ex?.useQuarterStep ?? false,
                  cardioSeconds: cardio
                      ? (int.tryParse(cardioCtrl.text) ?? 300).clamp(1, 86400)
                      : 0,
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
    int? fLv, fDays;
    bool? fSplit, fMono;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        final list = kAllWorkoutTemplates.where((t) =>
            (fLv == null || t['level'] == fLv) &&
            (fDays == null || _templateDays(t).length == fDays) &&
            (fSplit == null || t['split'] == fSplit) &&
            (fMono == null || t['mono'] == fMono)).toList();
        // ripremere il chip scelto toglie il filtro
        Widget chips<T>(List<(T, String)> opts, T? sel, void Function(T?) set) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final o in opts)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: ChoiceChip(
                      label: Text(o.$2),
                      selected: sel == o.$1,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor: Colors.amber.withAlpha(50),
                      onSelected: (_) => setS(() => set(sel == o.$1 ? null : o.$1)),
                    ),
                  ),
              ]),
            );
        return SizedBox(
          height: MediaQuery.of(c).size.height * 0.85,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                chips([(0, 'Principiante'), (1, 'Intermedio'), (2, 'Avanzato')], fLv, (v) => fLv = v),
                chips([for (final d in [2, 3, 4, 5]) (d, '$d giorni')], fDays, (v) => fDays = v),
                chips([(false, 'Full body'), (true, 'Split')], fSplit, (v) => fSplit = v),
                chips([(false, 'Multifrequenza'), (true, 'Monofrequenza')], fMono, (v) => fMono = v),
                Expanded(
                  child: list.isEmpty
                      ? const Center(
                          child: Text(
                            'Nessuna scheda con questi filtri',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final t in list)
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.withAlpha(60)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    switch (t['level']) {
                                      0 => Icons.signal_cellular_alt_1_bar_rounded,
                                      1 => Icons.signal_cellular_alt_2_bar_rounded,
                                      2 => Icons.signal_cellular_alt_rounded,
                                      _ => Icons.fitness_center_rounded,
                                    },
                                    color: Colors.amber,
                                  ),
                                ),
                                title: Text(
                                  t['name'] as String,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  [
                                    if ((t['levelName'] as String?)?.isNotEmpty ?? false)
                                      '${t['levelName']} · ${t['mono'] == true ? 'monofrequenza' : 'multifrequenza'}',
                                    t['desc'] as String,
                                  ].join('\n'),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
                                onTap: () {
                                  Navigator.pop(c);
                                  _confermaCaricaTemplate(t);
                                },
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _confermaCaricaTemplate(Map<String, dynamic> template) {
    final days = _templateDays(template).cast<Map>();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Carica "${template['name']}"?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final k in ['desc', 'info'])
                if ((template[k] as String?)?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      template[k] as String,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                    ),
                  ),
              for (final d in days) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Text(
                    '${d['dayName'] ?? ''}',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                for (final e in ((d['exercises'] as List?) ?? const []).cast<Map>())
                  Text(
                    '${e['targetSets']}×${{...(e['repsList'] as List? ?? const [])}.join('/')}  ${e['name']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                'Verranno aggiunte ${days.length} sessioni alla scheda. '
                'Le sessioni esistenti verranno mantenute.',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
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
                for (final dayData in days) {
                  widget.client.routine.add(workoutDayFromTemplate(dayData));
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
                            kBodyPartNames[entry.key]!,
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
                        dayName: _limitToOneEmoji(n),
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
                        kBodyPartNames[entry.key]!,
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
            content: Text("${newLogs.length} sessioni$nome importate!"),
            backgroundColor: Colors.green,
          ),
        );
        _tabController.animateTo(1);
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
                      "Il testo negli appunti non sembra un log valido.",
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
                    content: Text("${logs.length} sessioni$nome importate!"),
                    backgroundColor: Colors.green,
                  ),
                );
                _tabController.animateTo(1);
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
            "Scheda pronta: il file .workout si apre con GymApp o Gym Logbook. Codice copiato anche negli appunti (in GymApp: Template > Incolla codice).",
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _apriArchivioEserciziPT(
    BuildContext context,
    StateSetter setS,
    Function(ExerciseInfo) onSelect, {
    void Function(List<ExerciseInfo>)? onSelectMany,
  }) {
    final picked = <ExerciseInfo>[];
    String? selectedCategory;
    String? selectedEquipment;
    String searchQuery = '';

    final List<ExerciseInfo> archiveAll = kAllExercises;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setA) {
          final cats =
              archiveAll
                  .map((e) => e.category)
                  .toSet()
                  .where((c) => c.isNotEmpty)
                  .toList()
                ..sort();

          List<ExerciseInfo> filtered = selectedCategory != null
              ? archiveAll.where((e) => e.category == selectedCategory).toList()
              : archiveAll;

          if (selectedEquipment != null) {
            filtered = filtered
                .where((e) => exerciseEquipment(e) == selectedEquipment)
                .toList();
          }

          if (searchQuery.trim().length >= 2) {
            filtered = searchExercises(searchQuery, pool: filtered);
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cerca esercizio...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (v) => setA(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                const Text(
                  'GRUPPO MUSCOLARE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ptArchiveChip(
                        label: 'Tutti',
                        selected: selectedCategory == null,
                        onTap: () => setA(() => selectedCategory = null),
                      ),
                      ...cats.map(
                        (cat) => _ptArchiveChip(
                          label: cat,
                          selected: selectedCategory == cat,
                          onTap: () => setA(() => selectedCategory = cat),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ATTREZZO',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ptArchiveChip(
                        label: 'Corpo libero',
                        selected: selectedEquipment == 'corpo_libero',
                        onTap: () => setA(
                          () => selectedEquipment =
                              selectedEquipment == 'corpo_libero' ? null : 'corpo_libero',
                        ),
                      ),
                      _ptArchiveChip(
                        label: 'Manubri',
                        selected: selectedEquipment == 'manubri',
                        onTap: () => setA(
                          () => selectedEquipment =
                              selectedEquipment == 'manubri' ? null : 'manubri',
                        ),
                      ),
                      _ptArchiveChip(
                        label: 'Bilanciere',
                        selected: selectedEquipment == 'bilanciere',
                        onTap: () => setA(
                          () => selectedEquipment =
                              selectedEquipment == 'bilanciere' ? null : 'bilanciere',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final ex = filtered[i];
                      final isPicked = picked.contains(ex);
                      return GestureDetector(
                        onTap: () {
                          if (onSelectMany != null) {
                            setA(() => isPicked ? picked.remove(ex) : picked.add(ex));
                            return;
                          }
                          Navigator.pop(c);
                          setS(() => onSelect(ex));
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: isPicked
                                ? Border.all(color: Colors.amber, width: 2.5)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: ex.gifFilename != null
                                      ? Image.asset(
                                          exerciseAnimationAssetPath(
                                            ex.gifFilename!,
                                          ),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.fitness_center,
                                                  color: Colors.white30,
                                                  size: 32,
                                                ),
                                              ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.fitness_center,
                                            color: Colors.white30,
                                            size: 32,
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  ex.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (onSelectMany != null && picked.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.pop(c);
                            onSelectMany(List.of(picked));
                          },
                          child: Text(
                            'Aggiungi ${picked.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ptArchiveChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withAlpha(40) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.amber : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.amber : Colors.white60,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
      final fillPath = Path();
      bool first = true;
      double lastX = 0;
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
            fillPath.moveTo(x, size.height);
            fillPath.lineTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
            fillPath.lineTo(x, y);
          }
          lastX = x;
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
      if (!first) {
        fillPath.lineTo(lastX, size.height);
        fillPath.close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(40), color.withAlpha(0)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        );
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
    setState(() {
      _results = q.trim().length < 2
          ? kGifCatalog.toList()
          : searchExercises(q, pool: kGifCatalog);
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
                              exerciseAnimationAssetPath(e.gifSlug),
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
