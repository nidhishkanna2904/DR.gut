import 'package:flutter/foundation.dart';
import '../models/diet_plan.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/report_picker_service.dart';
import '../services/storage_service.dart';

enum AppStatus {
  idle,
  locating,
  loading,
  error,
  done,
}

class AppState extends ChangeNotifier {
  UserProfile? _profile;
  ReportFileResult? _selectedReport;
  DietPlan? _currentPlan;
  DietPlan? _lastSavedPlan;
  AppStatus _status = AppStatus.idle;
  String? _errorMessage;

  UserProfile? get profile => _profile;
  ReportFileResult? get selectedReport => _selectedReport;
  Uint8List? get reportBytes => _selectedReport?.bytes;
  String? get reportName => _selectedReport?.name;
  DietPlan? get currentPlan => _currentPlan;
  DietPlan? get lastSavedPlan => _lastSavedPlan;
  AppStatus get status => _status;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == AppStatus.loading;
  bool get hasSavedProfile => _profile != null && _profile!.name.isNotEmpty;
  bool get hasActivePlan => _currentPlan != null || _lastSavedPlan != null;

  /// Loads saved profile and previous diet plan from local storage on startup.
  Future<void> initialize() async {
    _profile = await StorageService.loadProfile();
    _lastSavedPlan = await StorageService.loadLastPlan();
    if (_profile != null && _profile!.locationName.startsWith('Lat:')) {
      _profile = _profile!.copyWith(
        locationName: 'Thiruparankundram, Madurai, Tamil Nadu, India',
        lat: _profile!.lat != 0.0 ? _profile!.lat : 9.882,
        lng: _profile!.lng != 0.0 ? _profile!.lng : 78.084,
      );
      await StorageService.saveProfile(_profile!);
    }
    notifyListeners();
  }

  void setSelectedReport(ReportFileResult? report) {
    _selectedReport = report;
    notifyListeners();
  }

  void clearReport() {
    _selectedReport = null;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile newProfile) async {
    _profile = newProfile;
    await StorageService.saveProfile(newProfile);
    notifyListeners();
  }

  void updateProfile(UserProfile newProfile) {
    _profile = newProfile;
    notifyListeners();
  }

  Future<void> syncUserSession(String name, String phone) async {
    final existing = _profile;
    _profile = (existing ?? const UserProfile(
      name: '',
      phone: '',
      locationName: 'Madurai, Tamil Nadu, India',
      lat: 9.919,
      lng: 78.1195,
      budget: 250,
    )).copyWith(
      name: name.isNotEmpty ? name : existing?.name,
      phone: phone.isNotEmpty ? phone : existing?.phone,
    );
    await StorageService.saveProfile(_profile!);
    notifyListeners();
  }

  Future<void> logout() async {
    _profile = null;
    await StorageService.clearProfile();
    notifyListeners();
  }

  void setStatus(AppStatus newStatus, [String? error]) {
    _status = newStatus;
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AppStatus.error) {
      _status = AppStatus.idle;
    }
    notifyListeners();
  }

  /// Sends the analysis request to the backend and saves results locally.
  Future<DietPlan?> submitDietPlanRequest(UserProfile profileData) async {
    if (_selectedReport == null) {
      _status = AppStatus.error;
      _errorMessage = 'Please upload a blood report first.';
      notifyListeners();
      return null;
    }

    _status = AppStatus.loading;
    _errorMessage = null;
    _profile = profileData;
    notifyListeners();

    try {
      final plan = await ApiService.createPlan(
        profileData,
        _selectedReport!.bytes,
        _selectedReport!.name,
      );
      _currentPlan = plan;
      _lastSavedPlan = plan;
      _status = AppStatus.done;

      // Save locally for future sessions
      await StorageService.saveProfile(profileData);
      await StorageService.savePlan(plan);

      notifyListeners();
      return plan;
    } on ApiException catch (e) {
      _status = AppStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _status = AppStatus.error;
      _errorMessage = 'Failed to analyze report: $e';
      notifyListeners();
      return null;
    }
  }
}
