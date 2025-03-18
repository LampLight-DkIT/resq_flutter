import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
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

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.contact.secretMessage;
    _requestLocationPermission();

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
    super.dispose();
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

// In EmergencyAlertPage._sendEmergencyAlert()
  void _sendEmergencyAlert() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorSnackbar('User not authenticated');
      return;
    }

    // Enhanced debugging
    print('Contact Details:');
    print('- ID: ${widget.contact.id}');
    print('- User ID: ${widget.contact.userId}');
    print('- Is Following: ${widget.contact.isFollowing}');
    print('- Name: ${widget.contact.name}');

    String recipientId = widget.contact.userId ?? widget.contact.id;

    if (recipientId.isEmpty) {
      _showErrorSnackbar('Invalid recipient ID');
      return;
    }

    context.read<EmergencyContactsBloc>().add(
          SendEmergencyAlert(
            currentUser.uid,
            recipientId,
            customMessage: _prepareMessage(),
          ),
        );
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
          if (state is EmergencyAlertSent) {
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
                // Alert icon
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
                const SizedBox(height: 24),

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
