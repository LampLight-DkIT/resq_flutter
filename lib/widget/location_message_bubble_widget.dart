import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMessageBubble extends StatefulWidget {
  final Message message;
  final bool isCurrentUser;

  const LocationMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  State<LocationMessageBubble> createState() => _LocationMessageBubbleState();
}

class _LocationMessageBubbleState extends State<LocationMessageBubble> {
  String locationAddress = "Loading address...";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _getAddressFromCoordinates();
  }

  Future<void> _getAddressFromCoordinates() async {
    final coordinates = widget.message.content.split(',');
    if (coordinates.length != 2) return;

    final latitude = double.tryParse(coordinates[0]);
    final longitude = double.tryParse(coordinates[1]);
    if (latitude == null || longitude == null) return;

    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          locationAddress =
              "${place.street}, ${place.locality}, ${place.administrativeArea}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        locationAddress = "Address unavailable";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = widget.message.content.split(',');
    if (coordinates.length != 2) return const SizedBox();

    final latitude = double.tryParse(coordinates[0]);
    final longitude = double.tryParse(coordinates[1]);
    if (latitude == null || longitude == null) return const SizedBox();

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color:
            widget.isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(
                Icons.map_outlined,
                color: Colors.white,
              ),
            ),
            title: Text(
              "Location Data",
              style: Theme.of(context).textTheme.labelSmall,
            ),
            subtitle: isLoading
                ? Text("Loading address...")
                : Text(locationAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge),
          ),
          // Location info and actions
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: widget.isCurrentUser ? Colors.blue[800] : Colors.red,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Shared Location',
                    style: TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _openMap(context, latitude, longitude),
                  icon: Icon(
                    Icons.open_in_new,
                    size: 20.0,
                  ),
                ),
              ],
            ),
          ),
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(
                right: 8.0, bottom: 4.0, left: 8.0, top: 1.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${widget.message.timestamp.hour}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to open map
  void _openMap(BuildContext context, double latitude, double longitude) async {
    try {
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      await launchUrl(Uri.parse(mapsUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }
}
