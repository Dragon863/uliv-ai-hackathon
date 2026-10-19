import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/job.dart';
import '../state/job_controller.dart';
import 'job_card.dart';
import 'report_form.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.controller, super.key});

  final JobController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton:
        Theme.of(context).platform == TargetPlatform.android ||
            MediaQuery.sizeOf(context).width < 840
        ? FloatingActionButton.extended(
            onPressed: () async {
              await controller.load();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Repair board refreshed'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          )
        : null,
    body: SafeArea(
      child: Column(
        children: [
          _TopBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 840
                  ? _WideLayout(controller: controller)
                  : _NarrowLayout(controller: controller),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.handyman_outlined,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEADOW HOUSE',
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              Text(
                'Repairs desk',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)
                    .copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const Spacer(),
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          //   decoration: BoxDecoration(
          //     color: colors.tertiaryContainer,
          //     borderRadius: BorderRadius.circular(18),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(
          //         Icons.eco_outlined,
          //         size: 18,
          //         color: colors.onTertiaryContainer,
          //       ),
          //       const SizedBox(width: 6),
          //       Text(
          //         'Local workspace',
          //         style: Theme.of(context).textTheme.labelLarge
          //             ?.copyWith(color: colors.onTertiaryContainer),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.controller});
  final JobController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: _PageScroll(child: _ReportPanel(controller: controller)),
        ),
        const SizedBox(width: 22),
        Expanded(
          flex: 6,
          child: _PageScroll(child: _JobsPanel(controller: controller)),
        ),
      ],
    ),
  );
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.controller});
  final JobController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportPanel(controller: controller),
        const SizedBox(height: 30),
        _JobsPanel(controller: controller),
      ],
    ),
  );
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: child);
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({required this.controller});
  final JobController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Home', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 24),
      ReportForm(controller: controller),
    ],
  );
}

class _JobsPanel extends StatelessWidget {
  const _JobsPanel({required this.controller});
  final JobController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final jobs = controller.jobs;
      final active = jobs
          .where((job) => job.status != JobStatus.completed)
          .length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repair board',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See reported issues and track their progress',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CountPill(count: active),
            ],
          ),
          const SizedBox(height: 18),
          if (jobs.isEmpty)
            const _EmptyState()
          else
            ...jobs.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: JobCard(
                  key: ValueKey(job.id),
                  job: job,
                  controller: controller,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count open',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.handyman_outlined,
                size: 30,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing to mend just yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'New reports will show up here, ready for the team.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
