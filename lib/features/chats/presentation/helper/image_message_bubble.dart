import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:resq/features/chats/models/message_model.dart';

class ImageMessageBubble extends StatefulWidget {
  final Message message;
  final bool isCurrentUser;

  const ImageMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  State<ImageMessageBubble> createState() => _ImageMessageBubbleState();
}

class _ImageMessageBubbleState extends State<ImageMessageBubble> {
  bool _isLoading = true;
  bool _loadFailed = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _extractAndProcessImageUrl();
  }

  void _extractAndProcessImageUrl() {
    // First, try to get the URL from attachmentUrl property
    String? url = widget.message.attachmentUrl;

    // If that's empty, try to extract from content
    if (url == null || url.isEmpty) {
      final content = widget.message.content;
      // Extract the URL part before any pipe character
      if (content.contains('|')) {
        url = content.split('|')[0];
      } else {
        url = content;
      }
    }

    // Clean up the URL if it contains token parameters
    if (url.contains('?alt=media&token=')) {
      // The URL is already complete, so just use it
      _imageUrl = url;
    } else {
      // Ensure URL has proper encoding
      _imageUrl = url;
    }

    // Debug output
    print("DEBUG: Extracted image URL: $_imageUrl");

    // Handle HEIC images by converting extension to jpg
    if (_imageUrl != null && _imageUrl!.toLowerCase().contains('.heic')) {
      _imageUrl = _imageUrl!.replaceAll('.heic', '.jpg');
      print("DEBUG: Converted HEIC URL to JPG: $_imageUrl");
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_imageUrl == null) {
      return _buildErrorContainer('No image available');
    }

    return GestureDetector(
      onTap: () => _showImagePreview(context, _imageUrl!),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
          maxHeight: 300,
        ),
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          color: widget.isCurrentUser
              ? Colors.blue.shade100
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Display image with CachedNetworkImage
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey.shade400,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        print(
                            "DEBUG: Failed to load image: $url, Error: $error");
                        _loadFailed = true;
                        // Try jpg if heic failed
                        if (url.toLowerCase().contains('.heic') &&
                            !url.toLowerCase().contains('.jpg')) {
                          Future.delayed(Duration.zero, () {
                            setState(() {
                              _imageUrl = url.replaceAll('.heic', '.jpg');
                            });
                          });
                        }
                        return _buildErrorContainer('Image failed to load');
                      },
                    ),

              // Show tap to retry message if load failed
              if (_loadFailed)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContainer(String message) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      height: 120,
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color:
            widget.isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 40, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            Text(
              'Tap to retry',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
