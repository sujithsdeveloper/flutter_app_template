import 'package:flutter/foundation.dart';

/// Supported in-app languages. The app ships for field teams across Kerala,
/// so Malayalam sits alongside English as a first-class language.
enum AppLanguage { english, malayalam }

/// A tiny, dependency-free language controller.
///
/// A full ARB/intl setup is overkill for the current surface area, but the UI
/// must still flip between Malayalam and English live. This [ValueNotifier]
/// lets any widget rebuild on language change via [ValueListenableBuilder].
class LanguageController {
  LanguageController._();

  static final ValueNotifier<AppLanguage> language = ValueNotifier<AppLanguage>(
    AppLanguage.english,
  );

  static void toggle() {
    language.value = language.value == AppLanguage.english
        ? AppLanguage.malayalam
        : AppLanguage.english;
  }

  /// Short label shown on the language switch (the *other* language to switch
  /// into, so the affordance reads as an action).
  static String switchLabel(AppLanguage current) =>
      current == AppLanguage.english ? 'മലയാളം' : 'English';
}

/// Resolved string table for a given [AppLanguage].
///
/// Malayalam strings are kept deliberately concise so they fit the same layout
/// slots as English without truncation.
class AppText {
  const AppText(this.lang);

  final AppLanguage lang;

  bool get isMl => lang == AppLanguage.malayalam;

  String _t(String en, String ml) => isMl ? ml : en;

  // Header
  String greeting(int hour) {
    if (hour < 12) return _t('Good morning', 'സുപ്രഭാതം');
    if (hour < 17) return _t('Good afternoon', 'ഉച്ച വണക്കം');
    return _t('Good evening', 'ശുഭ സന്ധ്യ');
  }

  String get volunteerLabel => _t('Volunteer', 'വോളണ്ടിയർ');
  String get adminBracket => _t('(admin)', '(അഡ്മിൻ)');
  String get roleFieldVolunteer => volunteerLabel;

  // Sync banner
  String get syncOffline => _t('Offline', 'ഓഫ്‌ലൈൻ');
  String get syncSyncing => _t('Syncing…', 'സിങ്ക് ചെയ്യുന്നു…');
  String get syncSynced => _t('All data synced', 'എല്ലാം സിങ്ക് ആയി');
  String pendingRecords(int n) =>
      _t('$n records waiting to upload', '$n റെക്കോർഡുകൾ അപ്‌ലോഡ് ബാക്കി');
  String get syncingNow =>
      _t('Uploading field data…', 'ഫീൽഡ് ഡാറ്റ അപ്‌ലോഡ് ചെയ്യുന്നു…');
  String get allSafe =>
      _t('Everything saved on device', 'എല്ലാം ഡിവൈസിൽ സേവ് ആയി');
  String get syncNow => _t('Sync now', 'ഇപ്പോൾ സിങ്ക്');
  String lastSynced(String t) => _t('Last sync $t', 'അവസാന സിങ്ക് $t');

  // Today's field work hero
  String get todayFieldWork =>
      _t('Today\'s field work', 'ഇന്നത്തെ ഫീൽഡ് ജോലി');
  String get todayFieldWorkSub => _t(
    'Stay on top of your plantation activities',
    'നിങ്ങളുടെ നടീൽ പ്രവർത്തനങ്ങൾ ട്രാക്ക് ചെയ്യുക',
  );
  String get viewAllTasks =>
      _t('View all tasks', 'എല്ലാ ടാസ്‌കുകൾ കാണുക');
  String get planting => _t('Planting', 'നടീൽ');
  String assignedToWorker(String name) =>
      _t('Assigned to $name', '$name ഏൽപ്പിച്ചു');
  String treesStat(int n) => _t('Trees: $n', 'മരങ്ങൾ: $n');
  String areaStat(double ha) =>
      _t('Area: $ha ha', 'വിസ്തീർണ്ണം: $ha ha');
  String todayAt(String time) => _t('Today, $time', 'ഇന്ന്, $time');
  String get taskStatusPending => _t('Pending', 'ബാക്കി');

