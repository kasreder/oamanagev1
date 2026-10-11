import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../constants.dart';
import '../main.dart';
import '../notifiers/auth_notifier.dart';

/// 비밀번호 변경 (/change-password)
/// - 관리자가 비번을 설정한 계정은 로그인 직후 라우터가 이 페이지로 강제 이동
/// - 자발적 변경도 같은 페이지 사용
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _State();
}

class _State extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      // 비번 자체는 GoTrue가 처리 (해시/정책), 플래그만 RPC로 해제
      await supabase.auth.updateUser(UserAttributes(password: _pwCtrl.text));
      await supabase.rpc('clear_must_change_password');
      await ref.read(authNotifierProvider.notifier).refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('변경 실패: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forced = ref.watch(authNotifierProvider).valueOrNull?.user
            ?.mustChangePassword ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 변경'),
        automaticallyImplyLeading: !forced,
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (forced)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '관리자가 설정한 임시 비밀번호로 로그인했습니다.\n계속하려면 새 비밀번호를 설정하세요.',
                        style: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer),
                      ),
                    ),
                  TextFormField(
                    controller: _pwCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: '새 비밀번호',
                      helperText: passwordPolicyText,
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => validatePassword(v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pw2Ctrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: '새 비밀번호 확인',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v != _pwCtrl.text ? '비밀번호가 일치하지 않습니다.' : null,
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset),
                    label: const Text('변경'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
