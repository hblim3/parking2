import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CarManagementScreen extends StatefulWidget {
  const CarManagementScreen({Key? key}) : super(key: key);

  @override
  State<CarManagementScreen> createState() => _CarManagementScreenState();
}

class _CarManagementScreenState extends State<CarManagementScreen> {
  List<dynamic> residentCars = [];
  List<dynamic> visitorCars = [];
  bool isLoading = true;

  // 💡 서버에서 받아올 제한 대수 변수 (과거로 돌아가서 지워졌던 것 복구!)
  int residentCarLimit = 1;
  int visitorCarLimit = 2;

  // 👇 [추가] 주차장 80% 초과 여부를 담을 변수
  bool _isOver80 = false;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _fetchCars();
    _checkOccupancy(); // 👈 [추가] 혼잡도 체크 함수 실행!
  }

  // 💡 내 정보(등록 제한 대수)를 불러오는 함수 복구!
  Future<void> _fetchUserInfo() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/user-info');
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      // 👇 2. 여기에 한 줄 추가!
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            residentCarLimit = data['user']['resident_car_limit'] ?? 1;
            visitorCarLimit = data['user']['visitor_car_limit'] ?? 2;
          });
        }
      }
    } catch (e) {
      print("내 정보 불러오기 실패: $e");
    }
  }

  Future<void> _fetchCars() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse('$baseUrl/api/cars');
    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      // 👇 3. 여기에 한 줄 추가!
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            residentCars = data['resident_cars'] ?? [];
            visitorCars = data['visitor_cars'] ?? [];
          });
        }
      }
    } catch (e) {
      print("서버 연결 실패 - 시연용 데이터를 표시합니다.");
      setState(() {
        residentCars = [
          {"c_number": "12가 3456", "c_name": "제네시스", "c_note": "법인차량"},
        ];
        visitorCars = [
          {
            "c_number": "99하 9999",
            "c_name": "소나타",
            "expire_date": "2026-05-14 18:00",
          },
        ];
      });
    } finally {
      if (mounted) {
        // 👇 화면이 살아있을 때만 로딩을 끄도록 수정!
        setState(() => isLoading = false);
      }
    }
  }

  // 👇 [추가] 현재 주차장 혼잡도를 체크하는 함수
  Future<void> _checkOccupancy() async {
    final url = Uri.parse('$baseUrl/api/app/parking-zones');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> zones = data['zones'] ?? [];

        int totalSlots = 0;
        int occupiedSlots = 0;

        for (var zone in zones) {
          if (zone['type'] != 'aisle') {
            totalSlots++;
            String status = zone['status']?.toString().toLowerCase() ?? '';
            if (status == 'occupied' ||
                status == '사용중' ||
                status == 'reserved' ||
                zone['isOccupied'] == true) {
              occupiedSlots++;
            }
          }
        }

        if (!mounted) return;
        setState(() {
          // 점유율이 80% 이상인지 판별하여 변수에 저장
          _isOver80 = totalSlots == 0
              ? false
              : (occupiedSlots / totalSlots) >= 0.8;
        });
      }
    } catch (e) {
      print("차량관리창 혼잡도 조회 실패: $e");
    }
  }

  Future<void> _addCar(String carNumber, String carName, String carType) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/cars');
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "c_number": carNumber,
          "c_name": carName,
          "car_type": carType,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isNotEmpty) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            _fetchCars();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('등록 완료')));
          }
        }
      } else {
        print("🚨 서버 거절 코드: ${response.statusCode}");
        String errorMessage = '차량 등록에 실패했습니다. (등록 대수 초과 또는 서버 오류)';

        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (e) {
            print("에러 응답 파싱 실패 (무시됨)");
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      print("차량 등록 통신 에러: $e");
    }
  }

  Future<void> _deleteCar(String carNumber) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    final url = Uri.parse(
      '$baseUrl/api/cars/${Uri.encodeComponent(carNumber)}',
    );

    try {
      final response = await http.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        _fetchCars();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('차량이 성공적으로 삭제되었습니다.')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('차량 삭제 실패')));
      }
    } catch (e) {
      print("차량 삭제 통신 에러: $e");
    }
  }

  // 💡 [수정] 괄호 안에 carType(입주민 또는 방문객)을 전달받도록 변경합니다.
  void _showAddCarDialog(String carType) {
    final TextEditingController numberController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    // ❌ 차량 구분 드롭다운 변수(selectedType) 삭제 완료!

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              // 💡 전달받은 타입에 따라 제목이 "입주민 등록" 또는 "방문객 등록"으로 바뀝니다.
              title: Text(
                '$carType 등록',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💡 등록 가능 대수 안내\n• 입주민 차량: $residentCarLimit대\n• 방문객 차량: $visitorCarLimit대\n(그 외 추가 등록은 관리자에 문의하세요)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // ❌ 드롭다운 메뉴(DropdownButtonFormField) 완전 삭제됨!

                    // 👇 전달받은 타입이 방문객이고 80% 초과일 때 경고창 띄우기
                    if (carType == '방문객' && _isOver80) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent,
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '🚨 현재 주차장 점유율이 80%를 초과하여 대단히 혼잡합니다. 지금 방문 차량을 등록하더라도 주차 여유가 생길 때까지 정문 차단기가 열리지 않습니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: numberController,
                      decoration: const InputDecoration(
                        labelText: '차량 번호',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '모델명',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (carType == '방문객' && _isOver80)
                        ? Colors.grey
                        : Colors.black87,
                  ),
                  onPressed: () {
                    // 👇 [핵심 방어막]
                    if (carType == '방문객' && _isOver80) {
                      FocusScope.of(context).unfocus();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🚨 혼잡도가 높아 현재 방문 차량을 등록할 수 없습니다.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    if (numberController.text.isNotEmpty &&
                        nameController.text.isNotEmpty) {
                      FocusScope.of(context).unfocus();
                      _addCar(
                        numberController.text,
                        nameController.text,
                        carType, // 👈 넘겨받은 carType으로 서버에 전송합니다!
                      );
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('차량 번호와 모델명을 입력해주세요.')),
                      );
                    }
                  },
                  child: const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCarList(List<dynamic> cars, bool isVisitor) {
    if (cars.isEmpty) {
      return Center(
        child: Text(
          '등록된 ${isVisitor ? "방문객" : "입주민"} 차량이 없습니다.',
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cars.length,
      itemBuilder: (context, index) {
        final car = cars[index];
        final String currentCarNumber = car['c_number'] ?? '번호 없음';

        // ✅ 변경할 코드 (모델명을 서랍에서 꺼내 괄호 안에 합쳐줍니다!)
        String carName = car['c_name']?.toString() ?? '';
        String carKind = car['c_kind']?.toString() ?? '';

        if (carKind.isNotEmpty) {
          carName = '$carName ($carKind)'; // 화면 출력 결과: "홍길동 차량 (테슬라)"
        }
        if (carName.isEmpty) {
          carName = isVisitor ? '방문객 차량' : '입주민 등록 차량';
        }

        String expireDate = car['expire_date']?.toString() ?? '';
        String displayTimeText = '';
        Color timeColor = Colors.redAccent;

        if (expireDate.isEmpty || expireDate == 'null') {
          displayTimeText = '⏳ 입차 대기 중 (입차 시 24시간 시작)';
          timeColor = Colors.orange;
        } else {
          if (expireDate.contains('T')) {
            try {
              DateTime expireDt = DateTime.parse(expireDate).toLocal();
              Duration diff = expireDt.difference(DateTime.now());

              if (diff.isNegative) {
                displayTimeText = '만료됨 (곧 자동 출차 처리됩니다)';
                timeColor = Colors.grey;
              } else {
                int hours = diff.inHours;
                int minutes = diff.inMinutes % 60;

                if (hours > 0) {
                  displayTimeText = '⏳ 남은 시간: $hours시간 $minutes분';
                } else {
                  displayTimeText = '🚨 남은 시간: $minutes분';
                }

                timeColor = diff.inMinutes < 180
                    ? Colors.redAccent
                    : Colors.blueAccent;
              }
            } catch (e) {
              displayTimeText = '시간 계산 오류';
            }
          } else {
            displayTimeText = '만료: $expireDate';
          }
        }
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: isVisitor
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.black12,
              child: Icon(
                Icons.directions_car,
                color: isVisitor ? Colors.orange : Colors.black87,
              ),
            ),
            title: Text(
              currentCarNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(carName, style: const TextStyle(color: Colors.black87)),
                  if (isVisitor)
                    Text(
                      displayTimeText,
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      '차량 삭제',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: Text('[$currentCarNumber] 차량을 목록에서 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteCar(currentCarNumber);
                        },
                        child: const Text(
                          '삭제',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            '차량 관리',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: '입주민 차량'),
              Tab(text: '방문객 차량'),
            ],
          ),
        ),
        body: isLoading
            ? const CustomLoading() // 👈 딱 이 한 줄로 깔끔하게 교체!
            : TabBarView(
                children: [
                  _buildCarList(residentCars, false),
                  _buildCarList(visitorCars, true),
                ],
              ),
        // 👇 [수정됨] Builder를 추가하여 현재 활성화된 탭을 정확하게 읽어옵니다!
        floatingActionButton: Builder(
          builder: (fabContext) {
            return FloatingActionButton.extended(
              onPressed: () async {
                await _checkOccupancy();

                // 💡 DefaultTabController의 현재 탭 인덱스 (0: 입주민, 1: 방문객)
                int currentTab = DefaultTabController.of(fabContext).index;
                String currentCarType = currentTab == 0 ? '입주민' : '방문객';

                if (currentTab == 1 && _isOver80) {
                  ScaffoldMessenger.of(fabContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '⚠️ 현재 주차장이 80% 이상 혼잡하여 방문 차량을 등록할 수 없습니다.',
                      ),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return; // 등록 팝업 띄우지 않음
                }

                // 💡 위에서 판단한 현재 탭의 종류(currentCarType)를 팝업창으로 전달합니다!
                _showAddCarDialog(currentCarType);
              },
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                '차량 추가',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }
}
