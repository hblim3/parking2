import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// 👇 새로 설치한 파이어베이스 패키지와 설정 파일 불러오기
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// 💡 분리된 방(파일)들을 불러옵니다. (아직 안 만든 파일은 빨간 줄이 뜰 수 있지만 괜찮습니다!)
import 'login_screen.dart';
import 'parking_screen.dart'; // 이미 있으신 파일
import 'inquiry_screen.dart'; // 나중에 만들 파일
import 'settings_screen.dart'; // 나중에 만들 파일
import 'car_management_screen.dart'; // 나중에 만들 파일
import 'notification_screen.dart';

// 💡 지금은 현재 테스트 중인 임의의 서버(에뮬레이터) 주소를 적어둡니다!
const String baseUrl = 'http://10.0.2.2:3000';

// 전역 변수: 스마트폰 안전 금고 & 다크모드 리모컨
final storage = FlutterSecureStorage();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  // 1. 플러터 엔진과 프레임워크가 자리를 잡을 때까지 기다립니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 파이어베이스를 우리 앱의 설정값(DefaultFirebaseOptions)으로 초기화합니다.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. 모든 준비가 끝나면 비로소 앱을 실행합니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Park On',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,
          home: const SplashCheckScreen(), // 앱 켜지면 무조건 자동로그인 검사부터!
        );
      },
    );
  }
}

// --- 자동 로그인(토큰) 검사기 ---
class SplashCheckScreen extends StatefulWidget {
  const SplashCheckScreen({Key? key}) : super(key: key);

  @override
  State<SplashCheckScreen> createState() => _SplashCheckScreenState();
}

class _SplashCheckScreenState extends State<SplashCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  void _checkLogin() async {
    String? token = await storage.read(key: 'jwt_token');
    await Future.delayed(const Duration(seconds: 1)); // 로딩 화면 1초 대기

    if (token != null) {
      // 토큰이 있으면 메인 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainTabScreen()),
      );
    } else {
      // 토큰이 없으면 로그인 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// --- 하단 탭 바 (메인 화면) ---
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  // 💡 탭을 눌렀을 때 보여줄 화면들 (아직 안 만든 파일은 주차장 화면으로 임시 대체해 둡니다)
  final List<Widget> _pages = [
    const ParkingScreen(),
    const InquiryScreen(), // 👈 수정됨!
    const NotificationScreen(), // (임시 알림 화면)
    const SettingsScreen(), // 👈 수정됨!
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking),
            label: '주차장',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: '문의'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '알림'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
