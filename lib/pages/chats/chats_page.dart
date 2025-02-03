import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatPage extends StatefulWidget {
  final Map<String, String> contact;

  const ChatPage({super.key, required this.contact});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class Message {
  final String text;
  final bool isSent;
  final DateTime timestamp;
  final String? attachmentPath;
  final MessageType type;

  Message({
    required this.text,
    required this.isSent,
    required this.timestamp,
    this.attachmentPath,
    required this.type,
  });
}

enum MessageType { text, image, audio, location, document }

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  void _sendMessage(
      {String? text,
      MessageType type = MessageType.text,
      String? attachmentPath}) {
    if ((text != null && text.trim().isNotEmpty) || attachmentPath != null) {
      setState(() {
        _messages.add(Message(
          text: text ?? '',
          isSent: true,
          timestamp: DateTime.now(),
          attachmentPath: attachmentPath,
          type: type,
        ));
      });
      _messageController.clear();

      // Scroll to bottom after message is sent
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? photo =
                      await _picker.pickImage(source: ImageSource.camera);
                  if (photo != null) {
                    _sendMessage(
                        type: MessageType.image, attachmentPath: photo.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image =
                      await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    _sendMessage(
                        type: MessageType.image, attachmentPath: image.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Voice'),
                onTap: () async {
                  Navigator.of(context).pop();
                  _sendMessage(
                      type: MessageType.audio,
                      attachmentPath: "sample_audio.mp3");
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Location'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _getLocation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Document'),
                onTap: () async {
                  Navigator.of(context).pop();
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();
                  if (result != null) {
                    _sendMessage(
                        text: result.files.single.name,
                        type: MessageType.document,
                        attachmentPath: result.files.single.path);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getLocation() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _sendMessage(
          text: "Location: ${position.latitude}, ${position.longitude}",
          type: MessageType.location);
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              child: Text(widget.contact['name']?[0] ?? ''),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contact['name'] ?? ''),
                Text(
                  widget.contact['status'] ?? 'Offline',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isSent
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: message.isSent
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.type == MessageType.image &&
                            message.attachmentPath != null)
                          Image.file(File(message.attachmentPath!)),
                        if (message.type == MessageType.audio)
                          IconButton(
                              icon: Icon(Icons.play_arrow),
                              onPressed: () {
                                _audioPlayer
                                    .play(UrlSource(message.attachmentPath!));
                              }),
                        if (message.type == MessageType.document &&
                            message.attachmentPath != null)
                          Row(
                            children: [
                              Icon(Icons.insert_drive_file),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  message.text,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (message.type == MessageType.location)
                          Text(message.text),
                        if (message.type == MessageType.text)
                          Text(message.text),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: message.isSent
                                ? Colors.white.withOpacity(0.7)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _showAttachmentOptions,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type a message",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) =>
                          _sendMessage(text: _messageController.text),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).primaryColor,
                    onPressed: () =>
                        _sendMessage(text: _messageController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
