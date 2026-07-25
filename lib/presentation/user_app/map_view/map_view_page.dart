import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'map_view_bloc.dart';
import 'map_view_state.dart';

class MapViewPage extends StatelessWidget {
  const MapViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapViewBloc(),
      child: const MapViewView(),
    );
  }
}

class MapViewView extends StatelessWidget {
  const MapViewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map View')),
      body: BlocBuilder<MapViewBloc, MapViewState>(
        builder: (context, state) {
          return const Center(
            child: Text('Map View Placeholder'),
          );
        },
      ),
    );
  }
}