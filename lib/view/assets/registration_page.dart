// lib/view/assets/registration_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class AssetRegistrationPage extends StatefulWidget {
  const AssetRegistrationPage({super.key, this.initialUid});

  final String? initialUid;

  @override
  State<AssetRegistrationPage> createState() => _AssetRegistrationPageState();
}

class _AssetRegistrationPageState extends State<AssetRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _assetTypeController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();
  final List<_MetadataField> _metadataFields = [];
  String _selectedStatus = '사용';
  final List<String> _statusOptions = const ['사용', '수리중', '폐기', '분실', '기타'];

  @override
  void initState() {
    super.initState();
    final initialUid = widget.initialUid;
    if (initialUid != null && initialUid.isNotEmpty) {
      _uidController.text = initialUid;
    }
  }

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _vendorController.dispose();
    _locationController.dispose();
    _assetTypeController.dispose();
    _organizationController.dispose();
    for (final field in _metadataFields) {
      field.dispose();
    }
    super.dispose();
  }

  void _addMetadataField() {
    setState(() {
      _metadataFields.add(_MetadataField());
    });
  }

  void _removeMetadataField(int index) {
    setState(() {
      _metadataFields.removeAt(index).dispose();
    });
  }

  Map<String, String> _collectMetadata() {
    final metadata = <String, String>{};
    for (final field in _metadataFields) {
      final key = field.keyController.text.trim();
      final value = field.valueController.text.trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      metadata[key] = value;
    }
    return metadata;
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _uidController.clear();
    _nameController.clear();
    _modelController.clear();
    _serialController.clear();
    _vendorController.clear();
    _locationController.clear();
    _assetTypeController.clear();
    _organizationController.clear();
    setState(() {
      _selectedStatus = _statusOptions.first;
      for (final field in _metadataFields) {
        field.dispose();
      }
      _metadataFields.clear();
    });
  }

  Future<void> _submit(InspectionProvider provider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final uid = _uidController.text.trim();
    final exists = provider.assetExists(uid);

    Future<void> save() async {
      provider.upsertAssetInfo(
        AssetInfo(
          uid: uid,
          name: _nameController.text.trim(),
          model: _modelController.text.trim(),
          serial: _serialController.text.trim(),
          vendor: _vendorController.text.trim(),
          location: _locationController.text.trim(),
          status: _selectedStatus,
          assets_types: _assetTypeController.text.trim(),
          organization: _organizationController.text.trim(),
          metadata: _collectMetadata(),
        ),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exists ? '자산 정보가 업데이트되었습니다.' : '자산이 등록되었습니다.'),
        ),
      );
    }

    if (exists) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('기존 자산 덮어쓰기'),
              content: const Text('동일한 UID의 자산이 존재합니다. 새로운 정보로 덮어쓸까요?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('덮어쓰기'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) {
        return;
      }
    }

    await save();
  }

  Widget _buildPreview(InspectionProvider provider) {
    final uid = _uidController.text.trim();
    final existing = uid.isEmpty ? null : provider.assetOf(uid);
    if (uid.isEmpty && existing == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final metadata = _collectMetadata();
    final previewItems = <_PreviewRow>[
      _PreviewRow('자산 UID', uid.isEmpty ? '-' : uid),
      _PreviewRow('사용자', _nameController.text.trim().isEmpty ? '-' : _nameController.text.trim()),
      _PreviewRow('모델명', _modelController.text.trim().isEmpty ? '-' : _modelController.text.trim()),
      _PreviewRow('시리얼', _serialController.text.trim().isEmpty ? '-' : _serialController.text.trim()),
      _PreviewRow('벤더', _vendorController.text.trim().isEmpty ? '-' : _vendorController.text.trim()),
      _PreviewRow('위치', _locationController.text.trim().isEmpty ? '-' : _locationController.text.trim()),
      _PreviewRow('상태', _selectedStatus.isEmpty ? '-' : _selectedStatus),
      _PreviewRow('장비 종류', _assetTypeController.text.trim().isEmpty ? '-' : _assetTypeController.text.trim()),
      _PreviewRow('소속', _organizationController.text.trim().isEmpty ? '-' : _organizationController.text.trim()),
    ];

    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('등록 미리보기', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final row in previewItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (metadata.isNotEmpty) ...[
              const Divider(),
              Text('추가 메타데이터', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final entry in metadata.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(entry.key, style: theme.textTheme.bodyMedium),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                ),
            ],
            if (existing != null) ...[
              const Divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '동일한 UID의 자산이 이미 존재합니다. 저장 시 기존 정보가 새 값으로 덮어써집니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    if (_metadataFields.isEmpty) {
      return OutlinedButton.icon(
        onPressed: _addMetadataField,
        icon: const Icon(Icons.add),
        label: const Text('메타데이터 추가'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _metadataFields.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _metadataFields[i].keyController,
                    decoration: const InputDecoration(
                      labelText: '키',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _metadataFields[i].valueController,
                    decoration: const InputDecoration(
                      labelText: '값',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeMetadataField(i),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '행 삭제',
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addMetadataField,
          icon: const Icon(Icons.add),
          label: const Text('행 추가'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? helperText,
    bool requiredField = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (!requiredField) {
          return null;
        }
        if (value == null || value.trim().isEmpty) {
          return '$label을 입력해주세요.';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        return AppScaffold(
          title: '자산 등록',
          selectedIndex: 3,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final formContent = Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('기본 정보', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _uidController,
                            label: '자산 UID *',
                            helperText: '자산을 식별할 고유한 UID를 입력하세요.',
                            requiredField: true,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _nameController,
                            label: '사용자 *',
                            helperText: '자산 사용자 혹은 담당자를 입력하세요.',
                            requiredField: true,
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _modelController,
                            label: '모델명',
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _serialController,
                            label: '시리얼 번호',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('운영 정보', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _vendorController,
                            label: '벤더',
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _locationController,
                            label: '위치',
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            items: _statusOptions
                                .map(
                                  (status) => DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedStatus = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: '상태',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _assetTypeController,
                            label: '장비 종류',
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 320 : double.infinity,
                          child: _buildTextField(
                            controller: _organizationController,
                            label: '소속 조직',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('추가 메타데이터', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _buildMetadataSection(),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _submit(provider),
                          icon: const Icon(Icons.save),
                          label: const Text('저장'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _clearForm,
                          child: const Text('초기화'),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: formContent),
                              const SizedBox(width: 24),
                              SizedBox(width: 320, child: _buildPreview(provider)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              formContent,
                              _buildPreview(provider),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MetadataField {
  _MetadataField()
      : keyController = TextEditingController(),
        valueController = TextEditingController();

  final TextEditingController keyController;
  final TextEditingController valueController;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class _PreviewRow {
  const _PreviewRow(this.label, this.value);

  final String label;
  final String value;
}
