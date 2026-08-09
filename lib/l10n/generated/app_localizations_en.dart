// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LMB10';

  @override
  String get loginScreenTitle => 'Sign in';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get pinLabel => 'Vehicle PIN';

  @override
  String get pinHelper => 'Required for lock/unlock, climate, seats, etc.';

  @override
  String get rememberPinTitle => 'Remember PIN on this device';

  @override
  String get rememberPinSubtitle =>
      'Stored encrypted locally (flutter_secure_storage).';

  @override
  String get loginButton => 'Login';

  @override
  String get dashboardDefaultTitle => 'Leapmotor';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get settingsTooltip => 'Settings, logs & backups';

  @override
  String get aboutTooltip => 'About';

  @override
  String get logoutTooltip => 'Log out';

  @override
  String get tileBattery => 'Battery';

  @override
  String get tileAutonomy => 'Range';

  @override
  String get tileLock => 'Lock';

  @override
  String get lockedLabel => 'Locked';

  @override
  String get unlockedLabel => 'Unlocked';

  @override
  String get tileChargeState => 'Charge status';

  @override
  String get chargingLabel => 'Charging';

  @override
  String get notChargingLabel => 'Not charging';

  @override
  String get disconnectedLabel => 'Disconnected';

  @override
  String get tileChargeCable => 'Charge cable';

  @override
  String get connectedLabel => 'Connected';

  @override
  String get disconnectedShortLabel => 'Disconn.';

  @override
  String get tileThermalMgmt => 'Thermal mgmt';

  @override
  String get activeLabel => 'Active';

  @override
  String get normalLabel => 'Normal';

  @override
  String get tileClimate => 'Climate';

  @override
  String get onLabel => 'On';

  @override
  String get offLabel => 'Off';

  @override
  String get tileTrunk => 'Trunk';

  @override
  String get openLabel => 'Open';

  @override
  String get closedLabel => 'Closed';

  @override
  String get tileSentry => 'Sentry';

  @override
  String get activeShortLabel => 'Active';

  @override
  String get inactiveLabel => 'Inactive';

  @override
  String get controlsButton => 'Vehicle controls';

  @override
  String get guardModeButton => 'Guard Mode (experimental)';

  @override
  String get preconditioningButton => 'Preconditioning';

  @override
  String get messagesButton => 'Messages';

  @override
  String get exportButton => 'Export data (anonymized JSON)';

  @override
  String get debugButton => 'View full status (debug)';

  @override
  String get pinDialogTitle => 'Vehicle PIN';

  @override
  String get pinDialogCancel => 'Cancel';

  @override
  String get pinDialogAccept => 'Accept';

  @override
  String get noLocationData => 'No location data';

  @override
  String get controlsScreenTitle => 'Vehicle controls';

  @override
  String get sectionSentry => 'Sentry';

  @override
  String get sectionActions => 'Actions';

  @override
  String get sectionClimate => 'Climate';

  @override
  String get sectionComfort => 'Comfort';

  @override
  String get sectionSunshadeWindows => 'Sunshade and windows';

  @override
  String get sectionSpeedLimit => 'Speed limit';

  @override
  String get sectionBattery => 'Battery';

  @override
  String get sectionSeats => 'Seats';

  @override
  String get actionSentryOn => 'Sentry ON';

  @override
  String get actionSentryOff => 'Sentry OFF';

  @override
  String get actionLock => 'Lock';

  @override
  String get actionUnlock => 'Unlock';

  @override
  String get actionTrunkOpen => 'Open trunk';

  @override
  String get actionTrunkClose => 'Close trunk';

  @override
  String get actionFindCar => 'Find car';

  @override
  String get actionUnlockCharger => 'Unlock charger';

  @override
  String get actionQuickHeat => 'Quick heat';

  @override
  String get actionQuickCool => 'Quick cool';

  @override
  String get actionDefrost => 'Defrost windshield';

  @override
  String get actionAcOff => 'Turn off climate';

  @override
  String get actionSteeringHeatOn => 'Steering wheel heat ON';

  @override
  String get actionSteeringHeatOff => 'Steering wheel heat OFF';

  @override
  String get actionSunshadeOpen => 'Open sunshade';

  @override
  String get actionSunshadeClose => 'Close sunshade';

  @override
  String get actionWindowsOpen => 'Open windows';

  @override
  String get actionWindowsClose => 'Close windows';

  @override
  String get actionPreheatOn => 'Preheat ON';

  @override
  String get actionPreheatOff => 'Preheat OFF';

  @override
  String speedLimitValue(int speed) {
    return 'Limit: $speed km/h';
  }

  @override
  String get readingChargeLimit => 'Reading current charge limit...';

  @override
  String chargeLimitValue(int percent) {
    return 'Charge limit: $percent%';
  }

  @override
  String get editFullScheduleButton => 'Edit full charging schedule';

  @override
  String get seatDriverHeat => 'Driver - Heat';

  @override
  String get seatPassengerHeat => 'Passenger - Heat';

  @override
  String get seatDriverVent => 'Driver - Ventilation';

  @override
  String get seatPassengerVent => 'Passenger - Ventilation';

  @override
  String get aboutScreenTitle => 'About';

  @override
  String get appTagline => 'Unofficial app for Leapmotor';

  @override
  String get authorLabel => 'Author';

  @override
  String get licenseLabel => 'License';

  @override
  String get licenseValue => 'GNU General Public License v3.0 (GPLv3)';

  @override
  String get repoLabel => 'Repository and releases';

  @override
  String get disclaimerText =>
      'Unofficial, independent project. Not affiliated with, endorsed by, or associated with Leapmotor.';

  @override
  String get messagesScreenTitle => 'Messages';

  @override
  String get noMessages => 'No messages.';

  @override
  String get noTitlePlaceholder => '(no title)';

  @override
  String get debugScreenTitle => 'Debug: full status';

  @override
  String get saveSnapshotButton => 'Save snapshot';

  @override
  String get compareSnapshotButton => 'Compare with snapshot';

  @override
  String get guardModeScreenTitle => 'Guard Mode (experimental)';

  @override
  String get guardModeWarning =>
      'For occasional, conscious use only, not to leave the car like this daily: the window stays partly open during part of the process, which reduces the vehicle\'s physical security while the sequence lasts.';

  @override
  String get videoCmdStepTitle => 'Experimental: recorder command (cmd 290)';

  @override
  String get videoCmdDescription =>
      'We don\'t know what \"operation\" value the server expects. Try one, then use the snapshot/diff in Debug, or check the car\'s native camera settings menu to see if the switch changed state.';

  @override
  String get pendriveStepTitle => 'USB drive with recording enabled';

  @override
  String get pendriveHint =>
      'Manually check that the USB drive is inserted and recording.';

  @override
  String get ambientLightsStep => 'Turn off ambient lighting (car menu)';

  @override
  String get foldMirrorsStep => 'Fold mirrors (quick access or menu)';

  @override
  String get headlightsOffStep => 'Turn off headlights';

  @override
  String get screensOffStep => 'Turn off screens';

  @override
  String get campingModeStep => 'Camping mode (experimental, unconfirmed)';

  @override
  String get activateOn3 => 'Activate (ON3)';

  @override
  String get deactivateOn3 => 'Deactivate (ON3)';

  @override
  String get openWindowStep => 'Open driver\'s window';

  @override
  String get openWindowButton => 'Open window';

  @override
  String get exitCarHint =>
      'Exit the car now with the window open before continuing.';

  @override
  String get lockCarStep => 'Lock the car';

  @override
  String get lockButton => 'Lock';

  @override
  String get closeWindowStep => 'Close window (experimental after locking)';

  @override
  String get closeWindowRemoteButton => 'Try closing remotely';

  @override
  String get closeWindowFallbackHint =>
      'If this button errors or the window doesn\'t move while the car is locked, you\'ll need to raise it by hand from outside as in the original method.';

  @override
  String get preconditioningScreenTitle => 'Preconditioning';

  @override
  String get experimentalScheduleWarning =>
      'Experimental: the exact schedule format is inferred by symmetry with the reference source code, not 100% confirmed. Verify it by feeling whether the car actually climates at the scheduled time.';

  @override
  String get modeLabel => 'Mode';

  @override
  String get heatChip => 'Heat';

  @override
  String get coldChip => 'Cold';

  @override
  String temperatureLabel(int temp) {
    return 'Temperature: $temp°C';
  }

  @override
  String get steeringWheelHeatToggle => 'Steering wheel heating';

  @override
  String get prepareNowButton => 'Precondition now (immediate test)';

  @override
  String get scheduleSectionTitle => 'Schedule';

  @override
  String hourLabel(String time) {
    return 'Time: $time';
  }

  @override
  String get daysNoneSelectedHint => 'Days (none selected = one-time only)';

  @override
  String get addToScheduleButton => 'Add to schedule';

  @override
  String get scheduledEntriesTitle => 'Scheduled entries';

  @override
  String get noScheduledEntries => 'No scheduled entries.';

  @override
  String get onceLabel => 'Once';

  @override
  String get dayShortSun => 'Sun';

  @override
  String get dayShortMon => 'Mon';

  @override
  String get dayShortTue => 'Tue';

  @override
  String get dayShortWed => 'Wed';

  @override
  String get dayShortThu => 'Thu';

  @override
  String get dayShortFri => 'Fri';

  @override
  String get dayShortSat => 'Sat';

  @override
  String get chargeScheduleScreenTitle => 'Charging schedule';

  @override
  String get chargeScheduleExperimentalWarning =>
      'Experimental: the weekday format (cycles) is inferred from the default value already used in the simple charge limit. Verify with the debug screen (snapshot/diff) after saving.';

  @override
  String get scheduleActiveToggle => 'Charging schedule active';

  @override
  String startTimeLabel(String time) {
    return 'Start: $time';
  }

  @override
  String endTimeLabel(String time) {
    return 'End: $time';
  }

  @override
  String get weekdaysTitle => 'Days of the week';

  @override
  String get saveScheduleButton => 'Save schedule';

  @override
  String lastUpdatedSeconds(int sec) {
    return 'Updated ${sec}s ago';
  }

  @override
  String lastUpdatedMinutes(int min) {
    return 'Updated $min min ago';
  }

  @override
  String lastUpdatedSecondsShort(int sec) {
    return '${sec}s ago';
  }

  @override
  String lastUpdatedMinutesShort(int min) {
    return '$min min ago';
  }

  @override
  String rangeKmAutonomy(String km) {
    return '$km km range';
  }

  @override
  String get chargeHistoryTitle => 'Charging history';

  @override
  String get chargeHistorySubtitle =>
      'Detected by the app since installation (not provided by Leapmotor).';

  @override
  String get noChargeDetected => 'No charge detected yet.';

  @override
  String get ongoingLabel => 'ongoing';

  @override
  String get consumptionCardTitle => 'Consumption and real range';

  @override
  String collectingDataMsg(int count) {
    return 'Collecting driving data ($count points). Needs several trips with the app open.';
  }

  @override
  String get notEnoughDataMsg =>
      'Not enough driving data detected yet (only charging/parked).';

  @override
  String avgConsumptionLabel(String percent) {
    return 'Average consumption: $percent% per 100 km';
  }

  @override
  String estimatedRangeLabel(int km) {
    return 'Estimated range (based on your real consumption): $km km';
  }

  @override
  String reportedRangeLabel(int km) {
    return 'Range reported by the car: $km km';
  }

  @override
  String get worseEfficiencyMsg =>
      'Your driving uses more than the manufacturer\'s estimate.';

  @override
  String get betterEfficiencyMsg =>
      'Your driving is more efficient than the manufacturer\'s estimate.';

  @override
  String get weeklyEfficiencyTitle => 'Efficiency: this week vs last';

  @override
  String get thisWeekLabel => 'This week';

  @override
  String get lastWeekLabel => 'Last week';

  @override
  String get betterThisWeekMsg =>
      'This week you\'re using less than last week (better efficiency).';

  @override
  String get worseThisWeekMsg => 'This week you\'re using more than last week.';

  @override
  String get needBothWeeksMsg =>
      'Needs driving data from both weeks to compare.';

  @override
  String percentPer100kmFmt(String value) {
    return '$value%/100km';
  }

  @override
  String get tirePressureTitle => 'Tire pressure';

  @override
  String get tireFrontLeft => 'Front L';

  @override
  String get tireFrontRight => 'Front R';

  @override
  String get tireRearLeft => 'Rear L';

  @override
  String get tireRearRight => 'Rear R';

  @override
  String barUnit(String value) {
    return '$value bar';
  }

  @override
  String get resolvingAddress => 'Finding address...';

  @override
  String parkedNear(String address) {
    return 'Parked near $address';
  }

  @override
  String get enableLocationPermission =>
      'Enable location permission to see distance';

  @override
  String get enableGps => 'Enable GPS to see distance';

  @override
  String distanceFromCurrentPosition(String distance) {
    return '$distance from your current location';
  }

  @override
  String get couldNotResolveAddress => 'Could not resolve address';

  @override
  String get hotspotStepTitle => 'Experimental: WiFi/hotspot (cmd 140)';

  @override
  String get hotspotDescription =>
      'Not confirmed what this command does: it could be the passenger WiFi hotspot, something related to keeping the car connected to your home network, or neither. Try a variant and verify with snapshot/diff, or by checking whether your router sees the car connected after locking it.';
}
