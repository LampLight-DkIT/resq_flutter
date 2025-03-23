import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resq/core/services/attachment_handler.dart';

class AttachmentOptionsBottomSheet extends StatelessWidget {
  final Function(ImageSource) onImageSelected;
  final Function() onDocumentSelected;
  final Function() onAudioSelected;
  final Function() onLocationSelected;
  final Function() onRecordAudio;

  const AttachmentOptionsBottomSheet({
    Key? key,
    required this.onImageSelected,
    required this.onDocumentSelected,
    required this.onAudioSelected,
    required this.onLocationSelected,
    required this.onRecordAudio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Share Content",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionItem(
                  context,
                  icon: Icons.camera_alt,
                  label: "Camera",
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    onImageSelected(ImageSource.camera);
                  },
                ),
                _buildOptionItem(
                  context,
                  icon: Icons.photo_library,
                  label: "Gallery",
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    onImageSelected(ImageSource.gallery);
                  },
                ),
                _buildOptionItem(
                  context,
                  icon: Icons.insert_drive_file,
                  label: "Document",
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    onDocumentSelected();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionItem(
                  context,
                  icon: Icons.music_note,
                  label: "Audio",
                  color: Colors.cyan,
                  onTap: () {
                    Navigator.pop(context);
                    onAudioSelected();
                  },
                ),
                _buildOptionItem(
                  context,
                  icon: Icons.mic,
                  label: "Record",
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    onRecordAudio();
                  },
                ),
                _buildOptionItem(
                  context,
                  icon: Icons.location_on,
                  label: "Location",
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    onLocationSelected();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class AudioRecordingDialog extends StatefulWidget {
  final Function(File) onComplete;

  const AudioRecordingDialog({
    Key? key,
    required this.onComplete,
    required Null Function() onCancel,
  }) : super(key: key);

  @override
  State<AudioRecordingDialog> createState() => _AudioRecordingDialogState();
}

class _AudioRecordingDialogState extends State<AudioRecordingDialog> {
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() async {
    final attachmentHandler = context.read<AttachmentHandler>();
    final success = await attachmentHandler.startRecording();

    if (success) {
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
      });
    } else {
      // Handle failure to start recording
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start audio recording')),
      );
    }
  }

  void _stopRecording() async {
    _timer?.cancel();
    final attachmentHandler = context.read<AttachmentHandler>();
    final audioFile = await attachmentHandler.stopRecording();

    if (audioFile != null) {
      widget.onComplete(audioFile);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save recording')),
      );
    }

    Navigator.pop(context);
  }

  String _formatDuration() {
    final minutes = (_recordDuration / 60).floor().toString().padLeft(2, '0');
    final seconds = (_recordDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Audio Recording'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRecording ? Icons.mic : Icons.mic_off,
              color: _isRecording ? Colors.red : Colors.grey,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _formatDuration(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isRecording ? 'Recording...' : 'Stopped',
            style: TextStyle(
              color: _isRecording ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            final attachmentHandler = context.read<AttachmentHandler>();
            if (_isRecording) {
              attachmentHandler.stopRecording();
            }
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _stopRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text(
            'Stop & Send',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
