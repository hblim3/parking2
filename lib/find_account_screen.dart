import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FindAccountScreen extends StatefulWidget {
  const FindAccountScreen({Key? key}) : super(key: key);

  @override
  State<FindAccountScreen> createState() => _FindAccountScreenState();
}

class _FindAccountScreenState extends State<FindAccountScreen> {
  // 아이디 찾기용
  final TextEditingController _dongController1 = TextEditingController();
  final TextEditingController _hoController1 = TextEditingController();
  final TextEditingController _aptPwdController =
      TextEditingController(); // 💡 닉네임 대신 공용 비번

  // 비밀번호 재설정용
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _dongController2 = TextEditingController();
  final TextEditingController _hoController2 = TextEditingController();
  final TextEditingController _newPwController = TextEditingController();

  Future<void> _findId() async {
    final url = Uri.parse('http://10.0.2.2:3000/api/find-id');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "u_dong": _dongController1.text, // dong -> u_dong
          "u_ho": _hoController1.text, // ho -> u_ho
          "apt_pwd": _aptPwdController.text,
        }),
      );
      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        _showResultDialog('아이디 찾기 성공', '회원님의 아이디는\n[ ${data['u_id']} ] 입니다.');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('서버 연결 실패')));
    }
  }

  Future<void> _resetPassword() async {
    final url = Uri.parse('http://10.0.2.2:3000/api/reset-pw');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "u_id": _idController.text,
          "u_dong": _dongController2.text, // dong -> u_dong
          "u_ho": _hoController2.text, // ho -> u_ho
          "newPassword": _newPwController.text,
        }),
      );
      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        _showResultDialog(
          '비밀번호 변경 완료',
          '비밀번호가 성공적으로 변경되었습니다.\n새 비밀번호로 로그인해주세요.',
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('서버 연결 실패')));
    }
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (title == '비밀번호 변경 완료') Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('계정 찾기'),
          backgroundColor: Colors.black87, // 💡 B&W 테마에 맞춤
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: '아이디 찾기'),
              Tab(text: '비밀번호 재설정'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  TextField(
                    controller: _dongController1,
                    decoration: const InputDecoration(
                      labelText: '동 (예: 101동)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hoController1,
                    decoration: const InputDecoration(
                      labelText: '호 (예: 201호)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 💡 닉네임 대신 아파트 공용 비밀번호
                  TextField(
                    controller: _aptPwdController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '아파트 공용 비밀번호',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _findId,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      '아이디 찾기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: '가입된 아이디',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dongController2,
                    decoration: const InputDecoration(
                      labelText: '동 (예: 101동)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hoController2,
                    decoration: const InputDecoration(
                      labelText: '호 (예: 201호)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '새로 사용할 비밀번호',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _resetPassword,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      '비밀번호 변경하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
