import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http; // 👈 추가!
import 'package:parking2/car_management_screen.dart';
import 'package:parking2/login_screen.dart';
import 'dart:convert'; // 👈 추가!
import 'main.dart';
import 'package:parking2/inquiry_screen.dart'; // 💡 패키지 명에 맞춰 수정 필요

// ...
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 💡 DB의 settings 테이블과 연동될 설정값들
  bool _isPushAlarmOn = true;

  // 👇 여기서부터 추가 👇
  String _userName = "로딩 중...";
  String _userDong = "";
  String _userHo = "";

  @override
  void initState() {
    super.initState();
    _fetchUserProfile(); // 화면이 켜질 때 내 정보 불러오기!
  }

  Future<void> _fetchUserProfile() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return; // 로그인 토큰이 없으면 중단

    final url = Uri.parse('$baseUrl/api/user-info');

    try {
      final response = await http.get(
        url,
        // 💡 핵심: 서버에 내 토큰(출입증)을 보여주면서 정보 요청!
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _userName = data['user']['u_name'];
            _userDong = data['user']['u_dong'];
            _userHo = data['user']['u_ho'];
          });
        }
      }
    } catch (e) {
      print("내 정보 불러오기 실패: $e");
      setState(() {
        _userName = "홍길동"; // 통신 실패 시 기본값
        _userDong = "101동";
        _userHo = "101호";
      });
    }
  }
  // ... 기존 _fetchUserProfile 함수 끝나는 부분 ...

  // 💡 [추가] 1. 푸시 알림 설정 서버에 저장하기
  Future<void> _updateNotificationSetting(bool value) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/settings/push');
    try {
      await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"alert_push": value ? 1 : 0}), // true면 1, false면 0 전송
      );
    } catch (e) {
      print("알림 설정 동기화 실패: $e");
    }
  }

  // 💡 [추가] 2. 다크 모드 설정 서버에 저장하기
  Future<void> _updateThemeSetting(bool isDark) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/settings/theme');
    try {
      await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"theme_mode": isDark ? 'dark' : 'light'}), //
      );
    } catch (e) {
      print("테마 설정 동기화 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 앱의 다크모드 상태 확인
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '설정 및 마이페이지',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // 1. 프로필 섹션 (user 테이블: u_name, u_dong, u_ho)
          _buildProfileHeader(isDark),

          const SizedBox(height: 12),

          // 2. 내 차량 관리
          _buildSectionTitle('내 등록 차량 관리'),
          _buildVehicleItem(
            icon: Icons.directions_car_filled,
            plate: '12가 3456',
            desc: '제네시스 (입주민)',
            onTap: () => _navigateTo(const CarManagementScreen()),
          ),
          _buildVehicleItem(
            icon: Icons.add_circle_outline,
            plate: '새 차량 등록',
            desc: '방문객 차량 및 신규 차량 등록',
            color: Colors.blueAccent,
            onTap: () => _navigateTo(const CarManagementScreen()),
          ),

          const SizedBox(height: 12),
          // 3. 앱 설정 섹션 수정
          _buildSectionTitle('앱 설정'),
          _buildSwitchItem(
            icon: Icons.notifications_active_outlined,
            title: '푸시 알림 수신',
            value: _isPushAlarmOn,
            onChanged: (val) {
              setState(() => _isPushAlarmOn = val); // 화면 즉시 변경
              _updateNotificationSetting(val); // 💡 서버 DB에 저장!
            },
          ),
          _buildSwitchItem(
            icon: Icons.dark_mode_outlined,
            title: '다크 모드',
            value: isDark,
            onChanged: (bool value) {
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
              _updateThemeSetting(value); // 💡 서버 DB에 저장!
            },
          ),
          const SizedBox(height: 12),

          // 4. 고객 지원 및 계정
          _buildSectionTitle('고객 지원 및 계정'),
          _buildMenuItem(
            icon: Icons.chat_bubble_outline,
            title: '내 민원 내역 확인',
            onTap: () {
              // 💡 기존 SnackBar 코드를 지우고 아래 한 줄을 넣습니다!
              _navigateTo(const InquiryScreen());
            },
          ),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '앱 버전 정보',
            onTap: () => _showVersionInfo(), // 버전 정보 팝업
          ),
          _buildMenuItem(
            icon: Icons.logout,
            title: '로그아웃',
            isDestructive: true,
            onTap: () => _handleLogout(), // 로그아웃 로직
          ),
        ],
      ),
    );
  }

  // --- 💡 주요 기능 로직들 ---

  // 페이지 이동 공통 함수
  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // 버전 정보 팝업창
  void _showVersionInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'Park On',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.apartment_rounded, size: 50),
      children: [const Text('본 서비스는 입주민 전용 스마트 주차 시스템입니다.')],
    );
  }

  // 로그아웃 로직 (회원님 코드 적용)
  void _handleLogout() async {
    const storage = FlutterSecureStorage();
    // 👇 여기서부터 새롭게 추가된 [FCM 토큰 삭제 요청 로직] 👇
    try {
      String? token = await storage.read(key: 'jwt_token');
      if (token != null) {
        // 서버로 알림 주소 폐기 통신 (DELETE 방식)
        await http.delete(
          Uri.parse('$baseUrl/api/device-token'),
          headers: {"Authorization": "Bearer $token"},
        );
      }
    } catch (e) {
      print("FCM 토큰 삭제 통신 실패 (서버 연동 전까지는 무시하셔도 됩니다): $e");
    }
    // 👆 여기까지 추가 완료 👆
    await storage.delete(key: 'jwt_token');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  // --- UI 컴포넌트들 ---

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.black87,
            child: Icon(Icons.person, color: Colors.white, size: 35),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_userName 님', // 💡 서버에서 받아온 이름으로 변경!
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '명학아파트 $_userDong $_userHo', // 💡 서버에서 받아온 동/호수로 변경!
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildVehicleItem({
    required IconData icon,
    required String plate,
    required String desc,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Container(
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.black87),
        title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      color: Theme.of(context).cardColor,
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        value: value,
        activeColor: Colors.blueAccent,
        onChanged: onChanged,
      ),
    );
  }

  // 💡 중괄호 {} 안에 required 를 넣어서 이름표(Named Parameter) 방식으로 변경했습니다!
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.redAccent : null),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: isDestructive ? Colors.redAccent : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}
