import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/api_constants.dart';

class ProfileImageHelper {
  static String resolve(String? imagePath) {
    final raw = imagePath?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    if (_isNetworkUrl(raw)) {
      return raw;
    }

    final localPath = resolveLocalPath(raw);
    if (localPath.isNotEmpty) {
      return localPath;
    }

    final normalized = raw.replaceAll('\\', '/').trim();
    if (_isNetworkUrl(normalized)) {
      return normalized;
    }

    final publicPath = _extractPublicPath(normalized);
    if (publicPath.isEmpty || _looksLikePrivateFilePath(publicPath)) {
      return '';
    }

    return _joinBaseUrl(publicPath);
  }

  static String resolveLocalPath(String? imagePath) {
    final raw = imagePath?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    if (File(raw).existsSync()) {
      return raw;
    }

    if (raw.startsWith('file://')) {
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        try {
          final path = uri.toFilePath(windows: Platform.isWindows);
          if (File(path).existsSync()) {
            return path;
          }
        } catch (_) {
          return '';
        }
      }
    }

    return '';
  }

  static bool isNetworkPath(String? imagePath) {
    final resolved = resolve(imagePath);
    return _isNetworkUrl(resolved);
  }

  static ImageProvider? imageProvider(String? imagePath) {
    final resolved = resolve(imagePath);
    if (resolved.isEmpty) {
      return null;
    }

    if (_isNetworkUrl(resolved)) {
      const baseUrl = ApiConstants.baseUrl;
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      if (resolved == baseUrl || resolved == '$cleanBase/' || resolved == cleanBase) {
        return null;
      }
      return NetworkImage(resolved);
    }

    if (File(resolved).existsSync()) {
      return FileImage(File(resolved));
    }

    return null;
  }

  static bool _isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _extractPublicPath(String path) {
    var normalized = path.trim();
    if (normalized.startsWith('~/')) {
      normalized = normalized.substring(1);
    }

    final lower = normalized.toLowerCase();
    for (final marker in const [
      '/wwwroot/',
      '/public/',
      '/uploads/',
      '/upload/',
      '/images/',
      '/image/',
      '/profile-images/',
      '/profileimages/',
      '/profile/',
    ]) {
      final index = lower.indexOf(marker);
      if (index >= 0) {
        if (marker == '/wwwroot/' || marker == '/public/') {
          return normalized.substring(index + marker.length - 1);
        }
        return normalized.substring(index);
      }
    }

    return normalized;
  }

  static bool _looksLikePrivateFilePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    return RegExp(r'^[a-zA-Z]:/').hasMatch(normalized) ||
        normalized.startsWith('/data/') ||
        normalized.startsWith('/var/') ||
        normalized.startsWith('/Users/') ||
        normalized.startsWith('/home/');
  }

  static String _joinBaseUrl(String path) {
    final baseUrl = ApiConstants.baseUrl.endsWith('/')
        ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1)
        : ApiConstants.baseUrl;
    final relativePath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$relativePath';
  }
}
