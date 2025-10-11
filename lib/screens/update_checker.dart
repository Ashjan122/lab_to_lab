import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      // التأكد من أن الـ context صالح
      if (!context.mounted) {
        print("Context is not mounted, skipping update check");
        return;
      }
      // 1️⃣ جلب رقم الإصدار الحالي للتطبيق
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentVersion = int.parse(packageInfo.buildNumber);
      print("Current version: $currentVersion");

      // 2️⃣ جلب بيانات التحديث من Firestore
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('version3')
          .get();

      if (!snapshot.exists) {
        print("Document 'version3' does not exist in appConfig collection");
        return;
      }

      int latestVersion = snapshot['lastVersion'];
      String updateUrl = snapshot['updatrUrl'];
      print("Latest version: $latestVersion");
      print("Update URL: $updateUrl");

      // 3️⃣ مقارنة رقم الإصدار
      if (latestVersion > currentVersion) {
        print("Update available! Showing dialog...");
        // 4️⃣ عرض الديالوق الإجباري
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false, // ما يقدر يطلع من الديالوق
            builder: (context) {
            return AlertDialog(
              title: const Text("تحديث جديد متاح"),
              content: const Text("يجب تحديث التطبيق للاستمرار."),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); // إغلاق الديالوق مؤقتاً
                    await _downloadAndInstall(updateUrl, context);
                  },
                  child: const Text("حدث الآن"),
                ),
              ],
            );
          },
          );
        }
      } else {
        print("No update needed. Current: $currentVersion, Latest: $latestVersion");
      }
    } catch (e) {
      print("Error checking update: $e");
    }
  }

  // 🧩 تحميل وتثبيت التحديث
  static Future<void> _downloadAndInstall(String url, BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/update.apk";
      Dio dio = Dio();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await dio.download(url, filePath);
      Navigator.of(context).pop(); // إغلاق التحميل

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحميل التحديث، جارٍ التثبيت...")),
      );

      await OpenFilex.open(filePath); // تشغيل ملف الـ APK
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء التحديث: $e")),
      );
    }
  }
}