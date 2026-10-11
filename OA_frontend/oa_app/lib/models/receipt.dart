import 'vendor.dart';

class ReceiptItem {
  final int? id;
  final int? receiptId;
  final int? assetId;
  final int rowNo;
  final String? category;
  final String? name;
  final String? sn;
  final int qty;
  final String? note;
  /// 금액(합계, 원) — 씨토크 등 금액 표기 양식용. null이면 인쇄 시 공란.
  final int? amount;

  const ReceiptItem({
    this.id,
    this.receiptId,
    this.assetId,
    this.rowNo = 1,
    this.category,
    this.name,
    this.sn,
    this.qty = 1,
    this.note,
    this.amount,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> j) => ReceiptItem(
        id: j['id'] as int?,
        receiptId: j['receipt_id'] as int?,
        assetId: j['asset_id'] as int?,
        rowNo: j['row_no'] as int? ?? 1,
        category: j['category'] as String?,
        name: j['name'] as String?,
        sn: j['sn'] as String?,
        qty: j['qty'] as int? ?? 1,
        note: j['note'] as String?,
        amount: j['amount'] as int?,
      );

  Map<String, dynamic> toJson() => {
        if (receiptId != null) 'receipt_id': receiptId,
        'asset_id': assetId,
        'row_no': rowNo,
        'category': category,
        'name': name,
        'sn': sn,
        'qty': qty,
        'note': note,
        'amount': amount,
      };

  ReceiptItem copyWith({
    int? id,
    int? receiptId,
    int? assetId,
    int? rowNo,
    String? category,
    String? name,
    String? sn,
    int? qty,
    String? note,
    int? amount,
    bool clearAmount = false,
  }) =>
      ReceiptItem(
        id: id ?? this.id,
        receiptId: receiptId ?? this.receiptId,
        assetId: assetId ?? this.assetId,
        rowNo: rowNo ?? this.rowNo,
        category: category ?? this.category,
        name: name ?? this.name,
        sn: sn ?? this.sn,
        qty: qty ?? this.qty,
        note: note ?? this.note,
        amount: clearAmount ? null : (amount ?? this.amount),
      );
}

class Receipt {
  final int id;
  final int? vendorId;
  final DateTime issuedAt;
  final String? receiverName;
  final String? receiverCompany;
  /// 인수자가 서명 담당자와 동일: 'helpdesk' | 'it_plan' | null
  final String? receiverSameAs;
  final String? receiverDepartment;
  final String? senderCompany;
  final String? senderDepartment;
  final String? senderContact;
  final String? senderManager;
  final String? memo;
  final String status; // draft / signed / void
  final String? signVendor;
  final String? signHelpdesk;
  final String? signItPlan;
  final String? signVendorName;
  final bool signVendorAsSender;
  final int? signHelpdeskUserId;
  final int? signItPlanUserId;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // 조인 필드
  final Vendor? vendor;
  final List<ReceiptItem> items;

  const Receipt({
    required this.id,
    this.vendorId,
    required this.issuedAt,
    this.receiverName,
    this.receiverCompany,
    this.receiverSameAs,
    this.receiverDepartment,
    this.senderCompany,
    this.senderDepartment,
    this.senderContact,
    this.senderManager,
    this.memo,
    this.status = 'draft',
    this.signVendor,
    this.signHelpdesk,
    this.signItPlan,
    this.signVendorName,
    this.signVendorAsSender = false,
    this.signHelpdeskUserId,
    this.signItPlanUserId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.vendor,
    this.items = const [],
  });

  bool get isSigned => status == 'signed';
  bool get isVoid => status == 'void';

  factory Receipt.fromJson(Map<String, dynamic> j) {
    final vJson = j['vendors'] as Map<String, dynamic>?;
    final itemsJson = (j['receipt_items'] as List?) ?? const [];
    return Receipt(
      id: j['id'] as int,
      vendorId: j['vendor_id'] as int?,
      issuedAt: DateTime.parse(j['issued_at'] as String),
      receiverName: j['receiver_name'] as String?,
      receiverCompany: j['receiver_company'] as String?,
      receiverSameAs: j['receiver_same_as'] as String?,
      receiverDepartment: j['receiver_department'] as String?,
      senderCompany: j['sender_company'] as String?,
      senderDepartment: j['sender_department'] as String?,
      senderContact: j['sender_contact'] as String?,
      senderManager: j['sender_manager'] as String?,
      memo: j['memo'] as String?,
      status: (j['status'] as String?) ?? 'draft',
      signVendor: j['sign_vendor'] as String?,
      signHelpdesk: j['sign_helpdesk'] as String?,
      signItPlan: j['sign_it_plan'] as String?,
      signVendorName: j['sign_vendor_name'] as String?,
      signVendorAsSender: j['sign_vendor_as_sender'] as bool? ?? false,
      signHelpdeskUserId: j['sign_helpdesk_user_id'] as int?,
      signItPlanUserId: j['sign_it_plan_user_id'] as int?,
      createdBy: j['created_by'] as int?,
      createdAt: j['created_at'] != null
          ? DateTime.parse(j['created_at'] as String).toLocal()
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.parse(j['updated_at'] as String).toLocal()
          : null,
      vendor: vJson != null ? Vendor.fromJson(vJson) : null,
      items: itemsJson
          .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.rowNo.compareTo(b.rowNo)),
    );
  }

  Map<String, dynamic> toJson() => {
        'vendor_id': vendorId,
        'issued_at': issuedAt.toIso8601String().split('T').first,
        'receiver_name': receiverName,
        'receiver_company': receiverCompany,
        'receiver_same_as': receiverSameAs,
        'receiver_department': receiverDepartment,
        'sender_company': senderCompany,
        'sender_department': senderDepartment,
        'sender_contact': senderContact,
        'sender_manager': senderManager,
        'memo': memo,
        'status': status,
        'sign_vendor': signVendor,
        'sign_helpdesk': signHelpdesk,
        'sign_it_plan': signItPlan,
        'sign_vendor_name': signVendorName,
        'sign_vendor_as_sender': signVendorAsSender,
        'sign_helpdesk_user_id': signHelpdeskUserId,
        'sign_it_plan_user_id': signItPlanUserId,
      };
}
