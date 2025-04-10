// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_message_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveMessageAdapter extends TypeAdapter<HiveMessage> {
  @override
  final int typeId = 2;

  @override
  HiveMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveMessage(
      id: fields[0] as String,
      senderId: fields[1] as String,
      receiverId: fields[2] as String,
      chatRoomId: fields[3] as String,
      content: fields[4] as String,
      timestamp: fields[5] as DateTime,
      type: fields[6] as HiveMessageType,
      isRead: fields[7] as bool,
      isPending: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveMessage obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderId)
      ..writeByte(2)
      ..write(obj.receiverId)
      ..writeByte(3)
      ..write(obj.chatRoomId)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.isRead)
      ..writeByte(8)
      ..write(obj.isPending);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveMessageTypeAdapter extends TypeAdapter<HiveMessageType> {
  @override
  final int typeId = 0;

  @override
  HiveMessageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HiveMessageType.text;
      case 1:
        return HiveMessageType.image;
      case 2:
        return HiveMessageType.video;
      case 3:
        return HiveMessageType.location;
      case 4:
        return HiveMessageType.document;
      case 5:
        return HiveMessageType.audio;
      case 6:
        return HiveMessageType.emergency;
      default:
        return HiveMessageType.text;
    }
  }

  @override
  void write(BinaryWriter writer, HiveMessageType obj) {
    switch (obj) {
      case HiveMessageType.text:
        writer.writeByte(0);
        break;
      case HiveMessageType.image:
        writer.writeByte(1);
        break;
      case HiveMessageType.video:
        writer.writeByte(2);
        break;
      case HiveMessageType.location:
        writer.writeByte(3);
        break;
      case HiveMessageType.document:
        writer.writeByte(4);
        break;
      case HiveMessageType.audio:
        writer.writeByte(5);
        break;
      case HiveMessageType.emergency:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveMessageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
