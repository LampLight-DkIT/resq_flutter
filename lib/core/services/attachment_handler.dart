import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heif_converter/heif_converter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:uuid/uuid.dart';

class AttachmentHandler {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;

  // Pick an image from gallery or camera
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  // Pick a document
  Future<File?> pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
    return null;
  }

  // Pick an audio file
  Future<File?> pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Error picking audio file: $e');
    }
    return null;
  }

  // Start recording audio
  Future<bool> startRecording() async {
    try {
      // Check microphone permission
      final permissionStatus = await Permission.microphone.request();
      if (!permissionStatus.isGranted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      // Create a unique filename for the recording
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final filePath = '${appDir.path}/audio_$timestamp.m4a';

      debugPrint('Recording to file: $filePath');

      // Configure recording
      final config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      // Start recording
      await _audioRecorder.start(config, path: filePath);
      _isRecording = true;
      _recordingPath = filePath;

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  // Stop recording and return the file
  Future<File?> stopRecording() async {
    if (!_isRecording || _recordingPath == null) return null;

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path != null) {
        return File(path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }

    return null;
  }

  // Check if currently recording
  bool get isRecording => _isRecording;

  // Get current location
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Get the current position
    return await Geolocator.getCurrentPosition();
  }

  // Upload file to Firebase Storage
// Updated uploadFile method for better media handling
  Future<String?> uploadFile(
      File file, String chatRoomId, MessageType type) async {
    try {
      String fileName = '${const Uuid().v4()}_${path.basename(file.path)}';
      String folder;

      // Handle HEIC image conversion more robustly
      if (file.path.toLowerCase().endsWith('.heic')) {
        print("DEBUG: Attempting to convert HEIC file: ${file.path}");
        try {
          String? convertedPath =
              await HeifConverter.convert(file.path, format: 'jpg');
          if (convertedPath != null) {
            final convertedFile = File(convertedPath);
            if (await convertedFile.exists()) {
              print(
                  "DEBUG: HEIC successfully converted to JPG: $convertedPath");
              file = convertedFile;
              fileName = '${const Uuid().v4()}_${path.basename(convertedPath)}';
            } else {
              print("DEBUG: Converted file doesn't exist: $convertedPath");
              // Try just changing the extension if converter fails
              final tempDir = await getTemporaryDirectory();
              final jpgPath =
                  '${tempDir.path}/${path.basenameWithoutExtension(file.path)}.jpg';
              await file.copy(jpgPath);
              if (await File(jpgPath).exists()) {
                print("DEBUG: Manually renamed file to JPG: $jpgPath");
                file = File(jpgPath);
                fileName = '${const Uuid().v4()}_${path.basename(jpgPath)}';
              }
            }
          } else {
            print("DEBUG: HEIC conversion failed. Using original file.");
          }
        } catch (e) {
          print("DEBUG: Error during HEIC conversion: $e");
          // Continue with original file
        }
      }

      // Determine the storage folder based on message type
      switch (type) {
        case MessageType.image:
          folder = 'images';
          break;
        case MessageType.document:
          folder = 'documents';
          break;
        case MessageType.audio:
          folder = 'audio';
          break;
        default:
          folder = 'other';
      }

      final storageRef =
          _storage.ref().child('chats/$chatRoomId/$folder/$fileName');

      // Better upload configuration with explicit settings
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getContentType(file.path, type),
        customMetadata: {
          'chatRoomId': chatRoomId,
          'originalFileName': path.basename(file.path),
        },
      );

      // Set up the upload task with detailed logging
      final uploadTask = storageRef.putFile(file, metadata);

      // Add a listener to monitor the upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print(
            'DEBUG: Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      }, onError: (e) {
        print('DEBUG: Upload error: $e');
      });

      // Wait for completion and get download URL
      final snapshot = await uploadTask
          .whenComplete(() => print('DEBUG: Upload completed successfully'));

      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('DEBUG: Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('ERROR uploading file: $e');
      print('ERROR stack trace: ${StackTrace.current}');
      return null;
    }
  }

// Helper to determine content type
  String _getContentType(String filePath, MessageType type) {
    switch (type) {
      case MessageType.image:
        if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
          return 'image/jpeg';
        } else if (filePath.endsWith('.png'))
          return 'image/png';
        else if (filePath.endsWith('.gif')) return 'image/gif';
        return 'image/jpeg'; // Default for images
      case MessageType.document:
        if (filePath.endsWith('.pdf')) {
          return 'application/pdf';
        } else if (filePath.endsWith('.doc') || filePath.endsWith('.docx'))
          return 'application/msword';
        return 'application/octet-stream'; // Default for documents
      case MessageType.audio:
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // Get file name from path
  String getFileName(String filePath) {
    return path.basename(filePath);
  }

  // Get file extension
  String getFileExtension(String filePath) {
    return path.extension(filePath).replaceFirst('.', '');
  }

  // Get file size in MB
  String getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Clean up resources
  Future<void> dispose() async {
    if (_isRecording) {
      await _audioRecorder.stop();
    }
    await _audioRecorder.dispose();
  }
}
