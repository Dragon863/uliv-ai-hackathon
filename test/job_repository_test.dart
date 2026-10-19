import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meadow_house_repairs/data/job_repository.dart';
import 'package:meadow_house_repairs/models/job.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'round-trips jobs and the next sequence through versioned storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = LocalJobRepository(preferences);
      final job = Job(
        id: 'MH-0008',
        description: '<b>check gate</b>',
        reporter: 'Sam',
        priority: JobPriority.urgent,
        status: JobStatus.inProgress,
        createdAt: DateTime.utc(2026, 10, 19, 14, 32),
        latestNote: 'Hinge ordered',
        history: [
          HistoryEntry(
            timestamp: DateTime.utc(2026, 10, 19, 14, 32),
            type: HistoryType.created,
            text: 'Repair reported by Sam',
          ),
          HistoryEntry(
            timestamp: DateTime.utc(2026, 10, 19, 14, 40),
            type: HistoryType.note,
            text: 'Hinge ordered',
          ),
        ],
      );

      await repository.save([job], 9);
      final snapshot = await repository.load();

      expect(preferences.getString(LocalJobRepository.storageKey), isNotNull);
      expect(snapshot.nextSequence, 9);
      expect(snapshot.jobs.single.toJson(), job.toJson());
    },
  );

  test('starts empty when persisted JSON is corrupt', () async {
    SharedPreferences.setMockInitialValues({
      LocalJobRepository.storageKey: '{broken',
    });
    final preferences = await SharedPreferences.getInstance();

    final snapshot = await LocalJobRepository(preferences).load();

    expect(snapshot.jobs, isEmpty);
    expect(snapshot.nextSequence, 1);
  });

  test(
    'loads and saves the shared snapshot through the configured API',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response('{"jobs":[],"nextSequence":4}', 200);
        }
        return http.Response('{"status":"saved"}', 200);
      });
      final repository = ApiJobRepository(
        baseUri: Uri.parse('https://repairs.example'),
        token: 'private-demo-token',
        client: client,
      );

      final snapshot = await repository.load();
      await repository.save(snapshot.jobs, snapshot.nextSequence);

      expect(snapshot.jobs, isEmpty);
      expect(snapshot.nextSequence, 4);
      expect(requests.map((request) => request.method), ['GET', 'PUT']);
      expect(requests.first.url, Uri.parse('https://repairs.example/api/jobs'));
      expect(
        requests.first.headers['authorization'],
        'Bearer private-demo-token',
      );
      expect(
        requests.last.headers['content-type'],
        contains('application/json'),
      );
      expect(requests.last.body, '{"jobs":[],"nextSequence":4}');
      repository.close();
    },
  );
}
