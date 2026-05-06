import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ingredient.dart';
import '../widgets/ingredient_form.dart';
import '../services/auth_service.dart';
import '../services/ingredient_service.dart';
import '../services/notification_service.dart';
import 'scan/widgets/analyzing_step.dart';
import 'scan/widgets/done_step.dart';
import 'scan/widgets/preview_step.dart';
import 'scan/widgets/review_step.dart';
import 'scan/widgets/select_step.dart';

// 스캔 화면의 단계
enum ScanStep { select, preview, analyzing, review, done }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _imageBytes;
  ScanStep _step = ScanStep.select;
  List<ScanIngredientItem> _items = []; // 인식 결과 (편집 가능)
  bool _isSaving = false;
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
    setState(() => _step = ScanStep.analyzing);

    try {
      final names = await IngredientApiService.analyzeImage(_imageBytes!);

      setState(() {
        _items = names
            .map((n) => ScanIngredientItem(name: n))
            .toList();
        _step = ScanStep.review;
      });

      if (_items.isEmpty) {
        _showInfo('식재료를 인식하지 못했습니다. 사진을 다시 찍어보세요.');
        setState(() => _step = ScanStep.preview);
      }
    } catch (e) {
      setState(() => _step = ScanStep.preview);
      _showError('분석 중 오류가 발생했습니다: $e');
    }
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

      final saved = await IngredientApiService.saveIngredientsBatch(
          userId, payloads);

      // 유통기한 있는 재료 알림 등록
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
      _showError('저장 중 오류가 발생했습니다: $e');
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

  // 직접 재료 추가
  void _addManual() {
    setState(() {
      _items.add(ScanIngredientItem(name: ''));
      _editItem(_items.length - 1);
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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

  // ──────────────────── UI ────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('냉장고 스캔'),
        centerTitle: true,
        actions: [
          if (_step != ScanStep.select && _step != ScanStep.analyzing)
            TextButton(
              onPressed: _reset,
              child: const Text('다시 촬영', style: TextStyle(color: Colors.white)),
            ),
        ],
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
