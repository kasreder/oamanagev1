import 'package:flutter/material.dart';

import '../../constants.dart';

/// 자산 목록에서 사용하는 필터/검색 바 위젯.
///
/// - 카테고리 드롭다운 (12개, constants.dart)
/// - 상태 드롭다운 (5개, constants.dart)
/// - 검색 TextField
class FilterBar extends StatefulWidget {
  /// 카테고리 변경 콜백 (null → 전체)
  final ValueChanged<String?> onCategoryChanged;

  /// 상태 변경 콜백 (null → 전체)
  final ValueChanged<String?> onStatusChanged;

  /// 검색어 변경 콜백
  final ValueChanged<String> onSearchChanged;

  /// 건물 목록 (선택적, 외부에서 주입)
  final List<String>? buildings;

  /// 건물 변경 콜백 (선택적)
  final ValueChanged<String?>? onBuildingChanged;

  const FilterBar({
    super.key,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    this.buildings,
    this.onBuildingChanged,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedBuilding;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 카테고리 드롭다운
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('전체'),
                ),
                ...assetCategories.map(
                  (cat) => DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value);
                widget.onCategoryChanged(value);
              },
            ),
          ),

          // 상태 드롭다운
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: '상태',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('전체'),
                ),
                ...assetStatuses.map(
                  (status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                widget.onStatusChanged(value);
              },
            ),
          ),

          // 건물 드롭다운 (buildings 목록이 있을 경우에만 표시)
          if (widget.buildings != null && widget.buildings!.isNotEmpty)
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _selectedBuilding,
                decoration: const InputDecoration(
                  labelText: '건물',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('전체'),
                  ),
                  ...widget.buildings!.map(
                    (b) => DropdownMenuItem<String>(
                      value: b,
                      child: Text(b),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedBuilding = value);
                  widget.onBuildingChanged?.call(value);
                },
              ),
            ),

          // 검색 필드
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '검색',
                hintText: '자산번호, 이름, 시리얼...',
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                widget.onSearchChanged(value);
                setState(() {}); // suffixIcon 갱신
              },
            ),
          ),
        ],
      ),
    );
  }
}
