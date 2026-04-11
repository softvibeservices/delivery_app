// lib/core/utils/dio_error_handler.dart

import 'package:dio/dio.dart';

/// Single source of truth for user-facing Dio error messages.
/// Replaces the identical _handleDioError() method that was duplicated
/// across OrdersProvider, DeliveredOrdersProvider, StickyNotesProvider,
/// and GoToProvider.
///
/// [entityName] is used in the 404 message, e.g. "No orders found."
String handleDioError(DioException e, {String entityName = 'data'}) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timeout. Please check your internet connection.';

    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      // 401 is handled globally by ApiService interceptor → SessionService.
      // Providers never see a 401 in practice, but guard anyway.
      if (statusCode == 401) {
        return 'Session expired. Please login again.';
      } else if (statusCode == 404) {
        return 'No $entityName found.';
      } else if (statusCode == 500) {
        return 'Server error. Please try again later.';
      }
      return 'Failed to fetch $entityName (Error $statusCode).';

    case DioExceptionType.cancel:
      return 'Request was cancelled.';

    case DioExceptionType.connectionError:
      return 'No internet connection. Please check your network.';

    default:
      return 'Failed to fetch $entityName. Please try again.';
  }
}