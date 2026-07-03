import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:nextsticker2/tools/tools.dart';

class TrainResult {
  final String destination;
  final String city;
  final String province;
  final List<String> hasGOrD;
  final List<String> overNight;
  final List<String> daytrip;

  TrainResult({
    required this.destination,
    required this.city,
    required this.province,
    required this.hasGOrD,
    required this.overNight,
    required this.daytrip,
  });

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return List<String>.from(value.map((e) => e.toString()).where((e) => e.isNotEmpty));
    }
    if (value is String) {
      return value.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  factory TrainResult.fromJson(Map<String, dynamic> json) {
    return TrainResult(
      destination: json['destination'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      hasGOrD: _parseList(json['hasGOrD']),
      overNight: _parseList(json['overNight']),
      daytrip: _parseList(json['daytrip']),
    );
  }
}

class TrainTicket extends StatefulWidget {
  const TrainTicket({Key? key}) : super(key: key);

  @override
  TrainTicketState createState() => TrainTicketState();
}

class TrainTicketState extends State<TrainTicket> {
  final TextEditingController _fromCtrl = TextEditingController(text: '沈阳');
  String _selectedProvince = '辽宁省';
  
  late io.Socket _socket;
  final List<TrainResult> _results = [];
  bool _isRunning = false;
  bool _searchTriggered = false;
  bool _forceReset = false;
  bool _isLoadingCache = true;
  // Accordion: only one item expanded at a time
  int? _expandedIndex;

  // Filter conditions (client-side quick filtering)
  bool _filterG = true;
  bool _filterOvernight = true;
  bool _filterDaytrip = true;

  // Train Scraper parameters (user controllable)
  bool _gOrDEnabled = true;
  final TextEditingController _gOrDPrefixesCtrl = TextEditingController(text: 'G, D');

  bool _overnightEnabled = true;
  final TextEditingController _overnightDepartBeforeCtrl = TextEditingController(text: '1.0');
  final TextEditingController _overnightDepartAfterCtrl = TextEditingController(text: '17.0');
  final TextEditingController _overnightArriveBeforeCtrl = TextEditingController(text: '14.0');
  final TextEditingController _overnightArriveAfterCtrl = TextEditingController(text: '4.0');
  final TextEditingController _overnightMaxDurationCtrl = TextEditingController(text: '19.0');

  bool _daytripEnabled = true;
  final TextEditingController _daytripDepartAfterCtrl = TextEditingController(text: '7.0');
  final TextEditingController _daytripArriveBeforeCtrl = TextEditingController(text: '12.0');
  final TextEditingController _daytripMaxDurationCtrl = TextEditingController(text: '2.0');

  List<TrainResult> get _filteredResults {
    return _results.where((item) {
      final bool hasGVal = _filterG && item.hasGOrD.isNotEmpty;
      final bool hasOvernightVal = _filterOvernight && item.overNight.isNotEmpty;
      final bool hasDaytripVal = _filterDaytrip && item.daytrip.isNotEmpty;
      return hasGVal || hasOvernightVal || hasDaytripVal;
    }).toList();
  }
  
  // Progress status tracking
  int _currentProgress = 0;
  int _totalProgress = 0;
  String _currentStation = '';
  String _progressStatus = '待搜索';

  final List<String> _provinces = [
    '吉林省', '黑龙江省', '辽宁省', '北京市', '上海市', 
    '江苏省', '浙江省', '安徽省', '福建省', '江西省', 
    '山东省', '河南省', '湖北省', '湖南省', '广东省', 
    '广西壮族自治区', '海南省', '四川省', '贵州省', '云南省', 
    '陕西省', '甘肃省', '青海省', '宁夏回族自治区', '新疆维吾尔自治区'
  ];

  @override
  void initState() {
    super.initState();
    _initSocket();
    _checkStatus();
  }



  void _initSocket() {
    final String socketUrl = CommonUtils.developmentMode 
        ? '${CommonUtils.wsLan}?type=train' 
        : 'https://nextsticker.cn?type=train';
    debugPrint('Connecting to socket: $socketUrl');
    
    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'forceNew': true,
      'query': {'type': 'train'},
    });

    if (!_socket.connected) {
      _socket.connect();
    }


    _socket.on('train:progress', (data) {
      debugPrint('Progress update received: $data');
      if (mounted) {
        if (_progressStatus == '待搜索') return;
        Map<String, dynamic> parsedData;
        if (data is Map) {
          parsedData = Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            parsedData = Map<String, dynamic>.from(json.decode(data));
          } catch (e) {
            parsedData = {};
          }
        } else {
          parsedData = {};
        }

        setState(() {
          _isRunning = true;
          _currentProgress = parsedData['current'] ?? _currentProgress;
          _totalProgress = parsedData['total'] ?? _totalProgress;
          _currentStation = parsedData['stationName'] ?? _currentStation;
          _progressStatus = parsedData['status'] ?? _progressStatus;
          debugPrint('[setState] progress=$_currentProgress/$_totalProgress station=$_currentStation status=$_progressStatus');
        });
      }
    });

    _socket.on('train:result', (data) {
      debugPrint('New result received: $data');
      if (mounted) {
        if (_progressStatus == '待搜索') return;
        Map<String, dynamic> parsedData;
        if (data is Map) {
          parsedData = Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            parsedData = Map<String, dynamic>.from(json.decode(data));
          } catch (e) {
            return;
          }
        } else {
          return;
        }

        setState(() {
          final newResult = TrainResult.fromJson(parsedData);
          // Avoid duplicate entries for same destination
          _results.removeWhere((item) => item.destination == newResult.destination);
          _results.insert(0, newResult);
        });
      }
    });

    _socket.on('train:done', (data) {
      debugPrint('Scraper task done: $data');
      if (mounted) {
        if (_progressStatus == '待搜索') return;
        Map<String, dynamic> parsedData;
        if (data is Map) {
          parsedData = Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            parsedData = Map<String, dynamic>.from(json.decode(data));
          } catch (e) {
            parsedData = {};
          }
        } else {
          parsedData = {};
        }

        setState(() {
          _isRunning = false;
          _progressStatus = '已完成 (用时: ${parsedData['elapsed'] ?? '未知'})';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索已完成！共找到 ${_results.length} 个匹配车站。'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _socket.on('train:error', (data) {
      debugPrint('Scraper error received: $data');
      if (mounted) {
        if (_progressStatus == '待搜索') return;
        Map<String, dynamic> parsedData;
        if (data is Map) {
          parsedData = Map<String, dynamic>.from(data);
        } else if (data is String) {
          try {
            parsedData = Map<String, dynamic>.from(json.decode(data));
          } catch (e) {
            parsedData = {};
          }
        } else {
          parsedData = {};
        }

        setState(() {
          _isRunning = false;
          _progressStatus = '运行出错: ${parsedData['message'] ?? '未知错误'}';
        });

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('查询失败'),
              ],
            ),
            content: Text(parsedData['message'] ?? '后台爬虫遇到未知的故障，请重试。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('我知道了'),
              )
            ],
          ),
        );
      }
    });
  }

  Future<void> _clearBackendCache() async {
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : "https://nextsticker.cn/";
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      await dio.post('${urlBase}api/train/clear');
      debugPrint('Cleared train cache on backend');
    } catch (e) {
      debugPrint('Error clearing train cache: $e');
    }
  }

  Future<void> _checkStatus() async {
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : "https://nextsticker.cn/";
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      final response = await dio.get('${urlBase}api/train/status');
      if (response.statusCode == 200 && response.data != null) {
        final bool running = response.data['isRunning'] ?? false;
        final activeTask = response.data['activeTask'];
        
        if (mounted) {
          if (_searchTriggered) return;
          setState(() {
            _isRunning = running;
            _isLoadingCache = false;
            if (activeTask != null) {
              // Restore parameters
              final fromObj = activeTask['from'];
              if (fromObj != null) {
                if (fromObj is String) {
                  _fromCtrl.text = fromObj;
                } else if (fromObj is Map) {
                  _fromCtrl.text = fromObj['stationsName'] ?? '';
                }
              }
              _selectedProvince = activeTask['to'] ?? _selectedProvince;
              
              // Restore filterSettings
              final fs = activeTask['filterSettings'];
              if (fs != null && fs is Map) {
                final g = fs['gOrD'];
                if (g != null && g is Map) {
                  _gOrDEnabled = g['enabled'] ?? _gOrDEnabled;
                  _gOrDPrefixesCtrl.text = g['prefixes']?.toString() ?? _gOrDPrefixesCtrl.text;
                }
                final overnight = fs['overnight'];
                if (overnight != null && overnight is Map) {
                  _overnightEnabled = overnight['enabled'] ?? _overnightEnabled;
                  _overnightDepartBeforeCtrl.text = overnight['departBefore']?.toString() ?? _overnightDepartBeforeCtrl.text;
                  _overnightDepartAfterCtrl.text = overnight['departAfter']?.toString() ?? _overnightDepartAfterCtrl.text;
                  _overnightArriveBeforeCtrl.text = overnight['arriveBefore']?.toString() ?? _overnightArriveBeforeCtrl.text;
                  _overnightArriveAfterCtrl.text = overnight['arriveAfter']?.toString() ?? _overnightArriveAfterCtrl.text;
                  _overnightMaxDurationCtrl.text = overnight['maxDuration']?.toString() ?? _overnightMaxDurationCtrl.text;
                }
                final dt = fs['daytrip'];
                if (dt != null && dt is Map) {
                  _daytripEnabled = dt['enabled'] ?? _daytripEnabled;
                  _daytripDepartAfterCtrl.text = dt['departAfter']?.toString() ?? _daytripDepartAfterCtrl.text;
                  _daytripArriveBeforeCtrl.text = dt['arriveBefore']?.toString() ?? _daytripArriveBeforeCtrl.text;
                  _daytripMaxDurationCtrl.text = dt['maxDuration']?.toString() ?? _daytripMaxDurationCtrl.text;
                }
              }

              // Restore progress
              _currentProgress = activeTask['current'] ?? 0;
              _totalProgress = activeTask['total'] ?? 0;
              _currentStation = activeTask['stationName'] ?? '';
              _progressStatus = activeTask['status'] ?? '';

              // Restore results
              _results.clear();
              final rawResults = activeTask['results'];
              if (rawResults != null && rawResults is List) {
                for (var r in rawResults) {
                  final item = TrainResult.fromJson(Map<String, dynamic>.from(r));
                  _results.removeWhere((x) => x.destination == item.destination);
                  _results.insert(0, item);
                }
              }
            } else {
              if (_isRunning) {
                _progressStatus = '后台正在搜索，等待接收进度...';
              }
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingCache = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking backend status: $e');
      if (mounted) {
        setState(() {
          _isLoadingCache = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _socket.off('train:progress');
    _socket.off('train:result');
    _socket.off('train:done');
    _socket.off('train:error');
    _fromCtrl.dispose();

    _gOrDPrefixesCtrl.dispose();
    _overnightDepartBeforeCtrl.dispose();
    _overnightDepartAfterCtrl.dispose();
    _overnightArriveBeforeCtrl.dispose();
    _overnightArriveAfterCtrl.dispose();
    _overnightMaxDurationCtrl.dispose();
    _daytripDepartAfterCtrl.dispose();
    _daytripArriveBeforeCtrl.dispose();
    _daytripMaxDurationCtrl.dispose();
    super.dispose();
  }

  void _showCityPicker() {
    const cities = [
      '北京', '上海', '广州', '深圳', '成都', '杭州',
      '西安', '武汉', '重庆', '南京', '天津', '沈阳',
      '大连', '哈尔滨', '长春', '青岛', '厦门', '郑州',
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '选择出发城市',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: cities.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  setState(() {
                    _fromCtrl.text = cities[i];
                    _currentProgress = 0;
                    _totalProgress = 0;
                    _currentStation = '';
                    _progressStatus = '待搜索';
                    _isRunning = false;
                    _results.clear();
                    _forceReset = true;
                  });
                  _clearBackendCache();
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cities[i],
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProvincePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '选择目的省份',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _provinces.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedProvince = _provinces[i];
                    _currentProgress = 0;
                    _totalProgress = 0;
                    _currentStation = '';
                    _progressStatus = '待搜索';
                    _isRunning = false;
                    _results.clear();
                    _forceReset = true;
                  });
                  _clearBackendCache();
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _provinces[i],
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSearch() async {
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : "https://nextsticker.cn/";

    _searchTriggered = true;
    try {
      final stopDio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      await stopDio.post('${urlBase}api/train/stop');
    } catch (_) {}

    if (!_socket.connected) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final bool resetParam = _forceReset;
    setState(() {
      _expandedIndex = null;
      _isRunning = true;
      if (resetParam) {
        _currentProgress = 0;
        _totalProgress = 0;
        _currentStation = '';
      }
      _progressStatus = '正在发起后台任务...';
      _forceReset = false;
    });

    final Map<String, dynamic> filterSettings = {
      'gOrD': {
        'enabled': _gOrDEnabled,
        'prefixes': _gOrDPrefixesCtrl.text,
      },
      'overnight': {
        'enabled': _overnightEnabled,
        'departBefore': double.tryParse(_overnightDepartBeforeCtrl.text) ?? 1.0,
        'departAfter': double.tryParse(_overnightDepartAfterCtrl.text) ?? 17.0,
        'arriveBefore': double.tryParse(_overnightArriveBeforeCtrl.text) ?? 14.0,
        'arriveAfter': double.tryParse(_overnightArriveAfterCtrl.text) ?? 4.0,
        'maxDuration': double.tryParse(_overnightMaxDurationCtrl.text) ?? 19.0,
      },
      'daytrip': {
        'enabled': _daytripEnabled,
        'departAfter': double.tryParse(_daytripDepartAfterCtrl.text) ?? 7.0,
        'arriveBefore': double.tryParse(_daytripArriveBeforeCtrl.text) ?? 12.0,
        'maxDuration': double.tryParse(_daytripMaxDurationCtrl.text) ?? 2.0,
      },
    };

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 5000,
        receiveTimeout: 5000,
      ));
      final response = await dio.post(
        '${urlBase}api/train/start',
        data: {
          'from': _fromCtrl.text,
          'to': _selectedProvince,
          'filterSettings': filterSettings,
          'reset': resetParam,
        },
      );
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('后台搜索任务已成功启动！正在监听进度数据...'),
            backgroundColor: Color(0xFF00897B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _isRunning = false;
          _progressStatus = '触发失败: ${response.statusMessage}';
        });
      }
    } catch (e) {
      setState(() {
        _isRunning = false;
        _progressStatus = '连接后台服务失败';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('触发搜索失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onCancel() async {
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : "https://nextsticker.cn/";
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      final response = await dio.post('${urlBase}api/train/stop');
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _isRunning = false;
          _progressStatus = '已取消';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已成功取消搜索任务'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('取消失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTrainChips(String label, List<String> trains, Color color) {
    if (trains.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: trains.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t,
                  style: TextStyle(fontSize: 11, color: Colors.grey[800], fontWeight: FontWeight.bold),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterInputField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    double width = 76,
  }) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 6, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          SizedBox(
            height: 32,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                suffixText: suffix,
                suffixStyle: const TextStyle(fontSize: 9, color: Colors.grey),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00897B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: enabled,
                activeColor: const Color(0xFF00897B),
                onChanged: onEnabledChanged,
              ),
            ),
          ],
        ),
        if (enabled) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2.0, bottom: 4.0),
            child: Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: children,
            ),
          ),
        ],
        const Divider(height: 6, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  void _showFilterSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, color: Color(0xFF00897B), size: 20),
                            SizedBox(width: 8),
                            Text(
                              '车次筛选过滤参数设置',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 12),
                    
                    _buildFilterSection(
                      title: '高铁动车过滤',
                      enabled: _gOrDEnabled,
                      onEnabledChanged: (val) {
                        setSheetState(() => _gOrDEnabled = val);
                        setState(() {});
                      },
                      children: [
                        _buildFilterInputField(
                          label: '车次前缀 (逗号隔开)',
                          controller: _gOrDPrefixesCtrl,
                          suffix: '',
                          width: 180,
                        ),
                      ],
                    ),
                    _buildFilterSection(
                      title: '夕发朝至过滤',
                      enabled: _overnightEnabled,
                      onEnabledChanged: (val) {
                        setSheetState(() => _overnightEnabled = val);
                        setState(() {});
                      },
                      children: [
                        Row(
                          children: [
                            _buildFilterInputField(
                              label: '出发早于',
                              controller: _overnightDepartBeforeCtrl,
                              suffix: '点',
                              width: 100,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterInputField(
                              label: '出发晚于',
                              controller: _overnightDepartAfterCtrl,
                              suffix: '点',
                              width: 100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildFilterInputField(
                              label: '到达早于',
                              controller: _overnightArriveBeforeCtrl,
                              suffix: '点',
                              width: 90,
                            ),
                            const SizedBox(width: 6),
                            _buildFilterInputField(
                              label: '到达晚于',
                              controller: _overnightArriveAfterCtrl,
                              suffix: '点',
                              width: 90,
                            ),
                            const SizedBox(width: 6),
                            _buildFilterInputField(
                              label: '最长历时',
                              controller: _overnightMaxDurationCtrl,
                              suffix: '小时',
                              width: 90,
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildFilterSection(
                      title: '一日游车过滤',
                      enabled: _daytripEnabled,
                      onEnabledChanged: (val) {
                        setSheetState(() => _daytripEnabled = val);
                        setState(() {});
                      },
                      children: [
                        _buildFilterInputField(
                          label: '出发晚于',
                          controller: _daytripDepartAfterCtrl,
                          suffix: '点',
                        ),
                        _buildFilterInputField(
                          label: '到达早于',
                          controller: _daytripArriveBeforeCtrl,
                          suffix: '点',
                        ),
                        _buildFilterInputField(
                          label: '最长历时',
                          controller: _daytripMaxDurationCtrl,
                          suffix: '小时',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('确 定', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchCardContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showCityPicker,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('出发城市',
                                style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _fromCtrl.text,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down,
                                    color: Color(0xFF00897B), size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showProvincePicker,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('目的省份',
                                style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _selectedProvince,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down,
                                    color: Color(0xFF00897B), size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showFilterSettingsBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF9FBFB),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF00897B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '车次筛选过滤参数设置',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '高铁动车匹配，夕发朝至及一日游的时间、历时设置',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isRunning ? _onCancel : _onSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.redAccent[700] : const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isRunning
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '取消搜索',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : const Text(
                          '搜索符合条件的车站',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTile(int i) {
    final item = _filteredResults[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('${item.destination}_${_expandedIndex == i}'),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(Icons.location_on, color: Color(0xFF00897B)),
            ),
            title: Text(
              '${item.destination} 站',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1A1A2E),
              ),
            ),
            subtitle: Text(
              '${item.city}市 | ${item.province}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            initiallyExpanded: _expandedIndex == i,
            onExpansionChanged: (expanded) {
              setState(() {
                _expandedIndex = expanded ? i : null;
              });
            },
            children: [
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 10),
              if (_filterG) _buildTrainChips('高铁动车', item.hasGOrD, Colors.blue),
              if (_filterOvernight) _buildTrainChips('夕发朝至', item.overNight, Colors.deepPurple),
              if (_filterDaytrip) _buildTrainChips('一日游车', item.daytrip, Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00695C), Color(0xFF00BFA5)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            '智能车次推荐',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  _buildSearchCardContent(),
                ],
              ),
            ),
          ),

          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('快速筛选: ', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('高铁动车', style: TextStyle(fontSize: 11)),
                      selected: _filterG,
                      selectedColor: Colors.blue.withOpacity(0.2),
                      checkmarkColor: Colors.blue,
                      onSelected: (val) => setState(() => _filterG = val),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('夕发朝至', style: TextStyle(fontSize: 11)),
                      selected: _filterOvernight,
                      selectedColor: Colors.deepPurple.withOpacity(0.2),
                      checkmarkColor: Colors.deepPurple,
                      onSelected: (val) => setState(() => _filterOvernight = val),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('一日游', style: TextStyle(fontSize: 11)),
                      selected: _filterDaytrip,
                      selectedColor: Colors.orange.withOpacity(0.2),
                      checkmarkColor: Colors.orange,
                      onSelected: (val) => setState(() => _filterDaytrip = val),
                    ),
                  ],
                ),
              ),
            ),

          if (_isRunning || _progressStatus != '待搜索')
            Padding(
              key: ValueKey('progress_$_currentProgress'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (_isRunning)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                              ),
                            if (_isRunning) const SizedBox(width: 8),
                            Text(
                              _isRunning ? '后台爬取中' : '状态反馈',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        if (_totalProgress > 0)
                          Text(
                            '进度: $_currentProgress / $_totalProgress 站',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_totalProgress > 0) ...[
                      LinearProgressIndicator(
                        value: _currentProgress / _totalProgress,
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _currentStation.isNotEmpty
                          ? '正在分析: $_currentStation 站 ($_progressStatus)'
                          : '当前状态: $_progressStatus',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: _isLoadingCache
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.teal,
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.train_outlined,
                              size: 72,
                              color: Colors.grey.withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isRunning ? '正在等待数据推送...' : '暂无搜索结果，点击上方按钮开始',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : _filteredResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_off,
                                  size: 72,
                                  color: Colors.grey.withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '没有符合当前筛选车次的结果',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredResults.length,
                            itemBuilder: (ctx, i) => _buildResultTile(i),
                          ),
          ),
        ],
      ),
    );
  }
}
