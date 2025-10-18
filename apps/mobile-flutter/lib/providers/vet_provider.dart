import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/clinic_models.dart';
import '../models/pet_model.dart';
import '../services/clinic_service.dart';

class VetProvider extends ChangeNotifier {
  final ClinicService _clinicService;

  VetProvider(this._clinicService);

  String? _clinicId;
  String _searchText = '';
  bool _isLoading = false;
  String? _error;

  // Data
  List<UserProfile> _patients = [];
  Map<String, List<Pet>> _ownerIdToPets = {};

  // Streams
  StreamSubscription<List<UserProfile>>? _patientsSub;
  final Map<String, StreamSubscription<List<Pet>>> _petsSubs = {};

  // Getters
  String? get clinicId => _clinicId;
  String get searchText => _searchText;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserProfile> get patients => _patients;
  List<Pet> petsForOwner(String ownerId) => _ownerIdToPets[ownerId] ?? const [];

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
    _subscribePatients();
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
  }

  @override
  void dispose() {
    disposeStreams();
    super.dispose();
  }
}
