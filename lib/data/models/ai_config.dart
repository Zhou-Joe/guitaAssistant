import 'package:hive/hive.dart';
part 'ai_config.g.dart';

@HiveType(typeId: 5)
class AIConfig extends HiveObject {
  @HiveField(0) String apiEndpoint;
  @HiveField(1) String apiKey;
  @HiveField(2) String modelName;
  @HiveField(3) bool isEnabled;

  AIConfig({this.apiEndpoint = '', this.apiKey = '', this.modelName = '', this.isEnabled = false});

  bool get isConfigured => apiEndpoint.isNotEmpty && apiKey.isNotEmpty && modelName.isNotEmpty;
}
