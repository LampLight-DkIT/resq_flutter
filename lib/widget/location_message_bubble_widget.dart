import 'package:flutter/material.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const LocationMessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final coordinates = message.content.split(',');
    if (coordinates.length != 2) return const SizedBox();

    final latitude = double.tryParse(coordinates[0]);
    final longitude = double.tryParse(coordinates[1]);
    if (latitude == null || longitude == null) return const SizedBox();

    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(
                  width: 250,
                  height: 150,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.map, size: 48, color: Colors.grey),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        try {
                          await launchUrl(Uri.parse(googleMapsUrl));
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Could not open maps')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: isCurrentUser ? Colors.blue[800] : Colors.red,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    try {
                      final mapsUrl =
                          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
                      await launchUrl(Uri.parse(mapsUrl));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open maps')),
                        );
                      }
                    }
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
