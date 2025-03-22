import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:resq/features/chats/models/message_model.dart';

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
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _audioUrl = '';
  String _audioInfo = '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _parseAudioMessage();
    _initAudioPlayer();
  }

  void _parseAudioMessage() {
    // The content format is "url|info"
    final parts = widget.message.content.split('|');
    if (parts.length >= 1) {
      _audioUrl = parts[0];
    }
    if (parts.length >= 2) {
      _audioInfo = parts[1];
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Listen to player state changes
      _audioPlayer.playerStateStream.listen((state) {
        if (state.playing != _isPlaying) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

      // Listen to duration changes
      _audioPlayer.durationStream.listen((newDuration) {
        if (newDuration != null) {
          setState(() {
            _duration = newDuration;
          });
        }
      });

      // Listen to position changes
      _audioPlayer.positionStream.listen((newPosition) {
        setState(() {
          _position = newPosition;
        });
      });

      // Load the audio file
      await _audioPlayer.setUrl(_audioUrl);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_position >= _duration) {
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play();
    }
  }

  String _formatDuration(Duration duration) {
    String minutes = (duration.inMinutes).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color:
            widget.isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio info text (optional)
          if (_audioInfo.isNotEmpty && _audioInfo != 'recorded_audio')
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _audioInfo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Audio player controls
          Row(
            children: [
              // Play/Pause button
              _isLoading
                  ? SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isCurrentUser ? Colors.blue : Colors.grey,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      color: widget.isCurrentUser
                          ? Colors.blue[700]
                          : Colors.grey[700],
                      onPressed: _playPause,
                    ),

              // Progress bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds / _duration.inMilliseconds
                          : 0.0,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isCurrentUser ? Colors.blue : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Microphone icon for recorded audio
              if (_audioInfo == 'recorded_audio')
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.mic,
                    size: 16,
                    color: widget.isCurrentUser
                        ? Colors.blue[700]
                        : Colors.grey[700],
                  ),
                ),
            ],
          ),

          // Timestamp row
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
}
