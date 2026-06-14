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
          "Authorization": "Bearer $token",
        },
      ); // 여기도 .timeout(const Duration(seconds: 3)) 붙여주시면 좋습니다!
      // 👇 [여기에 추가!] 서버 통신(http.get)이 끝난 바로 다음 줄입니다.
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;
          setState(() {
            _inquiries = data['inquiries'];
            // 💡 여기서 isLoading = false 를 지웁니다. (finally에서 할 것이므로)
          });
        }
      }
    } catch (e) {
      print("문의 내역 불러오기 실패: $e");
    } finally {
      // 💡 핵심 추가: 무조건 통신이 끝나면 로딩 창을 닫아줍니다!
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // 2. 서버로 새 문의 보내기 (수정됨)
  Future<void> _submitInquiry(String title, String content) async {
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
          "title": title,
          "content": content,
          "c_no": null, // 💡 차량 번호는 선택사항이므로 일단 null로 보냅니다.
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchInquiries();
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

  // 💡 문의 작성 팝업창 띄우기 (수정됨)
  void _showWriteDialog() {
    TextEditingController titleController = TextEditingController();
    TextEditingController contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '새 문의 접수',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 💡 카테고리 선택 부분이 삭제되었습니다.

              // 1. 제목 입력창
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '간략한 요약을 적어주세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 2. 내용 입력창 (여러 줄)
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  contentController.text.isNotEmpty) {
                // 💡 수정된 통신 함수 호출 (카테고리 제외)
                _submitInquiry(titleController.text, contentController.text);

                Navigator.pop(context); // 팝업 닫기
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')),
                );
              }
            },
            child: const Text('접수하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

                // 💡 영어 상태값을 한글로 번역합니다.
                String rawStatus =
                    item['status']?.toString().toLowerCase() ?? 'pending';
                String displayStatus = '대기중';
                Color statusColor = Colors.orange;

                if (rawStatus == 'answered') {
                  displayStatus = '답변완료';
                  statusColor = Colors.blue;
                }

                String createdAt = item['created_at']?.toString() ?? '날짜 정보 없음';
                if (createdAt.contains('T')) {
                  try {
                    DateTime dt = DateTime.parse(
                      createdAt,
                    ).toLocal(); // 한국 시간으로 변환
                    createdAt =
                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  } catch (e) {
                    createdAt = '날짜 형식 오류';
                  }
                }

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
                        // 💡 번역된 상태값만 우측 정렬 표시
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 중단: 제목
                        Text(
                          item['title'] ?? '제목 없음', // null 방지
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['content'] ?? '내용이 없습니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 관리자 답변
                        if (item['answer'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50],
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
                                  item['answer'] ?? '아직 관리자 답변이 등록되지 않았습니다.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: item['answer'] == null
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),
                        // 하단: 날짜
                        Text(
                          createdAt,
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
            ), // 💡 꼬였던 괄호가 여기서 안전하게 닫힙니다!
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
