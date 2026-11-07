// Schede predefinite: livello (principiante/intermedio/avanzato) x 2-5 giorni,
// full body o split, multi o monofrequenza. Le giornate sono scritte una volta
// con l'esercizio scelto per ogni livello; serie, ripetizioni, recuperi e note
// di progressione vengono dal ruolo dell'esercizio (fondamentale, multiarticolare,
// isolamento, core) e dal livello. Importato da main.dart.
String _l(String it, String en) => it;

Map<String, dynamic> _ex(
  String name,
  String gif,
  int sets,
  List<int> reps, {
  int rest = 90,
  int pause = 120,
  String note = '',
}) =>
    {
      'name': name,
      'targetSets': sets,
      'repsList': reps,
      'recoveryTime': rest,
      'interExercisePause': pause,
      'notePT': note,
      'noteCliente': '',
      'supersetGroup': 0,
      'gifFilename': gif,
    };

Map<String, dynamic> _day(
  String dayName,
  List<String> bodyParts,
  String? muscleImage,
  List<Map<String, dynamic>> exercises,
) =>
    {
      'dayName': dayName,
      'bodyParts': bodyParts,
      if (muscleImage != null) 'muscleImage': muscleImage,
      'exercises': exercises,
    };

// nome, gif, consiglio tecnico it, en. "secondi" = le ripetizioni sono secondi di tenuta.
const _ex_ = <String, (String, String, String, String)>{
  // petto
  'panca': ('Panca Piana', 'bench-press', 'Scapole strette e piedi a terra, bilanciere al petto basso con i gomiti a 45°', 'Shoulder blades pinched, feet planted, bar to the lower chest with elbows at 45°'),
  'pancaIncl': ('Panca Inclinata', 'incline-barbell-bench-press', 'Panca a 30°, bilanciere sulla parte alta del petto', 'Bench at 30°, bar to the upper chest'),
  'pancaInclM': ('Incline Dumbbell Press', 'incline-dumbbell-press', 'Panca a 30°, manubri che scendono ai lati del petto', 'Bench at 30°, dumbbells down to the sides of the chest'),
  'manubri': ('Distensioni con Manubri', 'dumbbell-press', 'Scendi finché senti allungare il petto, spingi senza battere i manubri', 'Lower until the chest stretches, press without clanking the dumbbells'),
  'chestPress': ('Chest Press Macchina', 'chest-press-machine', 'Maniglie all\'altezza del petto, schiena sempre appoggiata', 'Handles at chest height, back always on the pad'),
  'inclPress': ('Incline Chest Press Machine', 'incline-chest-press-machine', 'Schiena appoggiata, spingi in alto e in avanti', 'Back on the pad, press up and forward'),
  'croci': ('Croci ai Cavi', 'cable-crossover', 'Gomiti appena piegati e fermi, chiudi le mani davanti al petto', 'Elbows slightly bent and fixed, bring the hands together in front of the chest'),
  'peck': ('Peck Deck', 'pec-deck-fly', 'Spalle basse, porta avanti i gomiti senza staccare la schiena', 'Shoulders down, bring the elbows forward without leaving the pad'),
  'dip': ('Dip alle Parallele', 'chest-dips', 'Busto un po\' in avanti, scendi finché le spalle restano comode', 'Torso slightly forward, go down as far as the shoulders stay comfortable'),
  // dorso
  'lat': ('Lat Machine', 'lat-pulldown', 'Petto in fuori, tira la barra al mento portando i gomiti ai fianchi', 'Chest up, pull the bar to the chin driving the elbows to your sides'),
  'latStretta': ('Close Grip Lat Pulldown', 'close-grip-lat-pulldown', 'Presa stretta, porta le mani allo sterno senza dondolare', 'Close grip, pull to the sternum without swinging'),
  'trazioni': ('Trazioni alla Sbarra', 'pull-up', 'Da braccia tese a mento sopra la sbarra; se servono usa l\'elastico o la macchina assistita', 'From a dead hang to chin over the bar; use a band or the assisted machine if needed'),
  'rematore': ('Rematore con Bilanciere', 'barbell-bent-over-row', 'Busto a 45° e schiena neutra, bilanciere all\'ombelico', 'Torso at 45° and neutral back, bar to the belly button'),
  'rematoreM': ('Rematore con Manubrio', 'dumbbell-row', 'Mano e ginocchio sulla panca, tira il gomito verso il fianco', 'Hand and knee on the bench, drive the elbow to the hip'),
  'pulley': ('Pulley Basso', 'seated-cable-row', 'Busto fermo, tira al basso ventre e stringi le scapole', 'Torso still, pull to the lower belly and squeeze the shoulder blades'),
  'rowMachine': ('Seated Row Machine', 'seated-row-machine', 'Petto sull\'appoggio, tira con i gomiti e non con le mani', 'Chest on the pad, pull with the elbows, not the hands'),
  'tbar': ('T-Bar Row', 't-bar-row', 'Schiena neutra e ginocchia morbide, barra al petto basso', 'Neutral back and soft knees, bar to the lower chest'),
  'pullover': ('Cable Straight Arm Pulldown', 'cable-straight-arm-pulldown', 'Braccia quasi tese, porta la barra alle cosce sentendo i dorsali', 'Arms almost straight, sweep the bar to the thighs feeling the lats'),
  'stacco': ('Stacchi da Terra', 'deadlift', 'Bilanciere attaccato alle gambe, schiena neutra, spingi via il pavimento', 'Bar against the legs, neutral back, push the floor away'),
  'hyper': ('Back Extension', 'hyperextension', 'Sali fino ad allineare busto e gambe, senza inarcare', 'Rise until torso and legs line up, no overarching'),
  'face': ('Face Pull', 'face-pull', 'Corda all\'altezza degli occhi, tira verso la fronte aprendo i gomiti', 'Rope at eye level, pull to the forehead with the elbows wide'),
  'shrug': ('Alzate di Spalle', 'dumbbell-shrug', 'Sali dritto verso le orecchie, 1 secondo di pausa in alto', 'Straight up to the ears, 1-second pause at the top'),
  // spalle
  'lento': ('Lento Avanti', 'barbell-shoulder-press', 'In piedi, glutei e addome contratti, bilanciere sopra la testa in linea', 'Standing, glutes and abs tight, press the bar overhead in line'),
  'spalleM': ('Dumbbell Shoulder Press', 'dumbbell-shoulder-press', 'Seduto con schienale, manubri all\'altezza delle orecchie', 'Seated with back support, dumbbells at ear level'),
  'spalleMacchina': ('Shoulder Press Macchina', 'lever-shoulder-press', 'Schiena appoggiata, maniglie all\'altezza delle spalle', 'Back on the pad, handles at shoulder height'),
  'arnold': ('Arnold Press', 'arnold-press', 'Parti con i palmi verso di te e ruota mentre spingi', 'Start with palms facing you and rotate as you press'),
  'alzLat': ('Alzate Laterali', 'dumbbell-lateral-raise', 'Gomiti appena piegati, sali fino alle spalle senza slanci', 'Elbows slightly bent, raise to shoulder height without swinging'),
  'alzLatCavo': ('Cable Lateral Raise', 'cable-lateral-raise', 'Cavo dietro il corpo, tensione costante per tutto il movimento', 'Cable behind the body, constant tension all the way'),
  'alzLatMacchina': ('Lateral Raise Machine', 'lateral-raise-machine', 'Spingi con i gomiti, non con le mani', 'Push with the elbows, not the hands'),
  'alzPost': ('Alzate Posteriori', 'bent-over-lateral-raise', 'Busto quasi parallelo al pavimento, apri le braccia senza stringere le scapole', 'Torso nearly parallel to the floor, open the arms without squeezing the blades'),
  'postMacchina': ('Rear Delt Machine Fly', 'rear-delt-machine-fly', 'Petto sull\'appoggio, apri le braccia tenendo le spalle basse', 'Chest on the pad, open the arms keeping the shoulders down'),
  // braccia
  'curl': ('Curl con Bilanciere', 'barbell-curl', 'Gomiti fermi ai fianchi, niente slancio con la schiena', 'Elbows pinned to the sides, no swinging'),
  'curlM': ('Curl con Manubri Alternati', 'dumbbell-curl', 'Ruota il palmo verso l\'alto mentre sali', 'Turn the palm up as you curl'),
  'hammer': ('Curl Martello', 'hammer-curl', 'Presa neutra, gomiti fermi', 'Neutral grip, elbows still'),
  'curlIncl': ('Seated Incline Dumbbell Curl', 'seated-incline-dumbbell-curl', 'Panca a 45°, braccia lasciate indietro per allungare il bicipite', 'Bench at 45°, arms hanging back to stretch the biceps'),
  'scott': ('Scott Curl', 'lever-preacher-curl', 'Scendi fino a braccio quasi teso, senza rimbalzo', 'Lower to almost straight arms, no bounce'),
  'pushdown': ('Tricipiti ai Cavi', 'rope-pushdown', 'Gomiti fermi ai fianchi, apri la corda in basso', 'Elbows pinned, spread the rope at the bottom'),
  'overhead': ('Cable Rope Overhead Triceps Extension', 'cable-rope-overhead-triceps-extension', 'Di spalle al cavo, gomiti alti e fermi, allunga bene in basso', 'Back to the cable, elbows high and still, deep stretch at the bottom'),
  'french': ('French Press', 'lying-barbell-triceps-extension', 'Gomiti verso il soffitto, scendi alla fronte con controllo', 'Elbows to the ceiling, lower to the forehead under control'),
  'pancaStretta': ('Close Grip Bench Press', 'close-grip-bench-press', 'Presa larga quanto le spalle, gomiti vicini al corpo', 'Shoulder-width grip, elbows close to the body'),
  // gambe e glutei
  'squat': ('Squat con Bilanciere', 'squat', 'Piedi larghi quanto le spalle, scendi almeno a parallelo con schiena neutra e talloni a terra', 'Feet shoulder width, at least to parallel with a neutral back and heels down'),
  'goblet': ('Goblet Squat', 'dumbbell-goblet-squat', 'Manubrio al petto, busto dritto, gomiti dentro le ginocchia in basso', 'Dumbbell at the chest, torso upright, elbows inside the knees at the bottom'),
  'legPress': ('Leg Press', 'leg-press', 'Piedi a metà pedana, scendi finché il bacino resta appoggiato', 'Feet mid-platform, go down as long as the pelvis stays on the pad'),
  'hack': ('Hack Squats Machine', 'hack-squats-machine', 'Schiena appoggiata, scendi profondo controllando la discesa', 'Back on the pad, go deep controlling the descent'),
  'bulgaro': ('Bulgarian Split Squat', 'dumbbell-bulgarian-split-squat', 'Piede dietro sulla panca, scendi dritto col busto appena in avanti. Ripetizioni per gamba', 'Rear foot on the bench, drop straight down, torso slightly forward. Reps per leg'),
  'affondi': ('Affondi', 'dumbbell-lunge', 'Passo lungo, il ginocchio dietro sfiora il pavimento. Ripetizioni per gamba', 'Long step, back knee nearly touches the floor. Reps per leg'),
  'walking': ('Dumbbell Walking Lunge', 'dumbbell-walking-lunge', 'Passi lunghi e controllati, busto dritto. Ripetizioni per gamba', 'Long, controlled steps, torso upright. Reps per leg'),
  'rdl': ('Romanian Deadlift', 'romanian-deadlift', 'Ginocchia morbide, bacino indietro finché senti i femorali, schiena neutra', 'Soft knees, hips back until the hamstrings stretch, neutral back'),
  'rdlM': ('Dumbbell Romanian Deadlift', 'dumbbell-romanian-deadlift', 'Ginocchia morbide, bacino indietro finché senti i femorali, schiena neutra', 'Soft knees, hips back until the hamstrings stretch, neutral back'),
  'legCurl': ('Leg Curl', 'seated-leg-curl', 'Bacino fermo, piega fino in fondo e torna piano', 'Hips still, curl all the way and return slowly'),
  'legExt': ('Leg Extension', 'leg-extension', 'Ginocchio in linea col perno, 1 secondo di pausa in alto', 'Knee aligned with the pivot, 1-second pause at the top'),
  'hip': ('Hip Thrust', 'barbell-hip-thrusts', 'Scapole sulla panca e mento basso, spingi coi talloni fino ad allineare busto e cosce', 'Shoulder blades on the bench, chin tucked, drive through the heels until torso and thighs line up'),
  'hipMacchina': ('Hip Thrust Machine', 'hip-thrust-machine', 'Spingi coi talloni e stringi i glutei in alto per 1 secondo', 'Drive through the heels and squeeze the glutes at the top for 1 second'),
  'calf': ('Calf Raises', 'standing-calf-raise', 'Pausa in basso in allungamento e in alto in contrazione', 'Pause in the bottom stretch and in the top squeeze'),
  'calfSeduto': ('Lever Seated Calf Raise', 'lever-seated-calf-raise', 'Movimento completo, niente rimbalzi', 'Full range, no bouncing'),
  'abductor': ('Hip Abductor', 'hip-abduction-machine', 'Busto un po\' in avanti per lavorare di più i glutei', 'Lean slightly forward to hit the glutes more'),
  'kickback': ('Glute Kickback', 'glute-kickback-machine', 'Spingi indietro col tallone senza inarcare la schiena. Ripetizioni per gamba', 'Push back through the heel without arching the back. Reps per leg'),
  'pullThrough': ('Cable Pull Through', 'cable-pull-through', 'Piegati portando il bacino indietro, chiudi stringendo i glutei', 'Hinge at the hips, finish by squeezing the glutes'),
  'stepUp': ('Step Up', 'step_up', 'Spingi con la gamba sul rialzo, non aiutarti con quella a terra. Ripetizioni per gamba', 'Drive with the leg on the box, don\'t push off the floor leg. Reps per leg'),
  // core
  'plank': ('Plank', 'plank', 'Corpo in linea, glutei e addome contratti. I numeri sono secondi', 'Body in a straight line, glutes and abs tight. Numbers are seconds'),
  'plankLat': ('Plank Laterale', 'plank_laterale', 'Fianchi alti e corpo in linea. Secondi per lato', 'Hips high, body straight. Seconds per side'),
  'crunch': ('Crunch', 'crunch', 'Stacca solo le scapole, espira salendo', 'Lift only the shoulder blades, exhale on the way up'),
  'crunchCavo': ('Kneeling Cable Crunch', 'kneeling-cable-crunch', 'Arrotola il busto portando i gomiti alle cosce, anche ferme', 'Curl the torso bringing the elbows to the thighs, hips still'),
  'legRaise': ('Leg Raise', 'hanging-leg-raises', 'Niente slancio, porta su il bacino e non solo le gambe', 'No swinging, curl the pelvis up, not just the legs'),
  'kneeRaise': ('Hanging Knee Raises', 'hanging-knee-raises', 'Ginocchia al petto senza dondolare', 'Knees to the chest without swinging'),
  'deadBug': ('Dead Bug', 'dead-bug', 'Zona lombare sempre schiacciata a terra. Ripetizioni per lato', 'Lower back always pressed into the floor. Reps per side'),
  'pallof': ('Pallof Press', 'cable-half-kneeling-pallof-press', 'Spingi le mani avanti e resisti alla rotazione. Ripetizioni per lato', 'Press the hands out and resist the rotation. Reps per side'),
  'abWheel': ('Ab Wheel Rollout', 'ab-wheel-rollout', 'Vai avanti solo finché la schiena resta neutra', 'Roll out only as far as the back stays neutral'),
};

