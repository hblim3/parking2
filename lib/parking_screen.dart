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

    final url = Uri.parse('$baseUrl/api/parking-zones');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          parkingSlots = List<Map<String, dynamic>>.from(data['zones']);
        });
      } else {
        throw Exception('서버 응답 오류');
      }
    } catch (e) {
      print("서버 연결 실패 - 시연용 데이터를 표시합니다. 에러: $e");
      if (!mounted) return;
      setState(() {
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
              Navigator.pop(ctx);
              const storage = FlutterSecureStorage();
              String? token = await storage.read(key: 'jwt_token');
              if (token == null) return;

              final url = Uri.parse('$baseUrl/api/waitlist');
              try {
                final response = await http.post(
                  url,
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer $token",
                  },
                  body: jsonEncode({"target_slot_id": target}),
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
            child: const Text('신청하기', style: TextStyle(color: Colors.white)),
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

  // 💡 [수정됨] 전체 그릿드를 그리는 함수
  // 💡 [수정] 전체 그릿드를 그리는 함수
  Widget _buildFloorGrid(String floor) {
    // 서버가 floor를 안보내줄 수도 있으므로 전체 데이터를 쓰거나 B1만 필터링합니다.
    final floorSlots = parkingSlots;

    // 💡 [핵심 수정] DB의 area_number에 '통로'라는 글자가 들어가면 통로로 인식하게 바꿉니다!
    final slots = floorSlots
        .where((s) => !(s['area_number']?.toString().contains('통로') ?? false))
        .toList();
    final aisles = floorSlots
        .where((s) => (s['area_number']?.toString().contains('통로') ?? false))
        .toList();

    List<Widget> topRow = [];
    List<Widget> bottomRow = [];
    // ... (이 아래 for문 등 나머지 코드는 기존과 똑같이 유지합니다) ...

    // 2. 주차칸을 지그재그로 1열, 2열에 분배하여 두 줄을 만듭니다.
    for (int i = 0; i < slots.length; i++) {
      if (i % 2 == 0) {
        topRow.add(_buildSlotWidget(slots[i]));
      } else {
        bottomRow.add(_buildSlotWidget(slots[i]));
      }
    }

    // 💡 3. [핵심 수정] 통로의 길이를 딱 주차칸 2개 너비로 고정합니다!
    // 계산: 주차칸 가로(100) + 가운데 여백(12) + 주차칸 가로(100) = 212.0
    double aisleWidth = 212.0;

    // 4. 통로 데이터 할당 (통로1은 위로, 통로2는 아래로)
    Map<String, dynamic>? topAisle = aisles.isNotEmpty ? aisles.first : null;
    Map<String, dynamic>? bottomAisle = aisles.length > 1 ? aisles.last : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        // 통로가 주차칸들의 왼쪽 시작점과 딱 맞아떨어지도록 왼쪽 정렬
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 👉 상단 통로 (통로 1)
          if (topAisle != null) _buildAisleWidget(topAisle, aisleWidth),
          if (topAisle != null) const SizedBox(height: 16),

          // 👉 윗줄 주차칸 목록
          Row(children: topRow),

          const SizedBox(height: 12), // 첫 번째 줄과 두 번째 줄 사이 간격
          // 👉 아랫줄 주차칸 목록
          Row(children: bottomRow),

          // 👉 하단 통로 (통로 2)
          if (bottomAisle != null) const SizedBox(height: 16),
          if (bottomAisle != null) _buildAisleWidget(bottomAisle, aisleWidth),
        ],
      ),
    );
  }

  // 💡 [분리됨] 회원님의 "주차칸" 양식 100% 그대로 가져온 위젯
  // 💡 [수정] 일반 주차칸 위젯 생성 함수
  Widget _buildSlotWidget(Map<String, dynamic> slotData) {
    final String status = slotData['status']?.toString().toLowerCase() ?? '';

    // 💡 [핵심 1] DB에서 날아온 상태가 '에러'나 '불법주차'인지 확인하는 변수 추가!
    final bool isError =
        (status == 'error' || status == '불법주차' || status == '선넘음');

    final bool isOccupied =
        (status == 'occupied' || status == '사용중' || status == 'disabled') ||
        (slotData['isOccupied'] == true);

    final String slotName =
        slotData['area_number'] ?? slotData['slot'] ?? '알수없음';
    final String? parkedCarNumber = slotData['current_car_number'];
    final bool isMyCar = isOccupied && (parkedCarNumber == myCarNumber);

    Color boxColor;
    Color borderColor;
    IconData slotIcon;
    String badgeText = '';

    // 💡 [핵심 2] 조건문에 isError를 가장 먼저 확인하여 경고창 띄우기!
    if (isError) {
      boxColor = Colors.orange.withOpacity(0.15); // 주황색 경고 배경
      borderColor = Colors.orange; // 주황색 테두리
      slotIcon = Icons.warning_amber_rounded; // 경고 아이콘!
      badgeText = '주차선 위반';
    } else if (isMyCar) {
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
    return GestureDetector(
      onLongPress: () {
        if (isOccupied && !isMyCar) {
          _showNotificationDialog(slotName);
        } else if (!isOccupied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이미 빈자리입니다! 바로 주차하세요.')));
        }
      },
      child: Container(
        width: 100, // 회원님 양식 그대로
        height: 140, // 회원님 양식 그대로
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 3),
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
                    fontSize: 20,
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
  }

  // 💡 [수정] 회원님의 "통로" 양식을 가로형으로 살짝 편 위젯
  Widget _buildAisleWidget(Map<String, dynamic> slotData, double width) {
    final String status = slotData['status']?.toString().toLowerCase() ?? '';
    final bool isOccupied =
        (status == 'occupied' || status == '불법주차') ||
        (slotData['isOccupied'] == true);

    final String slotName = slotData['area_number'] ?? slotData['slot'] ?? '통로';

    // ... (이 아래 Color, Icon 설정 로직은 기존과 똑같이 유지합니다) ...

    Color boxColor;
    Color borderColor;
    IconData slotIcon;
    String badgeText = '';

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

    return GestureDetector(
      onLongPress: () {
        if (isOccupied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('통로 불법주차는 문의게시판을 통해 신고해 주세요.')),
          );
        }
      },
      child: Container(
        width: width, // 계산된 전체 주차장 가로 길이만큼 길어짐
        height: 70, // 가로 통로이므로 높이는 70으로 설정
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isOccupied ? 3 : 1.5, // 기존 디자인 그대로
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 세로 기둥(Column) 대신 가로 기둥(Row)으로 눕혔습니다
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(slotIcon, size: 28, color: borderColor),
                const SizedBox(width: 10),
                Text(
                  slotName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: borderColor,
                  ),
                ),
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