  // Operational overview
  String get overviewTitle => _t('Operational overview', 'പ്രവർത്തന അവലോകനം');
  String get statTreesToday => _t('Registered today', 'ഇന്ന് രജിസ്റ്റർ ചെയ്തവ');
  String get statInspections => _t('Inspections due', 'ബാക്കിയുള്ള പരിശോധനകൾ');
  String get statPlots => _t('Plots assigned', 'നൽകിയ പ്ലോട്ടുകൾ');
  String get statPendingSync => _t('Pending sync', 'സിങ്ക് ബാക്കി');

  // Quick actions
  String get quickActions => _t('Quick actions', 'പെട്ടെന്നുള്ള പ്രവർത്തനങ്ങൾ');
  String get registerTree =>
      _t('Register new tree', 'പുതിയ മരം രജിസ്റ്റർ ചെയ്യുക');
  String get registerTreeSub =>
      _t('Auto-captures GPS & photo', 'GPS & ഫോട്ടോ സ്വയം എടുക്കും');
  String get generateQr => _t('Generate QR', 'QR കോഡ് ഉണ്ടാക്കുക');
  String get generateQrSub =>
      _t('Tag a tree or plot', 'മരം/പ്ലോട്ട് ടാഗ് ചെയ്യുക');
  String get inspectTree => _t('Inspect tree', 'മരം പരിശോധിക്കുക');
  String get inspectTreeSub =>
      _t('Update GBH & survival', 'GBH & അതിജീവനം അപ്ഡേറ്റ്');

  // Plots / assignments
  String get myPlots => _t('My plots', 'എന്റെ പ്ലോട്ടുകൾ');
  String get viewAll => _t('View all', 'എല്ലാം കാണുക');
  String treesCount(int n) => _t('$n trees', '$n മരങ്ങൾ');
  String get statusHealthy => _t('Healthy', 'ആരോഗ്യകരം');
  String get statusNeedsCheck => _t('Needs check', 'പരിശോധന വേണം');
  String get statusInspectionDue => _t('Inspection due', 'പരിശോധന സമയം');

  // Bottom navigation
  String get navHome => _t('Home', 'ഹോം');
  String get navPlots => _t('Plots', 'പ്ലോട്ടുകൾ');
  String get navWorkers => _t('Volunteers', 'വോളണ്ടിയർമാർ');
  String get navRegister => _t('Register', 'രജിസ്റ്റർ');
  String get navSync => _t('Sync', 'സിങ്ക്');

  // Auth — role selection
  String get chooseRole =>
      _t('Choose your role', 'നിങ്ങളുടെ റോൾ തിരഞ്ഞെടുക്കുക');
  String get roleVolunteer => volunteerLabel;
  String get roleWorker => roleFieldVolunteer;
  String get roleVolunteerDesc => _t(
    'Manages plots, volunteers and planting tasks',
    'പ്ലോട്ടുകൾ, വോളണ്ടിയർമാർ, ടാസ്‌കുകൾ നിരീക്ഷിക്കുന്നു',
  );
  String get roleWorkerDesc => _t(
    'Assigned planting tasks by a volunteer (admin)',
    'വോളണ്ടിയർ (അഡ്മിൻ) ഏൽപ്പിക്കുന്ന നടീൽ ടാസ്‌കുകൾ ചെയ്യുന്നു',
  );
  String get continueAsVolunteer =>
      _t('Continue as volunteer (admin)', 'വോളണ്ടിയർ (അഡ്മിൻ) ആയി തുടരുക');
  String get continueAsWorker =>
      _t('Continue as Volunteer', 'വോളണ്ടിയർ ആയി തുടരുക');

