import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:nextsticker2/tools/tools.dart';

class FlightResult {
  final String city;
  final double totalPrice;
  final String goDepartTime;
  final String goArriveTime;
  final double goPrice;
  final String goDurating;
  final String returnDepartTime;
  final String returnArriveTime;
  final double returnPrice;
  final String returnDurating;
  final String departureDate;
  final String returnDate;

  FlightResult({
    required this.city,
    required this.totalPrice,
    required this.goDepartTime,
    required this.goArriveTime,
    required this.goPrice,
    required this.goDurating,
    required this.returnDepartTime,
    required this.returnArriveTime,
    required this.returnPrice,
    required this.returnDurating,
    required this.departureDate,
    required this.returnDate,
  });

  factory FlightResult.fromJson(Map<String, dynamic> json) {
    return FlightResult(
      city: json['city'] ?? '',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      goDepartTime: json['goDepartTime'] ?? '',
      goArriveTime: json['goArriveTime'] ?? '',
      goPrice: (json['goPrice'] as num?)?.toDouble() ?? 0.0,
      goDurating: json['goDurating'] ?? '',
      returnDepartTime: json['returnDepartTime'] ?? '',
      returnArriveTime: json['returnArriveTime'] ?? '',
      returnPrice: (json['returnPrice'] as num?)?.toDouble() ?? 0.0,
      returnDurating: json['returnDurating'] ?? '',
      departureDate: json['departureDate'] ?? '',
      returnDate: json['returnDate'] ?? '',
    );
  }
}

class FlightTicket extends StatefulWidget {
  const FlightTicket({Key? key}) : super(key: key);

  @override
  FlightTicketState createState() => FlightTicketState();
}

DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

class FlightTicketState extends State<FlightTicket> {
  final TextEditingController _fromCtrl = TextEditingController(text: '沈阳');

  late DateTimeRange _selectedDateRange;

  late io.Socket _socket;
  final List<FlightResult> _results = [];
  bool _isRunning = false;
  bool _searchTriggered = false;
  bool _forceReset = false;
  bool _isLoadingCache = true;

  // Progress status tracking
  int _currentProgress = 0;
  int _totalProgress = 0;
  String _currentCity = '';
  String _progressStatus = '待搜索';

  @override
  void initState() {
    super.initState();
    final today = _normalizeDate(DateTime.now());
    _selectedDateRange = DateTimeRange(
      start: today.add(const Duration(days: 1)),
      end: today.add(const Duration(days: 5)),
    );
    _initSocket();
    _checkStatus();
  }

