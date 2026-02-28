import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Aggiungi questo import in alto!
import 'dart:math' as scala;

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

class AuthLockScreen extends StatefulWidget {
  final String deviceId;
  final String correctCode;
  const AuthLockScreen({
    super.key,
    required this.deviceId,
    required this.correctCode,
  });

  @override
  State<AuthLockScreen> createState() => _AuthLockScreenState();
}

class _AuthLockScreenState extends State<AuthLockScreen> {
  final TextEditingController _ctrl = TextEditingController();

  void _verify() async {
    if (_ctrl.text == widget.correctCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authorized', true);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const PTDashboard()),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Codice Errato")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              "ID DISPOSITIVO: ${widget.deviceId}",
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: "Inserisci Codice Sblocco",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verify,
              child: const Text("ATTIVA DASHBOARD"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODELLI DATI ---
class ExerciseConfig {
  String name;
  int targetSets;
  List<int> repsList;
  int recoveryTime;
  int interExercisePause;
  String notePT; // <--- Nuova
  String noteCliente; // <--- Nuova

  ExerciseConfig({
    required this.name,
    required this.targetSets,
    required this.repsList,
    required this.recoveryTime,
    this.interExercisePause = 120,
    this.notePT = "", // Default vuoto
    this.noteCliente = "", // Default vuoto
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'targetSets': targetSets,
    'repsList': repsList,
    'recoveryTime': recoveryTime,
    'interExercisePause': interExercisePause,
    'notePT': notePT,
    'noteCliente': noteCliente,
  };

  factory ExerciseConfig.fromJson(Map<String, dynamic> json) => ExerciseConfig(
    name: json['name'],
    targetSets: json['targetSets'],
    repsList: List<int>.from(json['repsList']),
    recoveryTime: json['recoveryTime'],
    interExercisePause: json['interExercisePause'] ?? 120,
    notePT: json['notePT'] ?? "",
    noteCliente: json['noteCliente'] ?? "",
  );
}

class WorkoutDay {
  String dayName;
  List<ExerciseConfig> exercises;
  WorkoutDay({required this.dayName, required this.exercises});
  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    dayName: json['dayName'],
    exercises: (json['exercises'] as List)
        .map((e) => ExerciseConfig.fromJson(e))
        .toList(),
  );
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

// --- DASHBOARD ---
class PTDashboard extends StatefulWidget {
  const PTDashboard({super.key});
  @override
  State<PTDashboard> createState() => _PTDashboardState();
}

class _PTDashboardState extends State<PTDashboard> {
  List<Client> clients = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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
    // Salva solo i nomi e le schede (routine)
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
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() => clients.removeAt(i));
              _saveData();
            },
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
              }
              _saveData();
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
  final List<String> exSuggestions = [
    "Panca piana",
    "Pectoral machine",
    "Distensioni manubri",
    "Croci ai cavi",
    "Pulldown",
    "Lat machine",
    "Pulley",
    "Rematore",
    "Shoulder Press",
    "Alzate laterali",
    "Curl",
    "Curl hammer",
    "Pushdown corda",
    "Pushdown barra",
    "Stacchi rumeni",
    "Squat",
    "Leg press",
    "Leg extension",
    "Leg curl",
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
      ElevatedButton.icon(
        onPressed: _addSession,
        icon: const Icon(Icons.add),
        label: const Text("NUOVA SESSIONE"),
      ),
      ...widget.client.routine.asMap().entries.map(
        (entry) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            title: Text(
              entry.value.dayName,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ...entry.value.exercises.asMap().entries.map(
                (exEntry) => ListTile(
                  title: Text(exEntry.value.name),
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
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Center(
        child: IconButton(
          icon: const Icon(Icons.copy_all, size: 40, color: Colors.amber),
          onPressed: _copyRoutineToClipboard,
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
                          height: 180,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: MultiLineChartPainter(
                              entry.value,
                              lineColors,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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

    // 1. Raggruppamento base per esercizio
    for (var log in widget.client.performanceLogs) {
      String ex = log['exercise'] ?? "Esercizio";
      if (!logsByEx.containsKey(ex)) logsByEx[ex] = [];
      logsByEx[ex]!.add(log);
    }

    // 2. Normalizzazione SERIE PER SERIE (S1 con S1, S2 con S2...)
    logsByEx.forEach((exName, logs) {
      // Usiamo mappe per tracciare le medie di ogni singola serie
      Map<int, double> sumWPerSet = {};
      Map<int, double> sumRPerSet = {};
      Map<int, int> countPerSet = {};

      // Primo passaggio: calcoliamo le medie specifiche per posizione (indice)
      for (var log in logs) {
        var series = log['series'] as List;
        for (int i = 0; i < series.length; i++) {
          double w = (series[i]['w'] ?? 0.0).toDouble();
          double r = (series[i]['r'] ?? 0.0).toDouble();

          sumWPerSet[i] = (sumWPerSet[i] ?? 0) + w;
          sumRPerSet[i] = (sumRPerSet[i] ?? 0) + r;
          countPerSet[i] = (countPerSet[i] ?? 0) + 1;
        }
      }

      // Secondo passaggio: applichiamo la normalizzazione
      for (var log in logs) {
        var series = log['series'] as List;
        for (int i = 0; i < series.length; i++) {
          double avgW = (countPerSet[i]! > 0 && sumWPerSet[i]! > 0)
              ? sumWPerSet[i]! / countPerSet[i]!
              : 1.0;
          double avgR = (countPerSet[i]! > 0 && sumRPerSet[i]! > 0)
              ? sumRPerSet[i]! / countPerSet[i]!
              : 1.0;

          // Ora il valore 1.0 significa "In linea con la media di QUELLA specifica serie"
          series[i]['w_norm'] = (series[i]['w'] ?? 0.0) / avgW;
          series[i]['r_norm'] = (series[i]['r'] ?? 0.0) / avgR;
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
                            if (s.containsKey('repsList')) {
                              // Se c'è una lista specifica (come per 12-10-8)
                              List<int> reps = s['repsList'];
                              for (int i = 0; i < ctrls.length; i++) {
                                if (i < reps.length) {
                                  ctrls[i].text = reps[i].toString();
                                }
                              }
                            } else {
                              // Comportamento standard per gli altri suggerimenti
                              for (var ct in ctrls) {
                                ct.text = s['reps'].toString();
                              }
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                const Divider(),
                Wrap(
                  spacing: 5,
                  children: exSuggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 10)),
                          onPressed: () => setS(() => name = s),
                        ),
                      )
                      .toList(),
                ),

                TextField(
                  controller: TextEditingController(text: name)
                    ..selection = TextSelection.collapsed(offset: name.length),
                  decoration: const InputDecoration(labelText: "Nome"),
                  onChanged: (v) => name = v,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Set"),
                        onChanged: (v) =>
                            setS(() => sets = int.tryParse(v) ?? 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
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
                  onChanged: (v) => notePT =
                      v, // Ricorda di dichiarare 'String notePT = ex?.notePT ?? "";' all'inizio del metodo
                ),
                const SizedBox(height: 10),
                Text(
                  "Note dell'atleta: ${ex?.noteCliente ?? 'Nessuna'}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
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
                            if ((val > 1 || v.length >= 2) && i < sets - 1) {
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
                var newEx = ExerciseConfig(
                  name: name,
                  targetSets: sets,
                  recoveryTime: rec,
                  interExercisePause: pause,
                  notePT: notePT,
                  noteCliente: ex?.noteCliente ?? "",
                  repsList: ctrls
                      .take(sets)
                      .map((e) => int.tryParse(e.text) ?? 10)
                      .toList(),
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

  void _addSession() {
    String n = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nome Workout"),
        content: TextField(
          onChanged: (v) => n = v,
          autofocus: true,
          decoration: const InputDecoration(hintText: "es. Push Day"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (n.isNotEmpty)
                setState(
                  () => widget.client.routine.add(
                    WorkoutDay(dayName: n, exercises: []),
                  ),
                );
              widget.onUpdate();
              Navigator.pop(c);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _importLogDialog() {
    String rawData = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Importa Dati Atleta"),
        content: TextField(
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: "Incolla qui il JSON generato dall'app dell'atleta...",
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => rawData = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final dec = jsonDecode(rawData);
                setState(() {
                  // RESET MONOUSO: Puliamo tutto prima di caricare i nuovi dati
                  widget.client.performanceLogs.clear();

                  if (dec is List) {
                    for (var it in dec) {
                      widget.client.performanceLogs.add(
                        Map<String, dynamic>.from(it),
                      );
                    }
                  } else {
                    widget.client.performanceLogs.add(
                      Map<String, dynamic>.from(dec),
                    );
                  }
                });
                widget.onUpdate(); // Salva i dati dell'atleta permanentemente
                Navigator.pop(c);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Errore: Formato dati non valido"),
                  ),
                );
              }
            },
            child: const Text("RESETTA E IMPORTA"),
          ),
        ],
      ),
    );
  }

  void _copyRoutineToClipboard() {
    Clipboard.setData(
      ClipboardData(
        text: jsonEncode(widget.client.routine.map((e) => e.toJson()).toList()),
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

    // --- 1. CONFIGURAZIONE MARGINI ---
    // Aggiungiamo un offset per non far toccare le linee al titolo in alto
    const double topPadding = 20.0;
    final double chartHeight = size.height - topPadding;

    // --- 2. DISEGNO DELLA LEGENDA TESTUALE ---
    const textStyle = TextStyle(
      color: Colors.white24,
      fontSize: 9, // Leggermente più piccolo per stare in una riga sola
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: "Linea spessa = Peso  |  Linea sottile = Reps",
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Posizionamento: lo mettiamo a filo con l'inizio del grafico reale (dopo il padding)
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        0,
      ), // Ora è a Y=0, il grafico inizierà sotto
    );

    // --- 3. LOGICA DEL GRAFICO ---
    const double maxVal = 2.0;

    int maxSets = 0;
    for (var log in logs) {
      if ((log['series'] as List).length > maxSets) {
        maxSets = (log['series'] as List).length;
      }
    }

    for (int sIdx = 0; sIdx < maxSets; sIdx++) {
      final color = colors[sIdx % colors.length];

      final pWeight = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final pReps = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final pathW = Path();
      final pathR = Path();
      bool first = true;

      for (int i = 0; i < logs.length; i++) {
        var series = logs[i]['series'] as List;
        if (sIdx < series.length) {
          double x = (size.width / (logs.length > 1 ? logs.length - 1 : 1)) * i;
          if (logs.length == 1) x = size.width / 2;

          // Calcolo Y includendo il topPadding:
          // Più il valore è alto, più si avvicina al topPadding (non allo 0 assoluto)
          double yw =
              size.height -
              ((series[sIdx]['w_norm'] ?? 0.0) / maxVal * chartHeight);
          double yr =
              size.height -
              ((series[sIdx]['r_norm'] ?? 0.0) / maxVal * chartHeight);

          if (first) {
            pathW.moveTo(x, yw);
            pathR.moveTo(x, yr);
            first = false;
          } else {
            pathW.lineTo(x, yw);
            pathR.lineTo(x, yr);
          }
          canvas.drawCircle(Offset(x, yw), 3, Paint()..color = color);
        }
      }
      canvas.drawPath(pathW, pWeight);
      canvas.drawPath(pathR, pReps);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
