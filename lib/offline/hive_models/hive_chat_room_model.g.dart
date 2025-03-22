// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_chat_room_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveChatRoomAdapter extends TypeAdapter<HiveChatRoom> {
  @override
  final int typeId = 1;

  @override
  HiveChatRoom read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveChatRoom(
      id: fields[0] as String,
      currentUserId: fields[1] as String,
      otherUserId: fields[2] as String,
      otherUserName: fields[3] as String,
      otherUserPhotoUrl: fields[4] as String?,
      lastMessage: fields[5] as String?,
      lastMessageTime: fields[6] as DateTime?,
      isOnline: fields[7] as bool,
      unreadCount: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HiveChatRoom obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.currentUserId)
      ..writeByte(2)
      ..write(obj.otherUserId)
      ..writeByte(3)
      ..write(obj.otherUserName)
      ..writeByte(4)
      ..write(obj.otherUserPhotoUrl)
      ..writeByte(5)
      ..write(obj.lastMessage)
      ..writeByte(6)
      ..write(obj.lastMessageTime)
      ..writeByte(7)
      ..write(obj.isOnline)
      ..writeByte(8)
      ..write(obj.unreadCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveChatRoomAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
