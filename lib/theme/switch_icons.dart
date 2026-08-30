import 'package:iconic_morph/iconic_morph.dart';

abstract class SwitchIcons {
  // Material add_circle_outline
  static const String plus = 'custom:plus';
  static const String plusPath =
      'M12,2C6.48,2,2,6.48,2,12s4.48,10,10,10s10-4.48,10-10S17.52,2,12,2z M12,20c-4.41,0-8-3.59-8-8s3.59-8,8-8s8,3.59,8,8S16.41,20,12,20z M13,7h-2v4H7v2h4v4h2v-4h4v-2h-4V7z';

  // Material check_circle
  static const String check = 'custom:check';
  static const String checkPath =
      'M12,2C6.48,2,2,6.48,2,12s4.48,10,10,10s10-4.48,10-10S17.52,2,12,2z M10,17l-5-5l1.41-1.41L10,14.17l7.59-7.59L19,8L10,17z';

  // Material vpn_key
  static const String key = 'custom:key';
  static const String keyPath =
      'M12.65,10C11.83,7.67,9.61,6,7,6c-3.31,0-6,2.69-6,6s2.69,6,6,6c2.61,0,4.83-1.67,5.65-4H17v4h4v-4h2v-4H12.65z M7,14c-1.1,0-2-0.9-2-2s0.9-2,2-2s2,0.9,2,2S8.1,14,7,14z';

  // Material vpn_key_off
  static const String keyOff = 'custom:key_off';
  static const String keyOffPath =
      'M20.84 18.01L19.01 16.18V20.01H15.01V16.01H10.84L8.84 14.01H7.01C5.91 14.01 5.01 13.11 5.01 12.01C5.01 11.89 5.02 11.78 5.04 11.67L1.4 4.23L2.81 2.82L22.25 22.26L20.84 20.85L18.42 21.01H15.01V16.84L12.66 14.51C11.84 16.84 9.62 18.51 7.01 18.51C3.42 18.51 .51 15.6 .51 12.01C.51 9.71 1.71 7.69 3.51 6.54L1.4 4.42L2.81 3.01L22.25 22.45L20.84 21.04L18.42 21.01z M12.66 10.01H17.01V12.01H18.18L16.18 10.01H12.66L11.31 8.66L9.9 7.25L7.51 5.3C7.35 5.3 7.18 5.3 7.01 5.3C4.71 5.3 2.69 6.5 1.54 8.3L3.66 10.42C4.02 10.16 4.33 10.51 4.71 10.8L6.71 12.8L10.71 16.8L13.21 14.3V10.01z M17.01 10.01H21.01V12.01H19.01V14.01H17.01V10.01z M7.01 13.51C6.18 13.51 5.51 12.84 5.51 12.01C5.51 11.93 5.52 11.85 5.53 11.77L7.75 14.03C7.52 14.18 7.27 14.26 7.01 14.26z M7.01 10.01C7.84 10.01 8.51 10.68 8.51 11.51C8.51 11.59 8.5 11.67 8.49 11.75L6.27 9.49C6.5 9.34 6.75 9.26 7.01 9.26z';

  /// Register IconGeometry resolver for custom SVG path morphing
  static void initResolver() {
    IconGeometry.resolver = (asset) async {
      switch (asset) {
        case SwitchIcons.plus:
          return (
            viewBox: 24.0,
            isFill: false,
            pathData: [SwitchIcons.plusPath]
          );
        case SwitchIcons.check:
          return (
            viewBox: 24.0,
            isFill: false,
            pathData: [SwitchIcons.checkPath]
          );
        case SwitchIcons.key:
          return (
            viewBox: 24.0,
            isFill: false,
            pathData: [SwitchIcons.keyPath]
          );
        case SwitchIcons.keyOff:
          return (
            viewBox: 24.0,
            isFill: false,
            pathData: [SwitchIcons.keyOffPath]
          );
        default:
          return null;
      }
    };
  }
}
