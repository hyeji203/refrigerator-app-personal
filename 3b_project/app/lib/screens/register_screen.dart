import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_loading_indicator.dart';

/// 중복 확인 상태
enum _DupStatus { idle, checking, available, taken, failed }

/// 아이디·이메일 실시간 중복 확인 (입력을 멈추고 0.5초 뒤 서버에 확인)
class _DupCheck {
  final Future<bool> Function(String value) request;
  _DupStatus status = _DupStatus.idle;
  String? checkedValue; // status가 가리키는 값
  Timer? _debounce;
  Future<void>? _pending;

  _DupCheck(this.request);

  void cancel() => _debounce?.cancel();

  void reset() {
    cancel();
    status = _DupStatus.idle;
    checkedValue = null;
  }

  /// 입력이 바뀔 때 호출 (0.5초 동안 추가 입력이 없으면 확인)
  void schedule(String value, {required VoidCallback onUpdate}) {
    reset();
    _debounce = Timer(const Duration(milliseconds: 500),
        () => run(value, onUpdate: onUpdate));
  }

  /// 즉시 확인 (가입 버튼을 눌렀는데 아직 확인 전인 경우)
  Future<void> run(String value, {required VoidCallback onUpdate}) {
    cancel();
    if (checkedValue == value && status != _DupStatus.idle) {
      return _pending ?? Future.value();
    }
    checkedValue = value;
    status = _DupStatus.checking;
    onUpdate();
    final future = request(value).then((available) {
      if (checkedValue != value) return; // 그 사이 입력이 바뀜
      status = available ? _DupStatus.available : _DupStatus.taken;
    }).catchError((_) {
      // 네트워크 오류 시 막지 않고, 가입할 때 서버에서 다시 확인
      if (checkedValue == value) status = _DupStatus.failed;
    }).whenComplete(onUpdate);
    _pending = future;
    return future;
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();
  final _loginIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final _loginIdCheck =
      _DupCheck(context.read<AuthService>().isLoginIdAvailable);
  late final _emailCheck =
      _DupCheck(context.read<AuthService>().isEmailAvailable);

  // 서버에서 돌려준 닉네임 중복 오류 (값을 고치면 지움)
  String? _usernameServerError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _loginIdCheck.cancel();
    _emailCheck.cancel();
    _loginIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ──────────────────── 필드별 검증 ────────────────────
  String? _validateLoginId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '아이디를 입력해 주세요.';
    if (v.length < 4) return '아이디는 4자 이상이어야 해요.';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
      return '영문, 숫자, 밑줄(_)만 사용할 수 있어요.';
    }
    if (_loginIdCheck.status == _DupStatus.taken &&
        _loginIdCheck.checkedValue == v) {
      return '이미 사용 중인 아이디예요.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '비밀번호를 입력해 주세요.';
    if (v.length < 6) return '비밀번호는 6자 이상이어야 해요. (${v.length}/6)';
    return null;
  }

  String? _validateConfirm(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '비밀번호를 한 번 더 입력해 주세요.';
    if (v != _passwordController.text.trim()) return '비밀번호가 일치하지 않아요.';
    return null;
  }

