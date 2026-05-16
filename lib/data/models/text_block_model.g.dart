// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_block_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TextBlockModelAdapter extends TypeAdapter<TextBlockModel> {
  @override
  final int typeId = 2;

  @override
  TextBlockModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TextBlockModel(
      left: fields[0] as double,
      top: fields[1] as double,
      right: fields[2] as double,
      bottom: fields[3] as double,
      text: fields[4] as String,
      isDeleted: fields[5] as bool,
      translatedText: fields[6] as String?,
      aiTranslatedText: fields[7] as String?,
      originalText: fields[8] as String?,
      aiEnhancedText: fields[9] as String?,
      id: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TextBlockModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.left)
      ..writeByte(1)
      ..write(obj.top)
      ..writeByte(2)
      ..write(obj.right)
      ..writeByte(3)
      ..write(obj.bottom)
      ..writeByte(4)
      ..write(obj.text)
      ..writeByte(5)
      ..write(obj.isDeleted)
      ..writeByte(6)
      ..write(obj.translatedText)
      ..writeByte(7)
      ..write(obj.aiTranslatedText)
      ..writeByte(8)
      ..write(obj.originalText)
      ..writeByte(9)
      ..write(obj.aiEnhancedText)
      ..writeByte(10)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextBlockModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
