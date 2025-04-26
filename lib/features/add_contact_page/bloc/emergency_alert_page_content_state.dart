import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as record_plugin;
import 'package:resq/core/services/trigger_notification_service.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_event.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_state.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_alert_page.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/models/message_model.dart';

class EmergencyAlertPageContentState extends State<EmergencyAlertPageContent>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  bool _includeLocation = true;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isSending = false;
  String _errorMessage = '';
  bool _hasInitialized = false;
  bool _isProcessingStateChange = false;
  bool _isDisposed = false;
  StreamSubscription? _blocSubscription;

  final ImagePicker _picker = ImagePicker();
  final List<File> _imageFiles = [];
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
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasInitialized) {
        _hasInitialized = true;
        context.read<EmergencyContactsBloc>().add(ResetEmergencyAlertState());
        _setupBlocListener();
      }
    });

    _requestLocationPermission();
    _requestMediaPermissions();
  }

  void _setupBlocListener() {
    _blocSubscription?.cancel();
    _blocSubscription = context.read<EmergencyContactsBloc>().stream.listen(
      (state) {
        if (_isDisposed) return;
        if (_isProcessingStateChange) return;

        _isProcessingStateChange = true;

        if (state is EmergencyAlertSent ||
            state is EmergencyAlertWithMediaSent) {
          _handleSuccessState();
        } else if (state is EmergencyAlertError) {
          _handleErrorState(state.message);
        }

        _isProcessingStateChange = false;
      },
      onError: (error) {
        if (_isDisposed) return;
        _handleErrorState(error.toString());
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cancelOngoingOperations();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _stopRecording();
    _cancelOngoingOperations();
    super.dispose();
  }

  void _cancelOngoingOperations() {
    _blocSubscription?.cancel();
    _blocSubscription = null;
  }

  void _handleSuccessState() {
    setState(() {
      _isSending = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency alert sent successfully'),
        backgroundColor: Colors.green,
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.pop();
      }
    });
  }

  void _handleErrorState(String errorMessage) {
    setState(() {
      _isSending = false;
      _errorMessage = errorMessage;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to send alert: $errorMessage'),
        backgroundColor: Colors.red,
      ),
    );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission denied. Location will not be included.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ));

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _includeLocation = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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

  Future<void> _startRecording() async {
    try {
      final permissionStatus = await Permission.microphone.request();
      if (permissionStatus.isGranted) {
        final tempDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String filePath = '${tempDir.path}/audio_$timestamp.m4a';

        final config = record_plugin.RecordConfig(
          encoder: record_plugin.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        await _audioRecorder.start(config, path: filePath);

        setState(() {
          _isRecording = true;
          _audioPath = filePath;
        });
      } else {
        _showErrorSnackbar('Microphone permission denied');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error starting recording: $e');
      }
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
      for (var imageFile in _imageFiles) {
        final fileName = path.basename(imageFile.path);
        final storageRef = storage.ref().child(
            'emergency_alerts/${currentUser.uid}/$timestamp/images/$fileName');

        final uploadTask = storageRef.putFile(imageFile);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (mounted) {
            setState(() {
              _uploadProgress = (uploadedFiles +
                      snapshot.bytesTransferred / snapshot.totalBytes) /
                  totalFiles;
            });
          }
        });

        await uploadTask;
        final downloadUrl = await storageRef.getDownloadURL();
        mediaUrls.add(downloadUrl);
        uploadedFiles++;
      }

      if (_videoFile != null) {
        final fileName = path.basename(_videoFile!.path);
        final storageRef = storage.ref().child(
            'emergency_alerts/${currentUser.uid}/$timestamp/videos/$fileName');

        final uploadTask = storageRef.putFile(_videoFile!);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (mounted) {
            setState(() {
              _uploadProgress = (uploadedFiles +
                      snapshot.bytesTransferred / snapshot.totalBytes) /
                  totalFiles;
            });
          }
        });

        await uploadTask;
        final downloadUrl = await storageRef.getDownloadURL();
        mediaUrls.add(downloadUrl);
        uploadedFiles++;
      }

      if (_audioFile != null) {
        final fileName = path.basename(_audioFile!.path);
        final storageRef = storage.ref().child(
            'emergency_alerts/${currentUser.uid}/$timestamp/audio/$fileName');

        final uploadTask = storageRef.putFile(_audioFile!);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (mounted) {
            setState(() {
              _uploadProgress = (uploadedFiles +
                      snapshot.bytesTransferred / snapshot.totalBytes) /
                  totalFiles;
            });
          }
        });

        await uploadTask;
        final downloadUrl = await storageRef.getDownloadURL();
        mediaUrls.add(downloadUrl);
      }

      return mediaUrls;
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to upload media: $e');
      }
      return mediaUrls;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _sendEmergencyAlert() async {
    if (_isSending) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorSnackbar('User not authenticated');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = '';
    });

    String recipientId = widget.contact.userId ?? widget.contact.id;
    if (recipientId.isEmpty) {
      _showErrorSnackbar('Invalid recipient ID');
      setState(() {
        _isSending = false;
      });
      return;
    }

    try {
      String message = _prepareMessage();
      String? locationInfo = null;
      List<String> mediaUrls = [];

      if (_includeLocation && _currentPosition != null) {
        locationInfo =
            "https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}";
      }

      // Upload media if there are any attachments
      if (_imageFiles.isNotEmpty || _videoFile != null || _audioFile != null) {
        mediaUrls = await _uploadMediaFiles();
        if (mediaUrls.isNotEmpty) {
          message += "\n\nAttachments: ${mediaUrls.length} files attached.";
        }
      }

      // First send through emergency alert system
      if (!_isDisposed && mounted) {
        if (mediaUrls.isNotEmpty) {
          context.read<EmergencyContactsBloc>().add(
                SendEmergencyAlertWithMedia(
                  currentUser.uid,
                  recipientId,
                  customMessage: message,
                  mediaUrls: mediaUrls,
                ),
              );
        } else {
          context.read<EmergencyContactsBloc>().add(
                SendEmergencyAlert(
                  currentUser.uid,
                  recipientId,
                  customMessage: message,
                ),
              );
        }
      }

      // Now also create a chat message - THIS IS THE CRITICAL PART
      if (!_isDisposed && mounted && widget.contact.userId != null) {
        // Get chat room ID correctly
        final String chatRoomId =
            _getChatRoomId(currentUser.uid, widget.contact.userId!);

        // Create a chat message with the emergency type
        final chatMessage = Message(
          id: 'emergency_${DateTime.now().millisecondsSinceEpoch}',
          chatRoomId: chatRoomId,
          senderId: currentUser.uid,
          receiverId: widget.contact.userId!,
          content: message,
          timestamp: DateTime.now(),
          type: MessageType.emergency, // This is critical for proper display
          isRead: false,
        );

        // Send emergency message through the chat bloc
        widget.chatBloc
            .add(SendEmergencyMessage(chatMessage, location: locationInfo));
      }

      // Show notification
      if (!_isDisposed && mounted) {
        await TriggerNotificationService().handleOutgoingEmergencyAlert(
          contactName: widget.contact.name,
          additionalInfo: _messageController.text.trim(),
          location: locationInfo,
        );
      }
    } catch (e) {
      if (!_isDisposed) {
        _handleErrorState(e.toString());
      }
    }
  }

  String _prepareMessage() {
    String message = _messageController.text.trim();
    if (message.isEmpty) {
      message = "Emergency alert! I need help!";
    }

    if (_includeLocation && _currentPosition != null) {
      message += "\n\nMy current location: "
          "https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}";
    }

    return message;
  }

  String _getChatRoomId(String uid1, String uid2) {
    List<String> sortedIds = [uid1, uid2]..sort();
    return "${sortedIds[0]}_${sortedIds[1]}";
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !_isSending;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Alert'),
          backgroundColor: Colors.red,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isSending ? null : () => context.pop(),
          ),
          titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  hintText: 'Enter your message here',
                ),
              ),
              const SizedBox(height: 16),
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
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                childAspectRatio: 1.2, // Tighter aspect ratio
                children: [
                  _buildGridButton(
                    onPressed: _isSending ? null : _pickImage,
                    icon: Icons.camera_alt,
                    color: Colors.blue,
                    label: 'Photo',
                  ),
                  _buildGridButton(
                    onPressed: _isSending ? null : _pickImageFromGallery,
                    icon: Icons.photo_library,
                    color: Colors.blue,
                    label: 'Gallery',
                  ),
                  _buildGridButton(
                    onPressed: _isSending ? null : _recordVideo,
                    icon: Icons.videocam,
                    color: Colors.purple,
                    label: 'Video',
                  ),
                  _buildGridButton(
                    onPressed: _isSending
                        ? null
                        : (_isRecording ? _stopRecording : _startRecording),
                    icon: _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : Colors.green,
                    label: _isRecording ? 'Stop' : 'Audio',
                  ),
                ],
              ),
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
                                      onTap: _isSending
                                          ? null
                                          : () => _removeImage(index),
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
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _isSending ? null : _removeVideo,
                            ),
                          ],
                        ),
                      ],
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
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _isSending ? null : _removeAudio,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(),
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
              if (_isSending)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Sending emergency alert...'),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _sendEmergencyAlert,
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
        ),
      ),
    );
  }
}

Widget _buildGridButton({
  required VoidCallback? onPressed,
  required IconData icon,
  required Color color,
  required String label,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 24,
        color: color,
        tooltip: label,
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
    ],
  );
}
