import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/control_lab_info_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_price_list_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_users_screen.dart';
import 'package:lab_to_lab_admin/screens/manage_lab_tests_screen.dart';

class LabDatailsDashbord extends StatelessWidget {
   final String labId;
  final String labName;
  const LabDatailsDashbord({super.key,required this.labId,
    required this.labName,});

    Widget _buildCardLabDetails({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFF673AB7),
  }) {
    final BorderRadius cardRadius = BorderRadius.circular(12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final iconSize = (width * 0.25).clamp(20.0, 32.0); // أيقونة متناسبة
        final fontSize = (width * 0.10).clamp(15.0, 20.0); // خط متناسب

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: cardRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: cardRadius,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 8,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,

                        style: TextStyle(
                          fontSize: fontSize,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(icon, size: iconSize, color: color),
                    ],
                  ),
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '$labName',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body: Container(
         
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.count(
              crossAxisCount: 1,
              childAspectRatio: 3.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildCardLabDetails(icon: Icons.biotech, title: "بيانات المعمل", onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (_)=> ControlLabInfoScreen(labId: labId, labName: labName),));
                }),
                _buildCardLabDetails(icon: Icons.science, title: "إدارة التحاليل", onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (_)=> ManageLabTestsScreen(labId: labId, labName: labName),));
                }),
                _buildCardLabDetails(icon: Icons.price_change, title: "قائمة الاسعار", onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (_)=> LabPriceListScreen(labId: labId, labName: labName,canEdit: true,),));

                }),
                _buildCardLabDetails(icon: Icons.people, title: "المستخدمين", onTap: (){
                   Navigator.push(context, MaterialPageRoute(builder: (_)=> LabUsersScreen(labId: labId, labName: labName),));

                })
                
              ],
            ),
          ),
        ),
      ),);
  }
}