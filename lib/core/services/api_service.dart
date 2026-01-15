//lib\core\services\api_service.dart

import 'package:dio/dio.dart';
import '../../config/api_endpoints.dart';
import '../../config/constants.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio dio;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.productionBaseUrl,
        connectTimeout:
            Duration(seconds: AppConstants.apiTimeoutSeconds),
        receiveTimeout:
            Duration(seconds: AppConstants.apiTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }
}
