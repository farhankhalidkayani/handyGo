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
    if (fileId == null) {
      return Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
    }
    return Column(
      children: [
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Image.network(AppServices.media.viewUrl(fileId)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              AppServices.media.viewUrl(fileId),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_actionError != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_actionError!, style: const TextStyle(color: Colors.red)),
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
                return const Center(child: Text('No workers awaiting review.'));
              }
              return ListView.builder(
                itemCount: pending.length,
                itemBuilder: (context, i) {
                  final w = pending[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Skills: ${w.skills.join(', ')}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _docThumbnail('CNIC front', w.cnicFrontUrl),
                              _docThumbnail('CNIC back', w.cnicBackUrl),
                              _docThumbnail('Selfie', w.selfieUrl),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                onPressed: () => _decide(w, 'approved'),
                                child: const Text('Approve'),
                              ),
                              OutlinedButton(
                                onPressed: () => _decide(w, 'rejected'),
                                child: const Text('Reject'),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                                onPressed: () => _decide(w, 'suspended'),
                                child: const Text('Suspend'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _requestMoreInfo(w),
                                icon: const Icon(Icons.help_outline, size: 16),
                                label: const Text('Request more info'),
                              ),
                            ],
                          ),
                        ],
                      ),
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
