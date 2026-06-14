import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 통신 도구
import 'dart:convert'; // 통신 도구
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 💡 이 줄이 꼭 있어야 합니다!
import 'main.dart';
import 'dart:async'; // 👈 [추가] 타이머 기능을 쓰기 위해 필요합니다.

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({Key? key}) : super(key: key);

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  Timer? _timer; // 👈 1. 타이머 변수 선언
  String? myCarNumber; // 💡 고정된 번호를 지우고, 실시간으로 받아올 공간으로 변경
  // 👇 [추가] 내가 등록한 방문객 차량 번호들을 담을 리스트!
  List<String> myVisitorCars = [];

  // 👇 [추가] 아파트 이름을 담을 변수 (기본값 설정)
  String aptName = "우리 아파트";

  List<Map<String, dynamic>> parkingSlots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeParkingData(); // 💡 [3단계] 초기화 함수 호출로 변경된 상태
    // 👇 2. 5초마다 주차장 상태 갱신 함수를 반복 실행합니다.
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _fetchParkingStatus(); // 화면이 켜져있을 때만 새로고침!
        _fetchMyCars(); // 👈 [이 한 줄을 꼭 추가해 주세요!]
      }
    });
  }

  // 👇 3. 화면을 나갈 때 타이머를 반드시 꺼주는 함수 추가 (매우 중요!)
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 💡 [3단계에서 쓰일 초기화 함수]
  Future<void> _initializeParkingData() async {
    await _fetchUserInfo(); // 👈 [추가] 내 정보(아파트 이름) 먼저 가져오기!
    await _fetchMyCarNumber();
    await _fetchMyCars(); // 👈 [여기에 이 한 줄을 꼭 추가해 주세요!]
    await _fetchParkingStatus();
  }

  // 👇 [추가] 서버에 내 정보를 물어보는 새로운 함수입니다. (기존 함수들 위나 아래에 배치)
  Future<void> _fetchUserInfo() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/user-info');
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
        // 한글 깨짐 방지를 위해 utf8.decode 사용
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['user'] != null) {
          if (!mounted) return;
          setState(() {
            // 서버가 준 아파트 이름(a_name)을 변수에 쏙 넣습니다!
            aptName = data['user']['a_name'] ?? "우리 아파트";
          });
        }
      }
    } catch (e) {
      print("아파트 정보 로딩 실패: $e");
      if (!mounted) return;
      setState(() {
        aptName = "서초 스마트 아파트"; // 에러 시 시연용 기본값
      });
    }
  }

  // ====================================================================
  // 👇여기에 [2단계] 코드를 통째로 복사해서 붙여넣으세요!👇
  // ====================================================================
  Future<void> _fetchMyCarNumber() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/cars');
    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      // 👇 2. 여기에 한 줄 추가!
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true &&
            data['resident_cars'] != null &&
            data['resident_cars'].isNotEmpty) {
          setState(() {
            myCarNumber = data['resident_cars'][0]['c_number'];
          });
        }
      }
    } catch (e) {
      print("내 차량 정보 동적 로딩 실패 (시연용 기본값 유지): $e");
      myCarNumber = "12가 3456";
    }
  }

  Future<void> _fetchParkingStatus() async {
    // 💡 화면이 아직 화면 트리에 붙어있는지(살아있는지) 확인!
    // 이미 넘어간 상태라면 이 함수를 조용히 종료(return)시킵니다.
    if (!mounted) return;

    final url = Uri.parse('$baseUrl/api/app/parking-zones');

    try {
      final response = await http.get(url);
      // 👇 3. 여기에 한 줄 추가!
      if (!mounted) return;

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
            "slot": "a-b1-001", // 💡 통일됨
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "a-b1-002", // 💡 내 차 위치 통일됨
            "isOccupied": true,
            "current_car_number": "12가 3456", // 👈 내 차 번호
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
            "slot": "a-b1-003",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "a-b1-004",
            "isOccupied": false,
            "current_car_number": null,
          },
          {
            "floor": "B1",
            "type": "slot",
            "slot": "a-b1-005",
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
        ];
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 👇 [새로 추가] 서버에서 내 방문 차량 목록을 가져와서 상자에 담는 함수
  Future<void> _fetchMyCars() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/cars');
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['visitor_cars'] != null) {
          setState(() {
            // 방문 차량(visitor_cars) 목록에서 번호판(c_number)만 쏙쏙 뽑아서 저장합니다.
            myVisitorCars = (data['visitor_cars'] as List)
                .map((car) => car['c_number'].toString())
                .toList();
          });
        }
      }
    } catch (e) {
      print("방문 차량 정보 불러오기 실패: $e");
    }
  }

  // 👇 1. 기존 함수를 수정하여 [대기 취소] 버튼을 추가합니다!
  void _showNotificationDialog(String target) {
    String title = target == 'ALL' ? '빈자리 알림 대기' : '$target 구역 지정 알림';
    String content = target == 'ALL'
        ? '주차장에 빈자리가 생기면 푸시 알림을 받으시겠습니까?\n\n💡 이미 신청한 알림이 있다면 취소할 수도 있습니다.'
        : '$target 구역의 차량이 출차하면 푸시 알림을 받으시겠습니까?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
          // 👇 [핵심] 대기 취소 버튼 추가!
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelWaitlist(); // 취소 함수 호출
            },
            child: const Text(
              '대기 취소',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
            onPressed: () {
              Navigator.pop(ctx);
              _applyWaitlist(target); // 신청 함수 호출
            },
            child: const Text('신청하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 👇 2. 기존 창 안에 섞여있던 '신청 로직'을 별도 함수로 깔끔하게 분리
  Future<void> _applyWaitlist(String target) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅ $target 구역 알림 신청이 완료되었습니다.')));
      } else {
        throw Exception('서버 에러');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('대기 신청에 실패했습니다.')));
    }
  }

  // 👇 3. 서버에 "내 대기열 지워줘!"라고 요청하는 새로운 함수
  Future<void> _cancelWaitlist() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    // HTTP DELETE 메서드를 사용하여 서버의 취소 API를 호출합니다.
    final url = Uri.parse('$baseUrl/api/waitlist');
    try {
      final response = await http.delete(
        // 💡 통신 방식이 POST가 아니라 DELETE 입니다!
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ 알림 대기가 정상적으로 취소되었습니다.')),
        );
      } else {
        throw Exception('서버 에러');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('대기 취소에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 👉 [유지됨] 1. 기존 상단바 (새로고침 버튼 포함)
      appBar: AppBar(
        title: Text(
          '$aptName 주차장',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
          // 👉 [유지됨] 2. 기존 6가지 색상 범례 (빈자리, 예약중, 방문/이웃 등 그대로 둠!)
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
                _buildLegendItem(Colors.purple, '예약중'),
                const SizedBox(width: 8),
                _buildLegendItem(Colors.teal, '방문/이웃'),
                const SizedBox(width: 8),
                _buildLegendItem(Colors.redAccent, '주차됨'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.blueAccent, '내 차'),
                const SizedBox(width: 12),
                _buildLegendItem(Colors.orange, '불법주차'),
              ],
            ),
          ),

          // 🌟 [새로 추가됨] 3. 상단 여백 활용: 아파트 정보 및 실시간 동기화 상태
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  '$aptName B1 주차장', // 서버에서 받아온 아파트 이름 자동 적용
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '실시간 데이터 동기화 중',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 👉 [유지됨] 4. 가장 중요한 중앙 주차장 도면 영역 (기존 로직 100% 보존)
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: isLoading
                  ? const CustomLoading() // 기존의 로딩 화면
                  : _buildFloorGrid('B1'), // 기존의 주차장 그리는 함수
            ),
          ),

          // 🌟 5. 하단 여백 활용: 진행 방향 안내 (출구 삭제, 중앙 정렬)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false, // 아이폰 하단 홈 바 영역 침범 방지
              child: Row(
                // 👇 두 개만 남았으니 화면 한가운데(center)로 예쁘게 모아줍니다!
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 입구 안내
                  Row(
                    children: [
                      Icon(
                        Icons.login_rounded,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '입구 (좌측)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(width: 50), // 👈 입구와 진행방향 사이에 적당한 간격을 줍니다.
                  // 진행 방향 안내
                  Row(
                    children: [
                      Icon(
                        Icons.trending_flat_rounded,
                        color: Colors.green[600],
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '진행 방향',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 👉 [유지됨] 6. 기존 만차 시 알림 대기 플로팅 버튼
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
    if (parkingSlots.isEmpty) {
      return const Center(child: Text('주차장 데이터를 불러오는 중입니다.'));
    }

    // 1. 전체 주차장의 최대 행/열 계산
    int maxRow = 0;
    int maxCol = 0;
    for (var slot in parkingSlots) {
      int r = (slot['layout_row'] ?? 1) + (slot['layout_height'] ?? 1) - 1;
      int c = (slot['layout_column'] ?? 1) + (slot['layout_width'] ?? 1) - 1;
      if (r > maxRow) maxRow = r;
      if (c > maxCol) maxCol = c;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2. 가로폭을 기준으로 한 칸당 사이즈 계산
        double unitWidth = constraints.maxWidth / (maxCol > 0 ? maxCol : 1);
        double unitHeight = unitWidth * (120 / 110);

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          // 👇 1. ConstrainedBox를 추가해서 화면 높이만큼 최소 공간을 확보합니다.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            // 👇 2. Center를 추가해서 확보된 공간의 정중앙에 배치합니다.
            child: Center(
              // 👇 3. 여기서부터는 작성하셨던 기존 코드와 완전히 똑같습니다!
              child: SizedBox(
                height: maxRow * unitHeight,
                child: Stack(
                  children: [
                    // 1. 바닥 배경 (맨 밑에 깔림)
                    Container(color: Colors.grey[200]),

                    // 2. 기존 주차칸들
                    ...parkingSlots.map((slot) {
                      int row = (slot['layout_row'] ?? 1) - 1;
                      int col = (slot['layout_column'] ?? 1) - 1;
                      int w = slot['layout_width'] ?? 1;
                      int h = slot['layout_height'] ?? 1;

                      return Positioned(
                        left: col * unitWidth,
                        top: row * unitHeight,
                        width: w * unitWidth,
                        height: h * unitHeight,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0), // 칸 사이 간격
                          child: (slot['type'] == 'aisle')
                              ? _buildAisleWidget(slot)
                              : _buildSlotWidget(slot),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 💡 [수정 2] 고정 크기(width, height)를 삭제하고 글씨 자동 축소(FittedBox)를 적용합니다.
  Widget _buildSlotWidget(Map<String, dynamic> slotData) {
    final String status = slotData['status']?.toString().toLowerCase() ?? '';
    final bool isReserved = (status == 'reserved');
    final bool isError =
        (status == 'error' ||
        status == '불법주차' ||
        status == '선넘음' ||
        status == '이중주차');
    final bool isOccupied =
        (status == 'occupied' || status == '사용중' || status == 'disabled') ||
        (slotData['isOccupied'] == true);

    final String slotName =
        slotData['area_number'] ?? slotData['slot'] ?? '알수없음';
    final String? parkedCarNumber = slotData['current_car_number'];
    // 👇👇 [핵심 수정] 판별 로직을 변경합니다! 👇👇
    final bool isMyCar = isOccupied && (parkedCarNumber == myCarNumber);
    // 💡 [이름과 조건 변경] 무조건 내 차가 아니라고 청록색을 칠하는 게 아니라,
    // 내 방문객 리스트(myVisitorCars) 안에 주차된 번호판이 포함되어(contains) 있을 때만 참(true)이 됩니다!
    final bool isMyVisitor =
        isOccupied &&
        parkedCarNumber != null &&
        myVisitorCars.contains(parkedCarNumber);
    Color boxColor;
    Color borderColor;
    IconData slotIcon;
    String badgeText = '';

    if (isError) {
      boxColor = Colors.orange.withOpacity(0.15);
      borderColor = Colors.orange;
      slotIcon = Icons.warning_amber_rounded;
      badgeText = '위반';
    } else if (isReserved) {
      boxColor = Colors.purple.withOpacity(0.1);
      borderColor = Colors.purple;
      slotIcon = Icons.timer;
      badgeText = '예약중';
    } else if (isMyCar) {
      boxColor = Colors.blueAccent.withOpacity(0.1);
      borderColor = Colors.blueAccent;
      slotIcon = Icons.directions_car;
      badgeText = '내 차';
    } else if (isMyVisitor) {
      // 🚙 [추가됨] 번호판이 인식된 방문객/이웃 차량 -> 청록색으로 명확하게 구분!
      boxColor = Colors.teal.withOpacity(0.25);
      borderColor = Colors.teal;
      slotIcon = Icons.directions_car;
      // badgeText = '방문/이웃'; // 필요하시면 주석을 푸세요!
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
        if (isReserved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('다른 대기자가 3분 안에 주차할 예정인 예약칸입니다.')),
          );
        } else if (isOccupied && !isMyCar) {
          _showNotificationDialog(slotName);
        } else if (!isOccupied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이미 빈자리입니다! 바로 주차하세요.')));
        }
      },
      child: Container(
        // 🚨 기존에 있던 width: 110, height: 120 코드를 삭제했습니다! (부모 GridView가 크기를 결정함)
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              // 👇 칸이 너무 작아지면 안의 내용물(글씨/아이콘)도 덩달아 앙증맞게 줄어들도록 안전장치 적용!
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(slotIcon, size: 30, color: borderColor),
                    const SizedBox(height: 6),
                    Text(
                      slotName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: borderColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // 💡 [수정] 내 차(isMyCar)일 경우에만 차량 번호 텍스트를 화면에 그립니다.
                    if (isMyCar && parkedCarNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          parkedCarNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (badgeText.isNotEmpty)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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

  // 💡 [수정 3] 통로 카드도 고정 크기를 해제하고 크기 자동 반응형으로 변경합니다.
  Widget _buildAisleWidget(Map<String, dynamic> slotData) {
    final String status = slotData['status']?.toString().toLowerCase() ?? '';
    final bool isOccupied =
        (status == 'occupied' || status == '불법주차') ||
        (slotData['isOccupied'] == true);

    final String slotName = slotData['area_number'] ?? slotData['slot'] ?? '통로';

    Color boxColor;
    Color borderColor;
    IconData slotIcon;
    String badgeText = '';

    if (isOccupied) {
      boxColor = Colors.orange.withOpacity(0.15);
      borderColor = Colors.orange;
      slotIcon = Icons.warning_amber_rounded;
      badgeText = '이중';
    } else {
      boxColor = Colors.grey.withOpacity(0.05);
      borderColor = Colors.grey[400]!;
      slotIcon = Icons.add_road;
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
        // 🚨 여기도 width: 110, height: 120 코드를 과감히 삭제!
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isOccupied ? 2.5 : 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(slotIcon, size: 30, color: borderColor),
                    const SizedBox(height: 8),
                    Text(
                      slotName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: borderColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (badgeText.isNotEmpty)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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