  // Auth — volunteer (admin) login
  String get volunteerLogin => _t('Login', 'ലോഗിൻ');
  String get emailLabel => _t('Email address', 'ഇ-മെയിൽ വിലാസം');
  String get emailHint => _t('volunteer@omyearth.in', 'volunteer@omyearth.in');
  String get passwordLabel => _t('Password', 'പാസ്‌വേഡ്');
  String get passwordHint => _t('Enter your password', 'പാസ്‌വേഡ് നൽകുക');
  String get loginButton => _t('Login', 'ലോഗിൻ');
  String get invalidEmail => _t('Enter a valid email', 'ശരിയായ ഇ-മെയിൽ നൽകുക');
  String get passwordRequired =>
      _t('Password is required', 'പാസ്‌വേഡ് ആവശ്യമാണ്');
  String get loginFailed => _t('Login failed', 'ലോഗിൻ പരാജയപ്പെട്ടു');
  String get demoHint => _t(
    'Demo: volunteer@omyearth.in / OmyVol@2026',
    'ഡെമോ: volunteer@omyearth.in / OmyVol@2026',
  );

  // Auth — field volunteer login
  String get workerLogin => _t('Volunteer Login', 'വോളണ്ടിയർ ലോഗിൻ');
  String get phoneLabel => _t('Phone number', 'ഫോൺ നമ്പർ');
  String get phoneHint => _t('e.g. 97461 23456', 'ഉദാ. 97461 23456');
  String get volunteerCodeLabel =>
      _t('Volunteer (admin) code', 'വോളണ്ടിയർ (അഡ്മിൻ) കോഡ്');
  String get volunteerCodeHint => _t('e.g. OMY-2026', 'ഉദാ. OMY-2026');
  String get phoneRequired =>
      _t('Phone number is required', 'ഫോൺ നമ്പർ ആവശ്യമാണ്');
  String get codeRequired => _t(
    'Volunteer (admin) code is required',
    'വോളണ്ടിയർ (അഡ്മിൻ) കോഡ് ആവശ്യമാണ്',
  );
  String get workerLoginHint => _t(
    'Ask your volunteer (admin) for the access code',
    'ആക്‌സസ് കോഡിനായി നിങ്ങളുടെ വോളണ്ടിയർ (അഡ്മിൻ)യോട് ചോദിക്കുക',
  );
  String get demoWorkerHint =>
      _t('Demo: 97461 23456 / OMY-2026', 'ഡെമോ: 97461 23456 / OMY-2026');

  // Auth — common
  String get logout => _t('Logout', 'ലോഗൗട്ട്');
  String get logoutConfirm =>
      _t('Log out of the app?', 'ആപ്പിൽ നിന്ന് ലോഗൗട്ട് ചെയ്യണോ?');
  String get logoutConfirmYes => _t('Log out', 'ലോഗൗട്ട്');
  String get cancel => _t('Cancel', 'റദ്ദാക്കുക');
  String get backToRoleSelection => _t('Switch role', 'റോൾ മാറ്റുക');

  // Worker home
  String get myTasks => _t('My Tasks', 'എന്റെ ടാസ്‌കുകൾ');
  String get myTasksToday => _t('My tasks today', 'ഇന്നത്തെ ടാസ്‌കുകൾ');
  String get tasksAssigned => _t('Tasks assigned', 'ഏൽപ്പിച്ച ടാസ്‌കുകൾ');
  String get noTasksAssigned => _t(
    'No tasks assigned to you yet',
    'ഇതുവരെ ഒരു ടാസ്‌കും ഏൽപ്പിക്കപ്പെട്ടിട്ടില്ല',
  );
  String get hiGreeting => _t('Hi', 'ഹലോ');

