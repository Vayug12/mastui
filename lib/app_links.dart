/// Public links shown on the paywall and the subscription screen.
///
/// These must point at **your own** pages. Both Google Play and the App Store
/// reject subscription apps whose paywall has no working Terms / Privacy link,
/// and the store review team opens them. Host them anywhere (GitHub Pages,
/// Cloudflare Pages, Notion public page) and paste the URLs here.
abstract final class AppLinks {
  // TODO(mastui): Terms page still has to be created and hosted.
  static const terms = 'https://mastui.app/terms';

  /// Source text lives in docs/privacy-policy.md — update the Google Site from
  /// it whenever data handling changes.
  static const privacy = 'https://sites.google.com/view/mastuiprivacypolicy/home';
  static const supportEmail = 'sanjeev.yadav1201@gmail.com';

  /// Android package id, used to deep-link into the Play subscription screen.
  static const _androidPackage = 'app.mastui';

  /// Where the user cancels or changes their plan. Stores require this to be
  /// reachable from inside the app.
  static const androidManageSubscriptions =
      'https://play.google.com/store/account/subscriptions?package=$_androidPackage';
  static const iosManageSubscriptions =
      'https://apps.apple.com/account/subscriptions';
}
