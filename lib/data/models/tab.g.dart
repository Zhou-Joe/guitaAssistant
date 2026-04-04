// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TabAdapter extends TypeAdapter<Tab> {
  @override
  final int typeId = 2;

  @override
  Tab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Tab(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      fileType: fields[3] as TabFileType,
      folderId: fields[4] as String,
      tags: (fields[5] as List).cast<String>(),
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
      isFavorite: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Tab obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.fileType)
      ..writeByte(4)
      ..write(obj.folderId)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TabFileTypeAdapter extends TypeAdapter<TabFileType> {
  @override
  final int typeId = 1;

  @override
  TabFileType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TabFileType.pdf;
      case 1:
        return TabFileType.image;
      default:
        return TabFileType.pdf;
    }
  }

  @override
  void write(BinaryWriter writer, TabFileType obj) {
    switch (obj) {
      case TabFileType.pdf:
        writer.writeByte(0);
        break;
      case TabFileType.image:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabFileTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
