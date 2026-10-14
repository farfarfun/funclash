import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';

Future<void> clearAppData() async {
  await preferences.clearPreferences();
  try {
    await database.close();
  } catch (error) {
    // Drift rethrows a failed open from close; that file still has to go.
    commonPrint.log(
      'close database failed: $error',
      logLevel: LogLevel.warning,
    );
  }
  await safeDeletePath(await appPath.databasePath);
  await safeDeletePath(await appPath.profilesPath);
}
