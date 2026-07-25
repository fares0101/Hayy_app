import 'package:flutter/material.dart';

import '../../../data/user_app/datasources/interests_remote_data_source.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../injection_container.dart';
import 'discovery_list_page.dart';

class PlaceCollectionPage extends StatefulWidget {
  final String title;
  final String fallbackSubtitle;
  final List<String> placeIds;
  final List<DiscoveryListItem> fallbackItems;
  final List<String> categoryKeywords;
  final List<String> requestedCategoryLabels;
  final List<String> excludedKeywords;
  final List<String> fallbackSearchTerms;
  final bool includeUnclassifiedPlaces;

  const PlaceCollectionPage({
    super.key,
    required this.title,
    required this.fallbackSubtitle,
    required this.placeIds,
    required this.fallbackItems,
    this.categoryKeywords = const [],
    this.requestedCategoryLabels = const [],
    this.excludedKeywords = const [],
    this.fallbackSearchTerms = const [],
    this.includeUnclassifiedPlaces = false,
  });

  @override
  State<PlaceCollectionPage> createState() => _PlaceCollectionPageState();
}

class _PlaceCollectionPageState extends State<PlaceCollectionPage> {
  List<DiscoveryListItem> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, String> _categoryLookup = const {};

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    final trimmedIds = widget.placeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    final dataSource = sl<PlacesRemoteDataSource>();

