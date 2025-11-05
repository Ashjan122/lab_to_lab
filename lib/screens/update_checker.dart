import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static Future<void> checkForUpdate(BuildContext context) async {
    // ✅ حفظ المرجع المحلي لـ ScaffoldMessenger مبكرًا لتجنب مشاكل الـ context
    /*
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      // 1. التحقق من أن الـ context لا يزال "mounted"
      if (!context.mounted) return;

      // 2. جلب بيانات النسخة الحالية من التطبيق
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = int.parse(packageInfo.buildNumber);

      // 3. جلب بيانات التحديث من Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('version3')
          .get();

      if (!snapshot.exists) return;

      final latestVersion = snapshot['lastVersion'];
      final updateUrl = snapshot['updatrUrl'];

      // 4. التحقق من وجود تحديث
     if (latestVersion > currentVersion) {
        // ✅ عرض الديالوق (داخل شرط context.mounted)
        if (!context.mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("تحديث جديد متاح", textAlign: TextAlign.end),
              content: const Text("يجب تحديث التطبيق للاستمرار.", textAlign: TextAlign.end),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop(); // ✅ استخدم dialogContext بدل context هنا

                    final uri = Uri.parse(updateUrl);
try {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
} catch (e) {
  messenger?.showSnackBar(
    SnackBar(content: Text("فشل في فتح الرابط: $e")),
  );
}

                  },
                  child: const Text("حدث الآن"),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // ✅ استخدم messenger هنا أيضًا
      messenger?.showSnackBar(
        SnackBar(content: Text("خطأ أثناء التحقق من التحديث: $e")),
      );
    }*/
  }
}