const _timed = {'plank', 'plankLat'};

// Ruolo -> per livello: serie, ripetizioni, recupero, nota it, nota en.
// H fondamentale, C multiarticolare, I isolamento, K core.
// Serie, reps di partenza (fondo del range), recupero, nota. Stessa regola dei
// suggerimenti dell'app: reps in più riproposte, a partenza+2 aumenta il peso.
const _rx = <String, List<(int, List<int>, int, String, String)>>{
  'H': [
    (3, [8, 8, 8], 120, 'Range 8-10, 2-3 ripetizioni in riserva. Parti da 8 e aggiungi ripetizioni: a 10 su tutte le serie aumenta il peso e riparti da 8', 'Range 8-10, 2-3 reps in reserve. Start at 8 and add reps: at 10 on every set add weight and go back to 8'),
    (4, [6, 6, 6, 6], 150, 'Range 6-8, 1-2 ripetizioni in riserva. A 8 su tutte le serie aumenta di 2,5-5 kg e riparti da 6', 'Range 6-8, 1-2 reps in reserve. At 8 on every set add 2.5-5 kg and go back to 6'),
    (4, [4, 6, 6, 6], 180, 'Prima serie pesante da 4-6 a una ripetizione dal cedimento, poi 3 serie da 6-8 con il 10% in meno. In cima al range aumenta il peso', 'First set heavy for 4-6, one rep short of failure, then 3 sets of 6-8 with 10% less. At the top of the range add weight'),
  ],
  'C': [
    (3, [10, 10, 10], 90, 'Range 10-12, 2 ripetizioni in riserva. A 12 su tutte le serie aumenta il peso e riparti da 10', 'Range 10-12, 2 reps in reserve. At 12 on every set add weight and go back to 10'),
    (3, [8, 8, 8], 120, 'Range 8-10, 1-2 ripetizioni in riserva. Prima aggiungi ripetizioni fino a 10, poi il peso', 'Range 8-10, 1-2 reps in reserve. Add reps up to 10 first, then weight'),
    (4, [8, 8, 8, 8], 120, 'Range 8-10, una ripetizione in riserva; l\'ultima serie fino al cedimento tecnico', 'Range 8-10, one rep in reserve; last set to technical failure'),
  ],
  'I': [
    (2, [12, 12], 60, 'Range 12-14, peso leggero e 2 secondi in discesa', 'Range 12-14, light weight and 2 seconds on the way down'),
    (3, [10, 10, 10], 75, 'Range 10-12, vicino al cedimento. Cerca la contrazione, non il peso', 'Range 10-12, close to failure. Chase the squeeze, not the weight'),
    (3, [12, 12, 12], 60, 'Range 12-14 al cedimento. Ultima serie in drop set: togli il 30% e continua', 'Range 12-14 to failure. Last set as a drop set: strip 30% and keep going'),
  ],
  'K': [
    (3, [12, 12, 12], 45, '', ''),
    (3, [15, 15, 15], 45, '', ''),
    (3, [15, 15, 15], 45, 'Quando 17 diventano facili aggiungi un carico', 'When 17 gets easy, add load'),
  ],
};
const _timedSecs = [30, 45, 60];

