import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';

class InterestsRemoteDataSource {
  final ApiClient apiClient;

  InterestsRemoteDataSource(this.apiClient);

  Future<List<Map<String, dynamic>>> getInterests() async {
    final endpoints = <String>[
      ApiConstants.categories,
      '/api/Categories/GetAll',
      '/api/Categories/Get All',
    ];

    DioException? lastError;
    for (final endpoint in endpoints) {
      try {
        final response = await apiClient.get(endpoint);
        final parsed = _extractInterestsList(response.data);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } on DioException catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    return [];
  }

  Future<void> saveInterests({
    required List<String> selectedIds,
    List<String>? customInterests,
  }) async {
    final data = <String, dynamic>{
      'selectedCategoryIds': selectedIds,
    };

    if (customInterests != null && customInterests.isNotEmpty) {
      data['customInterests'] = customInterests;
    }

    await apiClient.post(
      '/api/interests',
      data: data,
    );
  }

  List<Map<String, dynamic>> _extractInterestsList(dynamic data) {
    final rawList = _extractRawList(data);
    if (rawList == null) {
      return [];
    }

    final parsed = <Map<String, dynamic>>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final id =
          _firstString(map, const ['id', 'Id', 'categoryId', 'CategoryId']);
      final name = _firstString(
        map,
        const [
          'name',
          'Name',
          'label',
          'Label',
          'title',
          'Title',
          'categoryName'
        ],
      );

      if (name.isEmpty) {
        continue;
      }

      parsed.add({
        'id': id.isEmpty ? name.toLowerCase().replaceAll(' ', '_') : id,
        'name': name,
      });
    }

    return parsed;
  }

  List<dynamic>? _extractRawList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      const listKeys = [
        'data',
        'items',
        'result',
        'results',
        'categories',
        'interests',
        'value',
        r'$values',
      ];
      for (final key in listKeys) {
        final value = map[key];
        if (value is List) {
          return value;
        }
        if (value is Map) {
          final nested = _extractRawList(value);
          if (nested != null) {
            return nested;
          }
        }
      }
    }
    return null;
  }

  String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
