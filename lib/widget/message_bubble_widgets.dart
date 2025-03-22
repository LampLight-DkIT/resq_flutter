import 'package:flutter/material.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:url_launcher/url_launcher.dart';

class ImageMessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const ImageMessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () {
                // Show full screen image viewer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        iconTheme: const IconThemeData(color: Colors.white),
                      ),
                      backgroundColor: Colors.black,
                      body: Center(
                        child: InteractiveViewer(
                          child: Image.network(
                            message.content,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'image_${message.id}',
                child: Image.network(
                  message.content,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (message.content.contains('caption:'))
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                message.content.split('caption:')[1],
                style: TextStyle(
                  color: isCurrentUser ? Colors.blue[900] : Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DocumentMessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const DocumentMessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Parse document info from content
    // Format: url|filename|filesize|filetype
    final parts = message.content.split('|');
    final url = parts[0];
    final fileName = parts.length > 1 ? parts[1] : 'Document';
    final fileSize = parts.length > 2 ? parts[2] : '';
    final fileType = parts.length > 3 ? parts[3].toUpperCase() : '';

    return InkWell(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  fileType,
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.blue[900] : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileSize,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.blue),
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AudioMessageBubble extends StatefulWidget {
  final Message message;
  final bool isCurrentUser;

  const AudioMessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final parts = widget.message.content.split('|');
    final url = parts[0];
    final duration = parts.length > 1 ? parts[1] : '0:00';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: widget.isCurrentUser ? Colors.blue[800] : Colors.black87,
              size: 36,
            ),
            onPressed: () {
              // In a real implementation, you would play the audio here
              setState(() {
                _isPlaying = !_isPlaying;
              });

              // For now, just launch the URL to play the audio
              launchUrl(Uri.parse(url));
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: widget.isCurrentUser
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: _isPlaying ? null : 0,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isCurrentUser ? Colors.blue : Colors.grey[700]!,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
