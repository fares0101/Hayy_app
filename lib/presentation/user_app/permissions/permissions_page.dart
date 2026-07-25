import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'permissions_bloc.dart';
import 'permissions_state.dart';

class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PermissionsBloc(),
      child: const PermissionsView(),
    );
  }
}

class PermissionsView extends StatelessWidget {
  const PermissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: BlocBuilder<PermissionsBloc, PermissionsState>(
        builder: (context, state) {
          return const Center(
            child: Text('Permissions Placeholder'),
          );
        },
      ),
    );
  }
}