// Giornata: nome ("italiano / english"), parti del corpo, slot (ruolo, esercizio
// per principiante, intermedio, avanzato; null = non previsto a quel livello).
typedef _Slot = (String, String?, String?, String?);
const _days = <String, (String, List<String>, List<_Slot>)>{
  'fbA': ('Full Body A', ['full_body'], [
    ('H', 'legPress', 'squat', 'squat'),
    ('C', 'chestPress', 'panca', 'panca'),
    ('C', 'lat', 'lat', 'trazioni'),
    ('I', 'legCurl', 'legCurl', 'legCurl'),
    ('I', 'alzLat', 'alzLat', 'alzLat'),
    ('K', 'plank', 'plank', 'abWheel'),
  ]),
  'fbB': ('Full Body B', ['full_body'], [
    ('H', 'goblet', 'rdl', 'stacco'),
    ('C', 'inclPress', 'pancaInclM', 'pancaInclM'),
    ('C', 'pulley', 'rematoreM', 'rematore'),
    ('C', 'hipMacchina', 'affondi', 'bulgaro'),
    ('I', 'face', 'face', 'face'),
    ('I', null, 'curlM', 'curl'),
    ('K', 'crunch', 'crunchCavo', 'legRaise'),
  ]),
  'fbC': ('Full Body C', ['full_body'], [
    ('H', 'legPress', 'hack', 'squat'),
    ('C', 'manubri', 'manubri', 'dip'),
    ('C', 'latStretta', 'latStretta', 'trazioni'),
    ('C', 'rdlM', 'hip', 'hip'),
    ('I', 'postMacchina', 'alzLatCavo', 'alzLatCavo'),
    ('I', null, 'pushdown', 'pushdown'),
    ('K', 'deadBug', 'pallof', 'pallof'),
  ]),
  'upA': ('Upper A', ['petto', 'dorso', 'spalle', 'braccia'], [
    ('H', 'chestPress', 'panca', 'panca'),
    ('C', 'lat', 'rematore', 'rematore'),
    ('C', 'spalleMacchina', 'spalleM', 'lento'),
    ('C', 'pulley', 'lat', 'trazioni'),
    ('I', 'alzLat', 'alzLat', 'alzLat'),
    ('I', 'curlM', 'curl', 'curl'),
    ('I', 'pushdown', 'pushdown', 'french'),
  ]),
  'upB': ('Upper B', ['petto', 'dorso', 'spalle', 'braccia'], [
    ('H', 'inclPress', 'pancaInclM', 'pancaIncl'),
    ('C', 'rowMachine', 'pulley', 'tbar'),
    ('C', 'peck', 'croci', 'dip'),
    ('C', 'latStretta', 'latStretta', 'latStretta'),
    ('I', 'face', 'face', 'postMacchina'),
    ('I', 'hammer', 'curlIncl', 'curlIncl'),
    ('I', 'overhead', 'overhead', 'overhead'),
  ]),
  'loA': ('Lower A', ['gambe', 'glutei'], [
    ('H', 'legPress', 'squat', 'squat'),
    ('C', 'rdlM', 'rdl', 'rdl'),
    ('C', 'affondi', 'bulgaro', 'bulgaro'),
    ('I', 'legExt', 'legExt', 'legExt'),
    ('I', 'legCurl', 'legCurl', 'legCurl'),
    ('I', 'calf', 'calf', 'calf'),
    ('K', 'plank', 'crunchCavo', 'abWheel'),
  ]),
  'loB': ('Lower B', ['gambe', 'glutei'], [
    ('H', 'goblet', 'stacco', 'stacco'),
    ('C', 'legPress', 'hack', 'hack'),
    ('C', 'hipMacchina', 'hip', 'hip'),
    ('C', null, 'walking', 'walking'),
    ('I', 'legCurl', 'legCurl', 'legCurl'),
    ('I', 'calfSeduto', 'calfSeduto', 'calfSeduto'),
    ('K', 'kneeRaise', 'legRaise', 'legRaise'),
  ]),
  'push': ('Spinta / Push', ['petto', 'spalle', 'braccia'], [
    ('H', 'chestPress', 'panca', 'panca'),
    ('C', 'spalleMacchina', 'spalleM', 'lento'),
    ('C', 'inclPress', 'pancaInclM', 'pancaInclM'),
    ('I', 'peck', 'croci', 'croci'),
    ('I', 'alzLat', 'alzLat', 'alzLatCavo'),
    ('I', 'pushdown', 'pushdown', 'pushdown'),
    ('I', null, 'overhead', 'french'),
  ]),
  'pull': ('Tirata / Pull', ['dorso', 'braccia'], [
    ('H', 'lat', 'rematore', 'trazioni'),
    ('C', 'pulley', 'lat', 'rematore'),
    ('C', 'rowMachine', 'rematoreM', 'tbar'),
    ('I', 'pullover', 'pullover', 'pullover'),
    ('I', 'postMacchina', 'face', 'face'),
    ('I', 'curlM', 'curl', 'curl'),
    ('I', null, 'hammer', 'curlIncl'),
  ]),
  'legs': ('Gambe / Legs', ['gambe', 'glutei'], [
    ('H', 'legPress', 'squat', 'squat'),
    ('C', 'rdlM', 'rdl', 'rdl'),
    ('C', null, 'legPress', 'hack'),
    ('C', 'hipMacchina', 'bulgaro', 'walking'),
    ('I', 'legExt', 'legExt', 'legExt'),
    ('I', 'legCurl', 'legCurl', 'legCurl'),
    ('I', 'calf', 'calf', 'calf'),
    ('K', 'plank', 'crunchCavo', 'legRaise'),
  ]),
  'pettoTri': ('Petto e tricipiti / Chest & triceps', ['petto', 'braccia'], [
    ('H', 'chestPress', 'panca', 'panca'),
    ('C', 'inclPress', 'pancaInclM', 'pancaInclM'),
    ('C', null, 'dip', 'dip'),
    ('I', 'peck', 'croci', 'croci'),
    ('I', 'pushdown', 'pushdown', 'pushdown'),
    ('I', 'overhead', 'french', 'french'),
  ]),
  'dorsoBi': ('Dorso e bicipiti / Back & biceps', ['dorso', 'braccia'], [
    ('H', 'lat', 'rematore', 'trazioni'),
    ('C', 'pulley', 'lat', 'rematore'),
    ('C', 'rowMachine', 'rematoreM', 'tbar'),
    ('I', 'pullover', 'pullover', 'pullover'),
    ('I', 'curlM', 'curl', 'curl'),
    ('I', 'hammer', 'hammer', 'curlIncl'),
    ('I', null, null, 'scott'),
  ]),
  'spalleCore': ('Spalle e addome / Shoulders & abs', ['spalle', 'core'], [
    ('H', 'spalleMacchina', 'spalleM', 'lento'),
    ('C', null, 'arnold', 'spalleM'),
    ('I', 'alzLat', 'alzLat', 'alzLat'),
    ('I', 'alzLatMacchina', 'alzLatCavo', 'alzLatMacchina'),
    ('I', 'postMacchina', 'face', 'face'),
    ('I', null, 'shrug', 'shrug'),
    ('K', 'crunch', 'crunchCavo', 'abWheel'),
    ('K', 'plank', 'legRaise', 'legRaise'),
  ]),
  'petto': ('Petto / Chest', ['petto'], [
    ('H', 'chestPress', 'panca', 'panca'),
    ('C', 'inclPress', 'pancaInclM', 'pancaIncl'),
    ('C', 'manubri', 'dip', 'pancaInclM'),
    ('I', 'peck', 'croci', 'croci'),
    ('I', null, 'peck', 'peck'),
    ('K', 'crunch', 'crunchCavo', 'crunchCavo'),
  ]),
  'dorso': ('Dorso / Back', ['dorso'], [
    ('H', 'lat', 'rematore', 'stacco'),
    ('C', 'pulley', 'lat', 'trazioni'),
    ('C', 'rowMachine', 'rematoreM', 'rematore'),
    ('C', null, 'pulley', 'tbar'),
    ('I', 'pullover', 'pullover', 'pullover'),
    ('I', 'hyper', 'hyper', 'hyper'),
  ]),
  'spalle': ('Spalle / Shoulders', ['spalle'], [
    ('H', 'spalleMacchina', 'spalleM', 'lento'),
    ('C', null, 'arnold', 'arnold'),
    ('I', 'alzLat', 'alzLat', 'alzLat'),
    ('I', 'alzLatMacchina', 'alzLatCavo', 'alzLatCavo'),
    ('I', 'postMacchina', 'alzPost', 'postMacchina'),
    ('I', 'face', 'face', 'face'),
    ('I', null, 'shrug', 'shrug'),
  ]),
  'braccia': ('Braccia / Arms', ['braccia', 'core'], [
    ('C', null, 'pancaStretta', 'pancaStretta'),
    ('I', 'curlM', 'curl', 'curl'),
    ('I', 'pushdown', 'pushdown', 'pushdown'),
    ('I', 'hammer', 'curlIncl', 'curlIncl'),
    ('I', 'overhead', 'french', 'french'),
    ('I', 'scott', 'scott', 'scott'),
    ('I', null, null, 'overhead'),
    ('K', 'plank', 'legRaise', 'legRaise'),
  ]),
  // focus glutei (livello intermedio)
  'gluteiA': ('Glutei A / Glutes A', ['glutei', 'gambe'], [
    ('H', null, 'hip', null),
    ('C', null, 'rdl', null),
    ('C', null, 'bulgaro', null),
    ('I', null, 'abductor', null),
    ('I', null, 'kickback', null),
    ('K', null, 'plank', null),
  ]),
  'gluteiB': ('Glutei B / Glutes B', ['glutei', 'gambe'], [
    ('H', null, 'goblet', null),
    ('C', null, 'stepUp', null),
    ('C', null, 'hipMacchina', null),
    ('I', null, 'pullThrough', null),
    ('I', null, 'legCurl', null),
    ('I', null, 'abductor', null),
    ('K', null, 'plankLat', null),
  ]),
};

