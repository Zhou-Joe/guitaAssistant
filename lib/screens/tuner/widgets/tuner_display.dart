import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';

class TunerDisplay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // 目标音符显示
            if (selectedStringNote != null) ...[
              Text(
                '目标：$selectedStringNote',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 检测到的音符
            Text(
              isListening && detectedNote.isNotEmpty ? detectedNote : '--',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: isInTune ? AppColors.success : AppColors.primary,
              ),
            ),
            // 频率显示
            if (isListening && frequency > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${frequency.toStringAsFixed(1)} Hz',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // 音高偏差指示器
            _buildPitchDeviationIndicator(),
            const SizedBox(height: 16),
            // 状态提示
            _buildStatusText(context),
            // 动画环
            if (isListening) ...[
              const SizedBox(height: 16),
              _buildAnimatedRing(),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPitchDeviationIndicator() {
    return Container(
      width: 280,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 中心线
          Container(
            width: 2,
            height: 40,
            color: Colors.grey.shade400,
          ),
          // 中心标记
          const Center(
            child: Text(
              '0',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // 刻度标记
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('-50', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                const SizedBox(width: 60),
                Text('50', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
          // 指针
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            child: Transform.translate(
              offset: Offset((cents / 50).clamp(-1.0, 1.0) * 100, 0),
              child: Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: isInTune ? AppColors.success : AppColors.error,
                  borderRadius: BorderRadius.circular(2),
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

    if (errorMessage != null) {
      status = errorMessage!;
      color = AppColors.error;
    } else if (!isListening) {
      status = '点击"开始调音"开始';
      color = Colors.grey.shade600;
    } else if (frequency <= 0) {
      status = '正在聆听...';
      color = AppColors.primary;
    } else if (isInTune) {
      status = '✓ 音准完美!';
      color = AppColors.success;
    } else if (cents < -30) {
      status = '太松了 - 拧紧';
      color = AppColors.error;
    } else if (cents > 30) {
      status = '太紧了 - 放松';
      color = AppColors.error;
    } else {
      status = '接近了...';
      color = AppColors.warning;
    }

    return Text(
      status,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildAnimatedRing() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 120 * value,
          height: 120 * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isInTune ? AppColors.success : AppColors.primary,
              width: 3,
            ),
          ),
          child: Icon(
            Icons.music_note,
            size: 40 * value,
            color: isInTune ? AppColors.success : AppColors.primary,
          ),
        );
      },
    );
  }
}
