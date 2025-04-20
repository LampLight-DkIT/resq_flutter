import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_alert_page_content_state.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';

class EmergencyAlertPage extends StatelessWidget {
  final EmergencyContact contact;

  const EmergencyAlertPage({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final repository = EmergencyContactsRepository();
    final chatBloc = context.read<ChatBloc>();

    return BlocProvider(
      create: (context) => EmergencyContactsBloc(repository: repository),
      child: EmergencyAlertPageContent(
        contact: contact,
        chatBloc: chatBloc,
      ),
    );
  }
}

class EmergencyAlertPageContent extends StatefulWidget {
  final EmergencyContact contact;
  final ChatBloc chatBloc;

  const EmergencyAlertPageContent({
    super.key,
    required this.contact,
    required this.chatBloc,
  });

  @override
  EmergencyAlertPageContentState createState() =>
      EmergencyAlertPageContentState();
}
