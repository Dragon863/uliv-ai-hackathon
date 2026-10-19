import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/job.dart';

class JobSnapshot {
  const JobSnapshot({required this.jobs, required this.nextSequence});

  final List<Job> jobs;
  final int nextSequence;

  factory JobSnapshot.fromJson(Map<String, dynamic> json) => JobSnapshot(
    jobs: (json['jobs'] as List<dynamic>)
        .map((item) => Job.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    nextSequence: json['nextSequence'] as int,
  );

  Map<String, Object?> toJson() => {
    'jobs': jobs.map((job) => job.toJson()).toList(),
    'nextSequence': nextSequence,
  };
}

abstract interface class JobRepository {
  Future<JobSnapshot> load();
  Future<void> save(List<Job> jobs, int nextSequence);
  void close();
}

/// Retained for offline development and repository tests. The app uses the API.
class LocalJobRepository implements JobRepository {
  LocalJobRepository(this._preferences);

  static const storageKey = 'meadow_jobs_v1';
  final SharedPreferences _preferences;

  @override
  Future<JobSnapshot> load() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null) return const JobSnapshot(jobs: [], nextSequence: 1);
    try {
      return JobSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const JobSnapshot(jobs: [], nextSequence: 1);
    }
  }

  @override
  Future<void> save(List<Job> jobs, int nextSequence) async {
    await _preferences.setString(
      storageKey,
      jsonEncode(JobSnapshot(jobs: jobs, nextSequence: nextSequence).toJson()),
    );
  }

  @override
  void close() {}
}

class ApiJobRepository implements JobRepository {
  ApiJobRepository({
    required Uri baseUri,
    this._token = '',
    http.Client? client,
  }) : _baseUri = _withTrailingSlash(baseUri),
       _client = client ?? http.Client();

  final Uri _baseUri;
  final String _token;
  final http.Client _client;

  static Uri _withTrailingSlash(Uri uri) =>
      uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');

  Uri get _endpoint => _baseUri.resolve('api/jobs');

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  @override
  Future<JobSnapshot> load() async {
    final response = await _client
        .get(_endpoint, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw _apiError(response.statusCode, response.body);
    }
    try {
      return JobSnapshot.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on Object catch (error) {
      throw FormatException('The server returned invalid job data: $error');
    }
  }

  @override
  Future<void> save(List<Job> jobs, int nextSequence) async {
    final response = await _client
        .put(
          _endpoint,
          headers: {
            ..._headers,
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(
            JobSnapshot(jobs: jobs, nextSequence: nextSequence).toJson(),
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw _apiError(response.statusCode, response.body);
    }
  }

  Exception _apiError(int statusCode, String body) {
    var message = body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        message = decoded['error'] as String;
      }
    } catch (_) {
      // Keep the response body when the server did not send JSON.
    }
    return Exception('Meadow House server returned $statusCode: $message');
  }

  @override
  void close() => _client.close();
}
