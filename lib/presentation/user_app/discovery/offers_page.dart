import 'package:flutter/material.dart';

import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../injection_container.dart';
import 'discovery_list_page.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  List<DiscoveryListItem> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    final dataSource = sl<PlacesRemoteDataSource>();

    final cached = dataSource.getCachedActiveOffers();
    if (cached != null && cached.isNotEmpty) {
      final List<DiscoveryListItem> mappedCached = [];
      for (final item in cached) {
        final rawMap = item is Map<String, dynamic>
            ? item
            : (item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{});
        if (rawMap.isNotEmpty) {
          mappedCached.add(DiscoveryDataMapper.fromOffer(rawMap));
        }
      }
      setState(() {
        _items = mappedCached;
        _isLoading = false;
      });
    }

    try {
      final response = await dataSource.getActiveOffers();

      if (!mounted) return;

      final List<DiscoveryListItem> mappedItems = [];
      for (int i = 0; i < response.length; i++) {
        final item = response[i];
        final rawMap = item is Map<String, dynamic>
            ? item
            : item is Map
                ? Map<String, dynamic>.from(item)
                : <String, dynamic>{};

        if (rawMap.isNotEmpty) {
          mappedItems.add(DiscoveryDataMapper.fromOffer(rawMap));
        }
      }

      setState(() {
        _items = mappedItems;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (_items.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load offers from the API.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscoveryListPage(
      title: 'Offers',
      pageKind: DiscoveryPageKind.offer,
      items: _items,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRetry: _loadOffers,
      emptyMessage: 'No active offers are available right now.',
      unavailableActionMessage: 'Offer details are not available right now.',
    );
  }
}
