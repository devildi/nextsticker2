import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MultiSelectWebPage extends StatefulWidget {
  final String? initialUrl;
  const MultiSelectWebPage({Key? key, this.initialUrl}) : super(key: key);

  @override
  State<MultiSelectWebPage> createState() => _MultiSelectWebPageState();
}

class _MultiSelectWebPageState extends State<MultiSelectWebPage> with SingleTickerProviderStateMixin {
  late final WebViewController _webViewController;
  late final TextEditingController _urlController;
  
  final List<String> _selectedTexts = [];
  String _currentDragSelection = '';
  bool _isLoading = true;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? 'https://imfw.cn/l/332667566');
    _initWebViewController();
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress / 100.0;
            });
          }
        },
        onPageStarted: (String url) {
          if (mounted) {
            setState(() {
              _isLoading = true;
              _loadingProgress = 0.0;
            });
          }
        },
        onPageFinished: (String url) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _injectSelectionScript();
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          final String url = request.url.toLowerCase();
          if (url.startsWith('http://') || url.startsWith('https://')) {
            return NavigationDecision.navigate;
          }
          debugPrint('Prevented navigation to custom scheme: ${request.url}');
          return NavigationDecision.prevent;
        },
      ))
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(_urlController.text.trim()));
  }

  void _injectSelectionScript() {
    const String jsScript = """
      (function() {
        if (window.nsSelectInjected) return;
        window.nsSelectInjected = true;

        window.nsSelectedElements = [];

        var style = document.createElement('style');
        style.id = 'ns-select-styles';
        style.innerHTML = `
          * {
            user-select: text !important;
            -webkit-user-select: text !important;
            -ms-user-select: text !important;
            -moz-user-select: text !important;
          }
          .ns-tap-selected {
            background-color: rgba(156, 39, 176, 0.22) !important;
            outline: 2px dashed #9c27b0 !important;
            outline-offset: 1px;
            border-radius: 4px;
            transition: all 0.15s ease;
            position: relative !important;
            display: inline;
          }
          .ns-tap-selected::after {
            content: attr(data-ns-index);
            position: absolute;
            top: -8px;
            right: -8px;
            background-color: #9c27b0;
            color: white;
            font-size: 10px;
            font-weight: bold;
            width: 16px;
            height: 16px;
            line-height: 16px;
            text-align: center;
            border-radius: 50%;
            box-shadow: 0 2px 4px rgba(0,0,0,0.35);
            z-index: 99999;
            pointer-events: none;
          }
        `;
        document.head.appendChild(style);

        window.nsUpdateIndexes = function() {
          for (var i = 0; i < window.nsSelectedElements.length; i++) {
            window.nsSelectedElements[i].setAttribute('data-ns-index', (i + 1).toString());
          }
        };

        window.nsSelectElement = function(el) {
          if (window.nsSelectedElements.indexOf(el) === -1) {
            el.classList.add('ns-tap-selected');
            window.nsSelectedElements.push(el);
            window.nsUpdateIndexes();
            return true;
          }
          return false;
        };

        window.nsDeselectElement = function(el) {
          var idx = window.nsSelectedElements.indexOf(el);
          if (idx !== -1) {
            el.classList.remove('ns-tap-selected');
            el.removeAttribute('data-ns-index');
            window.nsSelectedElements.splice(idx, 1);
            window.nsUpdateIndexes();
            
            if (el.tagName.toLowerCase() === 'span' && el.classList.contains('ns-drag-highlight')) {
              var parent = el.parentNode;
              while (el.firstChild) {
                parent.insertBefore(el.firstChild, el);
              }
              parent.removeChild(el);
            }
            return true;
          }
          return false;
        };

        window.nsAddSelection = function() {
          var selection = window.getSelection();
          if (selection.rangeCount > 0) {
            var range = selection.getRangeAt(0);
            var text = selection.toString().trim();
            if (text.length > 0) {
              var span = document.createElement('span');
              span.className = 'ns-tap-selected ns-drag-highlight';
              try {
                range.surroundContents(span);
                window.nsSelectElement(span);
                selection.removeAllRanges();
                Toaster.postMessage(JSON.stringify({action: 'add', text: text}));
              } catch (e) {
                try {
                  var content = range.extractContents();
                  span.appendChild(content);
                  range.insertNode(span);
                  window.nsSelectElement(span);
                  selection.removeAllRanges();
                  Toaster.postMessage(JSON.stringify({action: 'add', text: text}));
                } catch (err) {
                  console.error("Failed to wrap selection:", err);
                  Toaster.postMessage(JSON.stringify({action: 'add', text: text}));
                }
              }
            }
          }
        };

        document.addEventListener('click', function(e) {
          var target = e.target;
          if (target.classList.contains('ns-tap-selected')) {
            var cleanText = (target.innerText || target.textContent).trim();
            window.nsDeselectElement(target);
            Toaster.postMessage(JSON.stringify({action: 'remove', text: cleanText}));
            e.preventDefault();
            e.stopPropagation();
          }
        }, true);

        document.addEventListener('selectionchange', function() {
          var selection = window.getSelection();
          var text = selection.toString().trim();
          Toaster.postMessage(JSON.stringify({action: 'selection', text: text}));
        });
      })();
    """;
    _webViewController.runJavaScript(jsScript);
  }



  void _clearAllWebViewHighlights() {
    _webViewController.runJavaScript("""
      (function() {
        if (window.nsSelectedElements) {
          while (window.nsSelectedElements.length > 0) {
            window.nsDeselectElement(window.nsSelectedElements[0]);
          }
        }
      })();
    """);
  }

  void _removeWebViewHighlight(String text) {
    final encodedText = jsonEncode(text);
    _webViewController.runJavaScript("""
      (function() {
        var textToRemove = $encodedText;
        if (window.nsSelectedElements) {
          for (var i = 0; i < window.nsSelectedElements.length; i++) {
            var el = window.nsSelectedElements[i];
            var text = el.innerText || el.textContent;
            if (text && text.trim() === textToRemove) {
              window.nsDeselectElement(el);
              break;
            }
          }
        }
      })();
    """);
  }

  void _handleJsMessage(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final String action = data['action'] ?? '';
      final String text = data['text'] ?? '';

      if (action == 'add') {
        if (text.isNotEmpty && !_selectedTexts.contains(text)) {
          setState(() {
            _selectedTexts.add(text);
          });
          _showToast('已添加景点');
        }
      } else if (action == 'remove') {
        setState(() {
          _selectedTexts.remove(text);
        });
        _showToast('已移除景点');
      } else if (action == 'selection') {
        setState(() {
          _currentDragSelection = text;
        });
      }
    } catch (e) {
      debugPrint('Error parsing JS message: $e');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.purple.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }



  void _copySingleToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      _showToast('景点已复制！');
    });
  }

  void _removeSnippet(int index) {
    final text = _selectedTexts[index];
    setState(() {
      _selectedTexts.removeAt(index);
    });
    _removeWebViewHighlight(text);
  }

  void _clearAllSnippets() {
    setState(() {
      _selectedTexts.clear();
      _currentDragSelection = '';
    });
    _clearAllWebViewHighlights();
    _webViewController.runJavaScript("window.getSelection().removeAllRanges();");
    _showToast('已清空全部选择');
  }

  void _addDragSelection() {
    if (_currentDragSelection.isNotEmpty) {
      if (!_selectedTexts.contains(_currentDragSelection)) {
        _webViewController.runJavaScript("window.nsAddSelection();");
        setState(() {
          _currentDragSelection = '';
        });
      } else {
        _showToast('景点已存在');
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网页选点', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
            tooltip: '重新加载',
          ),
          if (_selectedTexts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllSnippets,
              tooltip: '清空所有选中',
            ),
        ],
      ),
      body: Column(
        children: [
          
          // Progress Bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress > 0 ? _loadingProgress : null,
              backgroundColor: Colors.purple.shade100,
              color: Colors.purple.shade600,
              minHeight: 3,
            ),
            
          // WebView Area
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading && _loadingProgress == 0)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.purple),
                  ),
              ],
            ),
          ),

          // Selection Helper Pop-up
          if (_currentDragSelection.isNotEmpty)
            _buildDragSelectionBanner(),

          // Bottom Action / Selected Panel trigger
          if (_selectedTexts.isNotEmpty)
            _buildBottomActionBar(),
        ],
      ),
    );
  }



  Widget _buildDragSelectionBanner() {
    final preview = _currentDragSelection.length > 30
        ? '${_currentDragSelection.substring(0, 30)}...'
        : _currentDragSelection;
        
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.purple.shade100, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '已选择文本 (可拖动蓝色手势微调)',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: const TextStyle(fontSize: 13, color: Colors.black87, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addDragSelection,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showSelectedTextsModal,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.article, color: Colors.purple.shade800, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '已选景点 (${_selectedTexts.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              '点击查看/编辑已选列表',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_up, color: Colors.purple.shade400),
                    ],
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showSelectedTextsModal,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('下一步'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectedTextsModal() {
    showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Modal Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '已选景点',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_selectedTexts.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  _clearAllSnippets();
                                });
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('清空'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Snippet List
                  Expanded(
                    child: _selectedTexts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('暂无已选景点', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _selectedTexts.length,
                            itemBuilder: (context, index) {
                              final text = _selectedTexts[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '景点 #${index + 1}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.purple.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.copy, size: 16),
                                                onPressed: () => _copySingleToClipboard(text),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                                color: Colors.grey.shade600,
                                                tooltip: '复制该景点',
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 16),
                                                onPressed: () {
                                                  setModalState(() {
                                                    _removeSnippet(index);
                                                  });
                                                  // Force parent state update as well
                                                  setState(() {});
                                                  if (_selectedTexts.isEmpty) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(4),
                                                color: Colors.red.shade400,
                                                tooltip: '删除该景点',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        text,
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Bottom copy action inside modal
                  if (_selectedTexts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade100)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context, _selectedTexts);
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('下一步'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).then((result) {
      if (result != null && result.isNotEmpty && mounted) {
        Navigator.pop(context, result);
      }
    });
  }
}
