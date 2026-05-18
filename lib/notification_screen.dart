import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
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
        throw Exception('서버 응답 오류');
      }
    } catch (e) {
      print("알림 목록 불러오기 실패 (시연용 Mock 데이터 적용): $e");

      if (!mounted) return;
      // 💡 [핵심 추가] 서버 연결 실패 시 시연을 위한 가짜 데이터를 띄워줍니다!
      setState(() {
        notifications = [
          {
            'noti_no': 1,
            'noti_type': 'system', // 안내 아이콘
            'noti_title': '🚨 빈자리 알림',
            'noti_message': '대기 신청하신 [A-5] 구역에 빈자리가 생겼습니다! 다른 입주민보다 먼저 주차하세요.',
            'is_read': 0, // 0 = 안 읽음 (테두리 및 강조 효과)
            'created_at': '방금 전',
          },
          {
            'noti_no': 2,
            'noti_type': 'visitor', // 자동차 아이콘
            'noti_title': '🅿️ 주차 완료 알림',
            'noti_message': '[A-2] 구역에 내 차량(12가 3456) 주차가 완료되었습니다.',
            'is_read': 0,
            'created_at': '25분 전',
          },
        ];
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(int notiNo) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/notifications/$notiNo/read');

    try {
      final response = await http.patch(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        _fetchNotifications();
      } else {
        throw Exception('서버 에러');
      }
    } catch (e) {
      print("알림 읽음 처리 통신 실패: $e");

      // 💡 [핵심 추가] 시연 중에 서버가 없더라도, 알림을 터치하면 바로 읽음 처리(회색) 되도록 구현!
      if (!mounted) return;
      setState(() {
        for (var noti in notifications) {
          if (noti['noti_no'] == notiNo) {
            noti['is_read'] = 1; // 1이면 읽음 처리되어 테두리가 사라짐
          }
        }
      });
    }
  }

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
      backgroundColor: Colors.grey[100],
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

                final int notiNo = noti['noti_no'] ?? 0;
                final String type = noti['noti_type'] ?? 'system';
                final String title = noti['noti_title'] ?? '알림';
                final String body = noti['noti_message'] ?? '';
                final bool isRead = noti['is_read'] == 1;
                String time = noti['created_at'] ?? '';
                // 💡 [시간 변환 코드 추가] T가 포함된 컴퓨터 시간이면 예쁘게 잘라줍니다.
                if (time.contains('T')) {
                  DateTime dt = DateTime.parse(
                    time,
                  ).toLocal(); // Z(표준시)를 한국 시간으로 변환
                  // YYYY-MM-DD HH:MM 형태로 조립
                  time =
                      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                }
                // 👆 여기까지 수정/추가 완료 👆
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
                      if (!isRead && notiNo != 0) {
                        _markAsRead(notiNo);
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('해당 구역의 화면으로 이동합니다.')),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