    // ── SWR Cached Data Load ─────────────────────────────────────────────────
    if (trimmedIds.isNotEmpty) {
      final List<Map<String, dynamic>> cached = [];
      for (final id in trimmedIds) {
        final detail = dataSource.getCachedPlaceDetails(id);
        if (detail != null && detail.isNotEmpty) {
          cached.add(detail);
        }
      }
      if (cached.isNotEmpty) {
        setState(() {
          _items = cached
              .map((item) => DiscoveryDataMapper.fromPlace(
                    item,
                    fallbackSubtitle: widget.fallbackSubtitle,
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } else {
      final cachedPlaces = dataSource.getCachedPlaces();
      if (cachedPlaces != null && cachedPlaces.isNotEmpty) {
        final maps = cachedPlaces
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        List<Map<String, dynamic>> filteredMaps = [];
        if (widget.categoryKeywords.isEmpty &&
            widget.requestedCategoryLabels.isEmpty &&
            widget.excludedKeywords.isEmpty) {
          filteredMaps = maps;
        } else {
          filteredMaps = maps.where(_matchesRequestedCategory).toList();
        }

        if (filteredMaps.isNotEmpty) {
          setState(() {
            _items = filteredMaps
                .map((item) => DiscoveryDataMapper.fromPlace(
                      item,
                      fallbackSubtitle: widget.fallbackSubtitle,
                    ))
                .toList();
            _isLoading = false;
          });
        }
      }
    }

    try {
      _categoryLookup = await _loadCategoryLookup();
      final responses = trimmedIds.isEmpty
          ? await _loadPlacesFromCollection(dataSource)
          : await _loadPlacesFromIds(dataSource, trimmedIds);

      if (!mounted) return;

      if (responses.isEmpty) {
        if (_items.isEmpty) {
          setState(() {
            _items = widget.fallbackItems;
            _isLoading = false;
            _errorMessage = widget.fallbackItems.isEmpty
                ? 'No ${widget.title.toLowerCase()} available right now.'
                : null;
          });
        }
        return;
      }

      setState(() {
        _items = responses
            .map(
              (item) => DiscoveryDataMapper.fromPlace(
                item,
                fallbackSubtitle: widget.fallbackSubtitle,
              ),
            )
            .toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (_items.isEmpty) {
        setState(() {
          _items = widget.fallbackItems;
          _isLoading = false;
          _errorMessage = widget.fallbackItems.isEmpty
              ? 'Failed to load ${widget.title.toLowerCase()} from the API.'
              : null;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadPlacesFromIds(
    PlacesRemoteDataSource dataSource,
    List<String> ids,
  ) async {
    final responses = await Future.wait(
      ids.map((id) async {
        try {
          return await dataSource.getPlaceDetails(id);
        } catch (_) {
          return null;
        }
      }),
    );

    return responses.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> _loadPlacesFromCollection(
    PlacesRemoteDataSource dataSource,
  ) async {
    final response = await dataSource.getPlaces();
    final maps = response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (widget.categoryKeywords.isEmpty &&
        widget.requestedCategoryLabels.isEmpty &&
        widget.excludedKeywords.isEmpty) {
      return maps;
    }

    final filteredMaps = maps.where(_matchesRequestedCategory).toList();
    if (filteredMaps.isNotEmpty || widget.fallbackSearchTerms.isEmpty) {
      return filteredMaps;
    }

    return _loadPlacesFromSearch(dataSource);
  }

  Future<List<Map<String, dynamic>>> _loadPlacesFromSearch(
    PlacesRemoteDataSource dataSource,
  ) async {
    final resultsById = <String, Map<String, dynamic>>{};

    for (final term in widget.fallbackSearchTerms) {
      final query = term.trim();
      if (query.isEmpty) {
        continue;
      }

      try {
        final response = await dataSource.searchPlaces(query);
        for (final item in response) {
          if (item is! Map) {
            continue;
          }

          final map = Map<String, dynamic>.from(item);
          final id = _extractText(map, const ['id', 'placeId']);
          resultsById[id.isEmpty ? map.toString() : id] = map;
        }
      } catch (_) {
        // Keep trying the remaining search terms.
      }
    }

    return resultsById.values.toList();
  }

  bool _matchesRequestedCategory(Map<String, dynamic> place) {
    final keywords = widget.categoryKeywords
        .map((keyword) => keyword.trim().toLowerCase())
        .where((keyword) => keyword.isNotEmpty)
        .toList();
    final requestedLabels = {
      widget.title.trim().toLowerCase(),
      widget.fallbackSubtitle.trim().toLowerCase(),
      ...widget.requestedCategoryLabels
          .map((label) => label.trim().toLowerCase())
          .where((label) => label.isNotEmpty),
    };
    final excludedKeywords = widget.excludedKeywords
        .map((keyword) => keyword.trim().toLowerCase())
        .where((keyword) => keyword.isNotEmpty)
        .toList();

    if (keywords.isEmpty && requestedLabels.isEmpty) {
      return true;
    }

    final structuredValues = <String>{
      _extractText(place, const [
        'categoryName',
        'type',
        'placeType',
        'mainCategory',
        'subcategory',
      ]),
      ..._resolveCategoryTexts(place),
      ..._collectStructuredTexts(place),
    }..removeWhere((value) => value.trim().isEmpty);

    final searchableValues =
        structuredValues.map((value) => value.toLowerCase()).toSet();

    if (searchableValues.isEmpty) {
      return widget.includeUnclassifiedPlaces;
    }

    final exactCategoryHit = _matchesAnyKeyword(
      values: searchableValues,
      keywords: requestedLabels,
    );
    final keywordHit = _matchesAnyKeyword(
      values: searchableValues,
      keywords: keywords,
    );
    final excludedHit = _matchesAnyKeyword(
      values: searchableValues,
      keywords: excludedKeywords,
    );

    if (exactCategoryHit) {
      return true;
    }

    if (keywordHit && !excludedHit) {
      return true;
    }

    if (keywordHit && excludedHit) {
      return _countKeywordMatches(searchableValues, keywords) >
          _countKeywordMatches(searchableValues, excludedKeywords);
    }

    final identityValues = _collectIdentityTexts(place)
        .map((value) => value.toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();

    if (identityValues.isNotEmpty) {
      final identityKeywordHit = _matchesAnyKeyword(
        values: identityValues,
        keywords: keywords,
      );
      final identityExcludedHit = _matchesAnyKeyword(
        values: identityValues,
        keywords: excludedKeywords,
      );

      if (identityKeywordHit && !identityExcludedHit) {
        return true;
      }

      if (identityKeywordHit && identityExcludedHit) {
        return _countKeywordMatches(identityValues, keywords) >
            _countKeywordMatches(identityValues, excludedKeywords);
      }
    }

    return false;
  }

  bool _matchesAnyKeyword({
    required Set<String> values,
    required Iterable<String> keywords,
  }) {
    for (final value in values) {
      for (final keyword in keywords) {
        if (keyword.isNotEmpty && value.contains(keyword)) {
          return true;
        }
      }
    }

    return false;
  }

  int _countKeywordMatches(Set<String> values, Iterable<String> keywords) {
    var matches = 0;
    for (final value in values) {
      for (final keyword in keywords) {
        if (keyword.isNotEmpty && value.contains(keyword)) {
          matches++;
        }
      }
    }

    return matches;
  }

  Future<Map<String, String>> _loadCategoryLookup() async {
    try {
      final dataSource = sl<InterestsRemoteDataSource>();
      final categories = await dataSource.getInterests();
      return {
        for (final item in categories)
          if ((item['id']?.toString().trim() ?? '').isNotEmpty &&
              (item['name']?.toString().trim() ?? '').isNotEmpty)
            item['id'].toString().trim(): item['name'].toString().trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  String _extractText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    for (final nestedKey in ['data', 'result', 'place', 'item', 'payload']) {
      final nestedValue = map[nestedKey];
      if (nestedValue is Map) {
        final nestedMap = Map<String, dynamic>.from(nestedValue);
        final nestedText = _extractText(nestedMap, keys);
        if (nestedText.isNotEmpty) {
          return nestedText;
        }
      }
    }

    return '';
  }

  Set<String> _resolveCategoryTexts(Map<String, dynamic> place) {
    final values = <String>{};
    const categoryIdKeys = [
      'categoryId',
      'CategoryId',
      'categoryID',
      'mainCategoryId',
      'subcategoryId',
    ];

    for (final key in categoryIdKeys) {
      values.addAll(_lookupCategoryNames(place[key]));
    }

    for (final nestedKey in ['data', 'result', 'place', 'item', 'payload']) {
      final nestedValue = place[nestedKey];
      if (nestedValue is Map) {
        values.addAll(
            _resolveCategoryTexts(Map<String, dynamic>.from(nestedValue)));
      }
    }

    return values;
  }

  Set<String> _lookupCategoryNames(dynamic value) {
    final names = <String>{};

    if (value == null) {
      return names;
    }

    if (value is Iterable) {
      for (final item in value) {
        names.addAll(_lookupCategoryNames(item));
      }
      return names;
    }

    final key = value.toString().trim();
    if (key.isEmpty) {
      return names;
    }

    final mapped = _categoryLookup[key];
    if (mapped != null && mapped.trim().isNotEmpty) {
      names.add(mapped.trim());
    }

    return names;
  }

  Set<String> _collectStructuredTexts(dynamic value, {String parentKey = ''}) {
    final results = <String>{};

    if (value == null) {
      return results;
    }

    if (value is String) {
      final normalizedParent = parentKey.toLowerCase();
      final shouldInclude = normalizedParent.contains('category') ||
          normalizedParent.contains('type') ||
          normalizedParent.contains('tag') ||
          normalizedParent.contains('class');
      final trimmed = value.trim();
      if (shouldInclude && trimmed.isNotEmpty) {
        results.add(trimmed);
      }
      return results;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        results.addAll(
          _collectStructuredTexts(
            entry.value,
            parentKey: entry.key.toString(),
          ),
        );
      }
      return results;
    }

    if (value is Iterable) {
      for (final item in value) {
        results.addAll(_collectStructuredTexts(item, parentKey: parentKey));
      }
      return results;
    }

    return results;
  }

  Set<String> _collectIdentityTexts(Map<String, dynamic> place) {
    final values = <String>{
      _extractText(place, const [
        'name',
        'title',
        'placeName',
        'businessName',
        'displayName',
      ]),
    }..removeWhere((value) => value.trim().isEmpty);

    return values;
  }

  @override
  Widget build(BuildContext context) {
    return DiscoveryListPage(
      title: widget.title,
      pageKind: DiscoveryPageKind.place,
      items: _items,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRetry: _loadPlaces,
      emptyMessage: 'No ${widget.title.toLowerCase()} linked from home yet.',
      unavailableActionMessage:
          '${widget.title} details are not available right now.',
    );
  }
}
