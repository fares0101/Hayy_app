class ApiConstants {
  static const String baseUrl =
      'https://hayy-api-2026-h2b4dghaerdvf9bh.francecentral-01.azurewebsites.net';

  // Auth Endpoints
  static const String login = '/api/app/auth/login';
  static const String register = '/api/app/auth/register';
  static const String forgotPassword = '/api/app/auth/forgot-password';
  static const String resetPassword = '/api/app/auth/reset-password';
  static const String verifyOtp = '/api/app/auth/verify-otp';
  static const String authMe = '/api/app/auth/me';

  // User Endpoints
  static const String userProfile = '/api/User/profile';
  static const String updateProfile = '/api/User/update';

  // Places Endpoints
  static const String places = '/api/Places';
  static const String placeDetails = '/api/Places/{id}';
  static const String searchPlaces = '/api/Places/search';
  static const String smartSearch = '/api/search/smart-search';
  static const String nearbyPlaces = '/api/Places/nearby';

  // AI Recommendations Endpoints
  static const String recommendations = '/api/Recommendations/user/{userId}';

  // Reviews Endpoints
  static const String reviews = '/api/Reviews';
  static const String placeReviews = '/api/Reviews/{placeId}';
  static const String userReviews = '/api/Reviews/user/{userId}';
  static const String updateReview = '/api/Reviews/{reviewId}';

  // Categories Endpoints
  static const String categories = '/api/Categories';

  // Offers Endpoints
  static const String activeOffers = '/api/Offers/active';
  static const String offerDetails = '/api/Offers/{id}';
  static const String offerPlaceDetails = '/api/Offers/place/{placeId}';

  // Events Endpoints
  static const String activeEvents = '/api/Events/active';
  static const String eventById = '/api/Events/{id}';

  // Event Booking Endpoints
  static const String eventBookings = '/api/EventBookings';
  static const String eventPaymentInitiate = '/api/EventPayment/initiate';
  static const String eventBookingMyQr = '/api/EventBookings/my-qr/{bookingId}';
  static const String myAllBookings = '/api/EventBookings/my-bookings';
  static const String eventBookingsMyBookings =
      '/api/EventBookings/my-bookings/{eventId}';
  static const String eventBookingById = '/api/EventBookings/status/{bookingId}';

  // PlaceFollows (Follow/Bookmark Places) Endpoints
  static const String myFollowedPlaces = '/api/PlaceFollows/user/follows/{userId}';
  static const String togglePlaceFollow = '/api/PlaceFollows/toggle';

  // Business Posts Endpoints
  static const String allBusinessPosts = '/api/BusinessPosts/all';
  static const String businessPostsByPlaceId = '/api/BusinessPosts/{placeId}';

  // Post Bookmarks Endpoints
  static const String postBookmarksToggle = '/api/PostBookmarks/toggle';
  static const String myPostBookmarks = '/api/PostBookmarks/my-bookmarks';


  // Likes Endpoints
  static const String likesToggle = '/api/Likes/toggle';
  static const String likesByPostId = '/api/Likes/post/{postId}';

  // Comments Endpoints
  static const String comments = '/api/Comments';
  static const String commentsByPostId = '/api/Comments/{postId}';
  static const String updateComment = '/api/Comments/{commentId}';
  static const String deleteComment = '/api/Comments/{commentId}';

  // Notifications Endpoints
  static const String notifications = '/api/Notifications';
  static const String notificationsUnreadCount =
      '/api/Notifications/unread-count';
  static const String notificationMarkAsRead = '/api/Notifications/{id}/read';
  static const String notificationsMarkAllAsRead =
      '/api/Notifications/read-all';

  // User Settings Endpoints
  static const String userSettings = '/api/UserSettings';


  // Timeout
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Google Sign-In
  // Use the Web client ID (serverClientId) from Google Cloud/Firebase.
  static const String googleServerClientId =
      '123332139804-sog66i9fon1muaamtm9phigskev8hj3k.apps.googleusercontent.com';

  // Optional: Android OAuth client ID (apps.googleusercontent.com).
  // Leave empty if not provided by backend team.
  static const String googleAndroidClientId =
      '123332139804-656rl235icb8du70ou2cpj38gonrg5au.apps.googleusercontent.com';
}
