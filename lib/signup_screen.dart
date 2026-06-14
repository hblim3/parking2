import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'package:flutter/services.dart'; // 👈 [이 줄을 추가해 주세요!] 입력 제어 도구

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // 컨트롤러들 (기존과 동일)
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _dongController = TextEditingController();
  final TextEditingController _hoController = TextEditingController();
  final TextEditingController _aptPwdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // 💡 [수정] 서버에서 받아온 아파트 목록을 저장할 변수
  List<dynamic> _aptList = [];
  String? _selectedAptNo; // 선택된 아파트 번호 (a_no)
  bool _isLoadingApts = true; // 아파트 목록 로딩 상태

  @override
  void initState() {
    super.initState();
    _loadApartments(); // 💡 화면이 시작될 때 목록을 불러옵니다.
  }

  // 💡 [추가] 서버에서 아파트 목록(a_no, a_name)을 가져오는 함수
  Future<void> _loadApartments() async {
    final url = Uri.parse('$baseUrl/api/apartments');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;
          setState(() {
            _aptList = data['apartments'];
            // 첫 번째 아파트를 기본값으로 설정
            if (_aptList.isNotEmpty) {
              _selectedAptNo = _aptList[0]['a_no'].toString();
            }
            _isLoadingApts = false;
          });
        }
      }
    } catch (e) {
      print("아파트 목록 불러오기 실패: $e");
      if (mounted) setState(() => _isLoadingApts = false);
    }
  }

  Future<void> _submitSignUp() async {
    if (_selectedAptNo == null) return;

    final url = Uri.parse('$baseUrl/api/signup');

    Map<String, dynamic> signUpData = {
      "u_id": _idController.text,
      "u_pwd": _pwdController.text,
      "u_name": _nameController.text,
      "u_email": _emailController.text,
      "u_phone": _phoneController.text,
      "u_dong": _dongController.text,
      "u_ho": _hoController.text,
      "a_no": int.parse(_selectedAptNo!), // 💡 선택된 번호 사용
      "a_pwd": _aptPwdController.text,
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(signUpData),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다! 로그인해 주세요.')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 실패. 아이디 중복 또는 빈칸을 확인해주세요.')),
        );
      }
    } catch (e) {
      print("통신 에러 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = isDark ? Colors.white : Colors.black;
    Color onPrimaryColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('입주민 회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '아파트 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 💡 [수정] 동적으로 생성되는 드롭다운 버튼
            _isLoadingApts
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: _selectedAptNo,
                    decoration: const InputDecoration(
                      labelText: '아파트 선택',
                      border: OutlineInputBorder(),
                    ),
                    // 서버에서 받은 _aptList를 바탕으로 메뉴 아이템 생성
                    items: _aptList.map((apt) {
                      return DropdownMenuItem<String>(
                        value: apt['a_no'].toString(), // 실제 DB의 a_no
                        child: Text(apt['a_name']), // 화면에 보여줄 아파트 이름
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedAptNo = value!),
                  ),

            const SizedBox(height: 10),
            // ... (나머지 텍스트 필드들은 기존과 동일) ...
            TextField(
              controller: _aptPwdController,
              decoration: const InputDecoration(
                labelText: '아파트 공용 비밀번호 (입주민 확인용)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dongController,
                    keyboardType: TextInputType
                        .number, // 👈 [방어 1] 터치 시 '숫자 전용 키패드'가 올라옵니다.
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly, // 👈 [방어 2] 혹시 복사/붙여넣기를 해도 '숫자'만 남기고 다 지워버립니다!
                    ],
                    decoration: const InputDecoration(
                      labelText: '동 (숫자만 입력)', // 안내 문구 수정
                      hintText: '예: 101',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hoController,
                    keyboardType: TextInputType.number, // 👈 동일하게 숫자 패드 적용
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // 👈 동일하게 숫자만 허용
                    ],
                    decoration: const InputDecoration(
                      labelText: '호 (숫자만 입력)', // 안내 문구 수정
                      hintText: '예: 1101',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 40, thickness: 2),
            const Text(
              '개인 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름 (실명)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일 주소',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '전화번호 (예: 010-1234-5678)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: '아이디',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pwdController,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: primaryColor,
                foregroundColor: onPrimaryColor,
              ),
              onPressed: _submitSignUp,
              child: const Text(
                '가입하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
