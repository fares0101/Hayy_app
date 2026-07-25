import 'package:flutter/material.dart';
import 'app_router.dart';
import 'core/widgets/app_theme.dart';
import 'presentation/user_app/splash/splash_page.dart';
import 'presentation/user_app/onboarding/onboarding_page.dart';
import 'presentation/user_app/login/login_page.dart';
import 'presentation/user_app/register/register_page.dart';
import 'presentation/user_app/forgot_password/forgot_password_page.dart';
import 'presentation/user_app/main_navigation/main_navigation_page.dart';
import 'presentation/user_app/interests/interests_page.dart';
import 'presentation/user_app/discovery/cafes_page.dart';
import 'presentation/user_app/discovery/events_page.dart';
import 'presentation/user_app/discovery/offers_page.dart';
import 'presentation/user_app/discovery/discovery_list_page.dart';
import 'presentation/user_app/discovery/restaurants_page.dart';
import 'presentation/user_app/place_details/place_details_page.dart';
import 'presentation/user_app/offer_details/offer_details_page.dart';
import 'presentation/user_app/post_details/post_details_page.dart';
import 'presentation/user_app/booking/screens/payment_result_screen.dart';
import 'presentation/user_app/profile/screens/favorite_screen.dart';
import 'presentation/user_app/profile/screens/history_screen.dart';
import 'presentation/user_app/profile/screens/my_reviews_screen.dart';
import 'injection_container.dart' as di;
import 'package:google_sign_in/google_sign_in.dart';
import 'core/constants/api_constants.dart';
import 'core/services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencies();
  final serverClientId = ApiConstants.googleServerClientId.trim();
  final androidClientId = ApiConstants.googleAndroidClientId.trim();
  await GoogleSignIn.instance.initialize(
    clientId: androidClientId.isEmpty ? null : androidClientId,
    serverClientId: serverClientId,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    _deepLinkService.initialize(_handleDeepLink);
    final initialLink = await _deepLinkService.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink);
    }
  }

  void _handleDeepLink(Uri uri) async {
    final pathString = uri.path.toLowerCase();
    if (pathString.contains('payment-result') || uri.host == 'payment-result') {
      final bookingId = uri.queryParameters['bookingId'] ?? '';
      final success = uri.queryParameters['success']?.toLowerCase() == 'true';

      final eventTitle = uri.queryParameters['eventTitle'] ?? 'Event Ticket';
      final seats = int.tryParse(uri.queryParameters['seats'] ?? '1') ?? 1;

      _navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentResultScreen(
            success: success,
            bookingId: bookingId,
            eventTitle: eventTitle,
            seats: seats,
          ),
        ),
      );
      return;
    }

    // Deep link handling removed - using OTP verification instead
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashPage(),
      routes: {
        AppRoutes.onboarding: (context) => const OnboardingPage(),
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.register: (context) => const RegisterPage(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(),
        AppRoutes.myReviews: (context) => const MyReviewsScreen(),
        AppRoutes.favorites: (context) => const FavoriteScreen(),
        AppRoutes.history: (context) => const HistoryScreen(),
        AppRoutes.home: (context) {
          final initialIndex =
              ModalRoute.of(context)?.settings.arguments as int?;
          return MainNavigationPage(initialIndex: initialIndex ?? 2);
        },
        AppRoutes.restaurants: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return RestaurantsPage(
            placeIds: _extractPlaceIds(args),
          );
        },
        AppRoutes.cafes: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return CafesPage(
            placeIds: _extractPlaceIds(args),
          );
        },
        AppRoutes.events: (context) => const EventsPage(),
        AppRoutes.offers: (context) => const OffersPage(),
        AppRoutes.completeProfile: (context) => const YourInterestsPage(),
        AppRoutes.interests: (context) => const YourInterestsPage(),
        AppRoutes.placeDetails: (context) {
          final placeId = ModalRoute.of(context)?.settings.arguments as String?;
          return PlaceDetailsPage(placeId: placeId);
        },
        AppRoutes.offerDetails: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map) {
            final mapArgs = Map<String, dynamic>.from(args);
            final offerId =
                mapArgs['id']?.toString() ?? mapArgs['offerId']?.toString() ?? '';
            return OfferDetailsPage(offerId: offerId, offerData: mapArgs);
          }
          final offerId = args?.toString() ?? '';
          return OfferDetailsPage(offerId: offerId);
        },
        AppRoutes.postDetails: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map) {
            final mapArgs = Map<String, dynamic>.from(args);
            final postId = mapArgs['id']?.toString() ??
                mapArgs['postId']?.toString() ??
                mapArgs['businessPostId']?.toString() ??
                '';
            return PostDetailsPage(postId: postId, initialPostData: mapArgs);
          }
          final postId = args?.toString() ?? '';
          return PostDetailsPage(postId: postId);
        },
      },
    );
  }
}

List<String> _extractPlaceIds(Object? args) {
  if (args is PlaceCollectionRouteArgs) {
    return args.placeIds;
  }

  if (args is List<String>) {
    return args;
  }

  if (args is List) {
    return args
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  if (args is String && args.trim().isNotEmpty) {
    return [args.trim()];
  }

  return const [];
}
