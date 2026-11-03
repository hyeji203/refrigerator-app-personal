import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_loading_indicator.dart';

const _green = Color(0xFF4CAF50);
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// 아이디 찾기 / 비밀번호 찾기 (가입 이메일 인증코드)
/// 성공하면 아이디를 반환해 로그인 화면에 채워 준다.
class FindAccountScreen extends StatelessWidget {
  final int initialTab;

  const FindAccountScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('계정 찾기'),
          bottom: const TabBar(
            labelColor: _green,
            indicatorColor: _green,
            tabs: [Tab(text: '아이디 찾기'), Tab(text: '비밀번호 찾기')],
          ),
        ),
        body: const TabBarView(
          children: [_FindIdTab(), _ResetPasswordTab()],
        ),
      ),
    );
  }
}

/// 인증코드 재전송 대기시간(60초)을 세는 도우미
mixin _ResendTimer<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  int resendLeft = 0;

  void startResendTimer() {
    _timer?.cancel();
    setState(() => resendLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => resendLeft--);
      if (resendLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

InputDecoration _decoration(String label, IconData icon,
        {String? error, String? helper, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
      errorText: error,
      errorMaxLines: 2,
      helperText: helper,
      helperMaxLines: 2,
      suffixIcon: suffix,
    );

Widget _primaryButton(String text,
    {required bool loading, required VoidCallback? onPressed}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: loading
          ? const AppLoadingIndicator()
          : Text(text,
              style: const TextStyle(fontSize: 16, color: Colors.white)),
    ),
  );
}

/// 코드 입력칸 + 재전송 버튼
Widget _codeField({
  required TextEditingController controller,
  required String email,
  required int resendLeft,
  required bool loading,
  required VoidCallback onResend,
  required VoidCallback onSubmit,
  String? error,
}) {
  return TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    maxLength: 6,
    autofocus: true,
    onSubmitted: (_) => onSubmit(),
    decoration: _decoration(
      '인증코드 6자리',
      Icons.mark_email_read_outlined,
      error: error,
      helper: '$email 으로 보낸 코드를 입력해 주세요. (5분간 유효)',
      suffix: TextButton(
        onPressed: resendLeft > 0 || loading ? null : onResend,
        child: Text(resendLeft > 0 ? '재전송 ${resendLeft}s' : '재전송'),
      ),
    ),
  );
}

// ──────────────────── 아이디 찾기 ────────────────────

class _FindIdTab extends StatefulWidget {
  const _FindIdTab();

  @override
  State<_FindIdTab> createState() => _FindIdTabState();
}

class _FindIdTabState extends State<_FindIdTab> with _ResendTimer {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _foundLoginId;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendCode() {
    final email = _emailCtrl.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = '이메일 형식이 올바르지 않아요. (예: name@example.com)');
      return;
    }
    _run(() async {
      await context.read<AuthService>().sendFindIdCode(email);
      _codeCtrl.clear();
      setState(() => _codeSent = true);
      startResendTimer();
    });
  }

  void _verify() {
    if (_codeCtrl.text.trim().length != 6) {
      setState(() => _error = '인증코드 6자리를 입력해 주세요.');
      return;
    }
    _run(() async {
      final loginId = await context
          .read<AuthService>()
          .findLoginId(_emailCtrl.text.trim(), _codeCtrl.text.trim());
      setState(() => _foundLoginId = loginId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_foundLoginId != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: _green, size: 64),
            const SizedBox(height: 16),
            const Text('가입하신 아이디예요', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            SelectableText(_foundLoginId!,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            _primaryButton('이 아이디로 로그인',
                loading: false,
                onPressed: () => Navigator.pop(context, _foundLoginId)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => DefaultTabController.of(context).animateTo(1),
              child: const Text('비밀번호도 잊으셨나요? 비밀번호 찾기'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('가입할 때 입력한 이메일로 인증코드를 보내드려요.',
            style: TextStyle(fontSize: 15)),
        const SizedBox(height: 20),
        TextField(
          controller: _emailCtrl,
          enabled: !_codeSent,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _sendCode(),
          decoration: _decoration('이메일', Icons.email_outlined,
              error: _codeSent ? null : _error),
        ),
        if (_codeSent) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _codeSent = false;
                _error = null;
              }),
              child: const Text('이메일 다시 입력'),
            ),
          ),
          _codeField(
            controller: _codeCtrl,
            email: _emailCtrl.text.trim(),
            resendLeft: resendLeft,
            loading: _loading,
            onResend: _sendCode,
            onSubmit: _verify,
            error: _error,
          ),
        ],
        const SizedBox(height: 24),
        _codeSent
            ? _primaryButton('확인', loading: _loading, onPressed: _verify)
            : _primaryButton('인증코드 받기', loading: _loading, onPressed: _sendCode),
      ],
    );
  }
}

