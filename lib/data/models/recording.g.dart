// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordingAdapter extends TypeAdapter<Recording> {
  @override
  final int typeId = 4;

  @override
  Recording read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recording(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      mode: fields[3] as RecordingMode,
      durationSeconds: fields[4] as int,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Recording obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.mode)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecordingModeAdapter extends TypeAdapter<RecordingMode> {
  @override
  final int typeId = 3;

  @override
  RecordingMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecordingMode.audio;
      case 1:
        return RecordingMode.video;
      default:
        return RecordingMode.audio;
    }
  }

  @override
  void write(BinaryWriter writer, RecordingMode obj) {
    switch (obj) {
      case RecordingMode.audio:
        writer.writeByte(0);
        break;
      case RecordingMode.video:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
