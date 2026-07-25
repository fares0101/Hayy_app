import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'add_review_bloc.dart';
import 'add_review_state.dart';

class AddReviewPage extends StatelessWidget {
  const AddReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddReviewBloc(),
      child: const AddReviewView(),
    );
  }
}

class AddReviewView extends StatelessWidget {
  const AddReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Review')),
      body: BlocBuilder<AddReviewBloc, AddReviewState>(
        builder: (context, state) {
          return const Center(
            child: Text('Add Review Placeholder'),
          );
        },
      ),
    );
  }
}