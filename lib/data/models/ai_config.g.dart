// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AIConfigAdapter extends TypeAdapter<AIConfig> {
  @override
  final int typeId = 5;

  @override
  AIConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AIConfig(
      apiEndpoint: fields[0] as String,
      apiKey: fields[1] as String,
      modelName: fields[2] as String,
      isEnabled: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AIConfig obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.apiEndpoint)
      ..writeByte(1)
      ..write(obj.apiKey)
      ..writeByte(2)
      ..write(obj.modelName)
      ..writeByte(3)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
