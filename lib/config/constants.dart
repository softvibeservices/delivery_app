//lib\config\constants.dart

class AppConstants {
  static const String appName = 'Ice Cream Delivery Partner';

  // Timeouts
  static const int apiTimeoutSeconds = 10;

  // Location intervals (in seconds)
  static const int locationUpdateNormal = 5;
  static const int locationUpdateLowBattery = 10;

  // OTP
  static const int otpLength = 6;
  static const int otpResendCooldown = 60;
}