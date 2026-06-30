import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:dio/dio.dart';

class TripImageItem {
  final TravelModel trip;
  final bool isCover;
  final DetailModel? point; // null if isCover
  final int? dayIndex;
  final int? pointIndex;

  String get imageUrl {
    if (isCover) {
      return trip.cover;
    } else {
      return point?.picURL ?? '';
    }
  }

  TripImageItem({
    required this.trip,
    required this.isCover,
    this.point,
    this.dayIndex,
    this.pointIndex,
  });

  String get title {
    if (isCover) {
      return '封面图片';
    } else {
      return '第 ${(dayIndex ?? 0) + 1} 天: ${point?.nameOfScence ?? ""}';
    }
  }

  String get description {
    if (isCover) {
      return trip.tripName;
    } else {
      return '${trip.tripName} • ${point?.nameOfScence ?? ""}';
    }
  }

  String get queryKey {
    return '${trip.uid}_${isCover ? "cover" : "${dayIndex}_${pointIndex}_${point?.nameOfScence}"}';
  }

  String get searchName {
    if (isCover) {
      return trip.city.isNotEmpty
          ? trip.city
          : (trip.detail.isNotEmpty && trip.detail[0].dayList.isNotEmpty
              ? trip.detail[0].dayList[0].nameOfScence
              : trip.tripName);
    } else {
      return point?.nameOfScence ?? '';
    }
  }
}

class ImageDetectionPage extends StatefulWidget {
  const ImageDetectionPage({Key? key}) : super(key: key);

  @override
  State<ImageDetectionPage> createState() => _ImageDetectionPageState();
}

class _ImageDetectionPageState extends State<ImageDetectionPage> {
  bool _isLoading = true;
  List<TravelModel> _trips = [];
  List<TripImageItem> _allImages = [];
  final Set<String> _failedImages = {};
  final Set<String> _repairingKeys = {};
  int _activeTab = 1; // 0: All, 1: Issues
  bool _isValidatingLinks = false;

  // Background repair state
  bool _isRepairing = false;
  bool _isRepairingInBackground = false;
  bool _isCancelled = false;
  int _repairProgress = 0;
  int _repairTotal = 0;
  int _repairSuccessCount = 0;
  StateSetter? _dialogSetState;

