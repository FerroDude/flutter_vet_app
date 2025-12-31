import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clinic_models.dart';
import '../models/pet_model.dart';
import '../models/symptom_models.dart';
import '../services/clinic_service.dart';

class VetProvider extends ChangeNotifier {
  final ClinicService _clinicService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  VetProvider(this._clinicService);

  String? _clinicId;
  String _searchText = '';
  bool _isLoading = false;
  String? _error;

  // Data
  List<UserProfile> _patients = [];
  final Map<String, List<Pet>> _ownerIdToPets = {};
  
  // Symptom tracking
  List<EnrichedSymptom> _recentSymptoms = [];
  bool _isSymptomsLoading = false;
  DateTime? _lastSymptomFetch;
  DateTime? _lastSymptomsViewedAt; // When vet last viewed symptoms

  // Stats tracking
  int _symptomsThisWeek = 0;
  int _symptomsLastWeek = 0;
  int _totalPetCount = 0;

  // Streams
  StreamSubscription<List<UserProfile>>? _patientsSub;
  final Map<String, StreamSubscription<List<Pet>>> _petsSubs = {};
  Timer? _symptomRefreshTimer;

  // Getters
  String? get clinicId => _clinicId;
  String get searchText => _searchText;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserProfile> get patients => _patients;
  List<Pet> petsForOwner(String ownerId) => _ownerIdToPets[ownerId] ?? const [];
  
  // Symptom getters
  List<EnrichedSymptom> get recentSymptoms => _recentSymptoms;
  bool get isSymptomsLoading => _isSymptomsLoading;
  
  /// Returns symptoms that haven't been viewed yet (new symptoms)
  List<EnrichedSymptom> get unseenSymptoms {
    if (_lastSymptomsViewedAt == null) {
      // If never viewed, all recent symptoms are "new"
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      return _recentSymptoms.where((s) => s.symptom.timestamp.isAfter(cutoff)).toList();
    }
    // Only symptoms after the last view time are "new"
    return _recentSymptoms.where((s) => s.symptom.timestamp.isAfter(_lastSymptomsViewedAt!)).toList();
  }
  
  /// Returns the count of unseen symptoms (for the dashboard badge)
  int get recentSymptomCount => unseenSymptoms.length;

  // Stats getters
  int get symptomsThisWeek => _symptomsThisWeek;
  int get symptomsLastWeek => _symptomsLastWeek;
  int get totalPetCount => _totalPetCount;
  
  /// Returns the symptom trend: positive = increase, negative = decrease, 0 = same
  int get symptomTrend {
    if (_symptomsLastWeek == 0) return _symptomsThisWeek > 0 ? 1 : 0;
    return _symptomsThisWeek - _symptomsLastWeek;
  }
  
  /// Returns percentage change in symptoms week over week
  double get symptomTrendPercent {
    if (_symptomsLastWeek == 0) return _symptomsThisWeek > 0 ? 100.0 : 0.0;
    return ((_symptomsThisWeek - _symptomsLastWeek) / _symptomsLastWeek) * 100;
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  Future<void> initialize(String clinicId) async {
    if (_clinicId == clinicId && _patientsSub != null) return;
    await disposeStreams();
    _clinicId = clinicId;
    
    // Load last viewed timestamp from storage
    await _loadLastSymptomsViewedAt();
    
    _subscribePatients();
    
    // Start symptom refresh timer (every 2 minutes)
    _symptomRefreshTimer?.cancel();
    _symptomRefreshTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _fetchRecentSymptoms(),
    );
  }

