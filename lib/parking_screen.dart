import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 통신 도구
import 'dart:convert'; // 통신 도구
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 💡 이 줄이 꼭 있어야 합니다!
import 'main.dart';

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({Key? key}) : super(key: key);

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  final String myCarNumber = "12가 3456";

  List<Map<String, dynamic>> parkingSlots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchParkingStatus();
  }

  Future<void> _fetchParkingStatus() async {
    setState(() => isLoading = true);

    // 💡 나중에 서버 컴퓨터(또는 AWS)의 진짜 IP 주소로 바꿔야 합니다!
    final url = Uri.parse('$baseUrl/api/parking-zones');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          // 💡 서버에서 보내주는 JSON 데이터를 그대로 리스트에 덮어씌웁니다.
          // (서버 개발자에게 기존 앱 데이터 형식과 똑같이 만들어서 보내달라고 요청하세요!)
          parkingSlots = List<Map<String, dynamic>>.from(data['zones']);
        });
      } else {
        throw Exception('서버 응답 오류');
      }
    } catch (e) {
      print("서버 연결 실패 - 시연용 데이터를 표시합니다. 에러: $e");
      if (!mounted) return;
      setState(() {
        // 💡 통신 실패 시에도 2칸-통로-3칸-통로-2칸이 나오도록 가짜 데이터를 세팅!
        parkingSlots = [
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-1",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-2",
            "isOccupied": true,
            "current_car_number": "12가 3456",
          },
          {
            "floor": "B1",
            "type": "aisle",
            "slot": "통로 1",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-3",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-4",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-5",
            "isOccupied": true,
            "current_car_number": "99하 9999",
          },
          {
            "floor": "B1",
            "type": "aisle",
            "slot": "통로 2",
            "isOccupied": true,
            "current_car_number": "불법 8888",
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-6",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-7",
            "isOccupied": false,
            "current_car_number": null,
          },
        ];
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 💡 알림 신청 팝업창을 띄우는 함수 (핵심 로직)
  void _showNotificationDialog(String target) {
    String title = target == 'ALL' ? '전체 빈자리 알림' : '$target 구역 지정 알림';
    String content = target == 'ALL'
        ? '주차장에 빈자리가 생기면 푸시 알림을 보내드릴까요?'
        : '$target 구역의 차량이 출차하면 푸시 알림을 보내드릴까요?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
            onPressed: () async {
              Navigator.pop(ctx); // 팝업창 닫기

              // 1. 내 토큰 꺼내오기
              const storage = FlutterSecureStorage();
              String? token = await storage.read(key: 'jwt_token');
              if (token == null) return;

              // 2. 서버로 대기열 신청 보내기 (target: 'ALL' 또는 'A-1')
              final url = Uri.parse('$baseUrl/api/waitlist');
              try {
                final response = await http.post(
                  url,
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer $token",
                  },
                  body: jsonEncode({
                    "target_slot_id": target, // 'ALL' 또는 특정 구역 이름
                  }),
                );

                if (response.statusCode == 200) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ $title 신청이 완료되었습니다. 자리가 나면 푸시 알림을 보내드릴게요!',
                      ),
                    ),
                  );
                } else {
                  throw Exception('서버 에러');
                }
              } catch (e) {
                print("대기열 신청 실패: $e");
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('대기 신청에 실패했습니다.')));
              }
            },
            child: const Text(
              '신청하기',
              style: TextStyle(color: Colors.white),
            ), // 💡 아까 지워졌던 부분 복구!
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '실시간 주차 현황',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchParkingStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, '빈자리'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.redAccent, '주차됨'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.blueAccent, '내 차'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.orange, '불법주차'),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black87),
                  )
                : _buildFloorGrid('B1'),
          ),
        ],
      ),
      // 💡 1. 전체 알림 신청 플로팅 버튼 추가!
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNotificationDialog('ALL'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.notifications_active),
        label: const Text(
          '만차 시 알림 대기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFloorGrid(String floor) {
    // 1. 해당 층의 데이터만 필터링
    final floorSlots = parkingSlots.where((s) => s['floor'] == floor).toList();

    // 2. 💡 핵심: 가로로 스크롤 할 수 있는 도화지를 만듭니다!
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        // 3. 리스트에 있는 순서대로 가로로 쭉 나열합니다.
        children: floorSlots.map((slotData) {
          final type = slotData['type'];

          if (type == 'blank') {
            return const SizedBox(width: 20); // 빈 공간일 경우 간격만 띄움
          }

          final isOccupied = slotData['isOccupied'];
          final slotName = slotData['slot'];
          final parkedCarNumber = slotData['current_car_number'];
          final isMyCar =
              (type == 'slot') &&
              isOccupied &&
              (parkedCarNumber == myCarNumber);

          Color boxColor;
          Color borderColor;
          IconData slotIcon;
          String badgeText = '';

          // 🎨 색상 및 아이콘 설정 (기존 로직 동일)
          if (type == 'aisle') {
            if (isOccupied) {
              boxColor = Colors.orange.withOpacity(0.15);
              borderColor = Colors.orange;
              slotIcon = Icons.warning_amber_rounded;
              badgeText = '불법주차';
            } else {
              boxColor = Colors.grey.withOpacity(0.05);
              borderColor = Colors.grey[400]!;
              slotIcon = Icons.add_road; // 통로 아이콘
            }
          } else {
            if (isMyCar) {
              boxColor = Colors.blueAccent.withOpacity(0.1);
              borderColor = Colors.blueAccent;
              slotIcon = Icons.directions_car;
              badgeText = '내 차';
            } else if (isOccupied) {
              boxColor = Colors.redAccent.withOpacity(0.1);
              borderColor = Colors.redAccent;
              slotIcon = Icons.directions_car;
            } else {
              boxColor = Colors.green.withOpacity(0.1);
              borderColor = Colors.green;
              slotIcon = Icons.local_parking;
            }
          }

          // 💡 4. 한 칸의 디자인과 크기 설정 (가로로 배열되므로 크기 고정)
          return GestureDetector(
            onLongPress: () {
              if (type == 'slot' && isOccupied && !isMyCar) {
                _showNotificationDialog(slotName);
              } else if (type == 'aisle' && isOccupied) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('통로 불법주차는 문의게시판을 통해 신고해 주세요.')),
                );
              } else if (!isOccupied) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이미 빈자리입니다! 바로 주차하세요.')),
                );
              }
            },
            child: Container(
              // 👉 여기서 한 칸의 가로/세로 크기를 조절할 수 있습니다!
              width: type == 'aisle' ? 70 : 100, // 통로는 조금 좁게, 주차칸은 넓게
              height: 140,
              margin: const EdgeInsets.only(
                right: 12,
              ), // 각 칸 사이의 여백 (2,3,2 띄어쓰기)
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: type == 'aisle' && !isOccupied ? 1.5 : 3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slotName,
                        style: TextStyle(
                          fontSize: type == 'aisle' ? 14 : 20,
                          fontWeight: FontWeight.w900,
                          color: borderColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(slotIcon, size: 32, color: borderColor),
                    ],
                  ),
                  if (badgeText.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
