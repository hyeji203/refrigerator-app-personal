import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/ingredient.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/ingredient_form.dart';
import 'widgets/analyzing_step.dart';
import 'widgets/done_step.dart';
import 'widgets/preview_step.dart';
import 'widgets/review_step.dart';
import 'widgets/select_step.dart';
import 'widgets/step_indicator.dart';
import '../../utils/error_message.dart';

enum ScanStep { select, preview, analyzing, review, done }

class ScanScreen extends StatefulWidget {
  /// 분석 시작/종료 시 호출 (하단 탭에 진행 표시용)
  final ValueChanged<bool>? onAnalyzingChanged;

  /// 분석이 성공적으로 끝났을 때 호출 (다른 탭에 있을 때 알림용)
  final VoidCallback? onAnalyzeCompleted;

  const ScanScreen(
      {super.key, this.onAnalyzingChanged, this.onAnalyzeCompleted});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _imageBytes;
  ScanStep _step = ScanStep.select;
  List<ScanIngredientItem> _items = [];
  bool _isSaving = false;

  // 분석 진행 상태
  CancelToken? _cancelToken;
  double _uploadProgress = 0; // 0.0 ~ 1.0 (실제 업로드 진행률)
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _cancelToken?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ──────────────────── 이미지 선택 ────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _step = ScanStep.preview;
      _items = [];
    });
  }

  // ──────────────────── AI 분석 ────────────────────

  Future<void> _analyze() async {
    if (_imageBytes == null) return;
    final token = CancelToken();
    setState(() {
      _step = ScanStep.analyzing;
      _cancelToken = token;
      _uploadProgress = 0;
      _elapsedSeconds = 0;
    });
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    widget.onAnalyzingChanged?.call(true);

    try {
      final userId = context.read<AuthService>().userId;
      final names = await IngredientApiService.analyzeImage(
        _imageBytes!,
        userId: userId,
        cancelToken: token,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _items = names.map((n) => ScanIngredientItem(name: n)).toList();
        _step = ScanStep.review;
      });
      if (_items.isEmpty) {
        _showInfo('식재료를 인식하지 못했습니다. 사진을 다시 찍어보세요.');
        setState(() => _step = ScanStep.preview);
      } else {
        widget.onAnalyzeCompleted?.call();
      }
    } catch (e) {
      if (!mounted) return;
      // 사용자가 직접 취소한 경우는 오류로 표시하지 않음
      if (e is DioException && CancelToken.isCancel(e)) return;
      setState(() => _step = ScanStep.preview);
      _showError(
          friendlyErrorMessage(e, fallback: '사진을 분석하지 못했어요. 잠시 후 다시 시도해 주세요.'));
    } finally {
      _finishAnalyzing(token);
    }
  }

  void _cancelAnalyze() {
    _cancelToken?.cancel();
    setState(() => _step = ScanStep.preview);
    _showInfo('분석을 취소했어요. 다시 분석하거나 다른 사진을 선택해 주세요.');
  }

  void _finishAnalyzing(CancelToken token) {
    if (_cancelToken != token) return; // 이미 새 분석이 시작된 경우
    _elapsedTimer?.cancel();
    _cancelToken = null;
    widget.onAnalyzingChanged?.call(false);
  }

  // ──────────────────── 저장 ────────────────────

  Future<void> _saveAll() async {
    final confirmed = _items.where((i) => i.selected).toList();
    if (confirmed.isEmpty) {
      _showInfo('저장할 재료를 하나 이상 선택해주세요.');
      return;
    }
    final userId = context.read<AuthService>().userId;
    if (userId == null) return;
    setState(() => _isSaving = true);

    try {
      final payloads = confirmed.map((item) {
        return {
          'ingredientName': item.name,
          'quantity': item.quantity.isEmpty ? null : item.quantity,
          'expiryDate': item.expiryDate != null
              ? DateFormat('yyyy-MM-dd').format(item.expiryDate!)
              : null,
          'addedMethod': 'AI',
        };
      }).toList();

      final saved =
          await IngredientApiService.saveIngredientsBatch(userId, payloads);

      if (mounted && saved.any((ing) => ing.expiryDate != null)) {
        await NotificationService.requestPermissionWithRationale(context);
      }
      for (final ing in saved) {
        if (ing.expiryDate != null) {
          await NotificationService.scheduleExpiryAlert(
            id: ing.userIngredientId,
            ingredientName: ing.ingredientName,
            expiryDateStr: ing.expiryDate!,
          );
        }
      }
      setState(() {
        _step = ScanStep.done;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      _showError(
          friendlyErrorMessage(e, fallback: '재료를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.'));
    }
  }

  // ──────────────────── 재료 편집 다이얼로그 ────────────────────

  void _editItem(int index) {
    final item = _items[index];
    final formKey = GlobalKey<IngredientFormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('재료 정보 수정'),
        content: IngredientForm(
          key: formKey,
          initialName: item.name,
          initialQuantity: item.quantity,
          initialExpiryDate: item.expiryDate,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final form = formKey.currentState!;
              if (form.name.isEmpty) return;
              setState(() {
                _items[index] = ScanIngredientItem(
                  name: form.name,
                  quantity: form.quantity,
                  expiryDate: form.expiryDate,
                  selected: item.selected,
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _addManual() {
    setState(() {
      _items.add(ScanIngredientItem(name: ''));
      _editItem(_items.length - 1);
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _step = ScanStep.select;
      _items = [];
    });
  }

  // 검토 중인 재료가 있으면 확인 후 초기화
  Future<void> _confirmReset() async {
    if (_step == ScanStep.review && _items.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('다시 촬영할까요?'),
          content: Text('인식한 재료 ${_items.length}개는 저장되지 않고 사라져요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('계속 확인하기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('다시 촬영'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _reset();
  }

  // 단계 인디케이터용 인덱스 (select·preview는 같은 '사진 선택' 단계)
  int get _stepIndex {
    switch (_step) {
      case ScanStep.select:
      case ScanStep.preview:
        return 0;
      case ScanStep.analyzing:
        return 1;
      case ScanStep.review:
        return 2;
      case ScanStep.done:
        return 3;
    }
  }

  // ──────────────────── UI ────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('냉장고 스캔'),
        centerTitle: true,
        actions: [
          // 완료 단계는 본문의 '다시 스캔하기' 버튼 사용
          if (_step == ScanStep.preview || _step == ScanStep.review)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _confirmReset,
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('다시 촬영',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
        bottom: ScanStepIndicator(currentIndex: _stepIndex),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case ScanStep.select:
        return SelectStep(
          onPickCamera: () => _pickImage(ImageSource.camera),
          onPickGallery: () => _pickImage(ImageSource.gallery),
        );
      case ScanStep.preview:
        return PreviewStep(
          imageBytes: _imageBytes!,
          onAnalyze: _analyze,
          onReset: _reset,
        );
      case ScanStep.analyzing:
        return AnalyzingStep(
          imageBytes: _imageBytes,
          pulseAnim: _pulseAnim,
          uploadProgress: _uploadProgress,
          elapsedSeconds: _elapsedSeconds,
          onCancel: _cancelAnalyze,
        );
      case ScanStep.review:
        return ReviewStep(
          items: _items,
          isSaving: _isSaving,
          onToggleAll: (v) => setState(() {
            for (final item in _items) {
              item.selected = v;
            }
          }),
          onToggleItem: (idx, v) => setState(() => _items[idx].selected = v),
          onEditItem: (idx) => _editItem(idx),
          onRemoveItem: (idx) => setState(() => _items.removeAt(idx)),
          onAddManual: _addManual,
          onSave: _saveAll,
        );
      case ScanStep.done:
        return DoneStep(
          savedCount:
              _items.where((i) => i.selected && i.name.isNotEmpty).length,
          onReset: _reset,
        );
    }
  }
}
