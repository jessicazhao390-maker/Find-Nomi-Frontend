import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // 用于解析后端传来的 JSON 数据
import 'package:http/http.dart' as http; // 用于发送网络请求
import 'dart:async'; // 引入定时器功能

void main() {
  runApp(const FindNomiApp());
}

class FindNomiApp extends StatelessWidget {
  const FindNomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find Nomi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF167B40)),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentMenuIndex = 0; 
  
  String latestLocationCn = "图书馆前";
  String latestLocationEn = "Library";
  String dateStr = "2026-06-17";
  String timeStr = "14:30:00";
  String cameraName = "CAM_Library_01";
  String conditionCn = "散步";
  String conditionEn = "Wandering";
  bool isLoading = true;
  String errorTip = "";

  // 大鹅中心坐标
  LatLng _goosePosition = const LatLng(29.8005, 121.56257);

  List<LatLng> goosePath = [];
  Timer? _gooseTimer; // 专门负责每隔几秒去拉取数据的定时器

  @override
  void initState() {
    super.initState();
    fetchGooseData(); // 刚进页面，立刻拉取一次保底

   // 开启轮询：每隔 3 秒自动执行一次 fetchGooseData 
    _gooseTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
    fetchGooseData(); 
    });
  }

   // 页面销毁时必须关掉定时器 
  @override
  void dispose() {
    _gooseTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchGooseData() async {
    setState((){
      isLoading = true;
      errorTip = "";
    });
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/get-locations'));
      
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body); 
        final List<dynamic> records = decodedData['data']; 

        //在前端强行按时间戳排序，彻底杜绝数据乱序导致的大鹅“闪现横跳”！
        records.sort((a, b) => a['timestamp'].toString().compareTo(b['timestamp'].toString()));
         List<LatLng> newGoosePath = records.map((record) {
           final loc = record['location'];
           return LatLng(loc['lat'], loc['lng']);
        }).toList();

        setState(() {
          goosePath = newGoosePath;
          if (goosePath.isNotEmpty) {
            _goosePosition = goosePath.last; 
          }

          if (records.isNotEmpty) {
            final latestRecord = records.last;
            latestLocationCn = latestRecord['location_cn'] ?? "未知 Unknown";
            latestLocationEn = latestRecord['location_en'] ?? "Unknown";
            dateStr = latestRecord['timestamp'].toString().split(' ')[0];
            timeStr = latestRecord['timestamp'].toString().split(' ')[1];
            cameraName = latestRecord['camera_id'] ?? "未知 Unknown";
            conditionCn = latestRecord['condition_cn'] ?? "未知 Unknown";
            conditionEn = latestRecord['condition_en'] ?? "Unknown";
          }
        });
        
       // print("✅ 成功获取并渲染了 ${goosePath.length} 条大鹅轨迹！");
      } else {
        print("⚠️ 服务器返回了错误状态码: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 获取数据失败，可能是后端没开或者地址写错了: $e");
    }
  }

// 👉 存放下拉菜单的所有地点选项
  final List<String> _locationOptions = [
    "杨福家楼 TB",
    "教学楼 PB",
    "思源报告厅 Siyuan Auditorium",
    "理工楼 PMB",
    "海洋楼 IAMET",
    "图书馆Library",
    "钟楼前草坪 Lawn",
    "诺丁河畔 Banks of Nottingham River",
    "新教学楼 DB",
    "国际创新创业大楼 IEB",
    "新奥迪报告厅 New Audi"
  ];
  
  // 👉 用于保存用户当前选中的地点 (如果没有选，就是 null)
  String? _selectedLocation;

  // 👉 用于保存用户选择的完整时间
  DateTime? _selectedDateTime;

  // 👉 唤起日期和时间选择器的核心逻辑
  Future<void> _pickDateTime() async {
    // 1. 先呼出“日期选择器”
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // 默认选定今天
      firstDate: DateTime(2020),   // 允许选择的最早年份
      lastDate: DateTime(2101),    // 允许选择的最晚年份
      builder: (context, child) {
        return Theme(
          // 给原生的选择器套上你的绿色主题
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF167B40), 
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      // 2. 日期选完后，紧接着呼出“时间选择器”
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF167B40),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        // 3. 把日期和具体时间拼装成一个完整的 DateTime 对象
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
            DateTime.now().second,
          );
        });
      }
    }
  }

