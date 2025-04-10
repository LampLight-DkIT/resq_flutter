import 'dart:math';

import 'package:flutter/material.dart';
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
  List<double> _coordinates = [];
  bool _hasError = false;
  String _displayLocation = "Location shared";

  @override
  void initState() {
    super.initState();
    _parseLocationData();
  }

  void _parseLocationData() {
    try {
      // Use locationData field if available, otherwise use content
      final location = widget.message.locationData ?? widget.message.content;
      print("DEBUG: Location content: $location");

      // Parse coordinates safely
      _coordinates = _parseCoordinates(location);

      if (_coordinates.length == 2) {
        _displayLocation =
            "Location: ${_coordinates[0].toStringAsFixed(6)}, ${_coordinates[1].toStringAsFixed(6)}";
      } else {
        _hasError = true;
      }
    } catch (e) {
      print("ERROR parsing location data: $e");
      _hasError = true;
    }
  }

  List<double> _parseCoordinates(String? locationString) {
    List<double> result = [];

    // Null or empty check
    if (locationString == null || locationString.trim().isEmpty) {
      print("DEBUG: Empty location string");
      return result;
    }

    try {
      // Trim whitespace and split by comma
      final parts = locationString.trim().split(",");

      // Ensure we have exactly 2 parts
      if (parts.length != 2) {
        print("DEBUG: Invalid number of coordinate parts: ${parts.length}");
        return result;
      }

      // Safely parse coordinates
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      // Validate coordinates
      if (lat == null || lng == null) {
        print("DEBUG: Failed to parse coordinates. Lat: $lat, Lng: $lng");
        return result;
      }

      // Additional strict validation
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        result.add(lat);
        result.add(lng);
      } else {
        print("DEBUG: Coordinates out of valid range. Lat: $lat, Lng: $lng");
      }
    } catch (e) {
      print("Unexpected error parsing coordinates: $e");
    }

    return result;
  }

  Future<void> _openInMaps(BuildContext context) async {
    if (_coordinates.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid location coordinates")));
      return;
    }

    try {
      // Create the Google Maps URL
      final url = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=${_coordinates[0]},${_coordinates[1]}");

      // Log the URL for debugging
      print("Opening map URL: $url");

      // Check if we can launch the URL
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fall back to showing a snackbar if URL can't be launched
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not open maps application")));
        }
      }
    } catch (e) {
      print("ERROR opening maps: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error opening maps: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safety check for MediaQuery
    final mediaWidth = MediaQuery.of(context).size.width;
    final safeWidth = max(mediaWidth * 0.6, 200.0); // Ensure minimum width

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment:
            widget.isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: safeWidth,
          height: 120,
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
          child: _hasError
              ? _buildErrorContent(context)
              : _buildLocationContent(context),
        ),
      ),
    );
  }

  Widget _buildLocationContent(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.grey.shade300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 36,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(height: 8),
                    if (_coordinates.length >= 2)
                      Text(
                        "${_coordinates[0].toStringAsFixed(4)}, ${_coordinates[1].toStringAsFixed(4)}",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.6),
              child: Text(
                _displayLocation,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openInMaps(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 32,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Invalid location data",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.6),
              child: const Text(
                "Location could not be displayed",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Try parsing location data again
                  setState(() {
                    _hasError = false;
                  });
                  _parseLocationData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
