/// Centralised route path constants.
///
/// Use the static path fields in [GoRoute] definitions.
/// Use the static builder methods (e.g. [generatorDetail]) when pushing/going.
abstract final class AppRoutes {
  // ── Static routes ──────────────────────────────────────────────────────────
  static const home = '/';
  static const map = '/map';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const devLogin = '/dev-login';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const myRentals = '/my-rentals';
  static const admin = '/admin';
  static const ownerDashboard = '/owner-dashboard';
  static const companyOnboard = '/company/onboard';

  // ── Route path templates (used in GoRoute definitions) ───────────────────
  static const generatorDetailPath = '/generators/:id';
  static const generatorRequestPath = '/generators/:id/request';
  static const companyProfilePath = '/company/:id';
  static const ownerEarningsPath = '/owner/earnings';
  static const addGeneratorPath = '/owner/generator/add';
  static const editGeneratorPath = '/owner/generator/:id/edit';
  static const ratePath = '/rate/:rentalId';
  static const receiptPath = '/receipt/:rentalId';
  static const offerPath = '/offer/:rentalId';
  static const invoicePath = '/invoice/:rentalId';
  static const chatPath = '/chat/:rentalId';
  static const reportPath = '/report';

  // ── Builders for parameterised routes ─────────────────────────────────────
  static String generatorDetail(String id) => '/generators/$id';
  static String generatorRequest(String id) => '/generators/$id/request';
  static String companyProfile(String id) => '/company/$id';
  static String ownerEarnings(String companyId) =>
      '/owner/earnings?company=$companyId';
  static String addGenerator(String companyId) =>
      '/owner/generator/add?company=$companyId';
  static String editGenerator(String id) => '/owner/generator/$id/edit';
  static String rate(String rentalId,
          {required String rateeId,
          required String rateeName,
          bool isOwner = false}) =>
      '/rate/$rentalId?ratee=$rateeId&name=${Uri.encodeComponent(rateeName)}'
      '${isOwner ? '&owner=true' : ''}';
  static String receipt(String rentalId) => '/receipt/$rentalId';
  static String offer(String rentalId) => '/offer/$rentalId';
  static String invoice(String rentalId) => '/invoice/$rentalId';
  static String chat(String rentalId, {required String otherName}) =>
      '/chat/$rentalId?name=${Uri.encodeComponent(otherName)}';
  static String report({
    required String type,
    required String id,
    String? rentalId,
    String? name,
  }) {
    final buf = StringBuffer('/report?type=$type&id=$id');
    if (rentalId != null) buf.write('&rental=$rentalId');
    if (name != null) buf.write('&name=${Uri.encodeComponent(name)}');
    return buf.toString();
  }
}
