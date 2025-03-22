import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as record_plugin;
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_event.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_state.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';

class EmergencyAlertPage extends StatelessWidget {
  final EmergencyContact contact;

  const EmergencyAlertPage({Key? key, required this.contact}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create a repository instance directly
    final repository = EmergencyContactsRepository();

    // Create a local EmergencyContactsBloc for this page
    return BlocProvider(
      create: (context) => EmergencyContactsBloc(repository: repository),
      child: EmergencyAlertPageContent(contact: contact),
    );
  }
}

class EmergencyAlertPageContent extends StatefulWidget {
  final EmergencyContact contact;

  const EmergencyAlertPageContent({Key? key, required this.contact})
      : super(key: key);

  @override
  State<EmergencyAlertPageContent> createState() =>
      _EmergencyAlertPageContentState();
}

class _EmergencyAlertPageContentState extends State<EmergencyAlertPageContent> {
  final TextEditingController _messageController = TextEditingController();
  bool _includeLocation = true;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;
  bool _isSending = false;
  String _errorMessage = '';

  // Media attachment variables
  final ImagePicker _picker = ImagePicker();
  List<File> _imageFiles = [];
  File? _videoFile;
  File? _audioFile;
  bool _isRecording = false;
  final _audioRecorder = record_plugin.AudioRecorder();
  String? _audioPath;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.contact.secretMessage;
    _requestLocationPermission();
    _requestMediaPermissions();

