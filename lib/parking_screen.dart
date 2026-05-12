import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 통신 도구
import 'dart:convert'; // 통신 도구
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 💡 이 줄이 꼭 있어야 합니다!

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
    final url = Uri.parse('http://10.0.2.2:3000/api/parking-zones');

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

      // 💡 서버가 꺼져있거나 통신에 실패하면, 앱이 뻗지 않고 기존 가짜 데이터를 보여줍니다.
      if (!mounted) return;
      setState(() {
        parkingSlots = [
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-1",
            "isOccupied": true,
            "current_car_number": "99하 9999",
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "A-2",
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
            "type": "aisle",
            "slot": "통로 1",
            "isOccupied": true,
            "current_car_number": "불법 8888",
          },
          {
            "floor": "B1",
            "type": "aisle",
            "slot": "통로 2",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "aisle",
            "slot": "통로 3",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "B-1",
            "isOccupied": true,
            "current_car_number": "12가 3456",
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "B-2",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "B-3",
            "isOccupied": true,
            "current_car_number": "55다 5555",
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
              final url = Uri.parse('http://10.0.2.2:3000/api/waitlist');
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
    final floorSlots = parkingSlots.where((s) => s['floor'] == floor).toList();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: floorSlots.length,
      itemBuilder: (context, index) {
        final slotData = floorSlots[index];
        final type = slotData['type'];
        final isOccupied = slotData['isOccupied'];
        final slotName = slotData['slot'];
        final parkedCarNumber = slotData['current_car_number'];

        final isMyCar =
            (type == 'slot') && isOccupied && (parkedCarNumber == myCarNumber);

        Color boxColor;
        Color borderColor;
        IconData slotIcon;
        String badgeText = '';

        if (type == 'aisle') {
          if (isOccupied) {
            boxColor = Colors.orange.withOpacity(0.15);
            borderColor = Colors.orange;
            slotIcon = Icons.warning_amber_rounded;
            badgeText = '불법주차';
          } else {
            boxColor = Colors.grey.withOpacity(0.05);
            borderColor = Colors.grey[400]!;
            slotIcon = Icons.add_road;
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

        // 💡 2. GestureDetector로 감싸서 터치/길게 누르기 이벤트 추가!
        return GestureDetector(
          onLongPress: () {
            if (type == 'slot' && isOccupied && !isMyCar) {
              // 내 차가 아닌 남의 차가 주차되어 있을 때만 알림 신청 가능!
              _showNotificationDialog(slotName);
            } else if (type == 'aisle' && isOccupied) {
              // 통로 불법주차를 눌렀을 때의 반응 (안내 메시지)
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
                    const SizedBox(height: 4),
                    Icon(slotIcon, size: 28, color: borderColor),
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
