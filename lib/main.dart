import 'package:flutter/material.dart';
import 'models/layout_preferences.dart';
import 'models/survey_session.dart';
import 'screens/data_entry_screen.dart';
import 'screens/saved_sessions_screen.dart';
import 'screens/setup_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '레벨 측량',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _fold4Mode = LayoutPreferences.forceFold4Layout;

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();

    Future<void> openSaved() async {
      final session = await Navigator.push<SurveySession?>( 
        context,
        MaterialPageRoute(
          builder: (_) => SavedSessionsScreen(storageService: storageService),
        ),
      );
      if (session != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DataEntryScreen.fromSession(session)),
        );
      }
    }

    void openSetup() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    }

    void showExcelImport() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('엑셀 불러오기는 준비 중입니다.')),
      );
    }

    void showExcelExport() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('엑셀 저장/공유는 준비 중입니다.')),
      );
    }

    Widget buildButton(
        {required IconData icon,
        required String label,
        required VoidCallback onPressed}) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('레벨 측량 도구'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '레벨 측량 도구',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '레벨 측량을 위한 새로운 시작,\n저장된 작업을 불러올 수 있습니다.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('폴드4 화면 맞춤'),
                      subtitle: const Text('접었을때/펼쳤을때 화면에 맞게 조절'),
                      value: _fold4Mode,
                      onChanged: (value) {
                        setState(() {
                          _fold4Mode = value;
                          LayoutPreferences.forceFold4Layout = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            buildButton(
              icon: Icons.playlist_add,
              label: '새로 입력',
              onPressed: openSetup,
            ),
            const SizedBox(height: 12),
            buildButton(
              icon: Icons.folder_open,
              label: '저장 불러오기',
              onPressed: openSaved,
            ),
            const SizedBox(height: 12),
            buildButton(
              icon: Icons.upload_file,
              label: '엑셀 불러오기',
              onPressed: showExcelImport,
            ),
            const SizedBox(height: 12),
            buildButton(
              icon: Icons.download,
              label: '엑셀 저장/공유',
              onPressed: showExcelExport,
            ),
          ],
        ),
      ),
    );
  }
}