import 'package:flutter/foundation.dart';

import '../data/job_repository.dart';
import '../models/job.dart';

class JobController extends ChangeNotifier {
  JobController(this._repository);

  final JobRepository _repository;
  List<Job> _jobs = [];
  int _nextSequence = 1;

  List<Job> get jobs => List.unmodifiable(_jobs);

  Future<void> load() async {
    final snapshot = await _repository.load();
    _jobs = snapshot.jobs;
    _nextSequence = snapshot.nextSequence;
    notifyListeners();
  }

  Future<String?> createJob({
    required String description,
    required String reporter,
    required JobPriority priority,
  }) async {
    final cleanDescription = description.trim();
    final cleanReporter = reporter.trim();
    if (cleanDescription.isEmpty) return 'Enter a description of the repair';
    if (cleanReporter.isEmpty) return 'Enter your name';
    final job = Job(
      id: 'MH-${_nextSequence.toString().padLeft(4, '0')}',
      description: cleanDescription,
      reporter: cleanReporter,
      priority: priority,
      status: JobStatus.newJob,
      createdAt: DateTime.now(),
      history: [
        HistoryEntry(
          timestamp: DateTime.now(),
          type: HistoryType.created,
          text: 'Repair reported by $cleanReporter',
        ),
      ],
    );
    final previousJobs = _jobs;
    final previousSequence = _nextSequence;
    _jobs = [job, ..._jobs];
    _nextSequence++;
    notifyListeners();
    try {
      await _persist();
    } catch (error) {
      _jobs = previousJobs;
      _nextSequence = previousSequence;
      notifyListeners();
      return 'Could not save this report to the server: $error';
    }
    return null;
  }

  Future<String?> startProgress(String id) async {
    final job = _find(id);
    if (job == null || job.status != JobStatus.newJob) {
      return 'This job cannot be started';
    }
    return _replace(
      job.copyWith(
        status: JobStatus.inProgress,
        history: [
          ...job.history,
          HistoryEntry(
            timestamp: DateTime.now(),
            type: HistoryType.progress,
            text: 'Work started',
          ),
        ],
      ),
    );
  }

  Future<String?> addNote(String id, String note) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      return 'Enter a progress note';
    }
    final job = _find(id);
    if (job == null || job.status != JobStatus.inProgress) {
      return 'Start work before adding a note';
    }
    return _replace(
      job.copyWith(
        latestNote: cleanNote,
        history: [
          ...job.history,
          HistoryEntry(
            timestamp: DateTime.now(),
            type: HistoryType.note,
            text: cleanNote,
          ),
        ],
      ),
    );
  }

  Future<String?> complete(String id, String note) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      return 'Enter a completion note';
    }
    final job = _find(id);
    if (job == null || job.status != JobStatus.inProgress) {
      return 'Only in-progress jobs can be completed';
    }
    return _replace(
      job.copyWith(
        status: JobStatus.completed,
        latestNote: cleanNote,
        history: [
          ...job.history,
          HistoryEntry(
            timestamp: DateTime.now(),
            type: HistoryType.completed,
            text: cleanNote,
          ),
        ],
      ),
    );
  }

  Job? _find(String id) {
    for (final job in _jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  Future<String?> _replace(Job updated) async {
    final previousJobs = _jobs;
    _jobs = _jobs
        .map((job) => job.id == updated.id ? updated : job)
        .toList(growable: false);
    notifyListeners();
    try {
      await _persist();
      return null;
    } catch (error) {
      _jobs = previousJobs;
      notifyListeners();
      return 'Could not save this update to the server: $error';
    }
  }

  Future<void> _persist() => _repository.save(_jobs, _nextSequence);

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