// immagine muscoli di ogni giorno generato (assets/muscle). ponytail: per il full body non c'è
// un'immagine intera, quindi A/B/C prendono spinta/tirata/gambe per distinguerli.
const _dayImage = {
  'fbA': 'push.png', 'fbB': 'pull.png', 'fbC': 'gambe.png',
  'upA': 'push.png', 'upB': 'pull.png', 'loA': 'gambe.png', 'loB': 'gambe.png',
  'push': 'push.png', 'pull': 'pull.png', 'legs': 'gambe.png',
  'pettoTri': 'push.png', 'dorsoBi': 'pull.png', 'spalleCore': 'spalle.png',
  'petto': 'petto.png', 'dorso': 'dorso.png', 'spalle': 'spalle.png', 'braccia': 'braccia.png',
  'gluteiA': 'glutei.png', 'gluteiB': 'glutei.png',
};

Map<String, dynamic> _buildDay(String key, int lv) {
  final (name, parts, slots) = _days[key]!;
  final exercises = <Map<String, dynamic>>[];
  for (final (role, b, i, a) in slots) {
    final k = [b, i, a][lv];
    if (k == null) continue;
    final (exName, gif, cueIt, cueEn) = _ex_[k]!;
    var (sets, reps, rest, noteIt, noteEn) = _rx[role]![lv];
    if (_timed.contains(k)) reps = List.filled(sets, _timedSecs[lv]);
    final note = [_l(cueIt, cueEn), _l(noteIt, noteEn)].where((s) => s.isNotEmpty).join('. ');
    exercises.add(_ex(exName, gif, sets, reps, rest: rest, note: '$note.'));
  }
  return _day(name, parts, _dayImage[key], exercises);
}

