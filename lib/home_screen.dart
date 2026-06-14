import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';
import 'package:lottie/lottie.dart'; // 👈 [여기에 1줄 추가!]
import 'dart:async'; // 👈 [추가]

class HomeScreen extends StatefulWidget {
  // 메인 화면에서 퀵 버튼을 누르면 다른 탭(지도, 문의 등)으로 넘어가기 위한 리모컨
  final Function(int) onTabChanged;

  const HomeScreen({Key? key, required this.onTabChanged}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer; // 👈 1. 타이머 변수 선언
  bool isLoading = true;
  bool _isFetching = false; // 👈 1. [추가] 통신 중복 방지용 자물쇠

  // 화면에 보여줄 데이터들
  String aptName = "우리 아파트";
  int totalSlots = 0;
  int occupiedSlots = 0;
  String myCarLocation = "외출 중 (미주차)";
  int visitorCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // 👇 2. 5초마다 메인 대시보드 데이터를 반복해서 불러옵니다.
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  // 👇 3. 화면을 나갈 때 강제 종료
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 💡 한 번의 로딩으로 서버에서 필요한 모든 요약 데이터를 긁어옵니다!
  Future<void> _loadDashboardData() async {
    // 👇 2. [추가] 이미 통신 중(true)이면 이번 타이머는 그냥 패스!
    if (_isFetching) return;
    _isFetching = true; // 자물쇠 잠금
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    try {
      // 1. 내 정보 (아파트 이름) 가져오기
      final userRes = await http.get(
        Uri.parse('$baseUrl/api/user-info'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(userRes.bodyBytes));
        if (userData['user'] != null) {
          aptName = userData['user']['a_name'] ?? "우리 아파트";
        }
      }

      // 2. 내 차량 및 방문 차량 정보 가져오기
      String? myCarNum;
      final carRes = await http.get(
        Uri.parse('$baseUrl/api/cars'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (carRes.statusCode == 200) {
        final carData = jsonDecode(carRes.body);
        if (carData['resident_cars'] != null &&
            carData['resident_cars'].isNotEmpty) {
          myCarNum = carData['resident_cars'][0]['c_number']; // 첫 번째 내 차 번호
        }
        if (carData['visitor_cars'] != null) {
          visitorCount = carData['visitor_cars'].length; // 현재 등록된 방문차량 대수
        }
      }

      // 3. 전체 주차장 혼잡도 및 내 차 위치 찾기
      final zoneRes = await http.get(
        Uri.parse('$baseUrl/api/app/parking-zones'),
      );
      if (zoneRes.statusCode == 200) {
        final zoneData = jsonDecode(zoneRes.body);
        List<dynamic> zones = zoneData['zones'] ?? [];

        int tSlots = 0;
        int oSlots = 0;
        String location = "외출 중 (미주차)";

        for (var zone in zones) {
          // 통로가 아닌 진짜 주차칸만 카운트!
          if (zone['type'] != 'aisle') {
            tSlots++;
            String status = zone['status']?.toString().toLowerCase() ?? '';
            if (status == 'occupied' ||
                status == '사용중' ||
                status == 'reserved' ||
                zone['isOccupied'] == true) {
              oSlots++;
            }
          }
          // 내 차 위치 찾기 (파이썬 카메라 연동 데이터)
          if (myCarNum != null && zone['current_car_number'] == myCarNum) {
            location = zone['slot'] ?? "알수없음";
          }
        }
        totalSlots = tSlots;
        occupiedSlots = oSlots;
        myCarLocation = location;
      }
    } catch (e) {
      print("대시보드 로딩 에러: $e");
    } finally {
      _isFetching = false; // 👇 3. [추가] 통신이 완전히 끝나면 자물쇠 풀기
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 혼잡도 퍼센트 계산 (안전장치 포함)
    double congestion = totalSlots == 0 ? 0 : (occupiedSlots / totalSlots);
    int percent = (congestion * 100).toInt();

    // 👇 [여기서부터 덮어쓰기!] 100% 조건(만차)을 맨 앞에 추가했습니다.
    Color statusColor = percent >= 100
        ? Colors.red[800]! // 🚨 만차일 때는 경각심을 주도록 더 진하고 어두운 빨간색 적용!
        : (percent >= 80
              ? Colors.redAccent
              : (percent >= 50 ? Colors.orange : Colors.green));

    String statusText = percent >= 100
        ? "만차 (주차 불가)" // 🚨 100%를 채우면 확실하게 만차로 표시!
        : (percent >= 80 ? "혼잡 (만차 임박)" : (percent >= 50 ? "보통" : "여유"));
    // 👆 [여기까지 덮어쓰기!]

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '$aptName',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              // 👇 딱딱한 동그라미 대신 로티 애니메이션으로 교체!
              child: Lottie.asset(
                'assets/loading_car.json', // 아까 저장한 파일 이름
                width: 150, // 크기는 입맛에 맞게 조절하세요!
                height: 150,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1️⃣ 최상단: 주차장 혼잡도 브리핑 카드
                    const Text(
                      "실시간 주차장 현황",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: statusColor,
                                ),
                              ),
                              Text(
                                "잔여 ${totalSlots - occupiedSlots}대 / 총 $totalSlots대",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: congestion,
                              minHeight: 12,
                              backgroundColor: Colors.grey[200],
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 👇👇 [여기서부터 새로 추가!] 80% 이상일 때만 뜨는 경고 배너 👇👇
                    if (percent >= 80) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1), // 연한 빨간색 배경
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '현재 점유율 80% 초과로 인해 방문 차량 입차가 일시적으로 제한됩니다.',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // 👆👆 [여기까지 추가 완료] 👆👆
                    const SizedBox(height: 24),

                    // 2️⃣ 중단: 내 차 위치 & 방문객 상태 반반 카드
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            Icons.directions_car,
                            "내 차 위치",
                            myCarLocation,
                            Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            Icons.people_alt,
                            "방문객 차량",
                            "$visitorCount대 등록됨",
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 3️⃣ 하단: 퀵 액션 버튼들
                    const Text(
                      "빠른 메뉴",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildQuickAction(
                          Icons.map,
                          "주차장 지도",
                          () => widget.onTabChanged(1),
                        ),
                        _buildQuickAction(
                          Icons.add_road,
                          "차량 관리",
                          () => widget.onTabChanged(4),
                        ), // 설정 탭 내부에 있다면 수정 필요
                        _buildQuickAction(
                          Icons.headset_mic,
                          "문의 게시판",
                          () => widget.onTabChanged(2),
                        ),
                        _buildQuickAction(
                          Icons.notifications,
                          "알림 보관함",
                          () => widget.onTabChanged(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 작은 정보 카드 UI 생성기
  Widget _buildInfoCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 퀵 액션 버튼 UI 생성기
  Widget _buildQuickAction(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          // 💡 투명도(dividerColor)를 버리고, 확실한 회색(400)이나 검은색 계열로 바꿉니다.
          border: Border.all(
            color: Colors.grey[400]!, // 👈 200보다 훨씬 진한 400으로 설정하세요.
            width: 1.2, // 💡 선 두께도 살짝 줍니다.
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).iconTheme.color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                // 💡 const 삭제 필수!
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color, // 💡 이 줄을 추가하세요!
              ),
            ),
          ],
        ),
      ),
    );
  }
}
