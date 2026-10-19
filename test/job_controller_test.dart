import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meadow_house_repairs/data/job_repository.dart';
import 'package:meadow_house_repairs/models/job.dart';
import 'package:meadow_house_repairs/state/job_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<JobController> createController() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = JobController(LocalJobRepository(preferences));
    await controller.load();
    return controller;
  }

  group('JobController', () {
    test(
      'rejects blank description and reporter without creating jobs',
      () async {
        final controller = await createController();

        expect(
          await controller.createJob(
            description: '  ',
            reporter: 'Sam',
            priority: JobPriority.normal,
          ),
          'Enter a description of the repair',
        );
        expect(
          await controller.createJob(
            description: 'Leaking tap',
            reporter: '  ',
            priority: JobPriority.normal,
          ),
          'Enter your name',
        );
        expect(controller.jobs, isEmpty);
      },
    );

    test('trims fields and creates unique IDs', () async {
      final controller = await createController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(
        await controller.createJob(
          description: '  Leaking tap  ',
          reporter: ' Sam ',
          priority: JobPriority.urgent,
        ),
        isNull,
      );
      expect(
        await controller.createJob(
          description: 'Broken latch',
          reporter: 'Jo',
          priority: JobPriority.normal,
        ),
        isNull,
      );

      expect(controller.jobs.map((job) => job.id), ['MH-0002', 'MH-0001']);
      expect(controller.jobs.last.description, 'Leaking tap');
      expect(controller.jobs.last.reporter, 'Sam');
      expect(controller.jobs.last.priority, JobPriority.urgent);
      expect(notifications, 2);
    });

    test('rolls back a report when the server save fails', () async {
      final controller = JobController(_FailingJobRepository());
      await controller.load();

      expect(
        await controller.createJob(
          description: 'Leaking tap',
          reporter: 'Sam',
          priority: JobPriority.normal,
        ),
        contains('Could not save this report to the server'),
      );
      expect(controller.jobs, isEmpty);
      controller.dispose();
    });

    test('updates only the selected job and appends progress notes', () async {
      final controller = await createController();
      await controller.createJob(
        description: 'Tap',
        reporter: 'Sam',
        priority: JobPriority.normal,
      );
      await controller.createJob(
        description: 'Door',
        reporter: 'Jo',
        priority: JobPriority.normal,
      );
      final originalOtherHistory = controller.jobs.last.history;

      expect(await controller.startProgress('MH-0002'), isNull);
      expect(await controller.addNote('MH-0002', '  Part ordered  '), isNull);

      final changed = controller.jobs.first;
      final unchanged = controller.jobs.last;
      expect(changed.status, JobStatus.inProgress);
      expect(changed.latestNote, 'Part ordered');
      expect(changed.history.map((entry) => entry.text), [
        'Repair reported by Jo',
        'Work started',
        'Part ordered',
      ]);
      expect(unchanged.status, JobStatus.newJob);
      expect(unchanged.history, same(originalOtherHistory));
    });

    test('blank completion note leaves the job completely unchanged', () async {
      final controller = await createController();
      await controller.createJob(
        description: 'Tap',
        reporter: 'Sam',
        priority: JobPriority.normal,
      );
      await controller.startProgress('MH-0001');
      await controller.addNote('MH-0001', 'Part ordered');
      final before = controller.jobs.single;

      expect(
        await controller.complete('MH-0001', '  '),
        'Enter a completion note',
      );
      expect(controller.jobs.single, same(before));
      expect(controller.jobs.single.status, JobStatus.inProgress);
    });

    test('completion note is saved and closes the job', () async {
      final controller = await createController();
      await controller.createJob(
        description: 'Tap',
        reporter: 'Sam',
        priority: JobPriority.normal,
      );
      await controller.startProgress('MH-0001');

      expect(
        await controller.complete('MH-0001', '  Washer replaced  '),
        isNull,
      );
      expect(controller.jobs.single.status, JobStatus.completed);
      expect(controller.jobs.single.latestNote, 'Washer replaced');
      expect(controller.jobs.single.history.last.text, 'Washer replaced');
      expect(controller.jobs.single.history.last.type, HistoryType.completed);
    });
  });
}

class _FailingJobRepository implements JobRepository {
  @override
  Future<JobSnapshot> load() async =>
      const JobSnapshot(jobs: [], nextSequence: 1);

  @override
  Future<void> save(List<Job> jobs, int nextSequence) async {
    throw StateError('server unavailable');
  }

  @override
  void close() {}
}
