import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/ingredient.dart';
import '../../../services/auth_service.dart';
import '../../../services/ingredient_service.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../../../widgets/ingredient_form.dart';
import '../../../utils/error_message.dart';

/// 식재료 추가/수정/삭제를 하나의 다이얼로그로 처리.
/// [ingredient]가 null이면 추가 모드, 값이 있으면 수정 모드.
/// 작업 완료 후 [onSaved]를 호출해 부모가 목록을 갱신하도록 위임.
class IngredientActionDialog extends StatefulWidget {
  final Ingredient? ingredient;
  final VoidCallback onSaved;

  const IngredientActionDialog({
    super.key,
    this.ingredient,
    required this.onSaved,
  });

  bool get isEditMode => ingredient != null;

  @override
  State<IngredientActionDialog> createState() => _IngredientActionDialogState();
}

class _IngredientActionDialogState extends State<IngredientActionDialog> {
  final _formKey = GlobalKey<IngredientFormState>();
  bool _isLoading = false;

  Future<void> _submit() async {
    final form = _formKey.currentState!;
    if (form.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재료명을 입력해주세요')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final expiryStr = form.expiryDate != null
        ? DateFormat('yyyy-MM-dd').format(form.expiryDate!)
        : null;
    try {
      if (widget.isEditMode) {
        await IngredientApiService.updateIngredient(
          widget.ingredient!.userIngredientId,
          {
            'ingredientName': form.name,
            'quantity': form.quantity.isEmpty ? null : form.quantity,
            'expiryDate': expiryStr,
          },
        );
      } else {
        final userId = context.read<AuthService>().userId;
        if (userId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('로그인이 필요합니다')),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
        final added = await IngredientApiService.addIngredient(userId, {
          'ingredientName': form.name,
          'quantity': form.quantity.isEmpty ? null : form.quantity,
          'expiryDate': expiryStr,
          'addedMethod': 'MANUAL',
        });
        if (expiryStr != null) {
          try {
            if (mounted) {
              await NotificationService.requestPermissionWithRationale(context);
            }
            await NotificationService.scheduleExpiryAlert(
              id: added.userIngredientId,
              ingredientName: added.ingredientName,
              expiryDateStr: expiryStr,
            );
          } catch (_) {}
        }
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e,
                fallback: widget.isEditMode
                    ? '수정하지 못했어요. 잠시 후 다시 시도해 주세요.'
                    : '식재료를 추가하지 못했어요. 잠시 후 다시 시도해 주세요.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    final ingredient = widget.ingredient!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${ingredient.ingredientName}을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await IngredientApiService.deleteIngredient(
            ingredient.userIngredientId);
        if (mounted) {
          Navigator.pop(context);
          widget.onSaved();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyErrorMessage(e,
                  fallback: '삭제하지 못했어요. 잠시 후 다시 시도해 주세요.')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditMode ? '식재료 수정' : '식재료 추가'),
      content: IngredientForm(
        key: _formKey,
        initialName: widget.ingredient?.ingredientName ?? '',
        initialQuantity: widget.ingredient?.quantity ?? '',
        initialExpiryDate: widget.ingredient?.expiryDate != null
            ? DateTime.tryParse(widget.ingredient!.expiryDate!)
            : null,
        firstDate: widget.isEditMode ? DateTime(2020) : null,
      ),
      actions: [
        if (widget.isEditMode) ...[
          TextButton(
            onPressed: _isLoading ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
          const Spacer(),
        ],
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const AppLoadingIndicator(size: 16)
              : Text(widget.isEditMode ? '저장' : '추가'),
        ),
      ],
    );
  }
}
