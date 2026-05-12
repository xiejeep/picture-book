// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PageModelAdapter extends TypeAdapter<PageModel> {
  @override
  final int typeId = 1;

  @override
  PageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PageModel(
      id: fields[0] as String,
      imagePath: fields[1] as String,
      textBlocks: (fields[2] as List).cast<TextBlockModel>(),
      pageIndex: fields[3] as int,
      createdAt: fields[4] as DateTime,
      imageWidth: fields[5] as double,
      imageHeight: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, PageModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.textBlocks)
      ..writeByte(3)
      ..write(obj.pageIndex)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.imageWidth)
      ..writeByte(6)
      ..write(obj.imageHeight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
