import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/tuner_provider.dart';
import 'package:guitar_assistant/config/constants.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/l10n/app_localizations.dart';
import 'widgets/tuner_display.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  int? _selectedStringIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
      create: (_) => TunerProvider(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(l10n.tuner),
          centerTitle: true,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Consumer<TunerProvider>(
          builder: (context, provider, child) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Tuner display
                    TunerDisplay(
                      frequency: provider.currentFrequency,
                      detectedNote: provider.detectedNote,
                      cents: provider.cents,
                      nearestStringNote: provider.nearestStringNote,
                      selectedStringNote: _selectedStringIndex != null
                          ? AppConstants.guitarStringNotes[_selectedStringIndex!]
                          : null,
                      targetFrequency: _selectedStringIndex != null
                          ? AppConstants.guitarStringFrequencies[_selectedStringIndex!]
                          : null,
                      isInTune: provider.isInTune,
                      isListening: provider.isListening,
                      errorMessage: provider.errorMessage,
                    ),
                    const Spacer(),
                    // 6 strings - 3 rows x 2 columns
                    // Layout mimics guitar fretboard view (6-5, 4-3, 2-1)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStringRow(provider, [0, 1]), // Strings 6, 5
                        const SizedBox(height: 8),
                        _buildStringRow(provider, [2, 3]), // Strings 4, 3
                        const SizedBox(height: 8),
                        _buildStringRow(provider, [4, 5]), // Strings 2, 1
                      ],
                    ),
                    const Spacer(),
                    // Start/Stop button
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: provider.isListening
                              ? AppColors.error
                              : AppColors.cta,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (provider.isListening) {
                            provider.stopListening();
                            provider.setSelectedString(null);
                            setState(() {
                              _selectedStringIndex = null;
                            });
                          } else {
                            provider.startListening();
                          }
                        },
                        child: Text(
                          provider.isListening ? l10n.stop : l10n.start,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStringRow(TunerProvider provider, List<int> indices) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: indices.map((index) => _buildStringButton(provider, index)).toList(),
    );
  }

  Widget _buildStringButton(TunerProvider provider, int index) {
    // String number (1-6): index 0 = string 6, index 5 = string 1
    final stringNum = 6 - index;
    final noteWithOctave = AppConstants.guitarStringNotes[index];
    final isSelected = _selectedStringIndex == index;
    final isDetected = provider.nearestStringIndex == index;
    final isInTune = isSelected && provider.isInTune && provider.isListening;

    // Determine colors
    Color bgColor;
    Color borderColor;

    if (isInTune) {
      bgColor = AppColors.cta;
      borderColor = AppColors.cta;
    } else if (isDetected && provider.isListening && _selectedStringIndex == null) {
      bgColor = AppColors.warning;
      borderColor = AppColors.warning;
    } else if (isSelected) {
      bgColor = AppColors.secondary;
      borderColor = AppColors.secondary;
    } else {
      bgColor = AppColors.surface;
      borderColor = AppColors.surfaceElevated;
    }

    const size = 72.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle selection - if already selected, deselect
          _selectedStringIndex = _selectedStringIndex == index ? null : index;
        });
        provider.setSelectedString(_selectedStringIndex);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isInTune || isDetected || isSelected ? borderColor : AppColors.surfaceElevated,
            width: 2,
          ),
          boxShadow: [
            if (isSelected || isDetected)
              BoxShadow(
                color: borderColor.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // String visual line (thicker for bass strings)
            Container(
              width: size - 16,
              height: stringNum >= 5 ? 3.5 : (stringNum >= 3 ? 2.5 : 1.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Note with octave
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  noteWithOctave,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isInTune || isDetected || isSelected
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'String $stringNum',
                  style: TextStyle(
                    fontSize: 9,
                    color: isInTune || isDetected || isSelected
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            // Check mark if in tune
            if (isInTune)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: AppColors.cta),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
