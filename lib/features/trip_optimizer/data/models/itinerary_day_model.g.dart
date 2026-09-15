// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'itinerary_day_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItineraryDayModelAdapter extends TypeAdapter<ItineraryDayModel> {
  @override
  final int typeId = 1;

  @override
  ItineraryDayModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItineraryDayModel(
      day: fields[0] as int,
      places: (fields[1] as List).cast<SpotModel>(),
      estimatedWalkingKm: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ItineraryDayModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.day)
      ..writeByte(1)
      ..write(obj.places)
      ..writeByte(2)
      ..write(obj.estimatedWalkingKm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItineraryDayModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