// 👉 1. 坐标翻译字典：把地名转换成后端需要的经纬度
  final Map<String, LatLng> _locationCoordinates = {
    "杨福家楼 TB": const LatLng(29.80030, 121.56221),
    "教学楼 PB": const LatLng(29.80048, 121.56324),
    "思源报告厅 Siyuan Auditorium": const LatLng(29.80040, 121.56270),
    "理工楼 PMB": const LatLng(29.80035, 121.56115),
    "海洋楼 IAMET": const LatLng(29.80059, 121.56025),
    "图书馆Library": const LatLng(29.80097, 121.56340),
    "钟楼前草坪 Lawn": const LatLng(29.80105, 121.56230),
    "诺丁河畔 Banks of Nottingham River": const LatLng(29.79980, 121.56283),
    "新教学楼 DB": const LatLng(29.79904, 121.56089),
    "国际创新创业大楼 IEB": const LatLng(29.79873, 121.55998),
    "新奥迪报告厅 New Audi": const LatLng(29.79888, 121.56155),
  };

  // 👉 2. 提交上报的核心函数
  Future<void> _submitReport() async {
    // 拦截：如果没填完就点提交，弹出提示
    if (_selectedLocation == null || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 请先完整填写大鹅出现的位置和时间！')),
      );
      return;
    }

    // 从字典里拿到对应的坐标
    final LatLng? coords = _locationCoordinates[_selectedLocation];
    if (coords == null) return;

    // 格式化时间为后端需要的 YYYY-MM-DD HH:MM:SS
    // 格式化时间为后端需要的 YYYY-MM-DD HH:MM:SS (把写死的 00 改成了真实的秒)
    final String timestampStr = '${_selectedDateTime!.year}-${_selectedDateTime!.month.toString().padLeft(2, '0')}-${_selectedDateTime!.day.toString().padLeft(2, '0')} ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}:${_selectedDateTime!.second.toString().padLeft(2, '0')}';

    // 组装发送给后端的 JSON 数据
    final payload = {
      "goose_id": "Nomi_01",
      "camera_id": "User_Report", // 标记为用户手动上报
      "timestamp": timestampStr,
      "location": {
        "lat": coords.latitude,
        "lng": coords.longitude
      }
    };

    try {
      // 向你本地的 FastAPI 发送 POST 请求
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/upload-location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 上报成功！感谢你提供大鹅线索！')),
        );
        
        // 清空表单，并切回主页
        setState(() {
          _selectedLocation = null;
          _selectedDateTime = null;
          _currentMenuIndex = 0; 
        });
        
        // 刷新主页地图
        fetchGooseData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 上报失败，状态码: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 网络请求出错: $e')),
      );
    }
  }

  int _reportStatus = 0;

  // ==========================================
  // 📍 足迹页面专用数据与逻辑 (新增)
  // ==========================================
  double _timeSliderValue = 0.65; 

  List<LatLng> _trajectoryPoints = [];

  LatLng _getDynamicGoosePosition() {
    if (_trajectoryPoints.isEmpty) return _goosePosition;
    if (_timeSliderValue <= 0) return _trajectoryPoints.first;
    if (_timeSliderValue >= 1) return _trajectoryPoints.last;

    double totalSegments = (_trajectoryPoints.length - 1).toDouble();
    double exactSegment = _timeSliderValue * totalSegments;
    int segmentIndex = exactSegment.floor();
    double segmentFraction = exactSegment - segmentIndex;

    LatLng p1 = _trajectoryPoints[segmentIndex];
    LatLng p2 = _trajectoryPoints[segmentIndex + 1];

    double lat = p1.latitude + (p2.latitude - p1.latitude) * segmentFraction;
    double lng = p1.longitude + (p2.longitude - p1.longitude) * segmentFraction;
    return LatLng(lat, lng);
  }

  String _getDynamicTime() {
    int totalMinutes = (600 * _timeSliderValue).round();
    int hours = 8 + (totalMinutes ~/ 60);
    int minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), 
      body: Stack(
        children: [
          // 【底层动态区域】
          Positioned.fill(
            child: _currentMenuIndex == 0 
                ? _buildMapPage()     
                : _currentMenuIndex == 1
                    ? _buildReportPage()
                    : _currentMenuIndex == 2
                        ? _buildHeatmapPage()
                        : _buildTrajectoryPage(), // 👈 接入今日足迹页面
          ),

          // 【上层固定区域：左侧菜单栏】
          Positioned(
            top: 20,
            left: 20,
            bottom: 20,
            child: SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🎯 修复 1：将 Logo 变成可点击的“主页传送门”
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMenuIndex = 0; // 点击 Logo，强制切回地图主页！
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF026002), 
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Text(
                        'Find Nomi',
                        style: GoogleFonts.audiowide(color: Colors.white, fontSize: 26, fontWeight: FontWeight.normal),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 主控制面板
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF167B40),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              _buildMenuButton(Icons.warning_amber_rounded, '上报\nReport', 1),
                              const SizedBox(height: 20),
                              _buildMenuButton(Icons.wb_sunny_outlined, '热力图\nHeatmap', 2),
                              const SizedBox(height: 20),
                              _buildMenuButton(Icons.show_chart_rounded, '今日足迹\nTrajectory', 3),
                            ],
                          ),
                          _buildLiveStatusCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(IconData icon, String text, int index) {
    bool isSelected = _currentMenuIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            // 👈 允许索引 1, 2, 3 进行跳转
            if (index >= 1 && index <= 3) { 
              _currentMenuIndex = index; 
            }
          });
        },
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer( 
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFDE5B) : const Color(0xFFF3ECA4), 
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF675305) : const Color(0xFF167B40), size: 28),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF675305) : const Color(0xFF006800), 
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECA4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cast_connected, color: Color(0xFF167B40)),
              SizedBox(width: 6),
              Text('实时状态\nLive Status', style: TextStyle(color: Color(0xFF006800), fontWeight: FontWeight.bold, fontSize: 13, height: 1.1)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('最新位置:', '$latestLocationCn\nLatest Location: $latestLocationEn'),
          const SizedBox(height: 8),
          _buildInfoRow('发现时间\nTimestamp', '$dateStr\n$timeStr'),
          const SizedBox(height: 8),
          _buildInfoRow('目击相机 Camera:', cameraName),
          const SizedBox(height: 8),
          _buildInfoRow('当前状态: $conditionCn\nCurrent Condition:\n$conditionEn', ''),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Text(
      value.isEmpty ? title : '$title $value',
      style: const TextStyle(fontSize: 11, color: Color(0xFF006800), height: 1.3),
    );
  }

