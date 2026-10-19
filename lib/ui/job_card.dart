import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/job.dart';
import '../state/job_controller.dart';

String formatTimestamp(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

class JobCard extends StatefulWidget {
  const JobCard({required this.job, required this.controller, super.key});
  final Job job;
  final JobController controller;

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  final _progressNote = TextEditingController();
  final _completionNote = TextEditingController();

  @override
  void dispose() {
    _progressNote.dispose();
    _completionNote.dispose();
    super.dispose();
  }

  Future<void> _perform(
    Future<String?> Function() action,
    String successMessage,
  ) async {
    final error = await action();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    SemanticsService.sendAnnouncement(
      View.of(context),
      successMessage,
      Directionality.of(context),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final colors = Theme.of(context).colorScheme;
    final mono = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w700);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 10,
              spacing: 12,
              children: [
                Text(job.id, style: mono?.copyWith(color: colors.primary)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusChip(status: job.status),
                    const SizedBox(width: 8),
                    if (job.priority == JobPriority.urgent)
                      const _UrgentBadge()
                    else
                      const _NormalBadge(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              job.description,
              style: Theme.of(context).textTheme.titleLarge,
              softWrap: true,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Info(icon: Icons.home_outlined, text: job.house),
                _Info(
                  icon: Icons.person_outline_rounded,
                  text: 'Reported by ${job.reporter}',
                ),
                _Info(
                  icon: Icons.calendar_today_outlined,
                  text: formatTimestamp(job.createdAt),
                ),
              ],
            ),
            if (job.latestNote != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: job.status == JobStatus.completed
                      ? colors.tertiaryContainer
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.status == JobStatus.completed
                          ? 'Completion note'
                          : 'Latest progress note',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.latestNote!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
            if (job.status == JobStatus.newJob) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => _perform(
                    () => widget.controller.startProgress(job.id),
                    'Job ${job.id} is now In Progress',
                  ),
                  icon: const Icon(Icons.build_outlined),
                  label: const Text('Start work'),
                ),
              ),
            ] else if (job.status == JobStatus.inProgress) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _progressNote,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Progress note',
                  hintText: 'Add an update about the repair',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _perform(() async {
                    final error = await widget.controller.addNote(
                      job.id,
                      _progressNote.text,
                    );
                    if (error == null) _progressNote.clear();
                    return error;
                  }, 'Progress note added to ${job.id}'),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Add progress note'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _completionNote,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Completion note',
                  hintText: 'Describe the fix',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _perform(() async {
                    final error = await widget.controller.complete(
                      job.id,
                      _completionNote.text,
                    );
                    if (error == null) _completionNote.clear();
                    return error;
                  }, '${job.id} marked completed'),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark completed'),
                ),
              ),
            ],
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 14),
              title: Text(
                'History (${job.history.length})',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: job.history
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 5, right: 10),
                            decoration: BoxDecoration(
                              color: entry.type == HistoryType.completed
                                  ? colors.tertiary
                                  : colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatTimestamp(entry.timestamp),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.text,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          softWrap: true,
        ),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final JobStatus status;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = switch (status) {
      JobStatus.newJob => 'New',
      JobStatus.inProgress => 'In Progress',
      JobStatus.completed => 'Completed',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Urgent priority',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NormalBadge extends StatelessWidget {
  const _NormalBadge();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Normal',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: colors.onSecondaryContainer),
      ),
    );
  }
}
