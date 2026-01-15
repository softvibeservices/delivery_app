//lib\config\api_endpoints.dart
class ApiEndpoints {
  // Base URLs
  static const String productionBaseUrl =
      'https://ice-inventory.vercel.app/';
  static const String developmentBaseUrl =
      'http://localhost:3000';

  // 🔐 Authentication
  static const String register = '/api/delivery/register';
  static const String loginOtp = '/api/delivery/login-otp';
  static const String verifyOtp = '/api/delivery/verify-otp';

  // 📦 Orders
  static const String pendingOrders = '/api/delivery/orders';
  static const String deliveredOrders = '/api/delivery/delivered-orders';
  static const String updateOrderStatus =
      '/api/delivery/update-order-status';

  // 📝 Sticky Notes
  static const String createStickyNote =
      '/api/delivery/sticky-notes';
  static const String searchProducts =
      '/api/delivery/search-products';

  // 🔍 Customers
  static const String searchCustomers =
      '/api/delivery/search-customers';
  static const String searchHistory =
      '/api/delivery/search-history';

  // 👤 Profile
  static const String getProfile = '/api/delivery/profile';
  static const String updateProfile =
      '/api/delivery/profile/update';
  static const String requestPasswordOtp =
      '/api/delivery/profile/request-password-otp';
  static const String changePassword =
      '/api/delivery/profile/change-password';

  // 📍 Location
  static const String updateLocation =
      '/api/delivery/update-location';
}