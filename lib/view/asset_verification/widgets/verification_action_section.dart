import 'package:flutter/material.dart';

class VerificationActionSection extends StatefulWidget {
  const VerificationActionSection({super.key, required this.assetUids});

  final List<String> assetUids;

  @override
  State<VerificationActionSection> createState() => _VerificationActionSectionState();
}

class _VerificationActionSectionState extends State<VerificationActionSection> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('인증 기능이 준비 중입니다.'),
      ),
    );
  }

  void _clear() {
    _noteController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final assetCount = widget.assetUids.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '인증 처리',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('선택된 자산: $assetCount건'),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '비고',
                hintText: '인증 관련 메모를 입력하세요.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('인증 완료 처리'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.clear),
                  label: const Text('입력 초기화'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '※ 실제 인증 절차 연동 전까지는 알림 메시지만 표시됩니다.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