// ──────────────────── 비밀번호 찾기 ────────────────────

enum _ResetStep { info, code, newPassword }

class _ResetPasswordTab extends StatefulWidget {
  const _ResetPasswordTab();

  @override
  State<_ResetPasswordTab> createState() => _ResetPasswordTabState();
}

class _ResetPasswordTabState extends State<_ResetPasswordTab>
    with _ResendTimer {
  final _loginIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  _ResetStep _step = _ResetStep.info;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  String get _loginId => _loginIdCtrl.text.trim();
  String get _email => _emailCtrl.text.trim();

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendCode() {
    if (_loginId.isEmpty) {
      setState(() => _error = '아이디를 입력해 주세요.');
      return;
    }
    if (!_emailPattern.hasMatch(_email)) {
      setState(() => _error = '이메일 형식이 올바르지 않아요. (예: name@example.com)');
      return;
    }
    _run(() async {
      await context.read<AuthService>().sendResetCode(_loginId, _email);
      _codeCtrl.clear();
      setState(() => _step = _ResetStep.code);
      startResendTimer();
    });
  }

  void _verify() {
    if (_codeCtrl.text.trim().length != 6) {
      setState(() => _error = '인증코드 6자리를 입력해 주세요.');
      return;
    }
    _run(() async {
      await context
          .read<AuthService>()
          .verifyResetCode(_loginId, _email, _codeCtrl.text.trim());
      setState(() => _step = _ResetStep.newPassword);
    });
  }

  void _reset() {
    final pw = _pwCtrl.text.trim();
    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 해요. (${pw.length}/6)');
      return;
    }
    if (pw != _pwConfirmCtrl.text.trim()) {
      setState(() => _error = '비밀번호가 일치하지 않아요.');
      return;
    }
    _run(() async {
      await context
          .read<AuthService>()
          .resetPassword(_loginId, _email, _codeCtrl.text.trim(), pw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 변경했어요. 새 비밀번호로 로그인해 주세요.')),
      );
      Navigator.pop(context, _loginId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    switch (_step) {
      case _ResetStep.info:
        children.addAll([
          const Text('아이디와 가입 이메일을 입력하면 인증코드를 보내드려요.',
              style: TextStyle(fontSize: 15)),
          const SizedBox(height: 20),
          TextField(
            controller: _loginIdCtrl,
            textInputAction: TextInputAction.next,
            decoration: _decoration('아이디', Icons.person_outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _sendCode(),
            decoration:
                _decoration('이메일', Icons.email_outlined, error: _error),
          ),
          const SizedBox(height: 24),
          _primaryButton('인증코드 받기', loading: _loading, onPressed: _sendCode),
        ]);
      case _ResetStep.code:
        children.addAll([
          Text('아이디: $_loginId', style: const TextStyle(fontSize: 15)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _step = _ResetStep.info;
                _error = null;
              }),
              child: const Text('아이디/이메일 다시 입력'),
            ),
          ),
          _codeField(
            controller: _codeCtrl,
            email: _email,
            resendLeft: resendLeft,
            loading: _loading,
            onResend: _sendCode,
            onSubmit: _verify,
            error: _error,
          ),
          const SizedBox(height: 24),
          _primaryButton('확인', loading: _loading, onPressed: _verify),
        ]);
      case _ResetStep.newPassword:
        final eye = IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        );
        children.addAll([
          const Text('새로 사용할 비밀번호를 입력해 주세요.',
              style: TextStyle(fontSize: 15)),
          const SizedBox(height: 20),
          TextField(
            controller: _pwCtrl,
            obscureText: _obscure,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: _decoration('새 비밀번호 (6자 이상)', Icons.lock_outline,
                suffix: eye),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwConfirmCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _reset(),
            decoration: _decoration('새 비밀번호 확인', Icons.lock_outline,
                error: _error),
          ),
          const SizedBox(height: 24),
          _primaryButton('비밀번호 변경', loading: _loading, onPressed: _reset),
        ]);
    }
    return ListView(padding: const EdgeInsets.all(24), children: children);
  }
}
