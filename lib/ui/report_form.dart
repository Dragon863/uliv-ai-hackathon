import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/job.dart';
import '../state/job_controller.dart';

class ReportForm extends StatefulWidget {
  const ReportForm({required this.controller, super.key});
  final JobController controller;

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _reporter = TextEditingController();
  JobPriority _priority = JobPriority.normal;
  bool _submitting = false;

  @override
  void dispose() {
    _description.dispose();
    _reporter.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final error = await widget.controller.createJob(
      description: _description.text,
      reporter: _reporter.text,
      priority: _priority,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final id = widget.controller.jobs.first.id;
    _description.clear();
    _reporter.clear();
    _priority = JobPriority.normal;
    _formKey.currentState!.reset();
    setState(() {});
    final message = 'Job $id created';
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: colors.primary),
                  const SizedBox(width: 9),
                  Text(
                    'Report a repair',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What needs fixing?',
                  hintText: 'Describe the repair',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a description of the repair'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reporter,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'Who is reporting this?',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 18),
              Text('Priority', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<JobPriority>(
                segments: const [
                  ButtonSegment(
                    value: JobPriority.normal,
                    label: Text('Normal'),
                    icon: Icon(Icons.circle_outlined),
                  ),
                  ButtonSegment(
                    value: JobPriority.urgent,
                    label: Text('Urgent'),
                    icon: Icon(Icons.priority_high_rounded),
                  ),
                ],
                selected: {_priority},
                onSelectionChanged: (selection) =>
                    setState(() => _priority = selection.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text(
                  'Submit report',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
