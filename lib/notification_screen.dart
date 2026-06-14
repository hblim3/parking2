import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';
import 'car_management_screen.dart';

class NotificationScreen extends StatefulWidget {
  // 👇 부모(메인 화면)로부터 탭을 변경하는 '리모컨(함수)'을 전달받도록 수정
  final Function(int)? onTabChanged;

  const NotificationScreen({Key? key, this.onTabChanged}) : super(key: key);

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
      if (mounted) setState(() => isLoading = false); // 👇 방어막 추가!
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

      // 👇 1. 여기에 한 줄 추가!
      if (!mounted) return;

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
      // 💡 [수정됨] 서버 없이 UI만 바로 확인할 수 있도록 시연용 가짜 데이터를 세팅합니다.
      setState(() {
        notifications = [
          {
            'noti_no': 1,
            'noti_type': 'system', // 안내 아이콘
            'noti_title': '🔔 지정 구역 빈자리 알림',
            'noti_message': '대기 신청하신 [a-b1-005] 구역의 차량이 출차했습니다! 지금 바로 주차하세요.',
            'is_read': 0, // 0 = 안 읽음 (테두리 및 강조 효과, 검은색 굵은 글씨)
            'created_at': '방금 전',
          },
          {
            'noti_no': 2,
            'noti_type': 'system',
            'noti_title': '🚨 만차 대기 빈자리 알림',
            'noti_message':
                '주차장에 빈자리([a-b1-004])가 발생했습니다! 빈자리를 찾고 계셨다면 지금 이동해 주세요.',
            'is_read': 0,
            'created_at': '2분 전',
          },
          {
            'noti_no': 3,
            'noti_type': 'visitor', // 자동차 아이콘
            'noti_title': '🅿️ 주차 완료 알림',
            'noti_message': '[a-b1-002] 구역에 내 차량(12가3456) 주차가 완료되었습니다.',
            'is_read': 1, // 1 = 읽음 (배경색 투명, 왼쪽 테두리 없음, 회색 글씨)
            'created_at': '25분 전',
          },
          // 👇 [여기에 추가!] 관리자 연락 요청 시연용 데이터
          {
            'noti_no': 4,
            'noti_type': 'manager_contact', // 관리자 타입
            'noti_title': '📢 관리자 연락 요청',
            'noti_message': '통로 주차 상태 확인이 필요합니다. 앱 알림 확인 후 관리사무소로 연락해주세요.',
            'is_read': 0, // 0 = 안 읽음 (빨간 테두리 쳐짐)
            'created_at': '방금 전',
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
            noti['is_read'] = true; // 1이면 읽음 처리되어 테두리가 사라짐
          }
        }
      });
    }
  }

  // =========================================================
  // 👇 [추가] 알림 스와이프 시 서버 DB에서도 삭제하는 함수
  // =========================================================
  Future<void> _deleteNotification(int notiNo) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/notifications/$notiNo');

    try {
      // 💡 HTTP DELETE 요청으로 서버에 삭제 지시
      await http.delete(url, headers: {"Authorization": "Bearer $token"});
      print("알림 삭제 완료 (notiNo: $notiNo)");
    } catch (e) {
      print("알림 삭제 통신 실패: $e");
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
      // 👇 [여기에 한 줄 추가!] 관리자 연락 타입일 때 확성기 아이콘 표시
      case 'manager_contact':
        return Icons.campaign_outlined;
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
          ? const CustomLoading() // 👈 딱 이 한 줄로 깔끔하게 교체!
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
                // 👇 기존의 딱딱한 매칭 방식 대신, or(||) 연산자로 둘 다 체크하게 변경합니다.
                final String type =
                    noti['noti_type'] ?? noti['notiType'] ?? 'system';
                final String title =
                    noti['noti_title'] ?? noti['notiTitle'] ?? '알림';
                final String body =
                    noti['noti_message'] ?? noti['notiMessage'] ?? '';
                final bool isRead =
                    (noti['read'] == true) ||
                    (noti['is_read'] == true) ||
                    (noti['is_read'] == 1);
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
                // 👇 여기서부터 끝까지 덮어쓰세요!
                return Dismissible(
                  // 1. 고유 키값 (어떤 알림인지 식별)
                  key: Key('$notiNo-$index'),

                  // 1. 양방향 스와이프 설정
                  direction: DismissDirection.horizontal,

                  // 3. 밀 때 뒤에 보이는 빨간색 배경과 휴지통 아이콘
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  // 4. 스와이프해서 완전히 넘겼을 때 실행되는 동작
                  onDismissed: (direction) {
                    // ① 서버에서 알림 삭제 (이전에 만든 함수 호출)
                    if (notiNo != 0) {
                      _deleteNotification(notiNo);
                    }

                    // ② 화면에서 즉시 알림 지우기
                    setState(() {
                      notifications.removeAt(index);
                    });

                    // ③ 알림 지워짐 안내 팝업
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('알림이 삭제되었습니다.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },

                  // 5. 원래 보여주던 UI (기존 Container 코드 그대로 들어감)
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRead ? Colors.transparent : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.2,
                        ),
                        left: isRead
                            ? BorderSide.none
                            : const BorderSide(color: Colors.black87, width: 4),
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

                        String notiType = noti['noti_type'] ?? 'system';

                        if (notiType == 'visitor') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CarManagementScreen(),
                            ),
                          ).then((_) => _fetchNotifications());
                        }
                        // 👇 [여기에 추가!] 관리자 알림이면 화면 이동 없이 스낵바만 띄웁니다.
                        else if (notiType == 'manager_contact') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('관리자 알림을 확인했습니다.')),
                          );
                        }
                        // 👆
                        else {
                          if (widget.onTabChanged != null) {
                            widget.onTabChanged!(0);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('주차장 화면으로 이동했습니다.')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
