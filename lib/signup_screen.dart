import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _dongController = TextEditingController();
  final TextEditingController _hoController = TextEditingController();
  final TextEditingController _aptPwdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedAptNo = '1';

  Future<void> _submitSignUp() async {
    final url = Uri.parse('$baseUrl/api/signup');

    Map<String, dynamic> signUpData = {
      "u_id": _idController.text,
      "u_pwd": _pwdController.text,
      "u_name": _nameController.text,
      "u_email": _emailController.text,
      "u_phone": _phoneController.text,
      "u_dong": _dongController.text,
      "u_ho": _hoController.text,
      "a_no": int.parse(_selectedAptNo),
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
            DropdownButtonFormField<String>(
              value: _selectedAptNo,
              decoration: const InputDecoration(
                labelText: '아파트 선택',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '1', child: Text('명학 아파트')),
                DropdownMenuItem(value: '2', child: Text('성결 아파트')),
                DropdownMenuItem(value: '3', child: Text('안양 아파트')),
              ],
              onChanged: (value) => setState(() => _selectedAptNo = value!),
            ),
            const SizedBox(height: 10),
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
                    decoration: const InputDecoration(
                      labelText: '동 (예: 101동)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hoController,
                    decoration: const InputDecoration(
                      labelText: '호 (예: 202호)',
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
            // 👇 여기서부터 새로 추가된 입력 칸들 👇
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
              keyboardType: TextInputType.phone, // 숫자 키패드가 뜨도록 설정
            ),
            const SizedBox(height: 10),
            // 👆 여기까지 새로 추가됨 👆
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