const _levelNames = [('Principiante', 'Beginner'), ('Intermedio', 'Intermediate'), ('Avanzato', 'Advanced')];
const _levelInfo = [
  ('Principiante: macchine e movimenti semplici, 2-3 ripetizioni in riserva. Le prime due settimane pensa alla tecnica. Poi parti dal numero di ripetizioni indicato e aggiungine: quando ne fai 2 in più su tutte le serie l\'app ti propone più peso.',
   'Beginner: machines and simple movements, 2-3 reps in reserve. Spend the first two weeks on technique, then start from the listed reps and add more: once you do 2 extra on every set the app suggests more weight.'),
  ('Intermedio: pesi liberi e range 6-12, 1-2 ripetizioni in riserva. Progressione doppia: prima aumenti le ripetizioni fino al massimo del range, poi il peso.',
   'Intermediate: free weights and 6-12 rep ranges, 1-2 reps in reserve. Double progression: first add reps up to the top of the range, then weight.'),
  ('Avanzato: top set pesante sui fondamentali, drop set sugli isolamenti. Ogni 6-8 settimane fai una settimana di scarico con metà delle serie.',
   'Advanced: heavy top set on the main lifts, drop sets on isolation work. Every 6-8 weeks take a deload week with half the sets.'),
];

// tipo -> nome, descrizione it/en, split, monofrequenza, giornate
const _types = <(String, String, String, String, String, bool, bool, List<String>)>[
  ('Full body', 'Full body', 'Tutto il corpo in ogni seduta, A e B alternate: ogni muscolo lavora 2 volte a settimana anche con poco tempo.', 'Whole body every session, A and B alternated: each muscle is trained twice a week even with little time.', 'fb2', false, false, ['fbA', 'fbB']),
  ('Full body', 'Full body', 'Tre sedute total body A, B, C a giorni alterni (es. lunedì, mercoledì, venerdì). Frequenza alta, sedute non troppo lunghe.', 'Three whole-body sessions A, B, C on alternate days (e.g. Mon, Wed, Fri). High frequency, sessions not too long.', 'fb3', false, false, ['fbA', 'fbB', 'fbC']),
  ('Upper / Lower', 'Upper / Lower', 'Una seduta per la parte alta e una per la parte bassa: ogni muscolo una volta a settimana, sedute mirate.', 'One upper-body and one lower-body session: each muscle once a week, focused sessions.', 'ul2', true, true, ['upA', 'loA']),
  ('Push / Pull / Legs', 'Push / Pull / Legs', 'Spinta (petto, spalle, tricipiti), tirata (dorso, bicipiti), gambe. Ogni muscolo una volta a settimana con più volume in quella seduta.', 'Push (chest, shoulders, triceps), pull (back, biceps), legs. Each muscle once a week with more volume in that session.', 'ppl3', true, true, ['push', 'pull', 'legs']),
  ('Upper / Lower', 'Upper / Lower', 'Due sedute parte alta e due parte bassa (A e B): ogni muscolo 2 volte a settimana, il miglior compromesso tra volume e recupero.', 'Two upper and two lower sessions (A and B): each muscle twice a week, the best balance of volume and recovery.', 'ul4', true, false, ['upA', 'loA', 'upB', 'loB']),
  ('Split', 'Split', 'Petto e tricipiti, dorso e bicipiti, gambe, spalle e addome: la monofrequenza classica, tanto volume per gruppo.', 'Chest and triceps, back and biceps, legs, shoulders and abs: the classic once-a-week split with lots of volume per group.', 'split4', true, true, ['pettoTri', 'dorsoBi', 'legs', 'spalleCore']),
  ('Upper / Lower + PPL', 'Upper / Lower + PPL', 'Upper e lower, poi spinta, tirata e gambe: ogni muscolo 2 volte a settimana con 5 sedute.', 'Upper and lower, then push, pull and legs: each muscle twice a week over 5 sessions.', 'ulppl5', true, false, ['upA', 'loA', 'push', 'pull', 'legs']),
  ('Split', 'Split', 'Un gruppo al giorno: petto, dorso, gambe, spalle, braccia. Monofrequenza con il massimo volume per seduta.', 'One muscle group a day: chest, back, legs, shoulders, arms. Once a week with maximum volume per session.', 'split5', true, true, ['petto', 'dorso', 'legs', 'spalle', 'braccia']),
];