  /// Load the last symptoms viewed timestamp from local storage
  Future<void> _loadLastSymptomsViewedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('lastSymptomsViewedAt_$_clinicId');
      if (timestamp != null) {
        _lastSymptomsViewedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Failed to load lastSymptomsViewedAt: $e');
    }
  }

  /// Mark all current symptoms as seen
  Future<void> markSymptomsAsSeen() async {
    _lastSymptomsViewedAt = DateTime.now();
    notifyListeners();
    
    // Persist to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'lastSymptomsViewedAt_$_clinicId',
        _lastSymptomsViewedAt!.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Failed to save lastSymptomsViewedAt: $e');
    }
  }

  void updateSearchText(String text) {
    _searchText = text.trim();
    _subscribePatients();
  }

  void _subscribePatients() {
    if (_clinicId == null) return;
    _setLoading(true);
    _patientsSub?.cancel();
    _patientsSub = _clinicService
        .clinicPatientsStream(_clinicId!, namePrefix: _searchText, limit: 25)
        .listen(
          (users) {
            _patients = users;
            _setLoading(false);
            notifyListeners();
            // Subscribe to pets for visible owners
            _subscribePetsForOwners(users.map((u) => u.id).toList());
            // Fetch symptoms when patients change
            _fetchRecentSymptoms();
          },
          onError: (e) {
            _setError('Failed to load patients: $e');
            _setLoading(false);
          },
        );
  }

  void _subscribePetsForOwners(List<String> ownerIds) {
    // Cancel subscriptions for owners no longer in view
    for (final entry in _petsSubs.entries.toList()) {
      if (!ownerIds.contains(entry.key)) {
        entry.value.cancel();
        _petsSubs.remove(entry.key);
        _ownerIdToPets.remove(entry.key);
      }
    }
    // Subscribe to pets for current owners
    for (final ownerId in ownerIds) {
      if (_petsSubs.containsKey(ownerId)) continue;
      final sub = _clinicService.ownerPetsStream(ownerId).listen((pets) {
        _ownerIdToPets[ownerId] = pets;
        notifyListeners();
      });
      _petsSubs[ownerId] = sub;
    }
  }

  /// Fetch recent symptoms from all clinic patients and calculate stats
  Future<void> _fetchRecentSymptoms() async {
    if (_patients.isEmpty || _isSymptomsLoading) return;
    
    // Throttle: don't fetch more than once per 30 seconds
    if (_lastSymptomFetch != null &&
        DateTime.now().difference(_lastSymptomFetch!).inSeconds < 30) {
      return;
    }
    
    _isSymptomsLoading = true;
    _lastSymptomFetch = DateTime.now();
    
    try {
      final List<EnrichedSymptom> allSymptoms = [];
      final now = DateTime.now();
      final cutoff48h = now.subtract(const Duration(hours: 48));
      final thisWeekStart = now.subtract(const Duration(days: 7));
      final lastWeekStart = now.subtract(const Duration(days: 14));
      
      int symptomsThisWeekCount = 0;
      int symptomsLastWeekCount = 0;
      int petCount = 0;
      
      // For each patient, get their pets and recent symptoms
      for (final patient in _patients) {
        final ownerName = patient.displayName.isNotEmpty 
            ? patient.displayName 
            : patient.email;
        
        // Get pets for this owner
        final petsSnap = await _firestore
            .collection('users')
            .doc(patient.id)
            .collection('pets')
            .get();
        
        petCount += petsSnap.docs.length;
        
        for (final petDoc in petsSnap.docs) {
          final petData = petDoc.data();
          final petName = petData['name'] as String? ?? 'Unknown Pet';
          
          // Get symptoms for the last 2 weeks (for stats calculation)
          final symptomsSnap = await _firestore
              .collection('users')
              .doc(patient.id)
              .collection('pets')
              .doc(petDoc.id)
              .collection('symptoms')
              .where('timestamp', isGreaterThan: Timestamp.fromDate(lastWeekStart))
              .orderBy('timestamp', descending: true)
              .get();
          
          for (final symptomDoc in symptomsSnap.docs) {
            final symptom = PetSymptom.fromJson(
              symptomDoc.data(),
              symptomDoc.id,
              patient.id,
              petDoc.id,
            );
            
            // Count symptoms for this week vs last week
            if (symptom.timestamp.isAfter(thisWeekStart)) {
              symptomsThisWeekCount++;
            } else if (symptom.timestamp.isAfter(lastWeekStart)) {
              symptomsLastWeekCount++;
            }
            
            // Only add to recent symptoms if within 48h
            if (symptom.timestamp.isAfter(cutoff48h)) {
              allSymptoms.add(EnrichedSymptom(
                symptom: symptom,
                petName: petName,
                ownerName: ownerName,
              ));
            }
          }
        }
      }
      
      // Update stats
      _symptomsThisWeek = symptomsThisWeekCount;
      _symptomsLastWeek = symptomsLastWeekCount;
      _totalPetCount = petCount;
      
      // Sort by timestamp (most recent first)
      allSymptoms.sort((a, b) => b.symptom.timestamp.compareTo(a.symptom.timestamp));
      
      // Keep only the most recent 20
      _recentSymptoms = allSymptoms.take(20).toList();
      _isSymptomsLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch recent symptoms: $e');
      _isSymptomsLoading = false;
    }
  }

  /// Get symptoms for a specific pet (for patient detail page)
  Future<List<PetSymptom>> getSymptomsForPet(String ownerId, String petId, {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('pets')
          .doc(petId)
          .collection('symptoms')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => PetSymptom.fromJson(doc.data(), doc.id, ownerId, petId))
          .toList();
    } catch (e) {
      debugPrint('Failed to get symptoms for pet: $e');
      return [];
    }
  }

  /// Force refresh symptoms (can be called from UI)
  Future<void> refreshSymptoms() async {
    _lastSymptomFetch = null; // Reset throttle
    await _fetchRecentSymptoms();
  }

  Future<void> disposeStreams() async {
    try {
      await _patientsSub?.cancel();
    } catch (_) {}
    _patientsSub = null;
    for (final sub in _petsSubs.values) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _petsSubs.clear();
    _ownerIdToPets.clear();
    _symptomRefreshTimer?.cancel();
    _symptomRefreshTimer = null;
    _recentSymptoms = [];
  }

  @override
  void dispose() {
    disposeStreams();
    super.dispose();
  }
}
