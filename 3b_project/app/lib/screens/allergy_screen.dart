import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/allergy.dart';
import '../utils/error_message.dart';

class AllergyScreen extends StatefulWidget {
  const AllergyScreen({super.key});

  @override
  State<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen> {
  // 선택 순서를 유지하기 위해 List 사용
  late List<String> _selected;
  // Autocomplete 입력창 컨트롤러 (fieldViewBuilder에서 받아 둠)
  TextEditingController? _fieldController;
  bool _isSaving = false;

  static const _green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    // 예전 자유 텍스트 입력값도 대표 항목으로 정규화 (예: 달걀 → 계란)
    _selected = parseAllergies(auth.allergies)
        .map(normalizeAllergen)
        .toSet()
        .toList();
  }

  List<String> get _customItems =>
      _selected.where((a) => !allergenKeywords.containsKey(a)).toList();

  void _toggle(String allergen) {
    setState(() {
      if (_selected.contains(allergen)) {
        _selected.remove(allergen);
      } else {
        _selected.add(allergen);
      }
    });
  }

  void _addCustom(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return;
    final normalized = normalizeAllergen(name);
    setState(() {
      if (!_selected.contains(normalized)) _selected.add(normalized);
    });
    _fieldController?.clear();
    if (normalized != name) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$name'은(는) '$normalized' 항목으로 추가했어요.")),
      );
    }
  }

  void _saveAllergies() async {
    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthService>();
      await auth.saveAllergies(joinAllergies(_selected));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selected.isEmpty
              ? '알레르기 정보를 비웠어요.'
              : '저장했어요. 이제 레시피 추천에서 ${_selected.join(', ')}을(를) 제외해요.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyErrorMessage(e,
                fallback: '알레르기 정보를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알레르기 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 설정이 어디에 쓰이는지 안내
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: _green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '선택한 재료는 AI 레시피 추천에서 제외되고, 레시피에 들어 있으면 ⚠ 표시로 알려드려요.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '알레르기 재료 선택',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '해당하는 항목을 모두 눌러 주세요',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allergenKeywords.keys.map((allergen) {
              final selected = _selected.contains(allergen);
              return FilterChip(
                label: Text(allergen),
                selected: selected,
                onSelected: (_) => _toggle(allergen),
                selectedColor: Colors.red[100],
                checkmarkColor: Colors.red[700],
                side: BorderSide(
                    color: selected ? Colors.red.shade300 : Colors.grey.shade300),
                labelStyle: TextStyle(
                  color: selected ? Colors.red[800] : null,
                  fontWeight: selected ? FontWeight.bold : null,
                ),
                tooltip: allergenKeywords[allergen]!.join(', '),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            '목록에 없는 재료',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Autocomplete<String>(
            optionsBuilder: (value) {
              final q = value.text.trim();
              if (q.isEmpty) return const Iterable<String>.empty();
              // 대표 항목 + 세부 키워드 중에서 자동완성
              final candidates = <String>{
                ...allergenKeywords.keys,
                ...allergenKeywords.values.expand((v) => v),
              };
              return candidates
                  .where((c) => c.contains(q) && !_selected.contains(c));
            },
            onSelected: (value) {
              _addCustom(value);
              FocusScope.of(context).unfocus();
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              _fieldController = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '예: 키위, 새우젓',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle, color: _green),
                    tooltip: '추가',
                    onPressed: () => _addCustom(controller.text),
                  ),
                ),
                onSubmitted: _addCustom,
              );
            },
          ),
          if (_customItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _customItems
                  .map((a) => InputChip(
                        label: Text(a),
                        selected: true,
                        showCheckmark: false,
                        selectedColor: Colors.red[100],
                        labelStyle: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.bold),
                        onDeleted: () => _toggle(a),
                        deleteButtonTooltipMessage: '삭제',
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          // 선택 요약
          Text(
            _selected.isEmpty
                ? '선택한 알레르기 재료가 없어요'
                : '선택됨 (${_selected.length}): ${_selected.join(', ')}',
            style: TextStyle(
              fontSize: 13,
              color: _selected.isEmpty ? Colors.grey : Colors.red[800],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
              ),
              onPressed: _isSaving ? null : _saveAllergies,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
