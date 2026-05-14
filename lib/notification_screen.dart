import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 👈 추가
import 'dart:convert'; // 👈 추가
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 👈 추가
import 'main.dart';

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

    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse('$baseUrl/api/notifications');

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
            notifications = List<Map<String, dynamic>>.from(
              data['notifications'],
            );
          });
        }
      } else {
        print("서버 에러 발생: 상태 코드 ${response.statusCode}");
      }
    } catch (e) {
      print("알림 목록 불러오기 실패 (네트워크 등): $e");
    } finally {
      // 💡 핵심 수정: 통신이 성공하든, 404 에러가 나든, 와이파이가 끊기든
      // 이 로직의 끝에서는 무조건 로딩(isLoading)을 false로 꺼줍니다!
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  // ... 기존 _fetchNotifications 함수 끝나는 부분 ...

  // 💡 [추가] 서버에 알림 읽음 처리(is_read = 1) 요청하기
  Future<void> _markAsRead(int notiNo) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    // REST API: 어떤 알림을 읽었는지 번호(notiNo)를 주소에 담아 보냅니다.
    final url = Uri.parse('$baseUrl/api/notifications/$notiNo/read');

    try {
      final response = await http.patch(
        // 상태를 일부 수정(업데이트)할 때는 주로 patch나 put을 씁니다.
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        // 💡 서버에서 읽음 처리가 성공하면, 알림 목록을 다시 불러와서 테두리를 투명하게(읽음 상태) 만듭니다!
        _fetchNotifications();
      }
    } catch (e) {
      print("알림 읽음 처리 실패: $e");
    }
  }

  // ... 기존 _getIconForType 함수 시작 부분 ...
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
          // 💡 여기서부터 파일 맨 끝까지 통째로 덮어써주세요!
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final noti = notifications[index];

                // 💡 서버에서 받아온 데이터 이름표
                final int notiNo = noti['noti_no'] ?? 0; // 👈 알림 고유 번호(PK)
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
                      // 1. 아직 안 읽은 알림(isRead가 false)일 때만 서버에 읽음 처리 요청을 보냅니다.
                      if (!isRead && notiNo != 0) {
                        _markAsRead(notiNo);
                      }

                      // 2. 알림 터치 시 나오는 팝업
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('해당 화면으로 이동합니다.')),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
} 
// 👈 파일의 맨 끝입니다. 이 아래에는 아무것도 없어야 합니다!