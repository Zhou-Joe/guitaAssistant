import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';

class TunerDisplay extends StatefulWidget {
  final double frequency;
  final String detectedNote;
  final double cents;
  final String? nearestStringNote;
  final String? selectedStringNote;
  final double? targetFrequency;
  final bool isInTune;
  final bool isListening;
  final String? errorMessage;

  const TunerDisplay({
    super.key,
    required this.frequency,
    required this.detectedNote,
    required this.cents,
    this.nearestStringNote,
    this.selectedStringNote,
    this.targetFrequency,
    required this.isInTune,
    required this.isListening,
    this.errorMessage,
  });

  @override
  State<TunerDisplay> createState() => _TunerDisplayState();
}

class _TunerDisplayState extends State<TunerDisplay> {
  @override
  Widget build(BuildContext context) {
    // Manual mode - user selected a specific string
    final isManualMode = widget.selectedStringNote != null;

    return Container(
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Target note display (manual mode)
          if (isManualMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.secondary, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'Target: ${widget.selectedStringNote}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Detected note / target note in manual mode
          Text(
            widget.isListening && widget.frequency > 0
                ? (isManualMode ? widget.selectedStringNote! : widget.detectedNote)
                : '--',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: widget.isInTune ? AppColors.cta : AppColors.textPrimary,
            ),
          ),
          // Frequency display
          if (widget.isListening && widget.frequency > 0)
            Text(
              '${widget.frequency.toStringAsFixed(1)} Hz',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textMuted,
              ),
            ),
          const SizedBox(height: 12),
          // Pitch deviation indicator
          _buildPitchDeviationIndicator(isManualMode),
          const SizedBox(height: 8),
          // Status text
          _buildStatusText(context),
        ],
      ),
    );
  }

  Widget _buildPitchDeviationIndicator(bool isManualMode) {
    Color indicatorColor;
    if (widget.cents.abs() <= 5) {
      indicatorColor = AppColors.cta;
    } else if (widget.cents.abs() <= 15) {
      indicatorColor = AppColors.warning;
    } else {
      indicatorColor = AppColors.error;
    }

    // In manual mode, show the cents directly
    // In auto mode, clamp to typical range
    final displayCents = isManualMode ? widget.cents : widget.cents.clamp(-50.0, 50.0);

    return Container(
      width: 280,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceElevated, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center line (in tune position)
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cta,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Center mark
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.cta.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          // Direction labels
          Positioned(
            left: 16,
            child: Icon(Icons.arrow_downward, size: 14, color: AppColors.textMuted),
          ),
          Positioned(
            right: 16,
            child: Icon(Icons.arrow_upward, size: 14, color: AppColors.textMuted),
          ),
          // Tick marks
          const Positioned(
            left: 40,
            child: Text('-50', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ),
          const Positioned(
            child: Text('0', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cta)),
          ),
          const Positioned(
            right: 40,
            child: Text('+50', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ),
          // Pointer
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Transform.translate(
              offset: Offset((displayCents / 50).clamp(-1.0, 1.0) * 110, 0),
              child: Container(
                width: 8,
                height: 44,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(BuildContext context) {
    String status;
    Color color;

    if (widget.errorMessage != null) {
      status = widget.errorMessage!;
      color = AppColors.error;
    } else if (!widget.isListening) {
      status = 'Tap Start to begin';
      color = AppColors.textMuted;
    } else if (widget.frequency <= 0) {
      status = 'Listening...';
      color = AppColors.secondary;
    } else if (widget.isInTune) {
      status = 'In Tune!';
      color = AppColors.cta;
    } else if (widget.cents < -15) {
      status = 'Too flat - tighten string';
      color = AppColors.error;
    } else if (widget.cents > 15) {
      status = 'Too sharp - loosen string';
      color = AppColors.error;
    } else {
      status = 'Almost there...';
      color = AppColors.warning;
    }

    return Text(
      status,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}