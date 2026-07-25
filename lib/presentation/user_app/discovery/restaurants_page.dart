import 'package:flutter/material.dart';

import 'place_collection_page.dart';

class RestaurantsPage extends StatelessWidget {
  final List<String> placeIds;

  const RestaurantsPage({
    super.key,
    this.placeIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    return PlaceCollectionPage(
      title: 'Restaurants',
      fallbackSubtitle: 'Restaurant',
      placeIds: placeIds,
      fallbackItems: const [],
      includeUnclassifiedPlaces: true,
      requestedCategoryLabels: const [
        'restaurant',
        'restaurants',
      ],
      categoryKeywords: const ['restaurant', 'food', 'dining', 'eat', 'grill'],
    );
  }
}