  // Worker: task update
  String get updateTask => _t('Update Task', 'ടാസ്‌ക് അപ്‌ഡേറ്റ് ചെയ്യുക');
  String get markAsPlanted =>
      _t('Mark as Planted', 'നട്ടതായി അടയാളപ്പെടുത്തുക');
  String get cantPlant => _t("Can't Plant", 'നടാൻ കഴിയില്ല');
  String get captureGps => _t('Capture GPS', 'GPS ക്യാപ്ചർ ചെയ്യുക');
  String get retryGps => _t('Retry GPS', 'GPS വീണ്ടും ശ്രമിക്കുക');
  String get gpsLocation => _t('GPS Location', 'GPS സ്ഥലം');
  String get gpsNotCaptured =>
      _t('GPS not captured yet', 'GPS ഇതുവരെ ക്യാപ്ചർ ചെയ്തിട്ടില്ല');
  String get gpsRequired =>
      _t('Please capture GPS location first', 'ആദ്യം GPS ക്യാപ്ചർ ചെയ്യുക');
  String get takePhoto => _t('Take Photo', 'ഫോട്ടോ എടുക്കുക');
  String get fromGallery => _t('From Gallery', 'ഗ്യാലറിയിൽ നിന്ന്');
  String get photoOptional => _t('Photo (optional)', 'ഫോട്ടോ (ഐച്ഛിക)');
  String get workerNotesLabel => _t('Notes', 'കുറിപ്പ്');
  String get workerNotesHint =>
      _t('Add notes about the planting…', 'നടീൽ കുറിപ്പ് ചേർക്കുക…');
  String get plantingDetails => _t('Planting Details', 'നടീൽ വിവരങ്ങൾ');
  String get cantPlantReason => _t('Reason', 'കാരണം');
  String get cantPlantReasonHint =>
      _t('Why can\'t you plant here?', 'ഇവിടെ നടാൻ കഴിയാത്തത് എന്തുകൊണ്ട്?');
  String get reasonRequired => _t('Please enter a reason', 'ഒരു കാരണം നൽകുക');
  String get taskUpdated =>
      _t('Task updated successfully', 'ടാസ്‌ക് വിജയകരമായി അപ്‌ഡേറ്റ് ചെയ്തു');
  String get taskCancelled => _t(
    'Task marked as cancelled',
    'ടാസ്‌ക് റദ്ദാക്കപ്പെട്ടതായി അടയാളപ്പെടുത്തി',
  );
  String get taskInfo => _t('Task Info', 'ടാസ്‌ക് വിവരം');
  String get adminNotesLabel => _t('Admin Notes', 'അഡ്മിൻ കുറിപ്പ്');
  String get gettingLocation =>
      _t('Getting location…', 'സ്ഥലം ലഭ്യമാക്കുന്നു…');

  // Worker: my trees + growth stages
  String get navMyTrees => _t('My Trees', 'എന്റെ മരങ്ങൾ');
  String get myTrees => _t('My Trees', 'എന്റെ മരങ്ങൾ');
  String get noTreesPlanted =>
      _t('No trees planted yet', 'ഇതുവരെ ഒരു മരവും നട്ടിട്ടില്ല');
  String get noTreesDesc => _t(
    'Trees you plant will appear here',
    'നിങ്ങൾ നടുന്ന മരങ്ങൾ ഇവിടെ കാണിക്കും',
  );
  String get daysGrowing => _t('days growing', 'ദിവസം വളരുന്നു');
  String get plantedOn => _t('Planted', 'നട്ടത്');
  String get growthHistory => _t('Growth History', 'വളർച്ചാ ചരിത്രം');
  String get treeUpdates => _t('Tree updates', 'മരം അപ്‌ഡേറ്റുകൾ');
  String get noTreeUpdates =>
      _t('No tree updates yet', 'ഇതുവരെ മരം അപ്‌ഡേറ്റുകൾ ഇല്ല');
  String heightLabel(double cm) =>
      _t('${cm.toStringAsFixed(0)} cm', '${cm.toStringAsFixed(0)} cm');
  String get addGrowthUpdate => _t('Add Update', 'അപ്‌ഡേറ്റ് ചേർക്കുക');
  String get noUpdatesYet =>
      _t('No updates recorded yet', 'ഇതുവരെ അപ്‌ഡേറ്റ് ഒന്നും ഇല്ല');
  String get heightCm => _t('Height (cm)', 'ഉയരം (cm)');
  String get heightHint => _t('e.g. 45', 'ഉദാ. 45');
  String get growthUpdateTitle => _t('Growth Update', 'വളർച്ചാ അപ്‌ഡേറ്റ്');
  String get selectStage => _t('Select Stage', 'ഘട്ടം തിരഞ്ഞെടുക്കുക');
  String get updateSaved => _t('Update saved', 'അപ്‌ഡേറ്റ് സേവ് ചെയ്തു');
  String get treeDetails => _t('Tree Details', 'മരം വിവരങ്ങൾ');
  String get currentStage => _t('Current Stage', 'നിലവിലെ ഘട്ടം');

