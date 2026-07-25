import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;

  void initialize(Function(Uri) onLinkReceived) {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      onLinkReceived(uri);
    });
  }

  Future<Uri?> getInitialLink() async {
    return await _appLinks.getInitialLink();
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
