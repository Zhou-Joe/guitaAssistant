import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/tuner_provider.dart';
import 'package:guitar_assistant/config/constants.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'widgets/string_widget.dart';
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
    return ChangeNotifierProvider(
      create: (_) => TunerProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('吉他调音'),
          centerTitle: true,
        ),
        body: Consumer<TunerProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // 调音显示器
                Expanded(
                  flex: 2,
                  child: TunerDisplay(
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
                  ),
                ),
                // 琴弦选择
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background,
                          AppColors.primary.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '点击选择要调的琴弦',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: 6,
                            itemBuilder: (context, index) {
                              final stringNum = 6 - index; // 显示 6,5,4,3,2,1
                              final note = AppConstants.guitarStringNotes[index];
                              final freq = AppConstants.guitarStringFrequencies[index];
                              final isSelected = _selectedStringIndex == index;
                              final isDetected = provider.nearestStringIndex == index;

                              return GuitarStringWidget(
                                stringNumber: stringNum,
                                note: note,
                                frequency: freq,
                                isSelected: isSelected,
                                isDetected: isDetected && provider.isListening,
                                isInTune: isSelected && provider.isInTune && provider.isListening,
                                onTap: () {
                                  setState(() {
                                    _selectedStringIndex = index;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        // 开始/停止按钮
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: provider.isListening
                                    ? AppColors.error
                                    : AppColors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: () {
                                if (provider.isListening) {
                                  provider.stopListening();
                                  setState(() {
                                    _selectedStringIndex = null;
                                  });
                                } else {
                                  provider.startListening();
                                }
                              },
                              child: Text(
                                provider.isListening ? '停止调音' : '开始调音',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