  // Growth stage labels
  String get stagePlanted => _t('Planted', 'നട്ടത്');
  String get stageSprouting => _t('Sprouting', 'മൊളിക്കുന്നു');
  String get stageGrowing => _t('Growing', 'വളരുന്നു');
  String get stageEstablished => _t('Established', 'ഉറച്ചു');
  String get stageNeedsAttention => _t('Needs Attention', 'ശ്രദ്ധ വേണം');
  String get stageDead => _t('Dead', 'ചത്തു');

  // Field volunteers (managed by volunteer admin)
  String get workers => _t('Volunteers', 'വോളണ്ടിയർമാർ');
  String get addWorker => _t('Add volunteer', 'വോളണ്ടിയറെ ചേർക്കുക');
  String get editWorker => _t('Edit volunteer', 'വോളണ്ടിയറെ എഡിറ്റ് ചെയ്യുക');
  String get workerName => _t('Full name', 'പൂർണ്ണ പേര്');
  String get workerPhone => _t('Phone number', 'ഫോൺ നമ്പർ');
  String get workerNameHint => _t('e.g. Rajan P', 'ഉദാ. രാജൻ പി');
  String get workerPhoneHint => _t('e.g. 98451 23456', 'ഉദാ. 98451 23456');
  String get saveWorker => _t('Save volunteer', 'വോളണ്ടിയറെ സേവ് ചെയ്യുക');
  String get workerSaved =>
      _t('Volunteer added successfully', 'വോളണ്ടിയർ ചേർത്തു');
  String get workerUpdated =>
      _t('Volunteer updated successfully', 'വോളണ്ടിയർ അപ്‌ഡേറ്റ് ചെയ്തു');
  String get workerSaveFailed =>
      _t('Failed to add volunteer', 'വോളണ്ടിയറെ ചേർക്കാൻ കഴിഞ്ഞില്ല');
  String get workerUpdateFailed =>
      _t('Failed to update volunteer', 'വോളണ്ടിയറെ അപ്‌ഡേറ്റ് ചെയ്യാൻ കഴിഞ്ഞില്ല');
  String get activeStatus => _t('Active status', 'സജീവ നില');
  String get edit => _t('Edit', 'എഡിറ്റ്');
  String get noWorkers => _t('No volunteers yet', 'ഇതുവരെ വോളണ്ടിയർമാർ ഇല്ല');
  String get noWorkersHint => _t(
    'Tap + to add your first volunteer',
    'ആദ്യ വോളണ്ടിയറെ ചേർക്കാൻ + ടാപ്പ് ചെയ്യുക',
  );
  String get searchWorkers => _t('Search volunteers', 'വോളണ്ടിയർമാരെ തിരയുക');
  String get activeToday => _t('Active today', 'ഇന്ന് സജീവം');
  String get notActiveToday => _t('No activity today', 'ഇന്ന് ഒന്നും ഇല്ല');
  String get treesToday => _t('trees today', 'ഇന്ന് മരങ്ങൾ');
  String get totalTrees => _t('Total trees', 'ആകെ മരങ്ങൾ');
  String get workerDetail => _t('Volunteer details', 'വോളണ്ടിയർ വിവരം');
  String get deactivate => _t('Deactivate', 'നിർജ്ജീവമാക്കുക');
  String get activate => _t('Activate', 'സജീവമാക്കുക');
  String get active => _t('Active', 'സജീവം');
  String get inactive => _t('Inactive', 'നിർജ്ജീവം');
  String get joinedOn => _t('Joined', 'ചേർന്ന തീയതി');
  String get recentActivity => _t('Recent activity', 'സമീപ പ്രവർത്തനം');
  String workersCount(int n) => _t('$n volunteers', '$n വോളണ്ടിയർമാർ');
  String activeCount(int n) => _t('$n active today', 'ഇന്ന് $n സജീവം');

  // Tree tasks
  String get tasks => _t('Tasks', 'ടാസ്‌കുകൾ');
  String get navTasks => _t('Tasks', 'ടാസ്‌കുകൾ');
  String get navProfile => _t('Profile', 'പ്രൊഫൈൽ');

