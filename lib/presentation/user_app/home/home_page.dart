import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../data/user_app/datasources/business_posts_remote_data_source.dart';
import '../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../data/user_app/datasources/comments_remote_data_source.dart';
import '../../../data/user_app/datasources/favorites_remote_data_source.dart';
import '../../../injection_container.dart';
import '../../../app_router.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../discovery/discovery_list_page.dart';
import 'comments_bottom_sheet.dart';
import 'home_filter_sheet.dart';
import '../../../core/services/signal_r_service.dart';
import '../../../core/utils/image_url_formatter.dart';

class HomePage extends StatefulWidget {
  final ScrollController scrollController;

  const HomePage({super.key, required this.scrollController});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  void handleHomeTabTap() {
    if (widget.scrollController.hasClients &&
        widget.scrollController.offset > 50) {
      widget.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _onRefresh();
    }
  }

  int _selectedCategory = 0;
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _posts = [];
  bool _offersLoading = true;
  bool _postsLoading = true;
  int _postsPage = 1;
  static const int _postsPageSize = 10;
  bool _hasMorePosts = true;
  bool _isLoadingMorePosts = false;
  StreamSubscription<Map<String, dynamic>>? _postSubscription;
  StreamSubscription<dynamic>? _notificationSubscription;
  Timer? _pollTimer;

  // Track which placeIds the user is currently following
  final Set<String> _followingSet = {};
  // Prevent double-tapping while API call is in progress
  final Set<String> _followLoadingSet = {};

  // Track liked post IDs
  final Set<String> _likedSet = {};
  // Prevent double-tap on like
  final Set<String> _likeLoadingSet = {};
  // Local likes counts (updated optimistically)
  final Map<String, int> _likesCountMap = {};
  // Local comments counts (updated when comment added)
  final Map<String, int> _commentsCountMap = {};

  static const List<String> _restaurantPlaceIds = [];
  static const List<String> _cafePlaceIds = [];

  // ── Home Search ────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  int _activeSearchId = 0;
  List<DiscoveryListItem> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  bool _hasSearched = false;
  HomeFilterState _filterState = const HomeFilterState();

  // ── AI Recommendations ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _recommendations = [];
  bool _recommendationsLoading = true;
  String? _recommendationsError;

