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
  // 💡 서버에서 두 개의 리스트를 따로 받을 준비!
  List<dynamic> residentCars = [];
  List<dynamic> visitorCars = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCars();
  }

  // 1. 서버에서 차량 목록 불러오기 (토큰 추가 완료)
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
        // 💡 서버에게 내 출입증(토큰) 보여주기!
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            residentCars = data['resident_cars'] ?? [];
            visitorCars = data['visitor_cars'] ?? [];
          });
        }
      } else {
        print('차량 목록 불러오기 거절됨: ${response.statusCode}');
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
      setState(() => isLoading = false);
    }
  }

  // 2. 서버에 새 차량 등록하기 (토큰 추가 & baseUrl 적용 완료)
  Future<void> _addCar(
    String carNumber,
    String carName,
    String carType,
    String carNote,
  ) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    // 💡 $baseUrl 로 수정 완료!
    final url = Uri.parse('$baseUrl/api/cars');
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // 💡 서버에게 내 출입증(토큰) 보여주기!
        },
        body: jsonEncode({
          "c_number": carNumber,
          "c_name": carName,
          "car_type": carType,
          "c_note": carNote,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchCars(); // 💡 등록 성공 시 목록 새로고침
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('등록 완료')));
      } else {
        // 서버에서 에러 메시지를 보낸 경우 (예: "방문객 등록 에러")
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'] ?? '등록 실패')));
      }
    } catch (e) {
      print("차량 등록 실패: $e");
    }
  }
  // ... 기존 _addCar 함수 끝나는 부분 ...

  // 💡 [추가] 4. 서버에 차량 삭제 요청하기
  Future<void> _deleteCar(String carNumber) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    // 💡 차량 번호의 한글과 띄어쓰기를 컴퓨터가 읽을 수 있는 주소 형식으로 변환합니다.
    final url = Uri.parse(
      '$baseUrl/api/cars/${Uri.encodeComponent(carNumber)}',
    );

    try {
      final response = await http.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        _fetchCars(); // 💡 삭제 성공 시 목록을 다시 불러와 화면 새로고침!
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

  // ... 기존 _showAddCarDialog 함수 시작 부분 ...
  // 3. 차량 추가 팝업
  void _showAddCarDialog() {
    final TextEditingController numberController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    String selectedType = '입주민';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                '차량 등록',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: '차량 구분',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: '입주민', child: Text('입주민 차량')),
                      DropdownMenuItem(
                        value: '방문객',
                        child: Text('방문객 차량 (24시간)'),
                      ),
                    ],
                    onChanged: (value) =>
                        setStateDialog(() => selectedType = value!),
                  ),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: '비고 (방문 목적 등)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (numberController.text.isNotEmpty &&
                        nameController.text.isNotEmpty) {
                      _addCar(
                        numberController.text,
                        nameController.text,
                        selectedType,
                        noteController.text,
                      );
                      Navigator.pop(context);
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

  // 💡 탭 내부의 리스트를 그려주는 공통 함수 (삭제 버튼 추가 완료!)
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

        // 💡 [수정 1] 차량 이름(모델명) 처리 - 비어있으면 알맞은 글씨로 채워줍니다!
        String carName = car['c_name']?.toString() ?? '';
        if (carName.isEmpty) {
          carName = isVisitor ? '방문객 차량' : '입주민 등록 차량';
        }

        // 💡 [수정] 만료 시간 표시 로직
        String expireDate = car['expire_date']?.toString() ?? '';
        String displayTimeText = '';
        Color timeColor = Colors.redAccent;

        if (expireDate.isEmpty || expireDate == 'null') {
          displayTimeText = '⏳ 입차 대기 중 (입차 시 24시간 시작)';
          timeColor = Colors.orange;
        } else {
          if (expireDate.contains('T')) {
            try {
              // 1. DB의 만료 시간을 가져옵니다.
              DateTime expireDt = DateTime.parse(expireDate).toLocal();
              // 2. 현재 시간과 비교해서 '남은 시간'을 계산합니다!
              Duration diff = expireDt.difference(DateTime.now());

              if (diff.isNegative) {
                // 이미 만료 시간이 지난 경우
                displayTimeText = '만료됨 (곧 자동 출차 처리됩니다)';
                timeColor = Colors.grey;
              } else {
                // 남은 시간을 시간과 분으로 쪼갭니다.
                int hours = diff.inHours;
                int minutes = diff.inMinutes % 60;

                if (hours > 0) {
                  displayTimeText = '⏳ 남은 시간: $hours시간 $minutes분';
                } else {
                  displayTimeText = '🚨 남은 시간: $minutes분'; // 1시간 미만일 때
                }

                // 남은 시간이 3시간(180분) 미만이면 빨간색 경고, 아니면 파란색으로 안정감 있게!
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
                  // 👇 빈칸 대신 위에서 만든 carName('방문객 차량')이 들어갑니다.
                  Text(carName, style: const TextStyle(color: Colors.black87)),
                  if (car['c_note'] != null &&
                      car['c_note'].toString().isNotEmpty)
                    Text(
                      '비고: ${car['c_note']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  // 👇 지저분한 시간 대신 위에서 변환한 예쁜 expireDate가 들어갑니다.
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
      length: 2, // 💡 탭을 2개로 나눕니다.
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
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black87),
              )
            : TabBarView(
                children: [
                  _buildCarList(residentCars, false), // 첫 번째 탭: 입주민
                  _buildCarList(visitorCars, true), // 두 번째 탭: 방문객
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddCarDialog,
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text(
            '차량 추가',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
