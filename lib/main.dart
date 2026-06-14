import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// 👇 새로 설치한 파이어베이스 패키지와 설정 파일 불러오기
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 👈 포그라운드 알림 수신용 추가!
import 'package:lottie/lottie.dart';

// 💡 분리된 방(파일)들을 불러옵니다. (아직 안 만든 파일은 빨간 줄이 뜰 수 있지만 괜찮습니다!)
import 'login_screen.dart';
import 'parking_screen.dart'; // 이미 있으신 파일
import 'inquiry_screen.dart'; // 나중에 만들 파일
import 'settings_screen.dart'; // 나중에 만들 파일
import 'car_management_screen.dart'; // 나중에 만들 파일
import 'notification_screen.dart';
import 'home_screen.dart';
import 'dart:convert'; // 👈 데이터 변환 도구
// main.dart 맨 위쪽
import 'package:http/http.dart' as http; // 👈 서버 통신 도구

// 💡 지금은 현재 테스트 중인 임의의 서버(에뮬레이터) 주소를 적어둡니다!
const String baseUrl =
    'http://springweb-env.eba-shnyk9a8.ap-northeast-2.elasticbeanstalk.com';

// 전역 변수: 스마트폰 안전 금고 & 다크모드 리모컨
final storage = FlutterSecureStorage();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
// 💡 [수정 위치 1] 여기에 함수를 통째로 추가하세요. (main 함수 바깥입니다)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("백그라운드 메시지 수신: ${message.messageId}");
}

void main() async {
  // 1. 플러터 엔진과 프레임워크가 자리를 잡을 때까지 기다립니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 파이어베이스를 우리 앱의 설정값(DefaultFirebaseOptions)으로 초기화합니다.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 👇👇 [여기부터 새로 추가!] 최신 폰을 위한 푸시 알림 권한 필수 요청 👇👇
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  print('사용자 알림 권한 상태: ${settings.authorizationStatus}');
  // 👆👆 [여기까지 추가] 👆👆
  // 3. 모든 준비가 끝나면 비로소 앱을 실행합니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false, // 디버그 배너 숨김
          title: 'Park On', // 💡 다시 넣었습니다!
          theme: ThemeData.light(), // 밝은 모드 설정
          darkTheme: ThemeData.dark(), // 다크 모드 설정
          themeMode: currentMode, // 💡 다크모드/라이트모드 전환 연결
          home: const SplashCheckScreen(), // 앱의 시작 화면
          // 혹시 더 필요한 설정이 있다면 여기에 계속 추가하시면 됩니다.
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
    if (!mounted) return; // 👇 1초 사이에 화면이 꺼졌으면 이동 취소!
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

  // 💡 [수정] 변수 정의 누락 해결: 내 차량 번호를 기억할 공간을 만듭니다.
  String? myCarNumber;

  @override
  void initState() {
    super.initState();
    // 💡 [수정] 앱이 켜질 때 내 차량 번호부터 서버에 물어보고 가져옵니다.
    _fetchMyCarNumber();
    _setupForegroundFCM();
  }

  // 💡 [추가] 서버에서 로그인한 사용자의 등록 차량 번호를 긁어오는 함수
  Future<void> _fetchMyCarNumber() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/cars');
    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true &&
            data['resident_cars'] != null &&
            data['resident_cars'].isNotEmpty) {
          if (!mounted) return;
          setState(() {
            // 사용자의 첫 번째 입주민 차량 번호를 변수에 할당합니다.
            myCarNumber = data['resident_cars'][0]['c_number'];
          });
        }
      }
    } catch (e) {
      print("메인 탭 화면 차량 번호 로드 실패: $e");
    }
  }

  void _setupForegroundFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (!mounted) return;

        // 새 알림이 오면 기존에 떠 있던 알림창을 즉시 삭제합니다.
        ScaffoldMessenger.of(context).clearSnackBars();

        String title = message.notification!.title ?? '알림';
        String body = message.notification!.body ?? '';

        // 내 차 알림인지 확인하는 로직 (이제 myCarNumber가 선언되어 에러가 나지 않습니다!)
        bool isMyCarNotification =
            myCarNumber != null && body.contains(myCarNumber!);

        if (isMyCarNotification) {
          // 💡 서버에서 온 본문(body) 내용에 '주차'나 '구역'이라는 단어가 포함되어 있다면?
          if (body.contains('주차') || body.contains('구역')) {
            title = '🅿️ [내 차] 주차 완료 알림'; // 주차 알림으로 띄움!
          } else {
            // 그 외에는 기존처럼 차단기 통과로 띄움!
            title = '🚗 [내 차] 차단기 통과 알림';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            // 내 차 알림일 경우 파란색 네온 테두리 적용
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isMyCarNotification
                    ? Colors.blueAccent
                    : Colors.transparent,
                width: isMyCarNotification ? 2.0 : 0.0,
              ),
            ),
            // [안 사라지는 버그 우회] 공식 action을 없애고 Row 안에 직접 버튼 배치!
            content: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isMyCarNotification
                              ? Colors.blueAccent
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(body, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    setState(() => _selectedIndex = 3);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '확인하기',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomeScreen(onTabChanged: _onItemTapped), // 0: 홈 (대시보드)
      const ParkingScreen(), // 1: 주차장
      const InquiryScreen(), // 2: 문의게시판
      NotificationScreen(onTabChanged: _onItemTapped), // 3: 알림
      const SettingsScreen(), // 4: 설정
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
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

// --- 공용 로딩 애니메이션 부품 ---
class CustomLoading extends StatelessWidget {
  const CustomLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/loading_car.json', // 💡 아까 저장하신 파일 이름
        width: 150,
        height: 150,
      ),
    );
  }
}
