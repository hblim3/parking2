import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CarManagementScreen extends StatefulWidget {
  const CarManagementScreen({Key? key}) : super(key: key);

  @override
  State<CarManagementScreen> createState() => _CarManagementScreenState();
}

class _CarManagementScreenState extends State<CarManagementScreen> {
  List<dynamic> registeredCars = []; // 서버에서 받아온 차량 리스트를 담을 빈 상자
  bool isLoading = true; // 로딩 뱅글뱅글 아이콘 표시 여부

  @override
  void initState() {
    super.initState();
    _fetchCars(); // 💡 화면이 켜지자마자 서버에 데이터 요청!
  }

  // 1. 서버에서 내 차량 목록 불러오기 (GET 요청)
  // 1. 서버에서 내 차량 목록 불러오기 (GET 요청)
  // car_management_screen.dart 파일의 _fetchCars 함수 수정
  Future<void> _fetchCars() async {
    final url = Uri.parse('http://10.0.2.2:3000/api/cars');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            registeredCars = data['cars'];
          });
        }
      }
    } catch (e) {
      print("서버 연결 실패 - 시연용 데이터를 표시합니다.");
      // 수정 후 👇
      setState(() {
        registeredCars = [
          {"c_number": "12가 3456", "c_name": "제네시스", "car_type": "입주민"},
        ];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 2. 서버에 새 차량 등록하기 (POST 요청)
  Future<void> _addCar(String carNumber, String carName, String carType) async {
    // 💡 carName 매개변수 추가!
    final url = Uri.parse('http://10.0.2.2:3000/api/cars');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "c_number": carNumber, // 💡 car_number -> c_number 로 변경
          "c_name": carName, // 💡 웹 DB 필수값 추가
          "car_type": carType,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchCars();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('차량이 성공적으로 등록되었습니다.')));
      }
    } catch (e) {
      print("차량 등록 실패: $e");
    }
  }

  // 3. 차량 추가 버튼을 눌렀을 때 뜨는 팝업창 UI
  void _showAddCarDialog() {
    final TextEditingController carNumberController = TextEditingController();
    final TextEditingController carNameController =
        TextEditingController(); // 💡 모델명 컨트롤러 추가!
    String selectedType = '입주민';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                '새 차량 등록',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: carNumberController,
                    decoration: const InputDecoration(
                      labelText: '차량 번호 (예: 12가 3456)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 👇 차량 모델명 입력 칸 추가 👇
                  TextField(
                    controller: carNameController,
                    decoration: const InputDecoration(
                      labelText: '차량 모델명 (예: 제네시스)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 👆 여기까지 👆
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: '차량 종류',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: '입주민', child: Text('입주민 (상시)')),
                      DropdownMenuItem(
                        value: '방문객',
                        child: Text('방문객 (24시간 후 만료)'),
                      ),
                    ],
                    onChanged: (value) =>
                        setStateDialog(() => selectedType = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // 💡 번호와 모델명을 모두 입력해야만 넘어가도록 안전장치 추가
                    if (carNumberController.text.isNotEmpty &&
                        carNameController.text.isNotEmpty) {
                      _addCar(
                        carNumberController.text,
                        carNameController.text,
                        selectedType,
                      );
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('차량 번호와 모델명을 모두 입력해주세요.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '차량 관리',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // 💡 데이터 로딩 중이면 뱅글뱅글, 다 불러왔는데 비어있으면 텍스트, 데이터가 있으면 리스트 출력
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.black87),
            )
          : registeredCars.isEmpty
          ? const Center(
              child: Text(
                '등록된 차량이 없습니다.\n아래 버튼을 눌러 추가해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: registeredCars.length,
              itemBuilder: (context, index) {
                final car = registeredCars[index];
                final isVisitor = car['car_type'] == '방문객';

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
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isVisitor
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car,
                        size: 30,
                        // 방문객 차량은 주황색, 입주민 차량은 검은색으로 표시
                        color: isVisitor ? Colors.orange : Colors.black87,
                      ),
                    ),
                    // 수정 전: car['car_number']
                    // 수정 후 👇
                    title: Text(
                      car['c_number'] ??
                          '번호 없음', // 💡 c_number 로 변경! 에러 방지용 기본값 추가
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        isVisitor ? '방문객 차량 (24시간 후 만료)' : '입주민 차량',
                        style: TextStyle(
                          color: isVisitor ? Colors.orange : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
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
    );
  }
}