  // Profile screen
  String get settings => _t('Settings', 'ക്രമീകരണങ്ങൾ');
  String get appInfo => _t('App Info', 'ആപ്പ് വിവരം');
  String get language => _t('Language', 'ഭാഷ');
  String get workerAccessCode =>
      _t('Worker access code', 'വർക്കർ ആക്‌സസ് കോഡ്');
  String get workerAccessCodeHint => _t(
    'Share this code so field workers can log in',
    'ഫീൽഡ് വർക്കർമാർക്ക് ലോഗിൻ ചെയ്യാൻ ഈ കോഡ് പങ്കിടുക',
  );
  String get accessCodeCopied =>
      _t('Access code copied', 'ആക്‌സസ് കോഡ് കോപ്പി ചെയ്തു');
  String get showAccessCode => _t('Show', 'കാണിക്കുക');
  String get hideAccessCode => _t('Hide', 'മറയ്ക്കുക');
  String get pendingTasks => _t('Pending tasks', 'ബാക്കി ടാസ്‌കുകൾ');
  String get allTasks => _t('All', 'എല്ലാം');
  String get unassigned => _t('Unassigned', 'ഏൽപ്പിക്കാത്തത്');
  String get assigned => _t('Assigned', 'ഏൽപ്പിച്ചത്');
  String get planted => _t('Planted', 'നട്ടത്');
  String get assignWorker => _t('Assign to worker', 'വർക്കറെ ഏൽപ്പിക്കുക');
  String get reassign => _t('Reassign worker', 'വർക്കറെ മാറ്റുക');
  String get assignedTo => _t('Assigned to', 'ഏൽപ്പിച്ചത്');
  String get noTasksYet => _t('No planting tasks yet', 'നടീൽ ടാസ്‌കുകൾ ഒന്നുമില്ല');
  String get noTasksHint => _t(
    'When a donor sponsors a tree in your region, the planting task appears here',
    'നിങ്ങളുടെ മേഖലയിൽ ഒരു ദാതാവ് മരം സ്പോൺസർ ചെയ്താൽ നടീൽ ടാസ്‌ക് ഇവിടെ കാണും',
  );
  String get needsPlanting => _t('Needs planting', 'നടീൽ ആവശ്യമാണ്');
  String get assignWorkerHint => _t(
    'Assign a field worker to plant this sponsored tree',
    'ഈ സ്പോൺസർ മരം നടാൻ ഒരു ഫീൽഡ് വർക്കറെ ഏൽപ്പിക്കുക',
  );
  String get sponsorWantsPlanting => _t(
        'A sponsor wants this tree planted',
        'ഒരു സ്പോൺസർ ഈ മരം നടാൻ ആഗ്രഹിക്കുന്നു',
      );
  String sponsorIntentFor(String species, String region) {
    if (region.isEmpty) {
      return _t(
        'A sponsor wants to plant this $species',
        'ഒരു സ്പോൺസർ ഈ $species നടാൻ ആഗ്രഹിക്കുന്നു',
      );
    }
    return _t(
      'A sponsor wants to plant this $species in $region',
      'ഒരു സ്പോൺസർ $region-ൽ ഈ $species നടാൻ ആഗ്രഹിക്കുന്നു',
    );
  }
  String get regionLabel => _t('Region', 'മേഖല');
  String get treeIdLabel => _t('Tree ID', 'മരം ID');
  String get targetLocation => _t('Target location', 'ലക്ഷ്യ സ്ഥാനം');
  String get adminNotes => _t('Notes', 'കുറിപ്പ്');
  String get targetDate => _t('Target date', 'ലക്ഷ്യ തീയതി');
  String get taskDetail => _t('Planting task', 'നടീൽ ടാസ്‌ക്');
  String get dueLabel => _t('Due', 'കാലാവധി');
  String get locationCopied => _t('Location copied', 'സ്ഥലം കോപ്പി ചെയ്തു');
  String get selectWorker =>
      _t('Select a field worker', 'ഒരു ഫീൽഡ് വർക്കറെ തിരഞ്ഞെടുക്കുക');
  String get workerAssigned =>
      _t('Worker assigned', 'വർക്കറെ ഏൽപ്പിച്ചു');
  String get plotLabel => _t('Plot', 'പ്ലോട്ട്');
  String get treesLabel => _t('Trees', 'മരങ്ങൾ');
  String tasksCount(int n) => _t('$n tasks', '$n ടാസ്‌കുകൾ');