  final List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.restaurant,
      'label': 'Restaurants',
      'route': AppRoutes.restaurants,
      'arguments':
          const PlaceCollectionRouteArgs(placeIds: _restaurantPlaceIds),
    },
    {
      'icon': Icons.coffee,
      'label': 'Cafes',
      'route': AppRoutes.cafes,
      'arguments': const PlaceCollectionRouteArgs(placeIds: _cafePlaceIds),
    },
    {
      'icon': Icons.event,
      'label': 'Events',
      'route': AppRoutes.events,
    },
    {
      'icon': Icons.local_offer,
      'label': 'Offers',
      'route': AppRoutes.offers,
    },
  ];

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    final currentToken = sl<UserSessionManager>().getToken();
    debugPrint("🔑 CURRENT AUTH ACCESS TOKEN: $currentToken");
    _loadFollowedPlaces();
    _loadOffers();
    _loadPosts();
    _loadRecommendations();

    // Connect to real-time SignalR notifications & subscribe to new posts & notifications stream
    sl<SignalRService>().connect();
    _postSubscription = sl<SignalRService>().postStream.listen((rawPost) {
      _onNewPostReceived(rawPost);
      _pollForNewPosts();
    });
    _notificationSubscription =
        sl<SignalRService>().notificationStream.listen((_) {
      _pollForNewPosts();
    });

    // Fallback: poll for new posts every 30 seconds in case SignalR doesn't push post events
    _pollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _pollForNewPosts());
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _postSubscription?.cancel();
    _notificationSubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    if (_hasSearched) return; // Don't paginated-load recent posts when showing search results

    final threshold = 300.0;
    if (widget.scrollController.position.pixels >=
        widget.scrollController.position.maxScrollExtent - threshold) {
      if (!_postsLoading && !_isLoadingMorePosts && _hasMorePosts) {
        _loadMorePosts();
      }
    }
  }

  // ── Search Logic ────────────────────────────────────────────────────────────
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _activeSearchId++;
      setState(() {
        _isSearching = false;
        _searchError = null;
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _performSearch(trimmed),
    );
  }

  Future<void> _performSearch(String query) async {
    final id = ++_activeSearchId;
    setState(() {
      _isSearching = true;
      _searchError = null;
      _hasSearched = true;
    });
    try {
      final userId = sl<UserSessionManager>().getUser()?.id ?? '';
      final raw = await sl<PlacesRemoteDataSource>().smartSearch(
        userId: userId,
        searchTerm: query,
      );
      if (!mounted || id != _activeSearchId) return;
      final items = raw.map((e) {
        final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
        return DiscoveryDataMapper.fromPlace(m);
      }).toList();
      setState(() {
        _searchResults = items;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || id != _activeSearchId) return;
      setState(() {
        _isSearching = false;
        _searchError = 'Search failed. Please try again.';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _onSearchChanged('');
  }

  List<DiscoveryListItem> get _filteredResults {
    var list = List<DiscoveryListItem>.from(_searchResults);
    if (_filterState.category.isNotEmpty) {
      list = list
          .where(
            (item) => item.subtitle.toLowerCase().contains(
                  _filterState.category.toLowerCase(),
                ),
          )
          .toList();
    }
    if (_filterState.sortBy == 'topRated') {
      list.sort((a, b) {
        final aR = double.tryParse(
              a.detailLine.replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0;
        final bR = double.tryParse(
              b.detailLine.replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0;
        return bR.compareTo(aR);
      });
    }
    return list;
  }

  Future<void> _openFilterSheet() async {
    final result = await HomeFilterSheet.show(
      context,
      current: _filterState,
    );
    if (result != null && mounted) {
      setState(() => _filterState = result);
    }
  }

  // ── Followed Places Initialization ─────────────────────────────────────────
  Future<void> _loadFollowedPlaces() async {
    final dataSource = sl<FavoritesRemoteDataSource>();
    final cached = dataSource.getCachedFavorites();
    if (cached != null) {
      _updateFollowingSet(cached);
    }

    try {
      final results =
          await dataSource.getMyFavorites(pageNumber: 1, pageSize: 200);
      if (!mounted) return;
      _updateFollowingSet(results);
    } catch (_) {
      // Silently fail if unable to fetch
    }
  }

  void _updateFollowingSet(List<Map<String, dynamic>> list) {
    setState(() {
      for (final item in list) {
        final placeData = (item['place'] is Map)
            ? Map<String, dynamic>.from(item['place'] as Map)
            : item;
        final id = item['placeId']?.toString() ??
            placeData['id']?.toString() ??
            placeData['placeId']?.toString();
        if (id != null && id.isNotEmpty) {
          _followingSet.add(id);
        }
      }
    });
  }

  Future<void> _loadOffers() async {
    final dataSource = sl<PlacesRemoteDataSource>();
    final cached = dataSource.getCachedActiveOffers();
    if (cached != null && cached.isNotEmpty) {
      final mappedCached = _mapOffersList(cached);
      setState(() {
        _offers = mappedCached;
        _offersLoading = false;
      });
    }

    try {
      final offers = await dataSource.getActiveOffers();

      if (!mounted) return;

      final mappedOffers = _mapOffersList(offers);
      setState(() {
        _offers = mappedOffers;
        _offersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_offers.isEmpty) {
        setState(() {
          _offers = [];
          _offersLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _mapOffersList(List<dynamic> list) {
    return list.map((o) {
      final item = o is Map<String, dynamic>
          ? o
          : (o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{});

      final String oId =
          _asString(item['id'] ?? item['offerId'] ?? item['offerID']);

      return {
        ...item,
        'id': oId,
        'offerId': oId,
        'title': _asString(
            item['title'] ?? item['offerTitle'] ?? item['placeName']),
        'description':
            _asString(item['description'] ?? item['shortDescription']),
        'badge': _formatOfferBadge(item['badge'] ??
            item['discount'] ??
            item['discountPercentage']),
        'image': ImageUrlFormatter.extractFromMap(item),
        'avatar': ImageUrlFormatter.format(
          item['avatar'] ?? item['logo'] ?? item['placeImage'],
        ),
        'placeId': _asString(item['placeId']),
      };
    }).toList();
  }

  Future<void> _loadPosts() async {
    final savedLikedIds = sl<UserSessionManager>().getLikedPostIds();
    _likedSet.addAll(savedLikedIds);

    final dataSource = sl<BusinessPostsRemoteDataSource>();
    final cached = dataSource.getCachedBusinessPosts(pageNumber: 1, pageSize: 10);
    if (cached != null && cached.isNotEmpty) {
      final mappedCached = _mapPostsListSync(cached);
      setState(() {
        _postsPage = 1;
        _hasMorePosts = cached.length == _postsPageSize;
        _isLoadingMorePosts = false;
        _posts = mappedCached;
        for (final p in mappedCached) {
          final pid = p['id'] as String;
          if (pid.isNotEmpty) {
            _likesCountMap[pid] = p['likes'] as int? ?? 0;
            _commentsCountMap[pid] = p['comments'] as int? ?? 0;
          }
        }
        _postsLoading = false;
      });
    }

    try {
      final posts =
          await dataSource.getBusinessPosts(pageNumber: 1, pageSize: 10);

      final mappedPosts = await _mapPostsListAsync(posts);

      if (!mounted) return;

      setState(() {
        _postsPage = 1;
        _hasMorePosts = posts.length == _postsPageSize;
        _isLoadingMorePosts = false;
        _posts = mappedPosts;
        for (final p in mappedPosts) {
          final pid = p['id'] as String;
          if (pid.isNotEmpty) {
            _likesCountMap[pid] = p['likes'] as int? ?? 0;
            _commentsCountMap[pid] = p['comments'] as int? ?? 0;
          }
        }
        _postsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_posts.isEmpty) {
        setState(() {
          _posts = [];
          _postsLoading = false;
          _hasMorePosts = false;
          _isLoadingMorePosts = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _mapPostsListSync(List<Map<String, dynamic>> posts) {
    return posts.map((item) {
      final postId = _asString(
        item['id'] ?? item['postId'] ?? item['businessPostId'],
      );

      final likesCount = _extractInt(
        item,
        const ['likesCount', 'likeCount', 'totalLikes'],
      );

      final commentsCount = _extractInt(
        item,
        const [
          'commentsCount',
          'commentCount',
          'totalComments',
          'comments',
          'commentList'
        ],
      );

      String placeId = '';
      final placeObj = item['place'] ??
          item['business'] ??
          item['author'] ??
          item['user'];
      if (placeObj is Map) {
        placeId = _asString(placeObj['id'] ??
            placeObj['placeId'] ??
            placeObj['businessId']);
      }
      if (placeId.isEmpty) {
        placeId = _asString(
            item['placeId'] ?? item['businessId'] ?? item['ownerId']);
      }

      final isLikedRaw =
          BusinessPostsRemoteDataSource.extractIsLikedFromMap(item);
      bool isLiked = (isLikedRaw == true) ||
          (postId.isNotEmpty && _likedSet.contains(postId));

      return {
        'id': postId,
        'placeId': placeId.isNotEmpty ? placeId : postId,
        'name': _extractPostAuthorName(item),
        'time': _formatRelativeTime(
          _extractPostValue(
            item,
            const ['createdAt', 'createdOn', 'postedAt', 'date'],
          ),
        ),
        'text': _asString(
          _extractPostValue(
            item,
            const ['content', 'description', 'text', 'caption', 'body'],
          ),
        ),
        'postImage': _extractPostImage(item),
        'avatar': _extractPostAvatar(item),
        'likes': likesCount,
        'comments': commentsCount,
        'isLiked': isLiked,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _mapPostsListAsync(List<Map<String, dynamic>> posts) async {
    final dataSource = sl<BusinessPostsRemoteDataSource>();
    return await Future.wait(
      posts.map((item) async {
        final postId = _asString(
          item['id'] ?? item['postId'] ?? item['businessPostId'],
        );

        int likesCount = _extractInt(
          item,
          const ['likesCount', 'likeCount', 'totalLikes'],
        );

        int commentsCount = _extractInt(
          item,
          const [
            'commentsCount',
            'commentCount',
            'totalComments',
            'comments',
            'commentList'
          ],
        );

        if (postId.isNotEmpty) {
          try {
            final commentsDataSource = sl<CommentsRemoteDataSource>();
            final extraData = await Future.wait([
              dataSource.getPostLikesDetails(postId).catchError(
                  (_) => const PostLikesResult(count: -1, isLiked: null)),
              commentsDataSource
                  .getComments(postId, pageNumber: 1, pageSize: 100)
                  .catchError((_) => <Map<String, dynamic>>[]),
            ]);

            final freshLikesResult = extraData[0] as PostLikesResult;
            if (freshLikesResult.count >= 0) {
              likesCount = freshLikesResult.count;
            }

            if (freshLikesResult.isLiked != null) {
              if (freshLikesResult.isLiked!) {
                _likedSet.add(postId);
                sl<UserSessionManager>().saveLikedPostId(postId);
              } else {
                _likedSet.remove(postId);
                sl<UserSessionManager>().removeLikedPostId(postId);
              }
            }

            final commentsList = extraData[1] as List;
            if (commentsList.isNotEmpty) {
              commentsCount = commentsList.length > commentsCount
                  ? commentsList.length
                  : commentsCount;
            }
          } catch (_) {}
        }

        String placeId = '';
        final placeObj = item['place'] ??
            item['business'] ??
            item['author'] ??
            item['user'];
        if (placeObj is Map) {
          placeId = _asString(placeObj['id'] ??
              placeObj['placeId'] ??
              placeObj['businessId']);
        }
        if (placeId.isEmpty) {
          placeId = _asString(
              item['placeId'] ?? item['businessId'] ?? item['ownerId']);
        }

        final isFollowing =
            item['isFollowing'] ?? item['isFollowed'] ?? item['following'];
        if (isFollowing == true && placeId.isNotEmpty) {
          _followingSet.add(placeId);
        }

        final isLikedRaw =
            BusinessPostsRemoteDataSource.extractIsLikedFromMap(item);
        bool isLiked = (isLikedRaw == true) ||
            (postId.isNotEmpty && _likedSet.contains(postId));
        if (isLikedRaw == false) {
          isLiked = false;
          _likedSet.remove(postId);
          sl<UserSessionManager>().removeLikedPostId(postId);
        } else if (isLiked && postId.isNotEmpty) {
          _likedSet.add(postId);
          sl<UserSessionManager>().saveLikedPostId(postId);
        }

        return {
          'id': postId,
          'placeId': placeId.isNotEmpty ? placeId : postId,
          'name': _extractPostAuthorName(item),
          'time': _formatRelativeTime(
            _extractPostValue(
              item,
              const ['createdAt', 'createdOn', 'postedAt', 'date'],
            ),
          ),
          'text': _asString(
            _extractPostValue(
              item,
              const ['content', 'description', 'text', 'caption', 'body'],
            ),
          ),
          'postImage': _extractPostImage(item),
          'avatar': _extractPostAvatar(item),
          'likes': likesCount,
          'comments': commentsCount,
          'isLiked': isLiked,
        };
      }),
    );
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMorePosts || !_hasMorePosts) return;

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      final nextPage = _postsPage + 1;
      final dataSource = sl<BusinessPostsRemoteDataSource>();
      final posts = await dataSource.getBusinessPosts(
        pageNumber: nextPage,
        pageSize: _postsPageSize,
      );

      if (posts.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMorePosts = false;
            _isLoadingMorePosts = false;
          });
        }
        return;
      }

      final mappedPosts = await Future.wait(
        posts.map((item) async {
          final postId = _asString(
            item['id'] ?? item['postId'] ?? item['businessPostId'],
          );

          int likesCount = _extractInt(
            item,
            const ['likesCount', 'likeCount', 'totalLikes'],
          );

          int commentsCount = _extractInt(
            item,
            const [
              'commentsCount',
              'commentCount',
              'totalComments',
              'comments',
              'commentList'
            ],
          );

          if (postId.isNotEmpty) {
            final commentsDataSource = sl<CommentsRemoteDataSource>();
            final extraData = await Future.wait([
              dataSource.getPostLikesDetails(postId).catchError(
                  (_) => const PostLikesResult(count: -1, isLiked: null)),
              commentsDataSource
                  .getComments(postId, pageNumber: 1, pageSize: 100)
                  .catchError((_) => <Map<String, dynamic>>[]),
            ]);

            final freshLikesResult = extraData[0] as PostLikesResult;
            if (freshLikesResult.count >= 0) {
              likesCount = freshLikesResult.count;
            }

            if (freshLikesResult.isLiked != null) {
              if (freshLikesResult.isLiked!) {
                _likedSet.add(postId);
                sl<UserSessionManager>().saveLikedPostId(postId);
              } else {
                _likedSet.remove(postId);
                sl<UserSessionManager>().removeLikedPostId(postId);
              }
            }

            final commentsList = extraData[1] as List;
            if (commentsList.isNotEmpty) {
              commentsCount = commentsList.length > commentsCount
                  ? commentsList.length
                  : commentsCount;
            }
          }

          // Extract placeId for the Follow toggle API
          String placeId = '';
          final placeObj = item['place'] ??
              item['business'] ??
              item['author'] ??
              item['user'];
          if (placeObj is Map) {
            placeId = _asString(placeObj['id'] ??
                placeObj['placeId'] ??
                placeObj['businessId']);
          }
          if (placeId.isEmpty) {
            placeId = _asString(
                item['placeId'] ?? item['businessId'] ?? item['ownerId']);
          }

          // Check if already following
          final isFollowing =
              item['isFollowing'] ?? item['isFollowed'] ?? item['following'];
          if (isFollowing == true && placeId.isNotEmpty) {
            _followingSet.add(placeId);
          }

          // Check if already liked
          final isLikedRaw =
              BusinessPostsRemoteDataSource.extractIsLikedFromMap(item);
          bool isLiked = (isLikedRaw == true) ||
              (postId.isNotEmpty && _likedSet.contains(postId));
          if (isLikedRaw == false) {
            isLiked = false;
            _likedSet.remove(postId);
            sl<UserSessionManager>().removeLikedPostId(postId);
          } else if (isLiked && postId.isNotEmpty) {
            _likedSet.add(postId);
            sl<UserSessionManager>().saveLikedPostId(postId);
          }

          return {
            'id': postId,
            'placeId': placeId.isNotEmpty ? placeId : postId,
            'name': _extractPostAuthorName(item),
            'time': _formatRelativeTime(
              _extractPostValue(
                item,
                const ['createdAt', 'createdOn', 'postedAt', 'date'],
              ),
            ),
            'text': _asString(
              _extractPostValue(
                item,
                const ['content', 'description', 'text', 'caption', 'body'],
              ),
            ),
            'postImage': _extractPostImage(item),
            'avatar': _extractPostAvatar(item),
            'likes': likesCount,
            'comments': commentsCount,
            'isLiked': isLiked,
          };
        }),
      );

      if (!mounted) return;

      setState(() {
        _postsPage = nextPage;
        final existingIds = _posts.map((p) => p['id'] as String).toSet();
        final newMapped = mappedPosts
            .where((p) => !existingIds.contains(p['id'] as String))
            .toList();
        _posts.addAll(newMapped);

        for (final p in newMapped) {
          final pid = p['id'] as String;
          if (pid.isNotEmpty) {
            _likesCountMap[pid] = p['likes'] as int? ?? 0;
            _commentsCountMap[pid] = p['comments'] as int? ?? 0;
          }
        }
        _hasMorePosts = posts.length == _postsPageSize;
        _isLoadingMorePosts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  void _onNewPostReceived(Map<String, dynamic> rawPost) {
    if (!mounted) return;

    // 1. Unwrap nested map if post data is inside data/post/item/result/payload/value
    Map<String, dynamic> targetPost = rawPost;
    for (final key in ['data', 'post', 'item', 'result', 'payload', 'value']) {
      if (rawPost[key] is Map) {
        targetPost = Map<String, dynamic>.from(rawPost[key] as Map);
        break;
      }
    }

    final postId = _asString(
      targetPost['id'] ??
          targetPost['postId'] ??
          targetPost['postID'] ??
          targetPost['businessPostId'] ??
          rawPost['id'] ??
          rawPost['postId'] ??
          rawPost['postID'],
    );

    final finalPostId = postId.isNotEmpty
        ? postId
        : 'post_${DateTime.now().millisecondsSinceEpoch}';

    // Avoid duplicate posts if it's already in our list
    final alreadyExists = _posts.any((p) => p['id'] == finalPostId);
    if (alreadyExists) return;

    // Extract fields
    int likesCount = _extractInt(
      targetPost,
      const ['likesCount', 'likeCount', 'totalLikes'],
    );
    int commentsCount = _extractInt(
      targetPost,
      const ['commentsCount', 'commentCount', 'totalComments'],
    );

    String placeId = '';
    final placeObj = targetPost['place'] ??
        targetPost['business'] ??
        targetPost['author'] ??
        targetPost['user'] ??
        rawPost['place'] ??
        rawPost['business'];

    if (placeObj is Map) {
      placeId = _asString(
          placeObj['id'] ?? placeObj['placeId'] ?? placeObj['businessId']);
    }
    if (placeId.isEmpty) {
      placeId = _asString(targetPost['placeId'] ??
          targetPost['businessId'] ??
          targetPost['ownerId'] ??
          rawPost['placeId'] ??
          rawPost['businessId']);
    }

    final authorName = _extractPostAuthorName(targetPost).isNotEmpty
        ? _extractPostAuthorName(targetPost)
        : _extractPostAuthorName(rawPost);

    final postMap = {
      'id': finalPostId,
      'placeId': placeId.isNotEmpty ? placeId : finalPostId,
      'name': authorName.isNotEmpty ? authorName : 'Community Post',
      'time': _formatRelativeTime(
        _extractPostValue(
          targetPost,
          const ['createdAt', 'createdOn', 'postedAt', 'date', 'time'],
        ),
      ),
      'text': _asString(
        _extractPostValue(
          targetPost,
          const [
            'content',
            'description',
            'text',
            'caption',
            'body',
            'message'
          ],
        ),
      ),
      'postImage': _extractPostImage(targetPost).isNotEmpty
          ? _extractPostImage(targetPost)
          : _extractPostImage(rawPost),
      'avatar': _extractPostAvatar(targetPost).isNotEmpty
          ? _extractPostAvatar(targetPost)
          : _extractPostAvatar(rawPost),
      'likes': likesCount,
      'comments': commentsCount,
    };

    setState(() {
      _posts.insert(0, postMap);
      _postsLoading = false;
    });

    // Check if the user is following the place that published this post!
    final isFollowed = _followingSet.contains(postMap['placeId']);
    if (isFollowed) {
      _showLocalPostNotification(postMap);
    }
  }

  /// Silently polls the API for any new posts not already in the list.
  /// Acts as a fallback when the backend doesn't push post events via SignalR.
  Future<void> _pollForNewPosts() async {
    if (!mounted) return;

    try {
      final dataSource = sl<BusinessPostsRemoteDataSource>();
      final latestPosts =
          await dataSource.getBusinessPosts(pageNumber: 1, pageSize: 5);

      if (!mounted || latestPosts.isEmpty) return;

      // Collect existing post IDs
      final existingIds = _posts.map((p) => p['id']?.toString() ?? '').toSet();

      // Find genuinely new posts
      final newPosts = <Map<String, dynamic>>[];
      for (final item in latestPosts) {
        final postId =
            _asString(item['id'] ?? item['postId'] ?? item['businessPostId']);
        if (postId.isEmpty || existingIds.contains(postId)) continue;

        // Extract placeId
        String placeId = '';
        final placeObj =
            item['place'] ?? item['business'] ?? item['author'] ?? item['user'];
        if (placeObj is Map) {
          placeId = _asString(
              placeObj['id'] ?? placeObj['placeId'] ?? placeObj['businessId']);
        }
        if (placeId.isEmpty) {
          placeId = _asString(
              item['placeId'] ?? item['businessId'] ?? item['ownerId']);
        }

        int likesCount =
            _extractInt(item, const ['likesCount', 'likeCount', 'totalLikes']);
        int commentsCount = _extractInt(
            item, const ['commentsCount', 'commentCount', 'totalComments']);

        newPosts.add({
          'id': postId,
          'placeId': placeId.isNotEmpty ? placeId : postId,
          'name': _extractPostAuthorName(item),
          'time': _formatRelativeTime(
            _extractPostValue(
                item, const ['createdAt', 'createdOn', 'postedAt', 'date']),
          ),
          'text': _asString(
            _extractPostValue(item,
                const ['content', 'description', 'text', 'caption', 'body']),
          ),
          'postImage': _extractPostImage(item),
          'avatar': _extractPostAvatar(item),
          'likes': likesCount,
          'comments': commentsCount,
        });
      }

      if (newPosts.isNotEmpty && mounted) {
        setState(() {
          // Prepend new posts at the top
          _posts.insertAll(0, newPosts);
        });

        // Show notification for followed places
        for (final postMap in newPosts) {
          if (_followingSet.contains(postMap['placeId'])) {
            _showLocalPostNotification(postMap);
            break; // Only show one notification per poll cycle
          }
        }
      }
    } catch (_) {
      // Silent failure - this is a background poll
    }
  }

  void _showLocalPostNotification(Map<String, dynamic> postMap) {
    final placeName = postMap['name'] ?? 'مكان تابعه';
    final textContent = postMap['text'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'منشور جديد من $placeName!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (textContent.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      textContent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF641C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'عرض',
          textColor: Colors.white,
          onPressed: () {
            widget.scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_hasSearched && _searchController.text.isNotEmpty) {
      await _performSearch(_searchController.text);
    } else {
      await Future.wait([
        _loadFollowedPlaces(),
        _loadOffers(),
        _loadPosts(),
        _loadRecommendations(),
      ]);
    }
    HapticFeedback.mediumImpact();
  }

  Future<void> _toggleFollow(String placeId) async {
    if (placeId.isEmpty) return;
    if (_followLoadingSet.contains(placeId)) return;

    setState(() => _followLoadingSet.add(placeId));

    // Optimistic update
    final wasFollowing = _followingSet.contains(placeId);
    final targetState = !wasFollowing;
    setState(() {
      if (targetState) {
        _followingSet.add(placeId);
      } else {
        _followingSet.remove(placeId);
      }
    });

    try {
      final dataSource = sl<PlacesRemoteDataSource>();
      final serverBool = await dataSource.toggleFollowPlace(placeId);
      // Sync with actual server response if returned
      if (mounted) {
        final finalState = serverBool ?? targetState;
        final stateChanged = wasFollowing != finalState;
        setState(() {
          if (finalState) {
            _followingSet.add(placeId);
          } else {
            _followingSet.remove(placeId);
          }
        });
        if (stateChanged) {
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      // Revert on failure
      if (!mounted) return;
      setState(() {
        if (wasFollowing) {
          _followingSet.add(placeId);
        } else {
          _followingSet.remove(placeId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update follow status: ${e.toString()}'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _followLoadingSet.remove(placeId));
    }
  }

  Future<void> _toggleLike(String postId, String postTitle) async {
    if (postId.isEmpty) return;
    if (_likeLoadingSet.contains(postId)) return;

    setState(() => _likeLoadingSet.add(postId));

    // Optimistic update
    final wasLiked = _likedSet.contains(postId);
    final currentCount = _likesCountMap[postId] ?? 0;
    setState(() {
      if (wasLiked) {
        _likedSet.remove(postId);
        _likesCountMap[postId] = (currentCount - 1).clamp(0, 9999);
      } else {
        _likedSet.add(postId);
        _likesCountMap[postId] = currentCount + 1;
      }
    });

    if (wasLiked) {
      sl<UserSessionManager>().removeLikedPostId(postId);
    } else {
      sl<UserSessionManager>().saveLikedPostId(postId);
    }

    try {
      final dataSource = sl<BusinessPostsRemoteDataSource>();
      final result = await dataSource.toggleLike(postId, title: postTitle);
      if (!mounted) return;
      final finalIsLiked = result.isLiked ?? !wasLiked;
      final stateChanged = wasLiked != finalIsLiked;
      setState(() {
        if (result.count >= 0) {
          _likesCountMap[postId] = result.count;
        }
        if (result.isLiked != null) {
          if (result.isLiked!) {
            _likedSet.add(postId);
            sl<UserSessionManager>().saveLikedPostId(postId);
          } else {
            _likedSet.remove(postId);
            sl<UserSessionManager>().removeLikedPostId(postId);
          }
        }
      });
      if (stateChanged) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      // Revert on failure
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedSet.add(postId);
        } else {
          _likedSet.remove(postId);
        }
        _likesCountMap[postId] = currentCount;
      });
      if (wasLiked) {
        sl<UserSessionManager>().saveLikedPostId(postId);
      } else {
        sl<UserSessionManager>().removeLikedPostId(postId);
      }
    } finally {
      if (mounted) setState(() => _likeLoadingSet.remove(postId));
    }
  }

  void _onOfferTap(Map<String, dynamic> offer) {
    final offerId = _asString(offer['offerId'] ?? offer['id']);
    if (offerId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.offerDetails,
        arguments: offer,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer ID is missing.')),
    );
  }

  void _onCategoryTap(int index) {
    setState(() => _selectedCategory = index);

    final route = _categories[index]['route'] as String?;
    if (route != null) {
      Navigator.pushNamed(
        context,
        route,
        arguments: _categories[index]['arguments'],
      );
    }
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String _formatOfferBadge(dynamic value) {
    final text = _asString(value);
    if (text.isEmpty) {
      return '';
    }

    if (text.contains('%')) {
      return text;
    }

    final parsed = num.tryParse(text);
    if (parsed != null) {
      final normalized =
          parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
      return '$normalized%';
    }

    return text;
  }

  dynamic _extractPostValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        return value;
      }
    }

    for (final nestedKey in ['business', 'place', 'user', 'data', 'result']) {
      final nested = map[nestedKey];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(nested);
        for (final key in keys) {
          final value = nestedMap[key];
          if (value != null) {
            return value;
          }
        }
      }
    }

    return null;
  }

  String _extractPostAuthorName(Map<String, dynamic> map) {
    return _asString(
      _extractPostValue(
        map,
        const [
          'businessName',
          'name',
          'placeName',
          'userName',
          'authorName',
          'title',
        ],
      ),
    ).isEmpty
        ? 'Business Post'
        : _asString(
            _extractPostValue(
              map,
              const [
                'businessName',
                'name',
                'placeName',
                'userName',
                'authorName',
                'title',
              ],
            ),
          );
  }

  bool _isValidImageUrl(String url) {
    final trimmed = url.trim().toLowerCase();
    if (trimmed.isEmpty ||
        trimmed == 'null' ||
        trimmed == 'undefined' ||
        trimmed == 'placeholder' ||
        trimmed.contains('placeholder') ||
        trimmed == 'none') {
      return false;
    }
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/');
  }

  DateTime? _parseDateTimeUtc(String text) {
    if (text.isEmpty) return null;
    final hasTimezone =
        text.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
    if (hasTimezone) {
      return DateTime.tryParse(text);
    } else {
      String normalized = text.trim();
      if (normalized.contains(' ')) {
        normalized = normalized.replaceAll(' ', 'T');
      }
      if (normalized.contains(':')) {
        normalized = '${normalized}Z';
      }
      return DateTime.tryParse(normalized) ?? DateTime.tryParse(text);
    }
  }

  String _extractPostImage(Map<String, dynamic> map) {
    return ImageUrlFormatter.extractFromMap(map);
  }

  String _extractPostAvatar(Map<String, dynamic> map) {
    // 1. Look inside nested publisher/place object FIRST for CoverImage or logo
    final placeObj = map['place'] ??
        map['business'] ??
        map['author'] ??
        map['publisher'] ??
        map['user'];
    if (placeObj is Map) {
      final placeMap = Map<String, dynamic>.from(placeObj);

      // Ensure the avatar exactly matches the cover/main image extracted in PlaceDetailsPage!
      final placeImg = ImageUrlFormatter.extractFromMap(placeMap);
      if (placeImg.isNotEmpty) return placeImg;

      final cover = ImageUrlFormatter.format(
        placeMap['CoverImage'] ??
            placeMap['coverImage'] ??
            placeMap['cover_image'] ??
            placeMap['Cover'] ??
            placeMap['cover'] ??
            placeMap['coverUrl'] ??
            placeMap['coverPath'] ??
            placeMap['logo'] ??
            placeMap['logoUrl'] ??
            placeMap['avatar'] ??
            placeMap['profileImage'],
      );
      if (cover.isNotEmpty) return cover;
    }

    // 2. Look for explicit CoverImage / place cover keys directly on main map
    final directCover = ImageUrlFormatter.format(
      map['CoverImage'] ??
          map['coverImage'] ??
          map['cover_image'] ??
          map['Cover'] ??
          map['cover'] ??
          map['coverUrl'] ??
          map['coverPath'] ??
          map['placeCover'] ??
          map['businessCover'] ??
          map['publisherCover'] ??
          map['placeLogo'] ??
          map['businessLogo'] ??
          map['logo'] ??
          map['avatar'],
    );
    if (directCover.isNotEmpty) return directCover;

    return '';
  }

  int _extractInt(Map<String, dynamic> map, List<String> keys) {
    final value = _extractPostValue(map, keys);

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }

    if (value is List) {
      return value.length;
    }

    return 0;
  }

  String _formatRelativeTime(dynamic value) {
    final text = _asString(value);
    if (text.isEmpty) {
      return 'Recently';
    }

    final parsed = _parseDateTimeUtc(text);
    if (parsed == null) {
      return text;
    }

    final now = DateTime.now();
    final difference = now.difference(parsed.toLocal());

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "min" : "mins"} ago';
    }
    if (difference.inHours < 24) {
      final hrs = difference.inHours;
      return '$hrs ${hrs == 1 ? "hour" : "hours"} ago';
    }
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    }

    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFFF641A),
        backgroundColor: Colors.white,
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Search App Bar ───────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0,
              toolbarHeight: 64,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Search Field
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search restaurants, cafes, events...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13.5,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: _clearSearch,
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey.shade500,
                                      size: 18,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          textInputAction: TextInputAction.search,
                          onChanged: (v) {
                            _onSearchChanged(v);
                            setState(() {});
                          },
                          onSubmitted: (v) => _performSearch(v.trim()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Filter Button with badge
                    GestureDetector(
                      onTap: _openFilterSheet,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: _filterState.hasActiveFilters
                                  ? const Color(0xFFFF641A)
                                  : const Color(0xFFF5F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: _filterState.hasActiveFilters
                                  ? Colors.white
                                  : const Color(0xFFFF641A),
                              size: 22,
                            ),
                          ),
                          if (_filterState.hasActiveFilters)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A1A),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_filterState.activeCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content: Search Results OR Home Feed ─────────────────────────────
            SliverToBoxAdapter(
              child: _hasSearched
                  ? _buildSearchResultsSection()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        _buildCategories(sw),
                        const SizedBox(height: 22),
                        _buildSectionHeader(
                            'Special Offers', Icons.local_offer_rounded),
                        const SizedBox(height: 12),
                        _buildOffersCarousel(sw, sh),
                        const SizedBox(height: 26),
                        _buildSectionHeader(
                            'Recommended For You', Icons.auto_awesome_rounded,
                            isAi: true),
                        const SizedBox(height: 12),
                        _buildNearestToYou(sw, sh),
                        const SizedBox(height: 26),
                        _buildSectionHeader(
                            'Recent Posts', Icons.dynamic_feed_rounded),
                        const SizedBox(height: 12),
                        _buildRecentPosts(sw, sh),
                        const SizedBox(height: 90),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header Builder ───────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon, {bool isAi = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF8C50), Color(0xFFFF641A)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          if (isAi) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF641A), Color(0xFFFF9A3C)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF641A).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 11),
                  SizedBox(width: 3),
                  Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Results Section ───────────────────────────────────────────────────

  Widget _buildSearchResultsSection() {
    if (_isSearching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: ShimmerLoading.buildHorizontalCardList(
            cardWidth: MediaQuery.of(context).size.width * 0.4,
            cardHeight: 180),
      );
    }

    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _searchError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _performSearch(_searchController.text),
              child: const Text(
                'Retry',
                style: TextStyle(color: Color(0xFFFF641A)),
              ),
            ),
          ],
        ),
      );
    }

    final results = _filteredResults;

    // Active filter chips (shown when searching)
    final filterChips = _buildActiveFilterChips();

    if (results.isEmpty) {
      return Column(
        children: [
          if (filterChips != null) filterChips,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 70),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text(
                  'No results found',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try adjusting your search or filters',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filterChips != null) filterChips,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${results.length} result${results.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = results[index];
            return DiscoveryCard(
              item: item,
              pageKind: DiscoveryPageKind.place,
              onPrimaryAction: () {
                if (item.actionRoute != null) {
                  Navigator.pushNamed(
                    context,
                    item.actionRoute!,
                    arguments: item.actionArguments ?? item.id,
                  );
                }
              },
              onSecondaryAction: () {},
            );
          },
        ),
      ],
    );
  }

  Widget? _buildActiveFilterChips() {
    if (!_filterState.hasActiveFilters) return null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          if (_filterState.category.isNotEmpty)
            _ActiveFilterPill(
              label: _filterState.category,
              onRemove: () => setState(
                () => _filterState = _filterState.copyWith(category: ''),
              ),
            ),
          if (_filterState.sortBy.isNotEmpty)
            _ActiveFilterPill(
              label: _filterState.sortBy == 'topRated'
                  ? 'Top Rated'
                  : _filterState.sortBy == 'newest'
                      ? 'Newest'
                      : 'Most Popular',
              onRemove: () => setState(
                () => _filterState = _filterState.copyWith(sortBy: ''),
              ),
            ),
          if (_filterState.openNow)
            _ActiveFilterPill(
              label: 'Open Now',
              onRemove: () => setState(
                () => _filterState = _filterState.copyWith(openNow: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategories(double sw) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_categories.length, (i) {
          final selected = i == _selectedCategory;
          final Color chipColor;
          switch (i) {
            case 0:
              chipColor = const Color(0xFFFF641A);
              break;
            case 1:
              chipColor = const Color(0xFF7B4F2E);
              break;
            case 2:
              chipColor = const Color(0xFF6B3FA0);
              break;
            default:
              chipColor = const Color(0xFF2E8B57);
          }
          return GestureDetector(
            onTap: () => _onCategoryTap(i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? chipColor : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? chipColor : Colors.grey.shade300,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _categories[i]['icon'] as IconData,
                    size: 15,
                    color: selected ? Colors.white : chipColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _categories[i]['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOffersCarousel(double sw, double sh) {
    final cardW = sw * 0.40;
    final cardH = sh * 0.28;

    if (_offersLoading) {
      return SizedBox(
        height: cardH,
        child: ShimmerLoading.buildHorizontalCardList(
            cardWidth: cardW, cardHeight: cardH),
      );
    }

    if (_offers.isEmpty) {
      return SizedBox(
        height: cardH,
        child: Center(
          child: Text(
            'No offers available',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return SizedBox(
      height: cardH,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _offers.length,
        itemBuilder: (context, i) {
          final offer = _offers[i];
          final String imageUrl = offer['image'] as String? ?? '';

          return GestureDetector(
            onTap: () => _onOfferTap(offer),
            child: Container(
              width: cardW,
              margin: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(color: Colors.grey.shade800);
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white38,
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.local_offer_outlined,
                              color: Colors.white38,
                              size: 28,
                            ),
                          ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0xCC000000),
                          ],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF641A),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          offer['badge']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ClipOval(
                              child: (offer['avatar'] as String? ?? '')
                                      .isNotEmpty
                                  ? Image.network(
                                      ImageUrlFormatter.format(offer['avatar']),
                                      width: 30,
                                      height: 30,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 30,
                                        height: 30,
                                        color: Colors.white24,
                                        child: const Icon(Icons.person,
                                            size: 18, color: Colors.white),
                                      ),
                                    )
                                  : Container(
                                      width: 30,
                                      height: 30,
                                      color: Colors.white24,
                                      child: const Icon(Icons.person,
                                          size: 18, color: Colors.white),
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    offer['title'] as String? ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                  Text(
                                    offer['description'] as String? ?? '',
                                    style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadRecommendations() async {
    final userId = sl<UserSessionManager>().getUser()?.id ?? '';
    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          _recommendationsLoading = false;
          _recommendationsError = null;
          _recommendations = [];
        });
      }
      return;
    }

    final dataSource = sl<PlacesRemoteDataSource>();
    final cached = dataSource.getCachedRecommendations(userId);
    if (cached != null && cached.isNotEmpty) {
      final mappedCached = await _mapRecommendations(cached);
      setState(() {
        _recommendations = mappedCached;
        _recommendationsLoading = false;
        _recommendationsError = null;
      });
    }

    try {
      final raw = await dataSource.getRecommendations(userId);
      final mapped = await _mapRecommendations(raw);

      if (!mounted) return;

      setState(() {
        _recommendations = mapped;
        _recommendationsLoading = false;
        _recommendationsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_recommendations.isEmpty) {
        setState(() {
          _recommendations = [];
          _recommendationsLoading = false;
          _recommendationsError = 'Failed to load recommendations';
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _mapRecommendations(List<dynamic> raw) async {
    final dataSource = sl<PlacesRemoteDataSource>();
    final mapped = <Map<String, dynamic>>[];
    final placeCache = <String, Map<String, dynamic>>{};

    for (final e in raw) {
      final recItem =
          e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final embeddedPlace = recItem['place'] is Map
          ? Map<String, dynamic>.from(recItem['place'])
          : (recItem['placeDetails'] is Map
              ? Map<String, dynamic>.from(recItem['placeDetails'])
              : null);

      final target = embeddedPlace ?? recItem;
      final placeId = _asString(
        target['placeId'] ??
            target['id'] ??
            target['place_id'] ??
            recItem['placeId'] ??
            recItem['id'],
      );

      Map<String, dynamic> details = target;
      if (placeId.isNotEmpty) {
        final cachedDetails = dataSource.getCachedPlaceDetails(placeId);
        if (cachedDetails != null && cachedDetails.isNotEmpty) {
          details = cachedDetails;
        } else if (placeCache.containsKey(placeId)) {
          details = placeCache[placeId]!;
        } else {
          try {
            final fetched = await dataSource.getPlaceDetails(placeId);
            if (fetched.isNotEmpty) {
              placeCache[placeId] = fetched;
              details = fetched;
            }
          } catch (_) {
            details = target;
          }
        }
      }

      final placeName = _asString(
        details['name'] ??
            details['placeName'] ??
            details['title'] ??
            target['name'] ??
            target['title'] ??
            recItem['title'] ??
            'Recommended Place',
      );

      final imgUrl = ImageUrlFormatter.extractFromMap(details).isNotEmpty
          ? ImageUrlFormatter.extractFromMap(details)
          : (ImageUrlFormatter.extractFromMap(target).isNotEmpty
              ? ImageUrlFormatter.extractFromMap(target)
              : ImageUrlFormatter.extractFromMap(recItem));

      String realRating = _extractRealRatingHelper(details);
      if (realRating.isEmpty) {
        realRating = _extractRealRatingHelper(target);
      }

      mapped.add({
        ...recItem,
        'id': placeId.isNotEmpty ? placeId : _asString(details['id']),
        'placeId': placeId.isNotEmpty ? placeId : _asString(details['id']),
        'name': placeName,
        'type': _asString(
          details['categoryName'] ??
              details['category'] ??
              details['type'] ??
              details['placeType'] ??
              target['categoryName'] ??
              '',
        ),
        'rating': realRating,
        'image': imgUrl,
        'imageUrl': imgUrl,
        'location': _asString(
          details['address'] ??
              details['location'] ??
              details['city'] ??
              details['district'] ??
              target['address'] ??
              '',
        ),
        'workingHours': _asString(
          details['workingHours'] ??
              details['openHours'] ??
              target['workingHours'] ??
              '',
        ),
        'status': _asString(details['status'] ??
            details['tagline'] ??
            target['status'] ??
            ''),
        'description': _asString(
          details['description'] ??
              details['shortDescription'] ??
              target['description'] ??
              '',
        ),
      });
    }
    return mapped;
  }

  String _extractRealRatingHelper(Map<String, dynamic> source) {
    final rawVal = source['rating'] ??
        source['averageRating'] ??
        source['averageRate'] ??
        source['rate'] ??
        source['overallRating'] ??
        source['totalRating'];

    if (rawVal == null) return '';
    if (rawVal is num) {
      if (rawVal <= 0.0 || rawVal <= 1.0) return '';
      return rawVal.toStringAsFixed(1);
    }
    final str = rawVal.toString().trim();
    if (str.isEmpty || str == '0' || str == '0.0') return '';
    final numVal = double.tryParse(str);
    if (numVal != null) {
      if (numVal <= 0.0 || numVal <= 1.0) return '';
      return numVal.toStringAsFixed(1);
    }
    return str;
  }

  Widget _buildNearestToYou(double sw, double sh) {
    final cardW = sw * 0.60;
    // use a fixed card height that ensures image + text fits clearly
    const imageH = 165.0;
    const infoH = 86.0;
    const cardH = imageH + infoH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recommendationsLoading)
          ShimmerLoading.buildHorizontalCardList(
              cardWidth: cardW, cardHeight: cardH)
        else if (_recommendationsError != null || _recommendations.isEmpty)
          SizedBox(
            height: cardH,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_outlined,
                      size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    _recommendationsError ?? 'No recommendations yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: cardH,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recommendations.length,
              itemBuilder: (context, i) {
                final place = _recommendations[i];
                final String rawImg = (place['image'] as String? ?? '').trim();
                final String imageUrl = rawImg.isNotEmpty
                    ? rawImg
                    : ImageUrlFormatter.extractFromMap(place);
                final rating = place['rating'] as String? ?? '';
                final description = place['description'] as String? ?? '';
                final type = place['type'] as String? ?? '';
                final location = place['location'] as String? ?? '';
                final workingHours = place['workingHours'] as String? ?? '';
                final status = place['status'] as String? ?? '';

                // Build a detail line similar to DiscoveryListPage
                String detailLine = location;
                if (detailLine.isEmpty) detailLine = workingHours;
                if (detailLine.isEmpty) detailLine = status;
                if (detailLine.isEmpty) detailLine = 'Available now';

                String accentLine = status;
                if (accentLine.isEmpty) accentLine = workingHours;
                if (accentLine.isEmpty) accentLine = description;
                if (accentLine.isEmpty) accentLine = 'Recommended for you';

                return GestureDetector(
                  onTap: () {
                    final placeId = _asString(place['placeId'] ?? place['id']);
                    if (placeId.isNotEmpty) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.placeDetails,
                        arguments: placeId,
                      );
                    }
                  },
                  child: Container(
                    width: cardW,
                    height: cardH,
                    clipBehavior: Clip.hardEdge,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Image ────────────────────────────────────────────
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(15),
                                topRight: Radius.circular(15),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: cardW,
                                      height: imageH,
                                      cacheWidth: 800,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (_, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          width: cardW,
                                          height: imageH,
                                          color: Colors.grey.shade200,
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        width: cardW,
                                        height: imageH,
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Color(0xFFBDBDBD),
                                          size: 24,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: cardW,
                                      height: imageH,
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.restaurant_outlined,
                                        color: Color(0xFFBDBDBD),
                                        size: 28,
                                      ),
                                    ),
                            ),
                            if (rating.isNotEmpty)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFFFFB800),
                                        size: 13,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        rating,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // ── Info ─────────────────────────────────────────────
                        Expanded(
                          child: ClipRect(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (type.isNotEmpty)
                                    Text(
                                      type,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8A8A8A),
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    place['name'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A1A),
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    detailLine,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6E6E6E),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    accentLine,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFE5D17),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Share Post ──────────────────────────────────────────────────────────────
  Future<void> _sharePost({
    required String postId,
    required String postTitle,
    required String postText,
  }) async {
    if (postId.isEmpty) return;

    // Build a deep-link that re-opens the app directly on this post.
    // Format: hayy://post/{postId}
    // (Android intent-filter / iOS universal-link must declare this scheme)
    final deepLink = 'hayy://post/$postId';

    final titlePart = postTitle.isNotEmpty ? postTitle : 'Check this post';
    final previewText = postText.isNotEmpty
        ? (postText.length > 120 ? '${postText.substring(0, 120)}…' : postText)
        : '';

    final shareText = [
      titlePart,
      if (previewText.isNotEmpty) previewText,
      deepLink,
    ].join('\n\n');

    await Share.share(
      shareText,
      subject: titlePart,
    );
  }

  Widget _buildRecentPosts(double sw, double sh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_postsLoading)
          ShimmerLoading.buildPostList()
        else if (_posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Center(
              child: Text(
                'No posts available right now',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _posts.length + (_isLoadingMorePosts ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _posts.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF641A),
                    ),
                  ),
                );
              }
              final post = _posts[i];
              final placeId = _asString(post['placeId'] ?? post['id']);
              final isFollowing = _followingSet.contains(placeId);
              final isFollowLoading = _followLoadingSet.contains(placeId);

              final postId = _asString(post['id']);
              final postTitle = _asString(post['name']);
              // Seed the count maps from API data on first render
              if (!_likesCountMap.containsKey(postId)) {
                _likesCountMap[postId] = (post['likes'] as int?) ?? 0;
              }
              if (!_commentsCountMap.containsKey(postId)) {
                _commentsCountMap[postId] = (post['comments'] as int?) ?? 0;
              }
              final isLiked = _likedSet.contains(postId);
              final isLikeLoading = _likeLoadingSet.contains(postId);
              final likesCount = _likesCountMap[postId] ?? 0;
              final commentsCount = _commentsCountMap[postId] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(
                        children: [
                          // ── Tappable avatar → place details ──────────────
                          GestureDetector(
                            onTap: placeId.isNotEmpty
                                ? () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.placeDetails,
                                      arguments: placeId,
                                    )
                                : null,
                            child: ClipOval(
                              child: (() {
                                final avatarUrl =
                                    (post['avatar'] as String? ?? '').trim();
                                return avatarUrl.isNotEmpty
                                    ? Image.network(
                                        avatarUrl,
                                        width: 40,
                                        height: 40,
                                        cacheWidth: 120,
                                        cacheHeight: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.store,
                                              size: 20, color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.store,
                                            size: 20, color: Colors.grey),
                                      );
                              })(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ── Tappable name → place details ─────────────────
                          Expanded(
                            child: GestureDetector(
                              onTap: placeId.isNotEmpty
                                  ? () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.placeDetails,
                                        arguments: placeId,
                                      )
                                  : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  Text(
                                    post['time'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: isFollowLoading
                                ? null
                                : () => _toggleFollow(placeId),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 7),
                              decoration: BoxDecoration(
                                color: isFollowing
                                    ? Colors.white
                                    : const Color(0xFFFF641A),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0xFFFF641A),
                                  width: 1.5,
                                ),
                              ),
                              child: isFollowLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFF641A),
                                      ),
                                    )
                                  : Text(
                                      isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        color: isFollowing
                                            ? const Color(0xFFFF641A)
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final updatedPost = Map<String, dynamic>.from(post);
                        updatedPost['isLiked'] = isLiked;
                        updatedPost['likes'] = likesCount;
                        updatedPost['likesCount'] = likesCount;
                        updatedPost['comments'] = commentsCount;
                        updatedPost['commentsCount'] = commentsCount;

                        final result = await Navigator.pushNamed(
                          context,
                          AppRoutes.postDetails,
                          arguments: updatedPost,
                        );

                        if (result is Map) {
                          final resMap = Map<String, dynamic>.from(result);
                          final newIsLiked = resMap['isLiked'] as bool?;
                          final newLikesCount = resMap['likesCount'] as int?;
                          final newCommentsCount =
                              resMap['commentsCount'] as int?;

                          if (!mounted) return;
                          setState(() {
                            if (newIsLiked != null) {
                              if (newIsLiked) {
                                _likedSet.add(postId);
                                sl<UserSessionManager>()
                                    .saveLikedPostId(postId);
                              } else {
                                _likedSet.remove(postId);
                                sl<UserSessionManager>()
                                    .removeLikedPostId(postId);
                              }
                            }
                            if (newLikesCount != null && newLikesCount >= 0) {
                              _likesCountMap[postId] = newLikesCount;
                            }
                            if (newCommentsCount != null &&
                                newCommentsCount >= 0) {
                              _commentsCountMap[postId] = newCommentsCount;
                            }
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              post['text'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF444444),
                                height: 1.45,
                              ),
                            ),
                          ),
                          if (_isValidImageUrl(
                              post['postImage'] as String? ?? '')) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  (post['postImage'] as String).trim(),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      height: 200,
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFFF641A),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: isLikeLoading
                                ? null
                                : () => _toggleLike(postId, postTitle),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                      scale: animation, child: child),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(isLiked),
                                color: isLiked
                                    ? const Color(0xFFFF641A)
                                    : const Color(0xFF888888),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likesCount',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF565656),
                            ),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () {
                              CommentsBottomSheet.show(
                                context,
                                postId,
                                onCommentAdded: () {
                                  setState(() {
                                    _commentsCountMap[postId] =
                                        (_commentsCountMap[postId] ?? 0) + 1;
                                  });
                                },
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    color: Color(0xFF888888), size: 17),
                                const SizedBox(width: 4),
                                Text(
                                  '$commentsCount',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF565656),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // ─── Share Button ──────────────────────────────────
                          GestureDetector(
                            onTap: () => _sharePost(
                              postId: postId,
                              postTitle: _asString(post['name']),
                              postText: _asString(post['text']),
                            ),
                            child: const Icon(
                              Icons.share_outlined,
                              color: Color(0xFF888888),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── Active Filter Pill ────────────────────────────────────────────────────────
class _ActiveFilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterPill({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF641A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF641A).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFF641A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFFFF641A),
            ),
          ),
        ],
      ),
    );
  }
}
