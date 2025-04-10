import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:resq/features/chats/models/message_model.dart';

class AudioMessageBubble extends StatefulWidget {
  final Message message;
  final bool isCurrentUser;

  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  String? _audioUrl;
  String _duration = "0:00";
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  double _playbackProgress = 0.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _extractAudioDetails();
    _initAudioPlayer();
  }

  void _extractAudioDetails() {
    try {
      // First, try to get the URL from attachmentUrl property
      String? url = widget.message.attachmentUrl;

      // If that's empty, try to extract from content
      if (url == null || url.isEmpty) {
        final content = widget.message.content;
        // Extract the URL part before any pipe character
        if (content.contains('|')) {
          final parts = content.split('|');
          url = parts[0];

          // Extract duration if available
          if (parts.length > 1) {
            _duration = parts[1];
          }
        } else {
          url = content;
        }
      }

      // Set the URL
      _audioUrl = url;

      // Debug output
      print("DEBUG: Extracted audio URL: $_audioUrl");
      print("DEBUG: Extracted duration: $_duration");
    } catch (e) {
      print("ERROR extracting audio details: $e");
      _hasError = true;
    }
  }

  void _initAudioPlayer() {
    try {
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _playbackProgress = 0.0;
            });
          }
        }
      }, onError: (error) {
        print("ERROR in player state stream: $error");
        if (mounted) {
          setState(() {
            _hasError = true;
            _isPlaying = false;
            _isLoading = false;
          });
        }
      });

      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        final duration = _audioPlayer.duration;
        if (duration != null && mounted) {
          setState(() {
            // Safely calculate progress with checks
            _playbackProgress = _calculateSafeProgress(position, duration);
          });
        }
      }, onError: (error) {
        print("ERROR in position stream: $error");
      });
    } catch (e) {
      print("ERROR initializing audio player: $e");
      _hasError = true;
    }
  }

  // Safely calculate playback progress with bounds checking
  double _calculateSafeProgress(Duration position, Duration duration) {
    if (duration.inMilliseconds <= 0) return 0.0;

    // Make sure we don't divide by zero
    final totalMs = max(duration.inMilliseconds, 1);

    // Calculate progress and clamp between 0 and 1
    final progress = position.inMilliseconds / totalMs;
    return min(max(progress, 0.0), 1.0);
  }

  @override
  void dispose() {
    try {
      _positionSubscription?.cancel();
      _playerStateSubscription?.cancel();
      _audioPlayer.dispose();
    } catch (e) {
      print("ERROR disposing audio player: $e");
    }
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_audioUrl == null || _hasError) return;

    if (_isPlaying) {
      try {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } catch (e) {
        print("ERROR pausing audio: $e");
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      try {
        // Check if we need to load a new URL
        if (_audioPlayer.processingState == ProcessingState.idle ||
            _audioPlayer.processingState == ProcessingState.completed) {
          await _audioPlayer.setUrl(_audioUrl!);
        }

        await _audioPlayer.play();
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        print("ERROR playing audio: $e");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        // Show error message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Couldn't play audio")),
          );
        }
      }
    }
  }

  // Format duration from seconds to mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // Get the current position as a string
  String _getCurrentPosition() {
    try {
      final position = _audioPlayer.position;
      final duration = _audioPlayer.duration;
      if (duration != null) {
        return "${_formatDuration(position)} / ${_formatDuration(duration)}";
      } else {
        return _formatDuration(position);
      }
    } catch (e) {
      return _duration;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color:
            widget.isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _hasError
          ? _buildErrorWidget()
          : Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.isCurrentUser
                        ? Colors.blue.shade50
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.isCurrentUser
                                  ? Colors.blue
                                  : Colors.black87,
                            ),
                          )
                        : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _isLoading ? null : _togglePlayPause,
                    color: widget.isCurrentUser ? Colors.blue : Colors.black87,
                    iconSize: 20,
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          // Background track
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: widget.isCurrentUser
                                  ? Colors.blue.shade200
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Progress indicator - safely calculate width
                          Container(
                            height: 4,
                            width:
                                (MediaQuery.of(context).size.width * 0.6 - 70) *
                                    min(max(_playbackProgress, 0.0), 1.0),
                            decoration: BoxDecoration(
                              color: widget.isCurrentUser
                                  ? Colors.blue.shade500
                                  : Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isPlaying ? _getCurrentPosition() : _duration,
                            style: TextStyle(
                              color: widget.isCurrentUser
                                  ? Colors.blue[900]
                                  : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.headset,
                                size: 12,
                                color: widget.isCurrentUser
                                    ? Colors.blue.shade800
                                    : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Audio',
                                style: TextStyle(
                                  color: widget.isCurrentUser
                                      ? Colors.blue.shade800
                                      : Colors.grey.shade700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorWidget() {
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          color: Colors.red.shade400,
          size: 28,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Audio unavailable",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                "Tap to try again",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() {
              _hasError = false;
              _playbackProgress = 0.0;
            });
            _initAudioPlayer();
          },
          color: Colors.blue,
          iconSize: 20,
        ),
      ],
    );
  }
}