  void _initSocket() {
    final String socketUrl = CommonUtils.developmentMode 
        ? '${CommonUtils.wsLan}?type=flight' 
        : '${CommonUtils.wsDomainName}?type=flight';
    debugPrint('Connecting to socket: $socketUrl');
    
    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'forceNew': true,
      'query': {'type': 'flight'},
    });

    if (!_socket.connected) {
      _socket.connect();
    }

    _socket.on('flight:progress', (data) {
      debugPrint('Flight progress update received: $data');
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
          _currentCity = parsedData['cityName'] ?? _currentCity;
          _progressStatus = parsedData['status'] ?? _progressStatus;
        });
      }
    });

    _socket.on('flight:result', (data) {
      debugPrint('New flight result received: $data');
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
          final newResult = FlightResult.fromJson(parsedData);
          // Avoid duplicate entries for same city
          _results.removeWhere((item) => item.city == newResult.city);
          _results.add(newResult);
          // Sort results dynamically: price from low to high
          _results.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
        });
      }
    });

    _socket.on('flight:done', (data) {
      debugPrint('Flight scraper task done: $data');
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
            content: Text('机票搜索已完成！共找到 ${_results.length} 个城市的最低价往返航班。'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _socket.on('flight:error', (data) {
      debugPrint('Flight scraper error received: $data');
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
            content: Text(parsedData['message'] ?? '后台机票爬虫遇到故障，请重试。'),
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
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : CommonUtils.domainName;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      await dio.post('${urlBase}api/flight/clear');
      debugPrint('Cleared flight cache on backend');
    } catch (e) {
      debugPrint('Error clearing flight cache: $e');
    }
  }

  Future<void> _checkStatus() async {
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : CommonUtils.domainName;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      final response = await dio.get('${urlBase}api/flight/status');
      if (response.statusCode == 200 && response.data != null) {
        final bool running = response.data['isRunning'] ?? false;
        final activeTask = response.data['activeTask'];
        
        if (mounted) {
          if (_searchTriggered) return;
          setState(() {
            _isRunning = running;
            _isLoadingCache = false;
            if (activeTask != null) {
              _fromCtrl.text = activeTask['from'] ?? _fromCtrl.text;
              
              final depDateStr = activeTask['departureDate'];
              final retDateStr = activeTask['returnDate'];
              if (depDateStr != null && retDateStr != null) {
                try {
                  final start = _normalizeDate(DateTime.parse(depDateStr));
                  final end = _normalizeDate(DateTime.parse(retDateStr));
                  _selectedDateRange = DateTimeRange(start: start, end: end);
                } catch (_) {}
              }

              _currentProgress = activeTask['current'] ?? 0;
              _totalProgress = activeTask['total'] ?? 0;
              _currentCity = activeTask['cityName'] ?? '';
              _progressStatus = activeTask['status'] ?? '';

              _results.clear();
              final rawResults = activeTask['results'];
              if (rawResults != null && rawResults is List) {
                for (var r in rawResults) {
                  final item = FlightResult.fromJson(Map<String, dynamic>.from(r));
                  _results.removeWhere((x) => x.city == item.city);
                  _results.add(item);
                }
                // Sort ascending
                _results.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
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
      debugPrint('Error checking flight status: $e');
      if (mounted) {
        setState(() {
          _isLoadingCache = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _socket.off('flight:progress');
    _socket.off('flight:result');
    _socket.off('flight:done');
    _socket.off('flight:error');
    _fromCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    await _showCustomDateRangePicker();
  }

  Future<void> _showCustomDateRangePicker() async {
    DateTime tempStart = _normalizeDate(_selectedDateRange.start);
    DateTime tempEnd = _normalizeDate(_selectedDateRange.end);
    bool isSelectingDeparture = true;
    DateTime? pickedStart;
    DateTime? pickedEnd;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final days = tempEnd.difference(tempStart).inDays + 1;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Title Bar with Cancel and Confirm
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ),
                        const Text(
                          '选择往返日期',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            pickedStart = tempStart;
                            pickedEnd = tempEnd;
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('确定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),

                  // Selection Mode Indicator & Date Cards
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        // Departure Date Card
                        _buildDateSelectionTab(
                          label: '去程',
                          date: tempStart,
                          isSelected: isSelectingDeparture,
                          onTap: () {
                            setSheetState(() {
                              isSelectingDeparture = true;
                            });
                          },
                        ),

                        // Middle Duration Badge
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFFCC80), width: 0.5),
                                ),
                                child: Text(
                                  '共$days天',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                            ],
                          ),
                        ),

                        // Return Date Card
                        _buildDateSelectionTab(
                          label: '返程',
                          date: tempEnd,
                          isSelected: !isSelectingDeparture,
                          onTap: () {
                            setSheetState(() {
                              isSelectingDeparture = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Prompt Banner
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelectingDeparture ? Icons.flight_takeoff : Icons.flight_land,
                          size: 16,
                          color: const Color(0xFFE65100),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSelectingDeparture ? '请在下方日历中点击选择「去程日期」' : '请在下方日历中点击选择「返程日期」',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                  // Calendar
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _DualCalendarWidget(
                        startDate: tempStart,
                        endDate: tempEnd,
                        isSelectingDeparture: isSelectingDeparture,
                        onDateTap: (date) {
                          setSheetState(() {
                            if (isSelectingDeparture) {
                              tempStart = date;
                              if (tempEnd.isBefore(tempStart)) {
                                tempEnd = tempStart.add(const Duration(days: 1));
                              }
                              isSelectingDeparture = false;
                            } else {
                              if (date.isBefore(tempStart)) {
                                tempStart = date;
                              } else {
                                tempEnd = date;
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (pickedStart != null && pickedEnd != null) {
      if (pickedEnd!.isBefore(pickedStart!)) {
        pickedEnd = pickedStart;
      }
      final duration = pickedEnd!.difference(pickedStart!).inDays;
      if (duration > 60) {
        pickedEnd = pickedStart!.add(const Duration(days: 60));
      }
      setState(() {
        _selectedDateRange = DateTimeRange(start: pickedStart!, end: pickedEnd!);
        _currentProgress = 0;
        _totalProgress = 0;
        _currentCity = '';
        _progressStatus = '待搜索';
        _isRunning = false;
        _results.clear();
        _forceReset = true;
      });
      _clearBackendCache();
    }
  }

  Widget _buildDateSelectionTab({
    required String label,
    required DateTime date,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF3E0) : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFE65100) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFFE65100) : Colors.grey,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '选择中',
                        style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${date.month}月${date.day}日',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFFE65100) : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getWeekday(date),
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? const Color(0xFFE65100) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSimpleDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _getWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  void _showCityPicker() {
    final cities = [
      '北京', '上海', '广州', '深圳', '成都', '杭州',
      '西安', '武汉', '重庆', '南京', '沈阳', '大连',
      '哈尔滨', '长沙', '厦门', '青岛', '郑州', '昆明',
      '东京', '首尔', '曼谷', '新加坡', '香港', '台北',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
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
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _fromCtrl.text = cities[i];
                        _currentProgress = 0;
                        _totalProgress = 0;
                        _currentCity = '';
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
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onSearch() async {
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : CommonUtils.domainName;

    _searchTriggered = true;
    try {
      final stopDio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      await stopDio.post('${urlBase}api/flight/stop');
    } catch (_) {}

    if (!_socket.connected) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final bool resetParam = _forceReset;
    setState(() {
      _isRunning = true;
      if (resetParam) {
        _currentProgress = 0;
        _totalProgress = 0;
        _currentCity = '';
      }
      _progressStatus = '正在发起后台任务...';
      _forceReset = false;
    });

    final String depDateStr = "${_selectedDateRange.start.year}-${_selectedDateRange.start.month.toString().padLeft(2, '0')}-${_selectedDateRange.start.day.toString().padLeft(2, '0')}";
    final String retDateStr = "${_selectedDateRange.end.year}-${_selectedDateRange.end.month.toString().padLeft(2, '0')}-${_selectedDateRange.end.day.toString().padLeft(2, '0')}";

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 5000,
        receiveTimeout: 5000,
      ));
      final response = await dio.post(
        '${urlBase}api/flight/start',
        data: {
          'from': _fromCtrl.text,
          'departureDate': depDateStr,
          'returnDate': retDateStr,
          'reset': resetParam,
        },
      );
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('后台搜索机票任务已成功启动！正在监听进度数据...'),
            backgroundColor: Color(0xFFE65100),
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
    final String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : CommonUtils.domainName;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: 3000,
        receiveTimeout: 3000,
      ));
      final response = await dio.post('${urlBase}api/flight/stop');
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

  Widget _buildFlightResultCard(FlightResult item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: City & Total Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.flight_land, color: Color(0xFFE65100), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.city,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '¥${item.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 12),
            
            // Go Flight Info
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '去程',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.goDepartTime} -> ${item.goArriveTime}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${item.goDurating})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '¥${item.goPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Return Flight Info
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '回程',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.returnDepartTime} -> ${item.returnArriveTime}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${item.returnDurating})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '¥${item.returnPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationDays = _selectedDateRange.end.difference(_selectedDateRange.start).inDays + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // ── 顶部渐变头部 ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE65100), Color(0xFFFF7043)],
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
                  // AppBar 区域
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            '飞机票比价',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 搜索卡片
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 出发城市选择
                            GestureDetector(
                              onTap: _showCityPicker,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.flight_takeoff, color: Color(0xFFE65100), size: 28),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '出发城市',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _fromCtrl.text,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 32, color: Color(0xFFEEEEEE)),
                            
                            // 往返日期选择
                            GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '去程日期',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${_formatSimpleDate(_selectedDateRange.start)} ${_getWeekday(_selectedDateRange.start)}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFFCC80), width: 0.5),
                                      ),
                                      child: Text(
                                        '$durationDays天',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            '返程日期',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${_formatSimpleDate(_selectedDateRange.end)} ${_getWeekday(_selectedDateRange.end)}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // 搜索与取消按钮行
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isRunning ? _onCancel : _onSearch,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100),
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
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            '点击取消',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        '搜索往返机票',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ── 进度条反馈卡片 ─────────────────────────────────────────
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE65100)),
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
                            '进度: $_currentProgress / $_totalProgress 城市',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_totalProgress > 0) ...[
                      LinearProgressIndicator(
                        value: _currentProgress / _totalProgress,
                        backgroundColor: const Color(0xFFFFF3E0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _currentCity.isNotEmpty
                          ? '正在分析: $_currentCity ($_progressStatus)'
                          : '当前状态: $_progressStatus',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

          // ── 内容区（列表） ─────────────────────────────────────────
          Expanded(
            child: _isLoadingCache
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE65100),
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.flight_outlined,
                              size: 72,
                              color: Colors.grey.withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isRunning ? '正在等待数据推送...' : '暂无低价机票结果，点击上方按钮开始比价',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) => _buildFlightResultCard(_results[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DualCalendarWidget extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final bool isSelectingDeparture;
  final ValueChanged<DateTime> onDateTap;

  const _DualCalendarWidget({
    required this.startDate,
    required this.endDate,
    required this.isSelectingDeparture,
    required this.onDateTap,
  });

  @override
  State<_DualCalendarWidget> createState() => _DualCalendarWidgetState();
}

class _DualCalendarWidgetState extends State<_DualCalendarWidget> {
  late PageController _pageController;
  late int _currentPage;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final initialMonth = widget.startDate;
    final monthsSinceEpoch = (initialMonth.year * 12 + initialMonth.month) - (1970 * 12 + 1);
    _currentPage = monthsSinceEpoch;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _pageToMonth(int page) {
    final totalMonths = 1970 * 12 + 1 + page;
    return DateTime(totalMonths ~/ 12, (totalMonths % 12) + 1);
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final currentMonth = _pageToMonth(_currentPage);
    final monthName = '${currentMonth.year}年${currentMonth.month}月';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 24),
              onPressed: _currentPage > 0
                  ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
            ),
            Text(
              monthName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 24),
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: _weekdays.map((w) {
            final isWeekend = w == '六' || w == '日';
            return Expanded(
              child: Center(
                child: Text(
                  w,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isWeekend ? const Color(0xFFE65100) : Colors.grey,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Divider(height: 12, color: Color(0xFFEEEEEE)),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, page) {
              return _buildMonthGrid(_pageToMonth(page));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday - 1; // 0 for Monday

    final List<Widget> cells = [];

    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    final now = DateTime.now();
    final today = _normalize(now);
    final normStart = _normalize(widget.startDate);
    final normEnd = _normalize(widget.endDate);

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isPast = date.isBefore(today);
      final isToday = date.isAtSameMomentAs(today);
      final isStart = date.isAtSameMomentAs(normStart);
      final isEnd = date.isAtSameMomentAs(normEnd);
      final isSameDay = isStart && isEnd;
      final isInRange = !date.isBefore(normStart) && !date.isAfter(normEnd);

      cells.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isPast ? null : () => widget.onDateTap(date),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Range background connector band
              if (isInRange && !isSameDay)
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          color: isStart ? Colors.transparent : const Color(0xFFFFF3E0),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: isEnd ? Colors.transparent : const Color(0xFFFFF3E0),
                        ),
                      ),
                    ],
                  ),
                ),

              // Day pill / button
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: (isStart || isEnd) ? const Color(0xFFE65100) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (isStart || isEnd || isToday) ? FontWeight.bold : FontWeight.normal,
                          color: isPast
                              ? Colors.grey.shade300
                              : (isStart || isEnd)
                                  ? Colors.white
                                  : isToday
                                      ? const Color(0xFFE65100)
                                      : const Color(0xFF1A1A2E),
                        ),
                      ),
                      if (isSameDay)
                        const Text(
                          '去/返',
                          style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      else if (isStart)
                        const Text(
                          '去程',
                          style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      else if (isEnd)
                        const Text(
                          '返程',
                          style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      else if (isToday)
                        const Text(
                          '今天',
                          style: TextStyle(fontSize: 9, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
                        )
                      else
                        const SizedBox(height: 11),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: 0.88,
      mainAxisSpacing: 2,
      crossAxisSpacing: 0,
      children: cells,
    );
  }
}
