import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_info_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_location_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_order_received_notifications_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_price_list_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_users_screen.dart';

class LabSettingsScreen extends StatelessWidget {
  final String labId;
  final String labName;
  const LabSettingsScreen({super.key, required this.labId, required this.labName});
 Widget _buildCardSettings({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  Color color = const Color.fromARGB(255, 90, 138, 201),
}) {
  final BorderRadius cardRadius = BorderRadius.circular(12);

  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;

      final iconSize = (width * 0.25).clamp(20.0, 32.0); // أيقونة متناسبة
      final fontSize = (width * 0.10).clamp(12.0, 14.0); // خط متناسب

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: cardRadius,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: iconSize, color: color),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return  Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
       appBar:  AppBar(
          title: Text('إعدادات $labName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,),
          body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey.shade200,
                const Color.fromARGB(255, 90, 138, 201).withOpacity(0.2),
                const Color.fromARGB(255, 90, 138, 201).withOpacity(0.35),
              ],
            ),
          ),
          child:  Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildCardSettings(icon: Icons.people,
                title: 'المستخدمين',
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder:  (context) => LabUsersScreen(labId: labId, labName: labName)));
                },),
                _buildCardSettings(icon: Icons.price_change,
                title: ' الأسعار',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder:  (context) => LabPriceListScreen(labId: labId, labName: labName)));
                },),
                _buildCardSettings(icon: Icons.business,
                title: 'بيانات المعمل',
                onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder:  (context) => LabInfoScreen(labId: labId, labName: labName)));
                },),
                _buildCardSettings(icon: Icons.notifications,
                title: 'الإشعارات ',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder:  (context) => const LabOrderReceivedNotificationsScreen()));
                },),
                _buildCardSettings(icon: Icons.location_on, title: "الموقع", onTap: (){
                Navigator.push(context, MaterialPageRoute(builder:  (context) => LabLocationScreen(labName: labName , labId: labId)));
              })

            ],

      )))));
  }
}