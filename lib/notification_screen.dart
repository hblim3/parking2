import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 👈 추가
import 'dart:convert'; // 👈 추가
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 👈 추가

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // 💡 나중에 서버에서 받아올 알림 내역 가짜 데이터 세팅
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => isLoading = true);

    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    // 💡 나중에 AWS 진짜 IP로 변경하세요!
    final url = Uri.parse('http://10.0.2.2:3000/api/notifications');

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
        if (data['success'] == true) {
          if (!mounted) return;
          setState(() {
            // 💡 서버 DB의 컬럼명과 앱의 변수명을 맞춰주는 과정입니다.
            notifications = List<Map<String, dynamic>>.from(
              data['notifications'],
            );
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("알림 목록 불러오기 실패: $e");
      // 통신 실패 시 시연을 위해 기존 가짜 데이터를 유지하거나 빈 리스트를 보여줍니다.
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 알림 종류에 따라 어울리는 아이콘을 반환하는 함수
  IconData _getIconForType(String type) {
    switch (type) {
      case 'inquiry':
        return Icons.question_answer_outlined; // 답변 아이콘
      case 'visitor':
        return Icons.no_crash_outlined; // 차량 아이콘
      case 'system':
        return Icons.info_outline; // 안내 아이콘
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // 아주 연한 회색 배경
      appBar: AppBar(
        title: const Text(
          '알림 내역',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.black87),
            )
          : notifications.isEmpty
          ? const Center(
              child: Text(
                '새로운 알림이 없습니다.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final noti = notifications[index];

                // 💡 서버에서 받아온 데이터 이름표
                final String type = noti['noti_type'] ?? 'system';
                final String title = noti['noti_title'] ?? '알림';
                final String body = noti['noti_message'] ?? '';
                final bool isRead = noti['is_read'] == 1;
                final String time = noti['created_at'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.transparent : Colors.white,
                    border: isRead
                        ? null
                        : const Border(
                            left: BorderSide(color: Colors.black87, width: 4),
                          ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isRead
                          ? Colors.grey[300]
                          : Colors.black87,
                      child: Icon(
                        _getIconForType(type),
                        color: isRead ? Colors.black54 : Colors.white,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            body,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('해당 화면으로 이동합니다. (준비 중)')),
                      );
                    },
                  ),
                );
              }, // <-- 아까 지워졌던 괄호 1
            ), // <-- 아까 지워졌던 괄호 2
    ); // <-- 아까 지워졌던 괄호 3
  }
} // <-- 아까 지워졌던 괄호 4 (클래스 닫기)