  bool _showBackToTop = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300) {
        if (!_showBackToTop) {
          setState(() {
            _showBackToTop = true;
          });
        }
      } else {
        if (_showBackToTop) {
          setState(() {
            _showBackToTop = false;
          });
        }
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final trips = await TravelDao.getAllLocalTrips();
      final List<TripImageItem> items = [];

      for (var trip in trips) {
        // 1. Cover image
        items.add(TripImageItem(
          trip: trip,
          isCover: true,
        ));

        // 2. Day spot images
        for (int d = 0; d < trip.detail.length; d++) {
          final day = trip.detail[d];
          for (int p = 0; p < day.dayList.length; p++) {
            final point = day.dayList[p];
            items.add(TripImageItem(
              trip: trip,
              isCover: false,
              point: point,
              dayIndex: d,
              pointIndex: p,
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _trips = trips;
          _allImages = items;
          _isLoading = false;
        });
        _validateLinksInBackground();
      }
    } catch (e) {
      debugPrint('加载图片数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _validateLinksInBackground() async {
    if (_isValidatingLinks) return;
    setState(() {
      _isValidatingLinks = true;
    });

    final List<TripImageItem> toCheck = _allImages.where((item) {
      if (item.imageUrl.isEmpty) return false;
      if (item.imageUrl == 'https://s21.ax1x.com/2025/08/04/pVUP4XQ.jpg') return false;
      return item.imageUrl.startsWith('http');
    }).toList();

    if (toCheck.isEmpty) {
      setState(() {
        _isValidatingLinks = false;
      });
      return;
    }

    final dio = Dio(BaseOptions(
      connectTimeout: 4000,
      receiveTimeout: 4000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ));

    // Limit concurrency to 5 checks at a time
    const int concurrency = 5;
    for (int i = 0; i < toCheck.length; i += concurrency) {
      if (!mounted) break;
      final chunk = toCheck.sublist(i, i + concurrency > toCheck.length ? toCheck.length : i + concurrency);
      
      await Future.wait(chunk.map((item) async {
        try {
          // Perform a fast GET request, bytes format to avoid reading whole files
          await dio.get(
            item.imageUrl,
            options: Options(
              responseType: ResponseType.bytes,
              validateStatus: (status) => status != null && status < 400,
            ),
          );
        } catch (e) {
          debugPrint('Link validation failed for ${item.imageUrl}: $e');
          if (mounted) {
            setState(() {
              _failedImages.add(item.queryKey);
            });
          }
        }
      }));
    }

    if (mounted) {
      setState(() {
        _isValidatingLinks = false;
      });
    }
  }

  bool _isIssue(TripImageItem item) {
    if (item.imageUrl.isEmpty ||
        item.imageUrl.trim() == '' ||
        item.imageUrl == 'https://s21.ax1x.com/2025/08/04/pVUP4XQ.jpg') {
      return true;
    }
    if (_failedImages.contains(item.queryKey)) {
      return true;
    }
    return false;
  }

  List<TripImageItem> get _filteredImages {
    if (_activeTab == 0) {
      return _allImages;
    } else {
      return _allImages.where((item) => _isIssue(item)).toList();
    }
  }

  int get _issueCount {
    return _allImages.where((item) => _isIssue(item)).length;
  }

  Future<void> _repairImage(TripImageItem item) async {
    final key = item.queryKey;
    if (_repairingKeys.contains(key)) return;

    setState(() {
      _repairingKeys.add(key);
    });

    final String searchName = item.searchName;
    if (searchName.isEmpty) {
      setState(() {
        _repairingKeys.remove(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法修复：缺少位置/景点名称')),
      );
      return;
    }

    try {
      debugPrint('修复图片: $searchName');
      final newUrl = await TravelDao.handleImageFailure(
        uid: item.trip.uid,
        tripName: item.trip.tripName,
        nameOfScence: searchName,
        isCover: item.isCover,
      );

      if (newUrl.isNotEmpty) {
        // Update local object representation
        if (item.isCover) {
          item.trip.cover = newUrl;
        } else if (item.point != null) {
          item.point!.picURL = newUrl;
        }

        // Save back to DB
        await TravelDao.save(item.trip.toJson());

        // Sync globally in Provider
        final updatedTrips = await TravelDao.getAllLocalTrips();
        if (mounted) {
          Provider.of<UserData>(context, listen: false).setTrips(updatedTrips);
          _failedImages.remove(key);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${item.title}" 图片修复成功！')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未找到 "${item.title}" 的可用图片')),
          );
        }
      }
    } catch (e) {
      debugPrint('修复失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修复出错: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _repairingKeys.remove(key);
        });
        _loadData(showSpinner: false);
      }
    }
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return AlertDialog(
              title: const Text('一键自动修复图片'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _repairTotal > 0 ? _repairProgress / _repairTotal : 0.0,
                  ),
                  const SizedBox(height: 16),
                  Text('正在修复中: $_repairProgress / $_repairTotal'),
                  if (_repairSuccessCount > 0)
                    Text('已成功修复: $_repairSuccessCount 张图片',
                        style: const TextStyle(color: Colors.green)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRepairingInBackground = true;
                    });
                    _dialogSetState = null;
                    Navigator.of(context).pop();
                  },
                  child: const Text('后台运行'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isCancelled = true;
                    });
                    _dialogSetState = null;
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _dialogSetState = null;
    });
  }

  Future<void> _autoRepairAll() async {
    if (_isRepairing) {
      setState(() {
        _isRepairingInBackground = false;
      });
      _showProgressDialog();
      return;
    }

    final issues = _allImages.where((item) => _isIssue(item)).toList();
    if (issues.isEmpty) return;

    setState(() {
      _isRepairing = true;
      _isRepairingInBackground = false;
      _isCancelled = false;
      _repairProgress = 0;
      _repairTotal = issues.length;
      _repairSuccessCount = 0;
    });

    _showProgressDialog();

    for (var item in issues) {
      if (_isCancelled) break;
      final String searchName = item.searchName;
      if (searchName.isNotEmpty) {
        try {
          final newUrl = await TravelDao.handleImageFailure(
            uid: item.trip.uid,
            tripName: item.trip.tripName,
            nameOfScence: searchName,
            isCover: item.isCover,
          );

          if (newUrl.isNotEmpty) {
            if (item.isCover) {
              item.trip.cover = newUrl;
            } else if (item.point != null) {
              item.point!.picURL = newUrl;
            }
            await TravelDao.save(item.trip.toJson());
            _repairSuccessCount++;
            _failedImages.remove(item.queryKey);
          }
        } catch (e) {
          debugPrint('批量修复失败: $e');
        }
      }
      _repairProgress++;
      if (mounted) {
        setState(() {}); // Updates state of ImageDetectionPage (progress in button)
        if (!_isCancelled && !_isRepairingInBackground && _dialogSetState != null) {
          _dialogSetState!(() {}); // Updates state of dialog
        }
      }
    }

    if (mounted) {
      // Dismiss progress dialog if not already popped and not running in background
      if (!_isCancelled && !_isRepairingInBackground && _dialogSetState != null) {
        _dialogSetState = null;
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('一键修复完成，成功修复 $_repairSuccessCount / $_repairTotal 张图片')),
      );
    }

    // Sync globally
    final updatedTrips = await TravelDao.getAllLocalTrips();
    if (mounted) {
      Provider.of<UserData>(context, listen: false).setTrips(updatedTrips);
      _loadData(showSpinner: false);
    }

    setState(() {
      _isRepairing = false;
      _isRepairingInBackground = false;
      _isCancelled = false;
    });
  }

  void _showFullscreenImage(TripImageItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black.withOpacity(0.9),
            body: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Hero(
                      tag: item.queryKey,
                      child: _isIssue(item)
                          ? Image.asset('assets/trip_fallback.png', fit: BoxFit.contain)
                          : CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              httpHeaders: const {
                                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                              },
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                              errorWidget: (context, url, error) => Image.asset('assets/trip_fallback.png', fit: BoxFit.contain),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 20,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.black.withOpacity(0.6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabButton(String label, int index, {int badgeCount = 0}) {
    final bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.indigo : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.red : Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int issues = _issueCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
              ),
            )
          : CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Beautiful Header
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 20,
                      20,
                      24,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3F51B5), Color(0xFF7E57C2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x3D3F51B5),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Text(
                              '图片检测与诊断',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isValidatingLinks) ...[
                              const SizedBox(width: 12),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_isValidatingLinks) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 48),
                            child: Text(
                              '正在后台自动检测所有网络图片链接的有效性...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Stats Cards
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatCard('行程总数', '${_trips.length}', Icons.card_travel),
                            _buildStatCard('图片总数', '${_allImages.length}', Icons.image),
                            _buildStatCard(
                              '异常检测',
                              '$issues',
                              Icons.warning_amber_rounded,
                              isHighlight: issues > 0,
                            ),
                          ],
                        ),
                        if (issues > 0) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _autoRepairAll,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _isRepairing ? Colors.white.withOpacity(0.85) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isRepairing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome, color: Colors.indigo, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isRepairing
                                        ? '一键自动修复中 ($_repairProgress / $_repairTotal)'
                                        : '一键自动修复失效图片',
                                    style: const TextStyle(
                                      color: Colors.indigo,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Tabs selector
                        Row(
                          children: [
                            _buildTabButton("全部图片", 0),
                            const SizedBox(width: 12),
                            _buildTabButton("异常检测", 1, badgeCount: issues),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid View of Images
                _filteredImages.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _activeTab == 0
                                    ? Icons.image_not_supported_outlined
                                    : Icons.check_circle_outline,
                                size: 64,
                                color: _activeTab == 0 ? Colors.grey : Colors.green,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _activeTab == 0 ? '暂无任何行程图片' : '恭喜！未检测到任何异常图片',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _filteredImages[index];
                              final bool hasIssue = _isIssue(item);
                              final bool isRepairing =
                                  _repairingKeys.contains(item.queryKey);

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  color: Colors.white,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Image layer
                                      GestureDetector(
                                        onTap: () => _showFullscreenImage(item),
                                        child: Hero(
                                          tag: item.queryKey,
                                          child: hasIssue
                                              ? Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.broken_image_outlined,
                                                      color: Colors.grey,
                                                      size: 32,
                                                    ),
                                                  ),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: item.imageUrl,
                                                  httpHeaders: const {
                                                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                                  },
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) {
                                                    // Cache error state locally to highlight broken image
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback((_) {
                                                      if (mounted &&
                                                          !_failedImages
                                                              .contains(
                                                                  item.queryKey)) {
                                                        setState(() {
                                                          _failedImages
                                                              .add(item.queryKey);
                                                        });
                                                      }
                                                    });
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color: Colors.grey,
                                                          size: 32,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ),

                                      // Label bottom overlay (Glassmorphism effect)
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: ClipRRect(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX: 5, sigmaY: 5),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 6),
                                              color: Colors.black.withOpacity(0.55),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    item.title,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.trip.tripName,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.8),
                                                      fontSize: 8,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Diagnostic & repair actions overlay
                                      if (hasIssue)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap: isRepairing
                                                ? null
                                                : () => _repairImage(item),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: isRepairing
                                                    ? Colors.white
                                                    : Colors.indigo,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.15),
                                                    blurRadius: 4,
                                                  )
                                                ],
                                              ),
                                              child: isRepairing
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                          Colors.indigo,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.build_circle,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _filteredImages.length,
                          ),
                        ),
                      ),
              ],
            ),
      floatingActionButton: _showBackToTop && _activeTab == 0
          ? FloatingActionButton(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              backgroundColor: const Color(0xFF3F51B5),
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight
              ? Colors.red[400]!.withOpacity(0.9)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlight
                ? Colors.red[300]!
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
