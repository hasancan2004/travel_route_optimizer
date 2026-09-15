// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spot_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpotModelAdapter extends TypeAdapter<SpotModel> {
  @override
  final int typeId = 0;

  @override
  SpotModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpotModel(
      name: fields[0] as String,
      category: fields[1] as String,
      rating: fields[2] as double,
      entryFee: fields[3] as double,
      lat: fields[4] as double,
      lng: fields[5] as double,
      calculatedScore: fields[6] as double?,
      imagePath: fields[7] as String?,
      isOutdoor: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SpotModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.rating)
      ..writeByte(3)
      ..write(obj.entryFee)
      ..writeByte(4)
      ..write(obj.lat)
      ..writeByte(5)
      ..write(obj.lng)
      ..writeByte(6)
      ..write(obj.calculatedScore)
      ..writeByte(7)
      ..write(obj.imagePath)
      ..writeByte(8)
      ..write(obj.isOutdoor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
