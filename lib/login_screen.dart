import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'signup_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'find_account_screen.dart'; // 💡 아이디/비밀번호 찾기 화면 연결!

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController pwController = TextEditingController();

  void _login() async {
    String inputId = idController.text.trim();
    String inputPw = pwController.text.trim();

    if (inputId.isEmpty || inputPw.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')));
      return;
    }

    try {
      final url = Uri.parse('$baseUrl/api/login');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"u_id": inputId, "u_pwd": inputPw}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await storage.write(key: 'jwt_token', value: data['token']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainTabScreen()),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data['message'])));
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('아이디 또는 비밀번호가 틀렸습니다.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('서버 연결 실패: $e')));
    }
  }

  // 💡 모던한 블랙 테두리 스타일의 입력 칸
  Widget _buildCustomTextField({
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
    bool isObscure = false,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black87, width: 1.5), // 선명한 검은색 테두리
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            decoration: const BoxDecoration(
              color: Colors.black87, // 아이콘 배경은 진한 검은색
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white), // 아이콘은 흰색
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                obscureText: isObscure,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 깔끔한 흰색 배경
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // 1. 중앙 메인 타이틀 (기울어진 로고 + SMART PARKING)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Transform.rotate(
                      angle: -0.3,
                      child: const Icon(
                        Icons.time_to_leave_rounded,
                        size: 90,
                        color: Colors.black87, // 시크한 검은색 로고
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SMART',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: 1.5,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'PARKING',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: 1.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                // 2. 아이디 / 비밀번호 입력 칸
                _buildCustomTextField(
                  icon: Icons.person,
                  hintText: '아이디',
                  controller: idController,
                ),
                const SizedBox(height: 12),
                _buildCustomTextField(
                  icon: Icons.lock,
                  hintText: '비밀번호',
                  controller: pwController,
                  isObscure: true,
                ),

                const SizedBox(height: 20),

                // 3. 로그인 버튼 (솔리드 블랙)
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white, // 글자색 흰색
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 12),

                // 4. 회원가입 버튼 (흰 바탕 + 검은 테두리)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(
                        color: Colors.black87,
                        width: 1.5,
                      ), // 검은색 테두리
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 30),

                // 5. 하단 텍스트 (찾기 화면 이동 기능 연동 완료)
                Center(
                  child: TextButton(
                    onPressed: () {
                      // 💡 이제 이 버튼을 누르면 이전에 만든 찾기 화면으로 이동합니다!
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindAccountScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '아이디 / 비밀번호 찾기 >',
                      style: TextStyle(
                        color: Colors.black54, // 모던한 느낌의 회색
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
