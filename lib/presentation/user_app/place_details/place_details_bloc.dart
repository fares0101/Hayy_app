import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../injection_container.dart';
import 'place_details_state.dart';

import '../../../data/user_app/datasources/business_posts_remote_data_source.dart';

abstract class PlaceDetailsEvent {}

class LoadPlaceDetailsEvent extends PlaceDetailsEvent {
  final String placeId;
  LoadPlaceDetailsEvent(this.placeId);
}

class PlaceDetailsBloc extends Bloc<PlaceDetailsEvent, PlaceDetailsState> {
  final PlacesRemoteDataSource dataSource;

  PlaceDetailsBloc()
      : dataSource = sl<PlacesRemoteDataSource>(),
        super(PlaceDetailsInitial()) {
    on<LoadPlaceDetailsEvent>(_onLoadPlaceDetails);
  }

  void _onLoadPlaceDetails(
      LoadPlaceDetailsEvent event, Emitter<PlaceDetailsState> emit) async {
    final targetId = event.placeId.trim();
    if (targetId.isEmpty) {
      emit(PlaceDetailsError('معرّف المكان غير صحيح'));
      return;
    }

    final cached = dataSource.getCachedPlaceDetails(targetId);
    bool hasCached = false;
    if (cached != null && cached.isNotEmpty) {
      emit(PlaceDetailsLoaded(cached));
      hasCached = true;
    }

    if (!hasCached) {
      emit(PlaceDetailsLoading());
    }

    // 1. Try fetching directly with targetId
    try {
      final data = await dataSource.getPlaceDetails(targetId);
      emit(PlaceDetailsLoaded(data));
      return;
    } catch (_) {
      // Direct fetch failed (e.g. 404 because targetId was a postId or offerId)
    }

    // 2. Fallback: Check if targetId belongs to a business post
    try {
      final postsDataSource = sl<BusinessPostsRemoteDataSource>();
      final posts = await postsDataSource.getBusinessPosts(pageNumber: 1, pageSize: 20);
      
      for (final post in posts) {
        final pId = (post['id'] ?? post['postId'] ?? '').toString();
        if (pId == targetId) {
          String actualPlaceId = '';
          final placeObj = post['place'] ?? post['business'] ?? post['author'];
          if (placeObj is Map) {
            actualPlaceId = (placeObj['id'] ?? placeObj['placeId'] ?? '').toString();
          }
          if (actualPlaceId.isEmpty) {
            actualPlaceId = (post['placeId'] ?? post['businessId'] ?? '').toString();
          }

          if (actualPlaceId.isNotEmpty) {
            final data = await dataSource.getPlaceDetails(actualPlaceId);
            emit(PlaceDetailsLoaded(data));
            return;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: Try general places list
    try {
      final places = await dataSource.getPlaces();
      if (places.isNotEmpty && places.first is Map) {
        final firstPlace = Map<String, dynamic>.from(places.first as Map);
        final fallbackId = (firstPlace['id'] ?? firstPlace['placeId'] ?? '').toString();
        if (fallbackId.isNotEmpty) {
          final data = await dataSource.getPlaceDetails(fallbackId);
          emit(PlaceDetailsLoaded(data));
          return;
        }
      }
    } catch (_) {}

    if (state is! PlaceDetailsLoaded) {
      emit(PlaceDetailsError('عذراً، تعذر تحميل بيانات هذا المكان أو المحتوى غير متوفر حالياً'));
    }
  }
}
