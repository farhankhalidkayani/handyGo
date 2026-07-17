import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handygo_shared/handygo_shared.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../services/app_services.dart';
import 'offers_screen.dart';
import 'service_request_screen.dart';

/// Plan §12 Customer App checklist: "Service request: ... AI chatbot ..." + "AI estimate card
/// (price, duration, urgency, confidence, solution, Book Service)". Calls aiRouter's `intake`
/// feature (§9.3) — rules-first category match, LLM only for disambiguation, so this works
/// (with a slightly less confident category) even if no LLM tier is configured.
class AiIntakeScreen extends StatefulWidget {
  final UserProfile profile;

  const AiIntakeScreen({super.key, required this.profile});

  @override
  State<AiIntakeScreen> createState() => _AiIntakeScreenState();
}

class _AiIntakeScreenState extends State<AiIntakeScreen> {
  final _problemController = TextEditingController();
  final _addressController = TextEditingController();
  bool _loadingEstimate = false;
  bool _submitting = false;
  String? _error;

  Map<String, dynamic>? _estimate;
  String? _selectedCategoryId;
  List<ServiceCategory> _categories = [];
  final List<String> _uploadedImageIds = [];
  bool _uploadingImage = false;
  final _recorder = AudioRecorder();
  bool _recording = false;
  String? _voiceNoteId;
  bool _uploadingVoiceNote = false;
  final List<int> _voiceNoteBuffer = [];
  StreamSubscription<List<int>>? _voiceNoteSub;

  /// Plan §12: "Service request: manual / AI chatbot / image". Auto-captioning the photo into
  /// the AI classifier needs a vision model and isn't wired up — this attaches the photo to
  /// the booking for the worker/admin to see, independent of the AI estimate.
  Future<void> _attachPhoto() async {
    setState(() => _uploadingImage = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final fileId = await AppServices.media.uploadImage(bytes: bytes, filename: picked.name);
      setState(() => _uploadedImageIds.add(fileId));
    } catch (e) {
      setState(() => _error = 'Could not attach photo: $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  /// Plan §12/C2 "voice" intake path — attachment only (see media_repository.dart for why
  /// transcription is out of scope). `startStream` is used instead of `start(path:)` so this
  /// also works on Flutter web, where there's no filesystem path to record into.
  Future<void> _toggleRecording() async {
    if (_recording) {
      await _voiceNoteSub?.cancel();
      await _recorder.stop();
      setState(() => _recording = false);
      if (_voiceNoteBuffer.isEmpty) return;
      setState(() => _uploadingVoiceNote = true);
      try {
        final fileId = await AppServices.media.uploadAudio(
          bytes: List<int>.from(_voiceNoteBuffer),
          filename: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        setState(() => _voiceNoteId = fileId);
      } catch (e) {
        setState(() => _error = 'Could not attach voice note: $e');
      } finally {
        if (mounted) setState(() => _uploadingVoiceNote = false);
      }
      return;
    }

    if (!await _recorder.hasPermission()) {
      setState(() => _error = 'Microphone permission denied');
      return;
    }
    _voiceNoteBuffer.clear();
    final stream = await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.wav));
    _voiceNoteSub = stream.listen(_voiceNoteBuffer.addAll);
    setState(() {
      _recording = true;
      _voiceNoteId = null;
    });
  }

  Future<void> _getEstimate() async {
    if (_problemController.text.trim().isEmpty) {
      setState(() => _error = 'Describe the problem first');
      return;
    }
    setState(() {
      _loadingEstimate = true;
      _error = null;
      _estimate = null;
    });
    try {
      final categories = await AppServices.categories.listAll();
      final estimate = await AppServices.bookings.getAiIntake(problemText: _problemController.text.trim());
      setState(() {
        _categories = categories;
        _estimate = estimate;
        _selectedCategoryId = estimate['categoryId'] as String?;
      });
    } catch (e) {
      setState(() => _error = 'Could not get an AI estimate: $e');
    } finally {
      if (mounted) setState(() => _loadingEstimate = false);
    }
  }

  Future<void> _bookService() async {
    final estimate = _estimate;
    if (estimate == null || _selectedCategoryId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      double lat = 0;
      double lng = 0;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {
        // fall back to (0,0) — same simplification as the manual flow
      }

      final categoryWasChanged = _selectedCategoryId != estimate['categoryId'];
      final booking = await AppServices.bookings.createBooking(
        customerId: widget.profile.id,
        categoryId: _selectedCategoryId!,
        problemText: _problemController.text.trim(),
        problemImages: _uploadedImageIds,
        voiceNoteUrl: _voiceNoteId,
        addressText: _addressController.text.trim(),
        lat: lat,
        lng: lng,
        detectedByAi: !categoryWasChanged,
        aiEstimateMin: (estimate['min'] as num?)?.toDouble(),
        aiEstimateMax: (estimate['max'] as num?)?.toDouble(),
        aiDurationMins: (estimate['durationMins'] as num?)?.toInt(),
        aiUrgency: estimate['urgency'] as String?,
        aiConfidence: (estimate['confidence'] as num?)?.toDouble(),
        aiSuggestedSolution: estimate['solution'] as String?,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OffersScreen(profile: widget.profile, bookingId: booking.id)),
      );
    } catch (e) {
      setState(() => _error = 'Could not create booking: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _problemController.dispose();
    _addressController.dispose();
    _voiceNoteSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    return Scaffold(
      appBar: AppBar(title: const Text('Describe your problem')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text('Describe it in your own words — Urdu, English, or Roman Urdu all work.'),
            const SizedBox(height: 12),
            TextField(
              controller: _problemController,
              decoration: const InputDecoration(labelText: 'e.g. "AC se pani tapak raha hai"'),
              maxLines: 3,
              enabled: estimate == null,
            ),
            const SizedBox(height: 16),
            if (estimate == null) ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              FilledButton(
                onPressed: _loadingEstimate ? null : _getEstimate,
                child: _loadingEstimate
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Get AI estimate'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => ServiceRequestScreen(profile: widget.profile)),
                ),
                child: const Text('Pick a category manually instead'),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI estimate', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategoryId = v),
                      ),
                      const SizedBox(height: 8),
                      Text('Estimated price: Rs. ${estimate['min']}–${estimate['max']}'),
                      Text('Estimated duration: ${estimate['durationMins']} mins'),
                      Text('Urgency: ${estimate['urgency']}'),
                      Text('Confidence: ${(((estimate['confidence'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%'),
                      if ((estimate['solution'] as String?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        Text(estimate['solution'] as String),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _uploadingImage ? null : _attachPhoto,
                icon: _uploadingImage
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(_uploadedImageIds.isEmpty
                    ? 'Attach a photo'
                    : '${_uploadedImageIds.length} photo(s) attached — add another'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploadingVoiceNote ? null : _toggleRecording,
                icon: _uploadingVoiceNote
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_recording ? Icons.stop_circle_outlined : Icons.mic_none),
                label: Text(_recording
                    ? 'Stop recording'
                    : _voiceNoteId != null
                        ? 'Voice note attached — tap to re-record'
                        : 'Record a voice note'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: _submitting ? null : _bookService,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                    : const Text('Book service'),
              ),
              TextButton(
                onPressed: _submitting ? null : () => setState(() => _estimate = null),
                child: const Text('Start over'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
