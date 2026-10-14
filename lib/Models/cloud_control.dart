import 'package:loftify/Utils/constant.dart' as Constant;

/// Versioned Community policy. Historical remote JSON and user overrides are
/// intentionally not inputs; ordinary user preferences still live in Hive.
class LoftifyControl {
  const LoftifyControl();

  static const community = LoftifyControl();

  bool get enableAppNotNull => true;
  bool get enableEasterEggs => true;
  bool get showDress => true;
  bool get showTagDress => true;
  bool get showCatutu => true;
  bool get showDownloadButton => true;
  bool get showImageQualitySettings => true;
  bool get showBigImageSettings => true;
  bool get showVideoDownloadButton => true;

  String get repoUrl => Constant.communityRepoUrl;
  String get issueUrl => Constant.communityIssueUrl;
  String get officialWebsite => Constant.communityRepoUrl;
  String get shareText => Constant.communityShareText;
}
