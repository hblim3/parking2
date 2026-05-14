import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 👈 추가!
import 'dart:convert'; // 👈 추가!
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 👈 토큰(출입증)용 추가!
import 'main.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({Key? key}) : super(key: key);

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  List<dynamic> _inquiries = []; // 서버에서 받을 빈 상자
  @override
  void initState() {
    super.initState();
    _fetchInquiries(); // 화면 켜지자마자 데이터 요청!
  }

  // 1. 서버에서 문의 내역 불러오기
  Future<void> _fetchInquiries() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) return;

    final url = Uri.parse('$baseUrl/api/inquiries');

    try {
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // 💡 내 출입증(토큰) 보여주기
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;
          setState(() {
            _inquiries = data['inquiries']; // 서버 데이터로 덮어쓰기
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("문의 내역 불러오기 실패: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 2. 서버로 새 문의 보내기
  Future<void> _submitInquiry(
    String category,
    String title,
    String content,
  ) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'jwt_token');

    final url = Uri.parse('$baseUrl/api/inquiries');

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "category": category,
          "title": title,
          "content": content,
        }),
      );

      if (response.statusCode == 200) {
        _fetchInquiries(); // 💡 성공하면 리스트 다시 불러와서 새로고침!
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('문의가 성공적으로 접수되었습니다.')));
      }
    } catch (e) {
      print("문의 접수 실패: $e");
    }
  }

  bool isLoading = true; // 로딩 상태 표시

  // 💡 문의 작성 팝업창 띄우기
  void _showWriteDialog() {
    TextEditingController titleController = TextEditingController();
    TextEditingController contentController = TextEditingController();

    // 카테고리 기본값 설정
    String selectedCategory = '시설보수';
    final List<String> categories = ['시설보수', '불법주차', '시스템오류', '기타문의'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // 팝업창 안에서 드롭다운 상태를 변화시키기 위해 필요
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              '새 문의 접수',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 카테고리 선택 드롭다운 (Spinner)
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: '문의 종류',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: categories.map((String category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() => selectedCategory = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. 제목 입력창
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      hintText: '간략한 요약을 적어주세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. 내용 입력창 (여러 줄)
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '상세 내용',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                ),
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      contentController.text.isNotEmpty) {
                    // 💡 방금 만든 통신 함수를 실행합니다!
                    _submitInquiry(
                      selectedCategory,
                      titleController.text,
                      contentController.text,
                    );

                    Navigator.pop(context); // 팝업 닫기

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('문의가 성공적으로 접수되었습니다.')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')),
                    );
                  }
                },
                child: const Text(
                  '접수하기',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 상태별 라벨 색상을 정해주는 함수
  Color _getStatusColor(String status) {
    if (status == '대기중') return Colors.orange;
    if (status == '답변완료') return Colors.blue;
    if (status == '처리완료') return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '문의 게시판',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _inquiries.isEmpty
          ? const Center(
              child: Text(
                '등록된 문의 내역이 없습니다.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _inquiries.length,
              itemBuilder: (context, index) {
                final item = _inquiries[index];
                final statusColor = _getStatusColor(item['status']!);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단: 카테고리 뱃지 & 처리 상태
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '[${item['category']}]',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            Text(
                              item['status']!,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 중단: 제목
                        Text(
                          item['title']!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // inquiry_screen.dart 리스트 빌더 내부
                        // ... 기존 날짜 표시 아래에 추가 ...
                        if (item['admin_answer'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50], // 답변 칸 배경색
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🛡️ 관리자 답변',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['admin_answer'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        // 하단: 날짜
                        Text(
                          // 💡 'created_at'으로 이름을 맞추고, 값이 없을 때를 대비한 안전장치 추가!
                          item['created_at'] != null
                              ? item['created_at'].toString()
                              : '날짜 정보 없음',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

      // 우측 하단 글쓰기 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showWriteDialog,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text(
          '문의하기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
