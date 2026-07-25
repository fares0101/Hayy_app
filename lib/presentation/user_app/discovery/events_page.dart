import 'package:flutter/material.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../injection_container.dart';
import '../booking/screens/select_date_time_screen.dart';
import 'discovery_list_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<DiscoveryListItem> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final dataSource = sl<PlacesRemoteDataSource>();

    final cached = dataSource.getCachedActiveEvents();
    if (cached != null && cached.isNotEmpty) {
      final List<DiscoveryListItem> mappedCached = [];
      for (final item in cached) {
        final rawMap = item is Map<String, dynamic>
            ? item
            : (item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{});
        if (rawMap.isNotEmpty) {
          mappedCached.add(DiscoveryDataMapper.fromEvent(rawMap));
        }
      }
      setState(() {
        _items = mappedCached;
        _isLoading = false;
      });
    }

    try {
      final response = await dataSource.getActiveEvents();

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
          mappedItems.add(DiscoveryDataMapper.fromEvent(rawMap));
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
          _errorMessage = 'Failed to load events. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscoveryListPage(
      title: 'Events',
      pageKind: DiscoveryPageKind.event,
      items: _items,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRetry: _loadEvents,
      emptyMessage: 'No active events are available right now.',
      unavailableActionMessage: 'Booking is not available for this event.',
      onPrimaryAction: (context, item) => _onBookingTap(context, item),
    );
  }

  void _onBookingTap(BuildContext context, DiscoveryListItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectDateTimeScreen(
          eventId: item.id,
          eventTitle: item.title,
          item: item,
        ),
      ),
    );
  }
}
