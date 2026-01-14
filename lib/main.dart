import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ApartmentApp());
}

class ApartmentApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام إدارة الشقق',
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        useMaterial3: true,
      ),
      home: LoginScreen(),
    );
  }
}

// --- شاشة تسجيل الدخول ---
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passController = TextEditingController();

  void _login() {
    if (_passController.text == "1998") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("كلمة المرور خاطئة!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.apartment_rounded, size: 80, color: Color(0xFF0D47A1)),
              const SizedBox(height: 32),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "كلمة المرور",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
                child: const Text("دخول", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- الشاشة الرئيسية ---
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Database? _db;
  List<Map<String, dynamic>> _results = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    String databasesPath = await getDatabasesPath();
    String path = p.join(databasesPath, 'apartments_final_v3.db');

    _db = await openDatabase(path, version: 1, onCreate: (db, version) {
      return db.execute(
          "CREATE TABLE apartments(id INTEGER PRIMARY KEY AUTOINCREMENT, subNum TEXT, owner TEXT, location TEXT, area TEXT)");
    });
    _loadAll();
  }

  void _loadAll() async {
    final data = await _db!.query('apartments');
    setState(() => _results = data);
  }

  void _search() async {
    if (_searchController.text.isEmpty) {
      _loadAll();
      return;
    }
    final data = await _db!.query('apartments',
        where: "subNum LIKE ?", whereArgs: ['%${_searchController.text}%']);
    setState(() => _results = data);
  }

  void _delete(int id) async {
    await _db!.delete('apartments', where: "id = ?", whereArgs: [id]);
    _loadAll();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف البيانات بنجاح")));
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['الشقق'];
    sheet.appendRow([TextCellValue("رقم الاكتتاب"), TextCellValue("المالك"), TextCellValue("الموقع"), TextCellValue("المساحة")]);

    for (var row in _results) {
      sheet.appendRow([
        TextCellValue(row['subNum'].toString()),
        TextCellValue(row['owner'].toString()),
        TextCellValue(row['location'].toString()),
        TextCellValue(row['area'].toString()),
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/Apartments_Report.xlsx";
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم التصدير إلى: $path"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("نظام إدارة الشقق", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        // تم إزالة زر التنزيل من هنا كما طلبت
      ),
      // القائمة الجانبية (Drawer)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF0D47A1)),
              child: Center(child: Text("القائمة", style: TextStyle(color: Colors.white, fontSize: 24))),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("الصفحة الرئيسية"),
              onTap: () {
                Navigator.pop(context);
                _loadAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text("إضافة شقة جديدة"),
              onTap: () {
                Navigator.pop(context);
                _showFormDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_copy),
              title: const Text("استخراج البيانات (Excel)"),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SearchBar(
              controller: _searchController,
              hintText: "ابحث برقم الاكتتاب...",
              leading: const Icon(Icons.search),
              onChanged: (val) => _search(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 25,
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text("رقم الاكتتاب")),
                    DataColumn(label: Text("المالك")),
                    DataColumn(label: Text("المساحة")),
                    DataColumn(label: Text("إجراءات")),
                  ],
                  rows: _results.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['subNum'].toString())),
                      DataCell(Text(item['owner'].toString())),
                      DataCell(Text(item['area'].toString())),
                      DataCell(Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showFormDialog(item: item)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(item['id'])),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // نافذة الإضافة والتعديل
  void _showFormDialog({Map<String, dynamic>? item}) {
    final bool isUpdate = item != null;
    final sub = TextEditingController(text: isUpdate ? item['subNum'] : "");
    final owner = TextEditingController(text: isUpdate ? item['owner'] : "");
    final loc = TextEditingController(text: isUpdate ? item['location'] : "");
    final area = TextEditingController(text: isUpdate ? item['area'] : "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpdate ? "تعديل البيانات" : "إضافة شقة جديدة"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: sub, decoration: const InputDecoration(labelText: "رقم الاكتتاب")),
              TextField(controller: owner, decoration: const InputDecoration(labelText: "اسم المالك")),
              TextField(controller: loc, decoration: const InputDecoration(labelText: "الموقع")),
              TextField(controller: area, decoration: const InputDecoration(labelText: "المساحة")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'subNum': sub.text,
                'owner': owner.text,
                'location': loc.text,
                'area': area.text,
              };
              if (isUpdate) {
                await _db!.update('apartments', data, where: "id = ?", whereArgs: [item['id']]);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تحديث البيانات بنجاح"), backgroundColor: Colors.blue));
              } else {
                await _db!.insert('apartments', data);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة البيانات بنجاح"), backgroundColor: Colors.green));
              }
              Navigator.pop(context);
              _loadAll();
            },
            child: Text(isUpdate ? "تحديث" : "حفظ"),
          )
        ],
      ),
    );
  }
}