Map<String, dynamic> _tpl(int lv, String nameIt, String nameEn, String descIt, String descEn,
        String id, bool split, bool mono, List<String> dayKeys) =>
    {
      'id': '$id-$lv',
      'name': '${_l(nameIt, nameEn)} ${dayKeys.length}${_l('gg', 'd')}',
      'desc': _l(descIt, descEn),
      'info': lv < 0 ? '' : _l(_levelInfo[lv].$1, _levelInfo[lv].$2),
      'level': lv,
      'levelName': lv < 0 ? '' : _l(_levelNames[lv].$1, _levelNames[lv].$2),
      'split': split,
      'mono': mono,
      'days': [for (final k in dayKeys) _buildDay(k, lv)],
    };

/// Getter: testi nella lingua corrente al momento dell'apertura.
List<Map<String, dynamic>> get kWorkoutTemplates => [
      for (int lv = 0; lv < 3; lv++)
        for (final t in _types) _tpl(lv, t.$1, t.$2, t.$3, t.$4, t.$5, t.$6, t.$7, t.$8),
      _tpl(1, 'Focus glutei', 'Glute focus', 'Glutei e femorali 2 volte a settimana, con una seduta di parte alta in mezzo.', 'Glutes and hamstrings twice a week, with an upper-body session in between.', 'glutei3', true, false, ['gluteiA', 'upA', 'gluteiB']),
      _tpl(1, 'Focus glutei', 'Glute focus', 'Due sedute glutei e due di parte alta: massimo lavoro sui glutei mantenendo il resto del corpo allenato.', 'Two glute sessions and two upper-body sessions: maximum glute work while keeping the rest trained.', 'glutei4', true, false, ['gluteiA', 'upA', 'gluteiB', 'upB']),
      _gianmarco(),
    ];

