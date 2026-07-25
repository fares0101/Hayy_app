import 'package:flutter/material.dart';

import 'place_collection_page.dart';

class CafesPage extends StatelessWidget {
  final List<String> placeIds;

  const CafesPage({
    super.key,
    this.placeIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    return PlaceCollectionPage(
      title: 'Cafes',
      fallbackSubtitle: 'Cafe',
      placeIds: placeIds,
      fallbackItems: const [],
      fallbackSearchTerms: const [
        'cafe',
        'coffee',
        'كافيه',
      ],
      requestedCategoryLabels: const [
        'cafe',
        'cafes',
        'coffee shop',
        'coffee',
      ],
      categoryKeywords: const [
        'cafe',
        'caffe',
        'café',
        'cafes',
        'coffee',
        'coffee shop',
        'espresso',
        'latte',
        'tea',
        'cappuccino',
        'americano',
        'كافيه',
        'كوفي',
      ],
      excludedKeywords: const [
        'restaurant',
        'restaurants',
        'food',
        'dining',
        'seafood',
        'grill',
      ],
    );
  }
}
