import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AttachmentOption {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  AttachmentOption({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class AttachmentOptionsBottomSheet extends StatelessWidget {
  final Function(ImageSource) onImageSelected;
  final VoidCallback onDocumentSelected;
  final VoidCallback onAudioSelected;
  final VoidCallback onLocationSelected;

  const AttachmentOptionsBottomSheet({
    Key? key,
    required this.onImageSelected,
    required this.onDocumentSelected,
    required this.onAudioSelected,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Share',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                _buildAttachmentOption(
                  context,
                  AttachmentOption(
                    title: 'Camera',
                    icon: Icons.camera_alt,
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      onImageSelected(ImageSource.camera);
                    },
                  ),
                ),
                _buildAttachmentOption(
                  context,
                  AttachmentOption(
                    title: 'Gallery',
                    icon: Icons.photo_library,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      onImageSelected(ImageSource.gallery);
                    },
                  ),
                ),
                _buildAttachmentOption(
                  context,
                  AttachmentOption(
                    title: 'Document',
                    icon: Icons.insert_drive_file,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      onDocumentSelected();
                    },
                  ),
                ),
                _buildAttachmentOption(
                  context,
                  AttachmentOption(
                    title: 'Audio',
                    icon: Icons.audiotrack,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      onAudioSelected();
                    },
                  ),
                ),
                _buildAttachmentOption(
                  context,
                  AttachmentOption(
                    title: 'Location',
                    icon: Icons.location_on,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      onLocationSelected();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption(BuildContext context, AttachmentOption option) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: option.onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: option.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: option.color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(option.icon, color: option.color, size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            option.title,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
