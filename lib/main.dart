import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '방재실 스마트 주차관제',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF2979FF),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const ParkingControlScreen(),
    );
  }
}

class ParkingControlScreen extends StatefulWidget {
  const ParkingControlScreen({super.key});

  @override
  State<ParkingControlScreen> createState() => _ParkingControlScreenState();
}

class _ParkingControlScreenState extends State<ParkingControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final String baseUrl = 'https://web-production-91d46.up.railway.app';

  bool _isSearching = false;
  bool _isLoadingReserved = false;
  bool _isSyncing = false;

  List<dynamic> _searchResults = [];
  List<dynamic> _reservedResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchReservedCars();
  }

  // 1. 차량 / 이름 통합 검색
  Future<void> _searchCars(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(keyword)}'),
      );
      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _searchResults = decoded['data'] ?? [];
        });
      }
    } catch (e) {
      _showSnackbar('검색 중 오류 발생: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // 2. 아파트너 예약 차량 목록 조회
  Future<void> _fetchReservedCars() async {
    setState(() => _isLoadingReserved = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/reserved'));
      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _reservedResults = decoded['data'] ?? [];
        });
      }
    } catch (e) {
      _showSnackbar('예약 목록 로드 오류: $e');
    } finally {
      setState(() => _isLoadingReserved = false);
    }
  }

  // 3. 1방재실 데이터 동기화
  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/sync'));
      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        _showSnackbar(
          '동기화 완료! SCS: ${decoded['scs_count']}건 / 입출차: ${decoded['enex_count']}건',
        );
        _fetchReservedCars();
      }
    } catch (e) {
      _showSnackbar('동기화 실패: $e');
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C2C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_parking_rounded, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text(
              '방재실 관제 센터',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '1방재실 데이터 강제 동기화',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00E676),
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _isSyncing ? null : _syncData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.grey,
          tabs: [
            const Tab(icon: Icon(Icons.search), text: '통합 검색'),
            Tab(
              icon: const Icon(Icons.event_available),
              text: '아파트너 예약 (${_reservedResults.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSearchTab(), _buildReservedTab()],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF1E1E1E),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '차량 4자리(예: 0572) 또는 이름(예: 강효영)',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF00E676),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2C),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _searchCars,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _searchCars(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '조회',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                )
              : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    '조회할 차량번호 4자리나 입주민 성함을 입력해 줘!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : SelectionArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, i) =>
                        _buildCarCard(_searchResults[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReservedTab() {
    if (_isLoadingReserved) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    if (_reservedResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              '등록된 아파트너 예약 차량이 없어.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchReservedCars,
              icon: const Icon(Icons.refresh),
              label: const Text('목록 다시 불러오기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2C),
              ),
            ),
          ],
        ),
      );
    }

    return SelectionArea(
      child: RefreshIndicator(
        color: const Color(0xFF00E676),
        onRefresh: _fetchReservedCars,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _reservedResults.length,
          itemBuilder: (context, i) =>
              _buildCarCard(_reservedResults[i], isReservation: true),
        ),
      ),
    );
  }

  Widget _buildCarCard(dynamic item, {bool isReservation = false}) {
    final carno = (item['carno'] ?? '-').toString();
    final name = (item['name'] ?? '-').toString();
    final dongHo = (item['dong_ho'] ?? '-').toString();
    final phone = (item['phone'] ?? '').toString().trim();
    final status = (item['parking_status'] ?? '-').toString();
    final isParking = status.contains('주차 중');
    final isExit = status.contains('출차');

    final lastEvent = item['last_event'] ?? '-';
    final lastTime = item['last_time'] ?? '-';
    final resDate = item['res_date'] ?? '';

    // 백엔드에서 전달되는 다건 입출차 히스토리 목록 (없으면 빈 리스트)
    final List<dynamic> history = item['history'] ?? [];

    Color badgeColor = const Color(0xFFFFA000);
    if (isParking) badgeColor = const Color(0xFF00E676);
    if (isExit) badgeColor = const Color(0xFF757575);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isParking
              ? const Color(0xFF00E676).withValues(alpha: 0.4)
              : Colors.white10,
        ),
      ),
      child: Theme(
        // ExpansionTile 기본 선 제거
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    carno,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      size: 16,
                      color: Colors.grey,
                    ),
                    tooltip: '이 차량번호로 재검색',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _searchController.text = carno;
                      _searchCars(carno);
                    },
                  ),
                  if (isReservation) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        '사전예약',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.home, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        dongHo,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      if (name != '-' && name.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.text = name;
                            _searchCars(name);
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.open_in_new,
                              size: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (phone.isNotEmpty && phone != '-')
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: phone));
                          _showSnackbar('📋 전화번호 복사 완료: $phone');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00E676,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFF00E676,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_android,
                                size: 13,
                                color: Color(0xFF00E676),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF00E676),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.copy,
                                size: 12,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isReservation && lastEvent == '-'
                          ? '예약일자: $resDate'
                          : '최근통과: $lastEvent',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    lastTime != '-' ? lastTime : '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(color: Colors.white24, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📊 상세 입출차 로그 (최근 내역)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E676),
                  ),
                ),
                Text(
                  history.isNotEmpty ? '${history.length}건 기록됨' : '상세 로그 없음',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  lastTime != '-'
                      ? '최근 1건: $lastTime ($lastEvent)'
                      : '보유한 입출차 내역이 없습니다.',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length > 5 ? 5 : history.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, hIndex) {
                    final h = history[hIndex];
                    final hType = h['io_type'] ?? '-';
                    final hTime = h['time'] ?? '-';
                    final hGate = h['gate'] ?? '-';
                    final isHIn = hType.toString().contains('입차');

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isHIn ? Icons.login : Icons.logout,
                                size: 14,
                                color: isHIn
                                    ? const Color(0xFF00E676)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$hType ($hGate)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isHIn ? Colors.white : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            hTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: '방재실 스마트 주차관제',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         scaffoldBackgroundColor: const Color(0xFF121212),
//         primaryColor: const Color(0xFF00E676),
//         colorScheme: const ColorScheme.dark(
//           primary: Color(0xFF00E676),
//           secondary: Color(0xFF2979FF),
//           surface: Color(0xFF1E1E1E),
//         ),
//       ),
//       home: const ParkingControlScreen(),
//     );
//   }
// }

// class ParkingControlScreen extends StatefulWidget {
//   const ParkingControlScreen({super.key});

//   @override
//   State<ParkingControlScreen> createState() => _ParkingControlScreenState();
// }

// class _ParkingControlScreenState extends State<ParkingControlScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   final TextEditingController _searchController = TextEditingController();

//   final String baseUrl = 'https://web-production-91d46.up.railway.app';

//   bool _isSearching = false;
//   bool _isLoadingReserved = false;
//   bool _isSyncing = false;

//   List<dynamic> _searchResults = [];
//   List<dynamic> _reservedResults = [];

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _fetchReservedCars();
//   }

//   // 1. 차량 / 이름 통합 검색
//   Future<void> _searchCars(String query) async {
//     final keyword = query.trim();
//     if (keyword.isEmpty) return;

//     setState(() => _isSearching = true);
//     try {
//       final res = await http.get(
//         Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(keyword)}'),
//       );
//       if (res.statusCode == 200) {
//         final decoded = json.decode(utf8.decode(res.bodyBytes));
//         setState(() {
//           _searchResults = decoded['data'] ?? [];
//         });
//       }
//     } catch (e) {
//       _showSnackbar('검색 중 오류 발생: $e');
//     } finally {
//       setState(() => _isSearching = false);
//     }
//   }

//   // 2. 아파트너 예약 차량 목록 조회
//   Future<void> _fetchReservedCars() async {
//     setState(() => _isLoadingReserved = true);
//     try {
//       final res = await http.get(Uri.parse('$baseUrl/reserved'));
//       if (res.statusCode == 200) {
//         final decoded = json.decode(utf8.decode(res.bodyBytes));
//         setState(() {
//           _reservedResults = decoded['data'] ?? [];
//         });
//       }
//     } catch (e) {
//       _showSnackbar('예약 목록 로드 오류: $e');
//     } finally {
//       setState(() => _isLoadingReserved = false);
//     }
//   }

//   // 3. 1방재실 데이터 동기화
//   Future<void> _syncData() async {
//     setState(() => _isSyncing = true);
//     try {
//       final res = await http.get(Uri.parse('$baseUrl/sync'));
//       if (res.statusCode == 200) {
//         final decoded = json.decode(utf8.decode(res.bodyBytes));
//         _showSnackbar(
//           '동기화 완료! SCS: ${decoded['scs_count']}건 / 입출차: ${decoded['enex_count']}건',
//         );
//         _fetchReservedCars();
//       }
//     } catch (e) {
//       _showSnackbar('동기화 실패: $e');
//     } finally {
//       setState(() => _isSyncing = false);
//     }
//   }

//   void _showSnackbar(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         behavior: SnackBarBehavior.floating,
//         backgroundColor: const Color(0xFF2C2C2C),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Row(
//           children: [
//             Icon(Icons.local_parking_rounded, color: Color(0xFF00E676)),
//             SizedBox(width: 10),
//             Text(
//               '방재실 관제 센터',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             tooltip: '1방재실 데이터 강제 동기화',
//             icon: _isSyncing
//                 ? const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Color(0xFF00E676),
//                     ),
//                   )
//                 : const Icon(Icons.sync_rounded),
//             onPressed: _isSyncing ? null : _syncData,
//           ),
//           const SizedBox(width: 8),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: const Color(0xFF00E676),
//           labelColor: const Color(0xFF00E676),
//           unselectedLabelColor: Colors.grey,
//           tabs: [
//             const Tab(icon: Icon(Icons.search), text: '통합 검색'),
//             Tab(
//               icon: const Icon(Icons.event_available),
//               text: '아파트너 예약 (${_reservedResults.length})',
//             ),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [_buildSearchTab(), _buildReservedTab()],
//       ),
//     );
//   }

//   Widget _buildSearchTab() {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(12),
//           color: const Color(0xFF1E1E1E),
//           child: Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _searchController,
//                   decoration: InputDecoration(
//                     hintText: '차량 4자리(예: 0572) 또는 이름(예: 강효영)',
//                     hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
//                     prefixIcon: const Icon(
//                       Icons.search,
//                       color: Color(0xFF00E676),
//                     ),
//                     filled: true,
//                     fillColor: const Color(0xFF2C2C2C),
//                     contentPadding: const EdgeInsets.symmetric(
//                       vertical: 0,
//                       horizontal: 16,
//                     ),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(10),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                   onSubmitted: _searchCars,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               ElevatedButton(
//                 onPressed: () => _searchCars(_searchController.text),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF00E676),
//                   foregroundColor: Colors.black,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 14,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//                 child: const Text(
//                   '조회',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: _isSearching
//               ? const Center(
//                   child: CircularProgressIndicator(color: Color(0xFF00E676)),
//                 )
//               : _searchResults.isEmpty
//               ? Center(
//                   child: Text(
//                     '조회할 차량번호 4자리나 입주민 성함을 입력해 줘!',
//                     style: TextStyle(color: Colors.grey[500]),
//                   ),
//                 )
//               : ListView.builder(
//                   padding: const EdgeInsets.all(12),
//                   itemCount: _searchResults.length,
//                   itemBuilder: (context, i) => _buildCarCard(_searchResults[i]),
//                 ),
//         ),
//       ],
//     );
//   }

//   Widget _buildReservedTab() {
//     if (_isLoadingReserved) {
//       return const Center(
//         child: CircularProgressIndicator(color: Color(0xFF00E676)),
//       );
//     }

//     if (_reservedResults.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey),
//             const SizedBox(height: 12),
//             const Text(
//               '등록된 아파트너 예약 차량이 없어.',
//               style: TextStyle(color: Colors.grey),
//             ),
//             const SizedBox(height: 12),
//             ElevatedButton.icon(
//               onPressed: _fetchReservedCars,
//               icon: const Icon(Icons.refresh),
//               label: const Text('목록 다시 불러오기'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF2C2C2C),
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     return RefreshIndicator(
//       color: const Color(0xFF00E676),
//       onRefresh: _fetchReservedCars,
//       child: ListView.builder(
//         padding: const EdgeInsets.all(12),
//         itemCount: _reservedResults.length,
//         itemBuilder: (context, i) =>
//             _buildCarCard(_reservedResults[i], isReservation: true),
//       ),
//     );
//   }

//   Widget _buildCarCard(dynamic item, {bool isReservation = false}) {
//     final carno = item['carno'] ?? '-';
//     final name = item['name'] ?? '-';
//     final dongHo = item['dong_ho'] ?? '-';
//     final phone = (item['phone'] ?? '').toString().trim();
//     final status = item['parking_status'] ?? '-';
//     final isParking = status.toString().contains('주차 중');
//     final isExit = status.toString().contains('출차');

//     final lastEvent = item['last_event'] ?? '-';
//     final lastTime = item['last_time'] ?? '-';
//     final resDate = item['res_date'] ?? '';

//     Color badgeColor = const Color(0xFFFFA000);
//     if (isParking) badgeColor = const Color(0xFF00E676);
//     if (isExit) badgeColor = const Color(0xFF757575);

//     return Card(
//       color: const Color(0xFF1E1E1E),
//       margin: const EdgeInsets.only(bottom: 10),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(
//           color: isParking
//               ? const Color(0xFF00E676).withValues(alpha: 0.4)
//               : Colors.white10,
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(14),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // 차량번호 및 상태 라벨
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Text(
//                       carno,
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     if (isReservation) ...[
//                       const SizedBox(width: 8),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.withValues(alpha: 0.2),
//                           borderRadius: BorderRadius.circular(4),
//                           border: Border.all(
//                             color: Colors.blue.withValues(alpha: 0.5),
//                           ),
//                         ),
//                         child: const Text(
//                           '사전예약',
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: Colors.blueAccent,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: badgeColor.withValues(alpha: 0.15),
//                     borderRadius: BorderRadius.circular(6),
//                     border: Border.all(
//                       color: badgeColor.withValues(alpha: 0.4),
//                     ),
//                   ),
//                   child: Text(
//                     status,
//                     style: TextStyle(
//                       color: badgeColor,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),

//             // 동호수 & 이름 & 원터치 전화번호 복사 칩
//             Wrap(
//               crossAxisAlignment: WrapCrossAlignment.center,
//               spacing: 12,
//               runSpacing: 8,
//               children: [
//                 Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.home, size: 14, color: Colors.grey),
//                     const SizedBox(width: 4),
//                     Text(
//                       dongHo,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         color: Colors.white70,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//                 Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.person, size: 14, color: Colors.grey),
//                     const SizedBox(width: 4),
//                     Text(
//                       name,
//                       style: const TextStyle(
//                         fontSize: 13,
//                         color: Colors.white70,
//                       ),
//                     ),
//                   ],
//                 ),
//                 // 전화번호가 존재할 때 터치 복사 가능한 칩 표시
//                 if (phone.isNotEmpty && phone != '-')
//                   Material(
//                     color: Colors.transparent,
//                     child: InkWell(
//                       borderRadius: BorderRadius.circular(6),
//                       onTap: () {
//                         Clipboard.setData(ClipboardData(text: phone));
//                         _showSnackbar('📋 전화번호 복사 완료: $phone');
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 8,
//                           vertical: 3,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color(
//                             0xFF00E676,
//                           ).withValues(alpha: 0.15),
//                           borderRadius: BorderRadius.circular(6),
//                           border: Border.all(
//                             color: const Color(
//                               0xFF00E676,
//                             ).withValues(alpha: 0.4),
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             const Icon(
//                               Icons.phone_android,
//                               size: 13,
//                               color: Color(0xFF00E676),
//                             ),
//                             const SizedBox(width: 4),
//                             Text(
//                               phone,
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 color: Color(0xFF00E676),
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(width: 5),
//                             const Icon(
//                               Icons.copy,
//                               size: 12,
//                               color: Colors.white70,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             const Divider(color: Colors.white10, height: 18),

//             // 입출차/예약 상세 시간 정보
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Expanded(
//                   child: Text(
//                     isReservation && lastEvent == '-'
//                         ? '예약일자: $resDate'
//                         : '최근통과: $lastEvent',
//                     style: TextStyle(fontSize: 12, color: Colors.grey[400]),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//                 Text(
//                   lastTime != '-' ? lastTime : '',
//                   style: TextStyle(fontSize: 12, color: Colors.grey[500]),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
