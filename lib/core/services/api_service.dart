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
        connectTimeout: const Duration(seconds: 30), // ✅ Increased timeout
        receiveTimeout: const Duration(seconds: 30), // ✅ Increased timeout
        sendTimeout: const Duration(seconds: 30),    // ✅ Added send timeout
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
          // ✅ Debug logging
          print('🌐 API Request: ${options.method} ${options.baseUrl}${options.path}');
          print('📦 Headers: ${options.headers}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          // ✅ Debug logging
          print('✅ API Response: ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          // ✅ Better error logging
          print('❌ API Error: ${error.type}');
          print('❌ URL: ${error.requestOptions.baseUrl}${error.requestOptions.path}');
          print('❌ Message: ${error.message}');
          if (error.response != null) {
            print('❌ Response: ${error.response?.data}');
          }
          handler.next(error);
        },
      ),
    );
  }
}