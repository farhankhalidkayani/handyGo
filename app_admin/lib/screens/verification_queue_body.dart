import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:handygo_shared/handygo_shared.dart';

import '../services/app_services.dart';

/// Plan §12 Admin Panel checklist: "Worker verification queue (approve/reject/more-info/
/// suspend/block + reason)". Read directly via client SDK (worker_profiles grants
/// read("users") broadly); the actual approve/reject write goes through aiRouter's
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

  Future<void> _decide(WorkerProfile worker, String status) async {
    setState(() => _actionError = null);
    try {
      await AppServices.updateWorkerVerification(workerProfileId: worker.id, status: status);
      setState(() => _pendingFuture = _loadPending());
    } catch (e) {
      setState(() => _actionError = 'Action failed: $e');
    }
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
                            children: [
                              FilledButton(
                                onPressed: () => _decide(w, 'approved'),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _decide(w, 'rejected'),
                                child: const Text('Reject'),
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