    // Debug print to check contact information
    print("EmergencyAlert - Contact ID: ${widget.contact.id}");
    print(
        "EmergencyAlert - Contact User ID: ${widget.contact.userId ?? 'null'}");
    print("EmergencyAlert - Secret Message: ${widget.contact.secretMessage}");
  }

  @override
  void dispose() {
    _messageController.dispose();
    _countdownTimer?.cancel();
    _stopRecording();
    super.dispose();
  }

  Future<void> _requestMediaPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoadingLocation = true;
    });

    final status = await Permission.location.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      setState(() {
        _includeLocation = false;
        _isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission denied. Alert will be sent without location.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        print(
            "Location retrieved: ${position.latitude}, ${position.longitude}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _includeLocation = false;
          _errorMessage = e.toString();
        });
        print("Location error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Image picking methods
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _imageFiles.add(File(image.path));
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFiles.add(File(image.path));
      });
    }
  }

  // Video recording methods
  Future<void> _recordVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });
    }
  }

  // Audio recording methods
  // Replace the _startRecording method with this updated version:

  Future<void> _startRecording() async {
    try {
      // Check if the microphone permission is granted
      final permissionStatus = await Permission.microphone.request();
      if (permissionStatus.isGranted) {
        // Get the app's temporary directory for storing the recording
        final tempDir =
            await getApplicationDocumentsDirectory(); // From path_provider package
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String filePath = '${tempDir.path}/audio_$timestamp.m4a';

        print('Recording to file: $filePath');

        // Create the configuration for recording
        final config = record_plugin.RecordConfig(
          encoder: record_plugin.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        // Start recording with the config
        await _audioRecorder.start(config, path: filePath);

        setState(() {
          _isRecording = true;
          _audioPath = filePath;
        });
      } else {
        _showErrorSnackbar('Microphone permission denied');
      }
    } catch (e) {
      print('Error starting recording: $e');
      _showErrorSnackbar('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioFile = File(path);
        }
      });
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  void _removeVideo() {
    setState(() {
      _videoFile = null;
    });
  }

  void _removeAudio() {
    setState(() {
      _audioFile = null;
    });
  }

  void _startCountdown() {
    setState(() {
      _countdownSeconds = 5;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdownSeconds > 0) {
            _countdownSeconds--;
          } else {
            _countdownTimer?.cancel();
            _sendEmergencyAlert();
          }
        });
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _countdownSeconds = 5;
      });
    }
  }

  Future<List<String>> _uploadMediaFiles() async {
    List<String> mediaUrls = [];
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return mediaUrls;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final storage = FirebaseStorage.instance;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    int totalFiles = _imageFiles.length +
        (_videoFile != null ? 1 : 0) +
        (_audioFile != null ? 1 : 0);
    int uploadedFiles = 0;

    try {
      // Upload images
      for (var imageFile in _imageFiles) {
        final fileName = path.basename(imageFile.path);
        final storageRef = storage.ref().child(
            'emergency_alerts/${currentUser.uid}/$timestamp/images/$fileName');

        final uploadTask = storageRef.putFile(imageFile);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = (uploadedFiles +
                    snapshot.bytesTransferred / snapshot.totalBytes) /
                totalFiles;
          });
        });

        await uploadTask;
        final downloadUrl = await storageRef.getDownloadURL();
        mediaUrls.add(downloadUrl);
        uploadedFiles++;
      }

      // Upload video if exists
      if (_videoFile != null) {
        final fileName = path.basename(_videoFile!.path);
        final storageRef = storage.ref().child(
            'emergency_alerts/${currentUser.uid}/$timestamp/videos/$fileName');

        final uploadTask = storageRef.putFile(_videoFile!);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = (uploadedFiles +
                    snapshot.bytesTransferred / snapshot.totalBytes) /
                totalFiles;
          });
        });

        await uploadTask;
        final downloadUrl = await storageRef.getDownloadURL();
        mediaUrls.add(downloadUrl);
        uploadedFiles++;
      }

      // Upload audio if exists
      if (_audioFile != null) {
        final fileName = path.basename(_audioFile!.path);
        final storageRef = storage.ref().child(
            'emergency_alerts/${currentUser.uid}/$timestamp/audio/$fileName');

        final uploadTask = storageRef.putFile(_audioFile!);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = (uploadedFiles +
                    snapshot.bytesTransferred / snapshot.totalBytes) /
                totalFiles;
          });
        });

        await uploadTask;
        final downloadUrl = await storageRef.getDownloadURL();
        mediaUrls.add(downloadUrl);
      }

      return mediaUrls;
    } catch (e) {
      print('Error uploading media: $e');
      _showErrorSnackbar('Failed to upload media: $e');
      return mediaUrls;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _sendEmergencyAlert() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorSnackbar('User not authenticated');
      return;
    }

    setState(() {
      _isSending = true;
    });

    // Enhanced debugging
    print('Contact Details:');
    print('- ID: ${widget.contact.id}');
    print('- User ID: ${widget.contact.userId}');
    print('- Is Following: ${widget.contact.isFollowing}');
    print('- Name: ${widget.contact.name}');

    String recipientId = widget.contact.userId ?? widget.contact.id;

    if (recipientId.isEmpty) {
      _showErrorSnackbar('Invalid recipient ID');
      setState(() {
        _isSending = false;
      });
      return;
    }

    try {
      // Upload media files if any
      List<String> mediaUrls = [];
      if (_imageFiles.isNotEmpty || _videoFile != null || _audioFile != null) {
        mediaUrls = await _uploadMediaFiles();
      }

      // Prepare message with media links
      String message = _prepareMessage();
      if (mediaUrls.isNotEmpty) {
        message += "\n\nAttachments: ${mediaUrls.length} files attached.";
      }

      // Send alert with media URLs
      if (mediaUrls.isNotEmpty) {
        // Use the media alert event if there are attachments
        context.read<EmergencyContactsBloc>().add(
              SendEmergencyAlertWithMedia(
                currentUser.uid,
                recipientId,
                customMessage: message,
                mediaUrls: mediaUrls,
              ),
            );
      } else {
        // Use the standard alert event if no attachments
        context.read<EmergencyContactsBloc>().add(
              SendEmergencyAlert(
                currentUser.uid,
                recipientId,
                customMessage: message,
              ),
            );
      }
    } catch (e) {
      handleError(e);
    }
  }

  String _prepareMessage() {
    String message = _messageController.text.trim();
    if (message.isEmpty) {
      message = "Emergency alert! I need help!";
    }

    if (_includeLocation && _currentPosition != null) {
      message += "\n\nMy current location: " +
          "https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}";
    }

    return message;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void handleError(dynamic e) {
    print("Error sending alert: $e");
    setState(() {
      _isSending = false;
      _errorMessage = e.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to send alert: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert'),
        backgroundColor: Colors.red,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
      ),
      body: BlocConsumer<EmergencyContactsBloc, EmergencyContactsState>(
        listener: (context, state) {
          print("Emergency state: $state");
          if (state is EmergencyAlertSent ||
              state is EmergencyAlertWithMediaSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Emergency alert sent successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          } else if (state is EmergencyAlertError) {
            setState(() {
              _isSending = false;
              _errorMessage = state.message;
            });
            print("EmergencyAlertError: ${state.message}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send alert: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Alert icon and contact info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'You are about to send an emergency alert to:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.contact.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.contact.relation.isNotEmpty &&
                          widget.contact.relation != 'App User')
                        Text(
                          widget.contact.relation,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency message
                const Text(
                  'Emergency Message',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter emergency message',
                  ),
                ),
                const SizedBox(height: 16),

                // Location option
                CheckboxListTile(
                  title: const Text('Include my current location'),
                  value: _includeLocation,
                  onChanged: (value) {
                    setState(() {
                      _includeLocation = value ?? false;
                    });
                    if (_includeLocation &&
                        _currentPosition == null &&
                        !_isLoadingLocation) {
                      _getCurrentLocation();
                    }
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_includeLocation && _isLoadingLocation)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_includeLocation && _currentPosition != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Media Attachments Section
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Media Attachments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Image attachment options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Video attachment options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _recordVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Record Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickVideoFromGallery,
                      icon: const Icon(Icons.video_library),
                      label: const Text('Video Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Audio recording option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _isRecording ? _stopRecording : _startRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(
                          _isRecording ? 'Stop Recording' : 'Record Audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isRecording ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Preview of attached media
                if (_imageFiles.isNotEmpty ||
                    _videoFile != null ||
                    _audioFile != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attachments:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Images preview
                        if (_imageFiles.isNotEmpty) ...[
                          const Text('Images:'),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imageFiles.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(_imageFiles[index]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],

                        // Video preview
                        if (_videoFile != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.videocam),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Video: ${path.basename(_videoFile!.path)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: _removeVideo,
                              ),
                            ],
                          ),
                        ],

                        // Audio preview
                        if (_audioFile != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.mic),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Audio: ${path.basename(_audioFile!.path)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: _removeAudio,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                const Divider(),

                // Error message if present
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Upload progress indicator
                if (_isUploading)
                  Column(
                    children: [
                      const Text('Uploading attachments...'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _uploadProgress),
                      Text('${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Countdown text if countdown is active
                if (_countdownTimer != null && _countdownTimer!.isActive)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Sending alert in $_countdownSeconds seconds',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cancelCountdown,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  )
                else if (_isSending)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Sending alert...'),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: _startCountdown,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'SEND EMERGENCY ALERT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