// Scheda personale (import .workout), lasciata com'era.
Map<String, dynamic> _gianmarco() => {
      'id': 'gianmarco',
      'name': 'Scheda Gianmarco',
      'desc': _l('Split personale petto, dorso, gambe, spalle, braccia.', 'Personal split: chest, back, legs, shoulders, arms.'),
      'info': '',
      'level': 2,
      'levelName': _l('Avanzato', 'Advanced'),
      'split': true,
      'mono': true,
      'days': [
        _day('Petto', ['petto'], 'petto.png', [
          _ex('Smith Machine Bench Press', 'smith-machine-bench-press', 4, [8, 8, 8, 8], note: 'Utilizzare Multipower'),
          _ex('High Cable Crossover', 'high-cable-crossover', 4, [8, 8, 8, 8]),
          _ex('Distensioni manubri', 'dumbbell-press', 4, [8, 8, 8, 8]),
          _ex('Pectoral machine', 'pec-deck-fly', 4, [8, 8, 8, 8]),
        ]),
        _day('Dorso', ['dorso'], 'dorso.png', [
          _ex('Lat machine convergente', 'lat-pulldown', 4, [8, 8, 8, 8]),
          _ex('Row machine', 'seated-row-machine', 4, [8, 8, 8, 8]),
          _ex('Pulley', 'seated-cable-row', 4, [8, 8, 8, 8]),
          _ex('Cable Straight Arm Pulldown', 'cable-straight-arm-pulldown', 4, [10, 10, 10, 10]),
        ]),
        _day('Gambe', ['gambe'], 'gambe.png', [
          _ex('Belt squat', 'belt-squat', 8, [8, 8, 8, 8, 8, 8, 8, 8]),
          _ex('Leg extension', 'leg-extension', 3, [15, 12, 10]),
          _ex('Leg Curl Seduto', 'seated-leg-curl', 4, [8, 8, 8, 8]),
          _ex('Leg Curl', 'leg-curl', 4, [8, 8, 8, 8]),
        ]),
        _day('Spalle', ['spalle'], 'spalle.png', [
          _ex('Shoulder Press Macchina', 'lever-shoulder-press', 4, [8, 8, 8, 8]),
          _ex('Alzate frontali', 'dumbbell-front-raise', 3, [10, 10, 10], rest: 60),
          _ex('Lateral Raise Machine', 'lateral-raise-machine', 8, [12, 10, 12, 10, 12, 10, 12, 10], rest: 60),
          _ex('Alzate laterali', 'dumbbell-lateral-raise', 4, [10, 8, 12, 10], rest: 60),
          _ex('Alzate Posteriori', 'bent-over-lateral-raise', 4, [12, 10, 10, 8], rest: 60),
        ]),
        _day('Braccia', ['braccia'], 'braccia.png', [
          _ex('Biceps machine', 'lever-preacher-curl', 5, [8, 8, 8, 8, 8], rest: 60),
          _ex('Curl cavi dal basso', 'cable-two-arm-curl-on-incline-bench', 5, [8, 8, 8, 8, 8], rest: 60),
          _ex('Curl hammer', 'cable-rope-hammer-curl', 5, [8, 8, 8, 8, 8], rest: 60),
          _ex('Push down cavo', 'one-arm-reverse-push-down', 5, [8, 8, 8, 8, 8], rest: 60),
          _ex('Push down corda', 'rope-pushdown', 5, [8, 8, 8, 8, 8], rest: 60),
          _ex('Spaccacranio', 'seated-one-arm-dumbbell-triceps-extension', 5, [8, 8, 8, 8, 8], rest: 60),
        ]),
      ],
    };