// 主页地图
  Widget _buildMapPage() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _goosePosition, 
        initialZoom: 16.0,
        onTap: (tapPosition, point) {
          print('点击了地图, 坐标代码为: const LatLng(${point.latitude}, ${point.longitude}),');
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
          userAgentPackageName: 'com.example.find_nomi',
        ),
        
        // 严格锁定最新位置的大鹅图标层
        MarkerLayer(
          markers: [
            Marker(
              point: _goosePosition, // 永远等于后端传来的最后一个最新点
              width: 60,
              height: 60,
              alignment: Alignment.center, 
              child: Image.asset('assets/nomi_goose.png', fit: BoxFit.contain),
            ),
          ],
        ),
      ],
    );
  }

  // 上报表单页 (完全保留你的原始代码)
  Widget _buildReportPage() {
    return Container(
      color: Colors.white, 
      padding: const EdgeInsets.only(left: 240, top: 40, bottom: 40, right: 40), 
      child: Center( 
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680), 
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () { setState(() { _currentMenuIndex = 0; }); },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.grey[600], size: 28),
                      const SizedBox(width: 8),
                      Text('返回 Back', style: TextStyle(fontSize: 22, color: Colors.grey[600], fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                _buildSectionTitle(Icons.flag_outlined, '位置 Location'),
                const SizedBox(height: 12),
                
                PopupMenuButton<String>(
                  position: PopupMenuPosition.under, // 👈 魔法核心：强制在下方展开！
                  color: const Color(0xFFF1F8F1), // 下拉菜单的背景色
                  elevation: 6, // 加上一点阴影更有立体感
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  constraints: const BoxConstraints(minWidth: 600, maxWidth: 600), // 让下拉框的宽度基本对齐你的主框
                  onSelected: (String newValue) {
                    setState(() {
                      _selectedLocation = newValue; // 选中后更新界面
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return _locationOptions.map((String location) {
                      return PopupMenuItem<String>(
                        value: location,
                        child: Text(
                          location,
                          style: const TextStyle(color: Color(0xFF006800), fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList();
                  },
                  // 👇 触发菜单的“绿框”本体
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9), 
                      border: Border.all(color: const Color(0xFF167B40)), 
                      borderRadius: BorderRadius.circular(6)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 28), // 隐形占位，用来平衡右边的箭头，让文字绝对居中
                        Text(
                          _selectedLocation ?? '选择 Select Location', // 有选择就显示选项，没选择就显示默认字
                          style: const TextStyle(color: Color(0xFF006800), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF167B40), size: 28),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                _buildSectionTitle(Icons.access_time_rounded, '时间 Timestamp'),
                const SizedBox(height: 12),
               /* Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(''), Icon(Icons.calendar_today_outlined, color: Colors.black87, size: 20)]),
                ),*/
                InkWell(
                  onTap: _pickDateTime, // 👈 绑定刚刚写的选择器函数
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400), 
                      borderRadius: BorderRadius.circular(6)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        Text(
                          _selectedDateTime != null 
                              ? '${_selectedDateTime!.year}-${_selectedDateTime!.month.toString().padLeft(2, '0')}-${_selectedDateTime!.day.toString().padLeft(2, '0')} ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}:${_selectedDateTime!.second.toString().padLeft(2, '0')}'
                              : '选择日期和时间 Select Date & Time', 
                          style: TextStyle(
                            color: _selectedDateTime != null ? Colors.black87 : Colors.grey.shade600, 
                            fontSize: 16,
                          ),
                        ), 
                        const Icon(Icons.calendar_today_outlined, color: Colors.black87, size: 20)
                      ]
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _buildSectionTitle(Icons.sentiment_satisfied_alt_rounded, '状态 Status'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildStatusChip(0, '散步中\nWandering')), const SizedBox(width: 16),
                    Expanded(child: _buildStatusChip(1, '睡觉中\nSleeping')), const SizedBox(width: 16),
                    Expanded(child: _buildStatusChip(2, '干饭中\nEating')),
                  ],
                ),
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () { setState(() { _currentMenuIndex = 0; }); },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('取消 Cancel', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _submitReport, 
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('提交 Report', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ), 
              ], // 👈 正确闭合 Column 的 children
            ), // 👈 正确闭合 Column
          ), // 👈 正确闭合 SingleChildScrollView
        ), // 👈 正确闭合 ConstrainedBox
      ), // 👈 正确闭合 Center
    ); // 👈 正确闭合 Container
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(children: [Icon(icon, size: 24, color: Colors.black87), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87))]);
  }

  Widget _buildStatusChip(int index, String text) {
    bool isSelected = _reportStatus == index;
    return GestureDetector(
      onTap: () { setState(() { _reportStatus = index; }); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFFFECB3) : const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(30), border: Border.all(color: isSelected ? const Color(0xFFFFCA28) : Colors.transparent, width: 1.5), boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))] : []),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? const Color(0xFFF4511E) : Colors.grey[700], fontWeight: FontWeight.normal, height: 1.2)),
      ),
    );
  }

  // ==================== 页面 2: 热力图页面 (完全保留你的原始代码) ====================
  Widget _buildHeatmapPage() {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: _goosePosition, initialZoom: 16.0),
          children: [
            TileLayer(
              urlTemplate: 'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.example.find_nomi',
            ),
            CircleLayer(
              circles: [
                CircleMarker(point: const LatLng(29.80105, 121.5625), color: Colors.greenAccent.withOpacity(0.3), radius: 80, useRadiusInMeter: false),
                CircleMarker(point: const LatLng(29.80105, 121.5625), color: Colors.orange.withOpacity(0.4), radius: 50, useRadiusInMeter: false),
                CircleMarker(point: const LatLng(29.80105, 121.5625), color: Colors.red.withOpacity(0.5), radius: 25, useRadiusInMeter: false),
                
                CircleMarker(point: const LatLng(29.8009, 121.56165), color: Colors.greenAccent.withOpacity(0.3), radius: 70, useRadiusInMeter: false),
                CircleMarker(point: const LatLng(29.8009, 121.56165), color: Colors.orange.withOpacity(0.4), radius: 40, useRadiusInMeter: false),
                CircleMarker(point: const LatLng(29.8009, 121.56165), color: Colors.red.withOpacity(0.5), radius: 15, useRadiusInMeter: false),
                
                CircleMarker(point: const LatLng(29.8010, 121.5634), color: Colors.greenAccent.withOpacity(0.3), radius: 90, useRadiusInMeter: false),
                CircleMarker(point: const LatLng(29.8010, 121.5634), color: Colors.orange.withOpacity(0.4), radius: 45, useRadiusInMeter: false),
                CircleMarker(point: const LatLng(29.8010, 121.5634), color: Colors.orange.withOpacity(0.5), radius: 25, useRadiusInMeter: false),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _goosePosition,
                  width: 60,
                  height: 60,
                  alignment: Alignment.center, 
                  child: Image.asset('assets/nomi_goose.png', fit: BoxFit.contain),
                ),
              ],
            ),
          ],
        ),

        Positioned(
          bottom: 30,
          right: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF1976D2), width: 2), 
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const Text(
              '总记录坐标 Total Records: 1,402',
              style: TextStyle(color: Color(0xFF1976D2), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 页面 3: 今日足迹 (安全新增，绝不影响原有代码) ====================
  Widget _buildTrajectoryPage() {
    LatLng currentGoosePos = _getDynamicGoosePosition(); 
    String currentTime = _getDynamicTime(); 

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: _goosePosition, initialZoom: 16.0),
          children: [
            TileLayer(
              urlTemplate: 'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.example.find_nomi',
            ),
            // 🎯 完全修复了常量表达式报错，适配 FlutterMap 8.x
            PolylineLayer(
              polylines: <Polyline<Object>>[
                Polyline<Object>(
                  points: _trajectoryPoints,
                  color: const Color(0xFF167B40),
                  strokeWidth: 4.0,
                  pattern: StrokePattern.dashed(segments: const [12.0, 12.0]), 
                ),
              ],
            ),
            MarkerLayer(
              markers: _trajectoryPoints.map((point) => Marker(
                point: point,
                width: 16, height: 16,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF4511E), width: 3),
                  ),
                ),
              )).toList(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: currentGoosePos,
                  width: 60, height: 60,
                  alignment: Alignment.center,
                  child: Image.asset('assets/nomi_goose.png', fit: BoxFit.contain),
                ),
              ],
            ),
          ],
        ),

        Positioned(
          bottom: 40,
          right: 40,
          child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF167B40), width: 2), 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment((_timeSliderValue * 2) - 1.0, 0),
                  child: Text(currentTime, style: const TextStyle(color: Color(0xFF167B40), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF167B40),
                    inactiveTrackColor: Colors.grey.shade300,
                    trackHeight: 6.0,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0, elevation: 4.0),
                    overlayColor: const Color(0xFF167B40).withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _timeSliderValue,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      setState(() {
                        _timeSliderValue = value; 
                      });
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('08:00 (起点)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text('18:00 (现在)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
