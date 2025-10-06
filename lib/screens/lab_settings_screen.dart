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
  Widget _buildCardSettings({required IconData icon, required String title, required VoidCallback onTap, Color color = const Color.fromARGB(255, 90, 138, 201)}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
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
          body: Padding(
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

      ))));
  }
}