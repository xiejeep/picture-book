// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AiSettingsModelAdapter extends TypeAdapter<AiSettingsModel> {
  @override
  final int typeId = 3;

  @override
  AiSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiSettingsModel(
      selectedModel: fields[0] as String,
      speechRate: fields[3] as double,
      useSlowSpeed: fields[4] as bool,
      selectedTextModel: fields[5] as String?,
      ttsEngine: fields[6] as String?,
      supertonicVoice: fields[7] as String?,
      supertonicSteps: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, AiSettingsModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.selectedModel)
      ..writeByte(3)
      ..write(obj.speechRate)
      ..writeByte(4)
      ..write(obj.useSlowSpeed)
      ..writeByte(5)
      ..write(obj.selectedTextModel)
      ..writeByte(6)
      ..write(obj.ttsEngine)
      ..writeByte(7)
      ..write(obj.supertonicVoice)
      ..writeByte(8)
      ..write(obj.supertonicSteps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
