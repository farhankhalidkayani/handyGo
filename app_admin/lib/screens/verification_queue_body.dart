import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §12 Admin Panel checklist: "Worker verification queue (approve/reject/more-info/
/// suspend/block + reason)". Read directly via client SDK (worker_profiles grants
/// read("users") broadly); the actual approve/reject/more-info write goes through aiRouter's
/// admin-gated updateWorkerVerification feature (see functions/aiRouter/src/handlers/).
class VerificationQueueBody extends StatefulWidget {
  const VerificationQueueBody({super.key});

  @override
  State<VerificationQueueBody> createState() => _VerificationQueueBodyState();
}

class _VerificationQueueBodyState extends State<VerificationQueueBody> {
  late Future<List<WorkerProfile>> _pendingFuture;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _loadPending();
  }

  Future<List<WorkerProfile>> _loadPending() async {
    final res = await AppServices.databases.listDocuments(
      databaseId: HandyGoConfig.databaseId,
      collectionId: Collections.workerProfiles,
      queries: [Query.equal('verificationStatus', 'under_review'), Query.limit(50)],
    );
    return res.documents.map((d) => WorkerProfile.fromMap({...d.data, '\$id': d.$id})).toList();
  }

  /// Reject/suspend/request-more-info all need a reason so the worker knows what to fix —
  /// approve doesn't, since there's nothing to explain.
  Future<String?> _promptForReason(String title) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    return (reason != null && reason.isNotEmpty) ? reason : null;
  }

  Future<void> _decide(WorkerProfile worker, String status) async {
    String? reason;
    if (status == 'rejected' || status == 'suspended') {
      reason = await _promptForReason(status == 'rejected' ? 'Reason for rejecting' : 'Reason for suspending');
      if (reason == null) return;
    }
    setState(() => _actionError = null);
    try {
      await AppServices.updateWorkerVerification(workerProfileId: worker.id, status: status, reason: reason);
      setState(() {
        _pendingFuture = _loadPending();
      });
    } catch (e) {
      setState(() => _actionError = 'Action failed: $e');
    }
  }

  Future<void> _requestMoreInfo(WorkerProfile worker) async {
    final reason = await _promptForReason('What do you need from this worker?');
    if (reason == null) return;
    setState(() => _actionError = null);
    try {
      await AppServices.updateWorkerVerification(
        workerProfileId: worker.id,
        requestMoreInfo: true,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to worker.')));
    } catch (e) {
      setState(() => _actionError = 'Action failed: $e');
    }
  }

  Widget _docThumbnail(String label, String? fileId) {
    final scheme = Theme.of(context).colorScheme;
    if (fileId == null) {
      return Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      );
    }
    return Column(
      children: [
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(AppServices.media.viewUrl(fileId)),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              AppServices.media.viewUrl(fileId),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 80,
                height: 80,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_actionError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_actionError!, style: TextStyle(color: scheme.error)),
          ),
        Expanded(
          child: FutureBuilder<List<WorkerProfile>>(
            future: _pendingFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final pending = snapshot.data!;
              if (pending.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt_outlined, size: 40, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 10),
                      Text('No workers awaiting review.', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pending.length,
                itemBuilder: (context, i) {
                  final w = pending[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(Icons.person_outline, color: scheme.onPrimaryContainer, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: w.skills
                                    .map((s) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: scheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(s,
                                              style: TextStyle(
                                                  color: scheme.onSecondaryContainer,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _docThumbnail('CNIC front', w.cnicFrontUrl),
                            _docThumbnail('CNIC back', w.cnicBackUrl),
                            _docThumbnail('Selfie', w.selfieUrl),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _decide(w, 'approved'),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Approve'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _decide(w, 'rejected'),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                              onPressed: () => _decide(w, 'suspended'),
                              icon: const Icon(Icons.pause_circle_outline, size: 18),
                              label: const Text('Suspend'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _requestMoreInfo(w),
                              icon: const Icon(Icons.help_outline, size: 18),
                              label: const Text('Request more info'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