  // Sync banner — extended states
  String get syncNeverSynced =>
      _t('Never synced', 'ഒരിക്കലും സിങ്ക് ചെയ്തിട്ടില്ല');
  String get syncPendingUpload => _t('Upload pending', 'അപ്‌ലോഡ് ബാക്കിയുണ്ട്');
  String get syncFailed => _t('Sync failed', 'സിങ്ക് പരാജയപ്പെട്ടു');
  String get syncRetry => _t('Retry', 'വീണ്ടും ശ്രമിക്കുക');
  String failedRecords(int n) => _t('$n records failed', '$n റെക്കോർഡ് പരാജയം');

  // Dashboard stats
  String get statTrees => _t('Trees assigned', 'നൽകിയ മരങ്ങൾ');

  // Plots — add / edit
  String get addPlot => _t('Add plot', 'പ്ലോട്ട് ചേർക്കുക');
  String get editPlot => _t('Edit plot', 'പ്ലോട്ട് എഡിറ്റ് ചെയ്യുക');
  String get savePlot => _t('Save plot', 'പ്ലോട്ട് സേവ് ചെയ്യുക');
  String get plotSaved => _t('Plot added successfully', 'പ്ലോട്ട് ചേർത്തു');
  String get plotUpdated =>
      _t('Plot updated successfully', 'പ്ലോട്ട് അപ്ഡേറ്റ് ചെയ്തു');
  String get plotSaveFailed =>
      _t('Failed to add plot', 'പ്ലോട്ട് ചേർക്കാൻ കഴിഞ്ഞില്ല');
  String get plotUpdateFailed =>
      _t('Failed to update plot', 'പ്ലോട്ട് അപ്ഡേറ്റ് ചെയ്യാൻ കഴിഞ്ഞില്ല');
  String get endPlot => _t('End plot', 'പ്ലോട്ട് അവസാനിപ്പിക്കുക');
  String endPlotConfirm(String name) => _t(
        'End "$name"? It will be marked retired and removed from your list.',
        '"$name" അവസാനിപ്പിക്കണോ? ഇത് റിട്ടയർ ആക്കി ലിസ്റ്റിൽ നിന്ന് നീക്കം ചെയ്യും.',
      );
  String get plotEnded => _t('Plot ended', 'പ്ലോട്ട് അവസാനിപ്പിച്ചു');
  String get plotEndFailed =>
      _t('Failed to end plot', 'പ്ലോട്ട് അവസാനിപ്പിക്കാൻ കഴിഞ്ഞില്ല');
  String get searchPlots => _t('Search plots', 'പ്ലോട്ടുകൾ തിരയുക');
  String get allPlots => _t('All plots', 'എല്ലാ പ്ലോട്ടുകളും');
  String get plotDetails => _t('Plot details', 'പ്ലോട്ട് വിവരങ്ങൾ');
  String get plotViewOnlyHint => _t(
        'Plot changes are managed from the web admin panel.',
        'പ്ലോട്ട് മാറ്റങ്ങൾ വെബ് അഡ്മിൻ പാനലിൽ നിന്ന് നിയന്ത്രിക്കുന്നു.',
      );
  String get noPlotsHint => _t(
        'Plots are added from the web admin panel. Pull to refresh once they appear.',
        'പ്ലോട്ടുകൾ വെബ് അഡ്മിൻ പാനലിൽ നിന്ന് ചേർക്കുന്നു. അവ വന്നാൽ പുൾ ടു റിഫ്രഷ് ചെയ്യുക.',
      );
  String get plotName => _t('Plot name', 'പ്ലോട്ട് പേര്');
  String get plotNameHint =>
      _t('e.g. Plot Meppadi A', 'ഉദാ. പ്ലോട്ട് മേപ്പാടി എ');
  String get plotLocation => _t('Location', 'സ്ഥലം');
  String get plotLocationHint =>
      _t('e.g. Wayanad · Meppadi', 'ഉദാ. വയനാട് · മേപ്പാടി');
  String get plotState => _t('State', 'സംസ്ഥാനം');
  String get plotStateHint => _t('Select state', 'സംസ്ഥാനം തിരഞ്ഞെടുക്കുക');
  String get plotDistrict => _t('District', 'ജില്ല');
  String get plotDistrictHint =>
      _t('Select district', 'ജില്ല തിരഞ്ഞെടുക്കുക');
  String get plotArea => _t('Area (hectares)', 'വിസ്തീർണ്ണം (ഹെക്ടർ)');
  String get plotAreaHint => _t('e.g. 2.4', 'ഉദാ. 2.4');
  String get plotNameRequired =>
      _t('Plot name is required', 'പ്ലോട്ട് പേര് ആവശ്യമാണ്');
  String get plotLocationRequired =>
      _t('Location is required', 'സ്ഥലം ആവശ്യമാണ്');
  String get plotStateRequired =>
      _t('Please select a state', 'സംസ്ഥാനം തിരഞ്ഞെടുക്കുക');
  String get plotDistrictRequired =>
      _t('Please select a district', 'ജില്ല തിരഞ്ഞെടുക്കുക');
  String get pickOnMap => _t('Pick on map', 'മാപ്പിൽ തിരഞ്ഞെടുക്കുക');
  String get searchPlaceHint =>
      _t('Search places in India…', 'ഇന്ത്യയിലെ സ്ഥലങ്ങൾ തിരയുക…');
  String get confirmLocation =>
      _t('Confirm location', 'സ്ഥലം സ്ഥിരീകരിക്കുക');
  String get useMyLocation => _t('Use my location', 'എന്റെ സ്ഥാനം ഉപയോഗിക്കുക');
  String get mapSearchFailed =>
      _t('Place search failed. Try again.', 'സ്ഥലം തിരയൽ പരാജയപ്പെട്ടു.');
  String get tapMapToMark =>
      _t('Search or tap the map to mark the plot', 'തിരയുക അല്ലെങ്കിൽ മാപ്പിൽ ടാപ്പ് ചെയ്യുക');
  String get openMapPicker =>
      _t('Open map picker', 'മാപ്പ് പിക്കർ തുറക്കുക');
  String get changeOnMap => _t('Change on map', 'മാപ്പിൽ മാറ്റുക');
  String get selectPlots =>
      _t('Assign to plots', 'പ്ലോട്ടുകളിലേക്ക് ഏൽപ്പിക്കുക');
  String get assignedPlots => _t('Assigned plots', 'ഏൽപ്പിച്ച പ്ലോട്ടുകൾ');
  String get managePlots => _t('Manage plots', 'പ്ലോട്ടുകൾ നിയന്ത്രിക്കുക');
  String get noPlotsAssigned =>
      _t('No plots assigned yet', 'ഇതുവരെ പ്ലോട്ടുകൾ ഏൽപ്പിച്ചിട്ടില്ല');
  String get plotRemoved => _t('Plot removed', 'പ്ലോട്ട് നീക്കി');
  String get plotsUpdated => _t('Plots updated', 'പ്ലോട്ടുകൾ അപ്ഡേറ്റ് ചെയ്തു');
  String get saveChanges => _t('Save changes', 'മാറ്റങ്ങൾ സേവ് ചെയ്യുക');
  String plotsAssignedCount(int n) =>
      _t('$n plots assigned', '$n പ്ലോട്ടുകൾ ഏൽപ്പിച്ചു');

  // Empty / generic
  String get noPlots => _t('No plots yet', 'ഇതുവരെ പ്ലോട്ടുകൾ ഇല്ല');
  String get loading => _t('Loading…', 'ലോഡ് ചെയ്യുന്നു…');

  // Generic
  String get comingSoon => _t('Coming soon', 'ഉടൻ വരുന്നു');
}
