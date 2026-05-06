import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ingredient.dart';
import '../services/auth_service.dart';
import '../services/ingredient_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_loading_indicator.dart';

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
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity);
    DateTime? expiry = item.expiryDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('재료 정보 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '재료명',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(
                  labelText: '수량 (예: 2개, 500g)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  expiry == null
                      ? '유통기한 선택 (선택사항)'
                      : '유통기한: ${DateFormat('yyyy-MM-dd').format(expiry!)}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) {
                    setDialogState(() => expiry = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            if (expiry != null)
              TextButton(
                onPressed: () => setDialogState(() => expiry = null),
                child: const Text('유통기한 제거', style: TextStyle(color: Colors.grey)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _items[index] = ScanIngredientItem(
                    name: nameCtrl.text.trim(),
                    quantity: qtyCtrl.text.trim(),
                    expiryDate: expiry,
                    selected: item.selected,
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('확인'),
            ),
          ],
        ),
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
        return _buildSelectStep();
      case ScanStep.preview:
        return _buildPreviewStep();
      case ScanStep.analyzing:
        return _buildAnalyzingStep();
      case ScanStep.review:
        return _buildReviewStep();
      case ScanStep.done:
        return _buildDoneStep();
    }
  }

  // ── STEP 1: 사진 선택 ──
  Widget _buildSelectStep() {
    return Center(
      key: const ValueKey('select'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘 영역
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Icon(Icons.kitchen,
                  size: 80, color: Colors.green.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              '냉장고 사진을 촬영하면\nAI가 재료를 자동으로 인식합니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.6),
            ),
            const SizedBox(height: 40),
            // 카메라 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt, size: 24),
                label: const Text('카메라로 촬영하기',
                    style: TextStyle(fontSize: 16)),
                onPressed: () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 갤러리 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library, size: 24),
                label: const Text('갤러리에서 선택하기',
                    style: TextStyle(fontSize: 16)),
                onPressed: () => _pickImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: 이미지 미리보기 ──
  Widget _buildPreviewStep() {
    return Column(
      key: const ValueKey('preview'),
      children: [
        // 이미지 미리보기
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(_imageBytes!, fit: BoxFit.cover),
              // 어두운 오버레이
              Container(color: Colors.black26),
              // 촬영 가이드 라인
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '냉장고 내부가\n선명하게 보이나요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 하단 버튼
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI로 식재료 인식하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('다른 사진 선택'),
                onPressed: _reset,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 3: AI 분석 중 ──
  Widget _buildAnalyzingStep() {
    return Center(
      key: const ValueKey('analyzing'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이미지 썸네일
          if (_imageBytes != null)
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
              ),
            ),
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: Colors.green, strokeWidth: 3),
          const SizedBox(height: 24),
          const Text(
            'AI가 식재료를 분석하고 있어요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Gemini Vision이 냉장고 안을 확인 중...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ── STEP 4: 결과 검토 및 편집 ──
  Widget _buildReviewStep() {
    final selectedCount = _items.where((i) => i.selected && i.name.isNotEmpty).length;

    return Column(
      key: const ValueKey('review'),
      children: [
        // 헤더 배너
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          color: Colors.green.shade50,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI가 ${_items.length}가지 재료를 인식했어요!\n저장할 재료를 확인하고 편집하세요.',
                  style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 13,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),

        // 재료 목록
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              // 전체 선택 토글
              Row(
                children: [
                  Checkbox(
                    value: _items.every((i) => i.selected),
                    onChanged: (v) => setState(() {
                      for (final item in _items) {
                        item.selected = v ?? true;
                      }
                    }),
                    activeColor: Colors.green,
                  ),
                  const Text('전체 선택',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('$selectedCount개 선택됨',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
              const Divider(height: 8),

              // 개별 재료 카드
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                if (item.name.isEmpty) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Checkbox(
                      value: item.selected,
                      onChanged: (v) =>
                          setState(() => item.selected = v ?? false),
                      activeColor: Colors.green,
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: item.selected ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.quantity.isNotEmpty)
                          Text('수량: ${item.quantity}',
                              style: const TextStyle(fontSize: 12)),
                        if (item.expiryDate != null)
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                '유통기한: ${DateFormat('yyyy-MM-dd').format(item.expiryDate!)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.orange),
                              ),
                            ],
                          ),
                        if (item.quantity.isEmpty && item.expiryDate == null)
                          Text(
                            '탭하여 수량·유통기한 입력',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 편집
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: Colors.blue),
                          onPressed: () => _editItem(idx),
                          tooltip: '편집',
                        ),
                        // 삭제
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 20, color: Colors.red),
                          onPressed: () =>
                              setState(() => _items.removeAt(idx)),
                          tooltip: '삭제',
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // 재료 직접 추가 버튼
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                label: const Text('재료 직접 추가',
                    style: TextStyle(color: Colors.green)),
                onPressed: _addManual,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // 저장 버튼
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const AppLoadingIndicator()
                  : const Icon(Icons.save_alt),
              label: Text(
                _isSaving
                    ? '저장 중...'
                    : '$selectedCount개 재료를 냉장고에 저장하기',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _isSaving ? null : _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 5: 저장 완료 ──
  Widget _buildDoneStep() {
    final savedCount = _items.where((i) => i.selected && i.name.isNotEmpty).length;

    return Center(
      key: const ValueKey('done'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle,
                  size: 72, color: Colors.green.shade500),
            ),
            const SizedBox(height: 28),
            const Text(
              '저장 완료!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '$savedCount가지 재료가 냉장고에 추가되었어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '유통기한을 입력한 재료는\n알림이 자동으로 등록되었습니다.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('다시 스캔하기',
                    style: TextStyle(fontSize: 15)),
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