  String? _validateUsername(String? value) {
    if ((value?.trim() ?? '').isEmpty) return '이름을 입력해 주세요.';
    return _usernameServerError;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '이메일을 입력해 주세요.';
    if (!_emailPattern.hasMatch(v)) {
      return '이메일 형식이 올바르지 않아요. (예: name@example.com)';
    }
    if (_emailCheck.status == _DupStatus.taken &&
        _emailCheck.checkedValue == v) {
      return '이미 가입된 이메일이에요.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // 선택 항목
    if (!RegExp(r'^[0-9\-]{9,13}$').hasMatch(v)) {
      return '숫자와 하이픈(-)만 입력해 주세요. (예: 010-1234-5678)';
    }
    return null;
  }

  // ──────────────────── 중복 확인 ────────────────────
  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onLoginIdChanged(String value) {
    final v = value.trim();
    // 형식이 맞지 않으면 서버에 묻지 않음 (형식 오류가 먼저 표시됨)
    if (_validateLoginId(v) == null) {
      _loginIdCheck.schedule(v, onUpdate: _refresh);
    } else {
      _loginIdCheck.reset();
    }
    _refresh();
  }

  void _onEmailChanged(String value) {
    final v = value.trim();
    if (_validateEmail(v) == null) {
      _emailCheck.schedule(v, onUpdate: _refresh);
    } else {
      _emailCheck.reset();
    }
    _refresh();
  }

  bool _isAvailable(_DupCheck check, TextEditingController controller) =>
      check.status == _DupStatus.available &&
      check.checkedValue == controller.text.trim();

  // 아이디·이메일 칸 아래 안내 (확인 중 / 사용 가능 / 확인 실패)
  String? _dupHelper(
      _DupCheck check, TextEditingController controller, String availableText) {
    if (check.checkedValue != controller.text.trim()) return null;
    switch (check.status) {
      case _DupStatus.checking:
        return '중복 확인 중...';
      case _DupStatus.available:
        return availableText;
      case _DupStatus.failed:
        return '중복 확인을 하지 못했어요. 가입할 때 다시 확인할게요.';
      default:
        return null;
    }
  }

  Widget? _dupIcon(_DupCheck check, TextEditingController controller) {
    if (check.checkedValue != controller.text.trim()) return null;
    switch (check.status) {
      case _DupStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _DupStatus.available:
        return const Icon(Icons.check_circle, color: Color(0xFF4CAF50));
      default:
        return null;
    }
  }

  // 서버 오류 메시지를 해당 필드에 연결. 연결할 필드가 없으면 false
  bool _applyServerError(String message) {
    if (message.contains('아이디')) {
      _loginIdCheck
        ..checkedValue = _loginIdController.text.trim()
        ..status = _DupStatus.taken;
    } else if (message.contains('닉네임')) {
      _usernameServerError = message;
    } else if (message.contains('이메일')) {
      _emailCheck
        ..checkedValue = _emailController.text.trim()
        ..status = _DupStatus.taken;
    } else {
      return false;
    }
    _formKey.currentState!.validate();
    _refresh();
    return true;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 아직 중복 확인이 끝나지 않은 값은 먼저 확인
    await Future.wait([
      _loginIdCheck.run(_loginIdController.text.trim(), onUpdate: _refresh),
      _emailCheck.run(_emailController.text.trim(), onUpdate: _refresh),
    ]);
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final authService = context.read<AuthService>();
      await authService.register(
        _loginIdController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _emailController.text.trim(),
        _phoneController.text.trim(),
      );

      // 가입 응답에 토큰이 포함되어 세션이 저장되므로 바로 홈으로 이동
      if (!mounted) return;
      final userId = authService.userId;
      if (userId != null) {
        NotificationService.scheduleExpiryNotifications(userId);
      }
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_usernameController.text.trim()}님, 가입을 환영해요!')),
      );
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        if (!_applyServerError(message)) _showError(message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('회원가입'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add,
                        size: 48, color: Color(0xFF4CAF50)),
                    const SizedBox(height: 16),
                    const Text(
                      '새 계정 만들기',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // 아이디 (로그인용)
                    TextFormField(
                      // 직접 입력한 필드만 실시간 검증 (다른 필드는 가입 버튼을 누를 때 검증)
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _loginIdController,
                      textInputAction: TextInputAction.next,
                      validator: _validateLoginId,
                      onChanged: _onLoginIdChanged,
                      decoration: InputDecoration(
                        labelText: '아이디 *',
                        helperText: _dupHelper(_loginIdCheck,
                                _loginIdController, '사용할 수 있는 아이디예요.') ??
                            '영문·숫자 4자 이상',
                        helperStyle:
                            _isAvailable(_loginIdCheck, _loginIdController)
                                ? const TextStyle(color: Color(0xFF2E7D32))
                                : null,
                        prefixIcon: const Icon(Icons.person),
                        suffixIcon: _dupIcon(_loginIdCheck, _loginIdController),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      validator: _validatePassword,
                      onChanged: (_) {
                        // 비밀번호를 바꾸면 확인란 일치 여부도 다시 검사
                        if (_passwordConfirmController.text.isNotEmpty) {
                          _confirmFieldKey.currentState?.validate();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: '비밀번호 *',
                        helperText: '6자 이상',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 확인
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      key: _confirmFieldKey,
                      controller: _passwordConfirmController,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.next,
                      validator: _validateConfirm,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인 *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        // 일치하면 체크 아이콘으로 바로 알려줌
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_passwordConfirmController.text.isNotEmpty &&
                                _passwordConfirmController.text.trim() ==
                                    _passwordController.text.trim())
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF4CAF50)),
                            IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 이름 (표시용)
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      validator: _validateUsername,
                      onChanged: (_) => _usernameServerError = null,
                      decoration: const InputDecoration(
                        labelText: '이름 *',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 이메일
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                      onChanged: _onEmailChanged,
                      decoration: InputDecoration(
                        labelText: '이메일 *',
                        helperText: _dupHelper(
                            _emailCheck, _emailController, '사용할 수 있는 이메일이에요.'),
                        helperStyle: _isAvailable(_emailCheck, _emailController)
                            ? const TextStyle(color: Color(0xFF2E7D32))
                            : null,
                        prefixIcon: const Icon(Icons.email),
                        suffixIcon: _dupIcon(_emailCheck, _emailController),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 전화번호
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: _validatePhone,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _register();
                      },
                      decoration: const InputDecoration(
                        labelText: '전화번호 (선택)',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 가입 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const AppLoadingIndicator()
                            : const Text(
                                '회원가입',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
