import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class IngredientForm extends StatefulWidget {
  final String initialName;
  final String initialQuantity;
  final DateTime? initialExpiryDate;
  final DateTime? firstDate;

  const IngredientForm({
    super.key,
    this.initialName = '',
    this.initialQuantity = '',
    this.initialExpiryDate,
    this.firstDate,
  });

  @override
  State<IngredientForm> createState() => IngredientFormState();
}

class IngredientFormState extends State<IngredientForm> {
  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  DateTime? expiryDate;

  String get name => nameController.text.trim();
  String get quantity => quantityController.text.trim();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    quantityController = TextEditingController(text: widget.initialQuantity);
    expiryDate = widget.initialExpiryDate;
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.firstDate ?? DateTime.now();
    final last = DateTime.now().add(const Duration(days: 365 * 3));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '재료명 *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: '수량 (예: 2개, 500g)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(
            expiryDate == null
                ? '유통기한 선택'
                : DateFormat('yyyy-MM-dd').format(expiryDate!),
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: expiryDate != null && expiryDate!.isAfter(first)
                  ? expiryDate!
                  : (DateTime.now().isAfter(first) ? DateTime.now() : first),
              firstDate: first,
              lastDate: last,
            );
            if (picked != null) setState(() => expiryDate = picked);
          },
        ),
        if (expiryDate != null)
          TextButton.icon(
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('유통기한 삭제'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => setState(() => expiryDate = null),
          ),
      ],
    );
  }
}
