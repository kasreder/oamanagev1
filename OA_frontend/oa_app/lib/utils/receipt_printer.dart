import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:dio/dio.dart';

import '../main.dart';
import '../models/receipt.dart';

/// 인수증 A4 인쇄/PDF (printing 패키지).
/// vendors.template_variant 로 업체별 양식 분기:
///   default | aj(AJ네트웍스) | koffice(한국오피스) | iguard(아이가드)
///   | ctok(씨토크) | boim(보임테크놀러지)
/// 샘플 문서의 구조를 따르되 픽셀 단위 복제는 아님.

/// 인쇄 표시 모드: 보임 / 값만 공란(수기 기입) / 항목 자체 숨김
enum PrintFieldMode { shown, blank, hidden }

/// 인쇄 옵션 (관리자·운영자만 변경 — 기본은 모두 보임)
class ReceiptPrintOptions {
  final PrintFieldMode issuedAt; // 발행일
  final PrintFieldMode confirmDate; // 확인일 (인쇄 시점 오늘 날짜)
  final PrintFieldMode docNo; // 문서번호

  const ReceiptPrintOptions({
    this.issuedAt = PrintFieldMode.shown,
    this.confirmDate = PrintFieldMode.shown,
    this.docNo = PrintFieldMode.shown,
  });
}

class ReceiptPrinter {
  /// [userNames]: users.id → employee_name (헬프데스크/IT기획팀 담당자 표시용)
  static Future<void> printReceipt(
    BuildContext context,
    Receipt r, {
    Map<int, String> userNames = const {},
    ReceiptPrintOptions options = const ReceiptPrintOptions(),
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) => _buildPdf(r, format, userNames, options),
    );
  }

  /// 앱 안 다이얼로그로 PDF를 바로 표시 (다운로드/인쇄창 없이 보기 전용,
  /// 상단 프린터 아이콘으로 인쇄도 가능)
  static Future<void> showPreviewDialog(
    BuildContext context,
    Receipt r, {
    Map<int, String> userNames = const {},
    ReceiptPrintOptions options = const ReceiptPrintOptions(),
    String title = '양식 미리보기',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 920),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PdfPreview(
                  build: (format) => _buildPdf(r, format, userNames, options),
                  allowPrinting: true,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _dateFmt = DateFormat('yyyy-MM-dd');
  static final _wonFmt = NumberFormat('#,###');

  static Future<Uint8List> _buildPdf(
    Receipt r,
    PdfPageFormat format,
    Map<int, String> userNames,
    ReceiptPrintOptions options,
  ) async {
    final variantForFont = r.vendor?.templateVariant ?? 'default';
    // koffice: 원본(굴림 계열)과 가장 비슷한 상업 무료 서체 나눔고딕(SIL OFL)
    final pw.ThemeData theme;
    if (variantForFont == 'koffice') {
      theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nanumGothicRegular(),
        bold: await PdfGoogleFonts.nanumGothicBold(),
      );
    } else {
      theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansKRRegular(),
        bold: await PdfGoogleFonts.notoSansKRBold(),
      );
    }

    // 서명 이미지 로드 (signed URL 발급 후 다운로드)
    Future<pw.MemoryImage?> loadSig(String? path) async {
      if (path == null || path.isEmpty) return null;
      try {
        final url = await supabase.storage
            .from('receipt-signatures')
            .createSignedUrl(path, 300);
        final res = await Dio().get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        return pw.MemoryImage(Uint8List.fromList(res.data ?? []));
      } catch (_) {
        return null;
      }
    }

    final sigVendor = await loadSig(r.signVendor);
    final sigHelp = await loadSig(r.signHelpdesk);
    final sigIt = await loadSig(r.signItPlan);

    final variant = r.vendor?.templateVariant ?? 'default';

    pw.MemoryImage? ajLogo;
    if (variant == 'aj') {
      try {
        final bytes =
            await rootBundle.load('assets/vendor_logos/aj_networks.png');
        ajLogo = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    final ctx = _Ctx(
      r: r,
      options: options,
      sigVendor: sigVendor,
      sigHelp: sigHelp,
      sigIt: sigIt,
      helpName: userNames[r.signHelpdeskUserId],
      itName: userNames[r.signItPlanUserId],
      ajLogo: ajLogo,
    );

    final body = switch (variant) {
      'aj' => _bodyAj(ctx),
      'koffice' => _bodyKoffice(ctx),
      'iguard' => _bodyIguard(ctx),
      'ctok' => _bodyCtok(ctx),
      'boim' => _bodyBoim(ctx),
      _ => _bodyDefault(ctx),
    };

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.Page(
        pageFormat: format.copyWith(
          marginTop: 30,
          marginBottom: 30,
          marginLeft: 30,
          marginRight: 30,
        ),
        build: (_) => body,
      ),
    );
    return doc.save();
  }

  // ── 공통 텍스트 헬퍼 ────────────────────────────────────────────────

  static String _dateText(PrintFieldMode m, DateTime d) => switch (m) {
        PrintFieldMode.shown => _dateFmt.format(d),
        _ => '____________',
      };

  /// "2026년 8월 11일" 형식 (blank 시 월·일 공란)
  static String _koreanDate(PrintFieldMode m, DateTime d) =>
      m == PrintFieldMode.shown
          ? '${d.year}년 ${d.month}월 ${d.day}일'
          : '${d.year}년   월   일';

  static String _noteWithSn(ReceiptItem it) {
    final parts = <String>[
      if ((it.note ?? '').trim().isNotEmpty) it.note!.trim(),
      if ((it.sn ?? '').trim().isNotEmpty) 'SN: ${it.sn!.trim()}',
    ];
    return parts.join(' / ');
  }

  // ── default (기존 양식) ─────────────────────────────────────────────

  static pw.Widget _bodyDefault(_Ctx c) {
    final r = c.r;
    final options = c.options;
    final vendorName = r.vendor?.name ?? '(거래처 미지정)';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 2)),
          ),
          child: pw.Text(vendorName,
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 16),
        pw.Text('인 수 증',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (options.issuedAt != PrintFieldMode.hidden)
              pw.Text('발행일: ${_dateText(options.issuedAt, r.issuedAt)}'),
            if (options.docNo != PrintFieldMode.hidden)
              pw.Text(options.docNo == PrintFieldMode.shown
                  ? '문서번호: R-${r.id}'
                  : '문서번호: ________'),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          pw.Text('인수업체: ${r.receiverCompany ?? "-"}    '),
          pw.Text('인수부서: ${r.receiverDepartment ?? "-"}    '),
          pw.Text('인수자: ${r.receiverName ?? "-"}'),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Text('발송업체: ${r.senderCompany ?? "-"}    '),
          pw.Text('발송부서: ${r.senderDepartment ?? "-"}    '),
          pw.Text('발송담당자: ${r.senderManager ?? "-"}'),
        ]),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(3),
            4: const pw.FixedColumnWidth(40),
            5: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('#', header: true),
                _cell('항목', header: true),
                _cell('제품명', header: true),
                _cell('SN', header: true),
                _cell('수량', header: true),
                _cell('비고', header: true),
              ],
            ),
            ...r.items.map((it) => pw.TableRow(children: [
                  _cell('${it.rowNo}'),
                  _cell(it.category ?? ''),
                  _cell(it.name ?? ''),
                  _cell(it.sn ?? ''),
                  _cell('${it.qty}'),
                  _cell(it.note ?? ''),
                ])),
            if (r.items.length < 5)
              for (int k = r.items.length; k < 5; k++)
                pw.TableRow(children: List.filled(6, _cell(''))),
          ],
        ),
        pw.SizedBox(height: 12),
        if ((r.memo ?? '').isNotEmpty) ...[
          pw.Text('비고: ${r.memo}'),
          pw.SizedBox(height: 12),
        ],
        pw.Spacer(),
        if (options.confirmDate != PrintFieldMode.hidden)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  '확인일: ${_dateText(options.confirmDate, DateTime.now())}'),
            ),
          ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sigBox(
              r.signVendorAsSender ? '거래처(발송업체)' : '거래처',
              c.sigVendor,
              name: r.signVendorName,
            ),
            pw.SizedBox(width: 8),
            _sigBox('헬프데스크', c.sigHelp, name: c.helpName),
            pw.SizedBox(width: 8),
            _sigBox('IT기획팀', c.sigIt, name: c.itName),
          ],
        ),
      ],
    );
  }

  // ── aj: AJ네트웍스 납품확인서 ────────────────────────────────────────

  static pw.Widget _bodyAj(_Ctx c) {
    final r = c.r;
    pw.Widget headerCell(String t) => pw.Container(
        padding: const pw.EdgeInsets.all(5),
        alignment: pw.Alignment.center,
        child: pw.Text(t,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)));

    // 서명 블록 (공급받는자/공급자)
    pw.Widget signBlock({
      required String roleTitle, // <공급 받는자> / <공급자>
      required String company,
      required String dateLabel, // 설치/인수일자 or 출고일자
      required String dateValue,
      pw.MemoryImage? sig,
      String? name,
    }) {
      pw.Widget label(String t) => pw.Container(
          width: 110,
          padding: const pw.EdgeInsets.all(5),
          decoration: const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(width: 0.5))),
          child: pw.Text(t,
              style:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));
      pw.Widget row(String l, pw.Widget v) => pw.Container(
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
          child: pw.Row(children: [
            label(l),
            pw.Expanded(child: pw.Center(child: v)),
          ]));
      return pw.Column(children: [
        row('$roleTitle\n회사명 / 부서명',
            pw.Text(company, style: const pw.TextStyle(fontSize: 10))),
        row(dateLabel,
            pw.Text(dateValue, style: const pw.TextStyle(fontSize: 10))),
        pw.Container(
          height: 44,
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1))),
          child: pw.Row(children: [
            label('담당자 / 서명'),
            pw.Expanded(
              child: pw.Stack(children: [
                if (sig != null)
                  pw.Center(
                      child:
                          pw.Image(sig, height: 36, fit: pw.BoxFit.contain)),
                if (name != null && name.isNotEmpty)
                  pw.Positioned(
                      left: 8,
                      bottom: 4,
                      child: pw.Text(name,
                          style: const pw.TextStyle(fontSize: 10))),
              ]),
            ),
          ]),
        ),
      ]);
    }

    final issuedTxt = _koreanDate(c.options.issuedAt, r.issuedAt);
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2)),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 로고
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1))),
            child: c.ajLogo != null
                ? pw.Image(c.ajLogo!, height: 26)
                : pw.Text('AJ네트웍스',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1))),
            child: pw.Text('납 품 확 인 서',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          // 7행 고정표: 순번/모델명/비고/수량 (좌측 "모델명" 안내열)
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FixedColumnWidth(34),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(children: [
                headerCell(''),
                headerCell('순번'),
                headerCell('모델명'),
                headerCell('비고'),
                headerCell('수량'),
              ]),
              for (int i = 0; i < 7; i++)
                pw.TableRow(children: [
                  i == 3 ? headerCell('모델명') : _cell(''),
                  _cell('${i + 1}'),
                  _cell(i < r.items.length ? (r.items[i].name ?? '') : ''),
                  _cell(i < r.items.length ? _noteWithSn(r.items[i]) : ''),
                  _cell(i < r.items.length
                      ? '${r.items[i].qty} ${r.items[i].category ?? ""}'
                          .trim()
                      : ''),
                ]),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1))),
            child: pw.Text('* 상기 본인은 위에 물품을 정히 인수하였음을 증명합니다.',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          signBlock(
            roleTitle: '<공급 받는자>',
            company: r.receiverCompany ?? '-',
            dateLabel: '설치 / 인수일자',
            dateValue: issuedTxt,
            sig: c.sigIt,
            name: c.itName,
          ),
          pw.SizedBox(height: 4),
          signBlock(
            roleTitle: '<공급 받는자>',
            company: '헬프데스크',
            dateLabel: '설치 / 인수일자',
            dateValue: issuedTxt,
            sig: c.sigHelp,
            name: c.helpName,
          ),
          pw.SizedBox(height: 4),
          signBlock(
            roleTitle: '<공급자>',
            company: r.senderCompany ?? (r.vendor?.name ?? '-'),
            dateLabel: '출고일자',
            dateValue: _koreanDate(PrintFieldMode.shown, r.issuedAt),
            sig: c.sigVendor,
            name: r.signVendorName,
          ),
          pw.Spacer(),
        ],
      ),
    );
  }

  // ── koffice: 한국오피스컴퓨터 납품확인서 ────────────────────────────

  static pw.Widget _bodyKoffice(_Ctx c) {
    final r = c.r;
    final vendorName = r.vendor?.name ?? '-';
    pw.Widget signRow(String role, String company, String dept,
        pw.MemoryImage? sig, String? name) {
      pw.Widget cell(pw.Widget child, {double? w, bool grey = false}) =>
          pw.Container(
            width: w,
            height: 30,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5),
              color: grey ? PdfColors.grey200 : null,
            ),
            child: child,
          );
      return pw.Row(children: [
        cell(pw.Text(role,
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            w: 70, grey: true),
        pw.Expanded(
            child:
                cell(pw.Text(company, style: const pw.TextStyle(fontSize: 9)))),
        cell(pw.Text('부  서',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            w: 50, grey: true),
        pw.Expanded(
            child: cell(pw.Text(dept, style: const pw.TextStyle(fontSize: 9)))),
        cell(pw.Text('성함/ 사인',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            w: 60, grey: true),
        pw.Expanded(
          child: pw.Container(
            height: 30,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: pw.Stack(children: [
              if (sig != null)
                pw.Center(
                    child: pw.Image(sig, height: 26, fit: pw.BoxFit.contain)),
              if (name != null && name.isNotEmpty)
                pw.Positioned(
                    left: 4,
                    bottom: 8,
                    child: pw.Text(name,
                        style: const pw.TextStyle(fontSize: 9))),
            ]),
          ),
        ),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(vendorName,
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('수  신 :  ${r.receiverCompany ?? "-"}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('참  조 :  ${r.receiverName ?? "-"} 귀하',
                      style: const pw.TextStyle(fontSize: 10)),
                ]),
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('담  당 :  ${r.senderManager ?? "-"}',
                      style: const pw.TextStyle(fontSize: 10)),
                  if (c.options.issuedAt != PrintFieldMode.hidden)
                    pw.Text(
                        '납품일 :  ${_koreanDate(c.options.issuedAt, r.issuedAt)}',
                        style: const pw.TextStyle(fontSize: 10)),
                ]),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('납  품  확  인  서',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('아래와 같이 납품합니다.',
                style: const pw.TextStyle(fontSize: 11)),
            pw.Text(vendorName, style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('품 목', header: true),
                _cell('모 델 명', header: true),
                _cell('S/N', header: true),
                _cell('수량', header: true),
              ],
            ),
            for (int i = 0; i < 12; i++)
              pw.TableRow(children: [
                _cell(i < r.items.length ? (r.items[i].category ?? '') : ''),
                _cell(i < r.items.length ? (r.items[i].name ?? '') : ''),
                _cell(i < r.items.length ? (r.items[i].sn ?? '') : ''),
                _cell(i < r.items.length ? '${r.items[i].qty}' : ''),
              ]),
          ],
        ),
        pw.Spacer(),
        signRow('납품처', vendorName, r.senderDepartment ?? '',
            c.sigVendor, r.signVendorName),
        signRow('수령자', r.receiverCompany ?? '', '헬프데스크', c.sigHelp,
            c.helpName),
        signRow('확인자', r.receiverCompany ?? '', 'IT 기획팀', c.sigIt,
            c.itName),
      ],
    );
  }

  // ── iguard: 아이가드 문서형 납품확인서 ──────────────────────────────

  static pw.Widget _bodyIguard(_Ctx c) {
    final r = c.r;
    final vendorName = r.vendor?.name ?? '-';
    int seq = 0;
    String no() => '${++seq}.';
    pw.Widget numbered(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 11)));
    pw.Widget signLine(String role, String who, pw.MemoryImage? sig,
            String? name) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(children: [
            pw.Text('$role : $who  ',
                style: const pw.TextStyle(fontSize: 11)),
            if (name != null && name.isNotEmpty)
              pw.Text('$name  ', style: const pw.TextStyle(fontSize: 11)),
            if (sig != null)
              pw.Image(sig, height: 26, fit: pw.BoxFit.contain),
            pw.Text(' (인)', style: const pw.TextStyle(fontSize: 10)),
          ]),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 20),
        pw.Text('납  품  확  인  서',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 30),
        // 인수 날짜 — 인쇄 옵션 "발행일" 체크와 동일하게 동작
        //   ✓ 보임: 날짜 인쇄 / – 공란: 수기 기입 안내 / ☐ 숨김: 항목 생략
        // 번호는 생략 여부와 무관하게 1번부터 연속 부여
        if (c.options.issuedAt == PrintFieldMode.shown)
          numbered(
              '${no()}  인수 날짜 : ${_koreanDate(PrintFieldMode.shown, r.issuedAt)}')
        else if (c.options.issuedAt == PrintFieldMode.blank)
          numbered('${no()}  인수 날짜 기입 부탁드립니다. '
              '( ${_koreanDate(PrintFieldMode.blank, r.issuedAt)} )'),
        numbered(
            '${no()}  인수업체 : ${r.receiverCompany ?? "-"} ${r.receiverName ?? ""} 귀하'),
        numbered('${no()}  납품내역'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10),
          child: pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _cell('품 목', header: true),
                  _cell('수 량', header: true),
                  _cell('비 고', header: true),
                ],
              ),
              ...r.items.map((it) => pw.TableRow(children: [
                    _cell([
                      if ((it.category ?? '').isNotEmpty) it.category!,
                      if ((it.name ?? '').isNotEmpty) it.name!,
                    ].join(' ')),
                    _cell('${it.qty}'),
                    _cell(_noteWithSn(it)),
                  ])),
              if (r.items.length < 3)
                for (int k = r.items.length; k < 3; k++)
                  pw.TableRow(children: List.filled(3, _cell(''))),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        numbered('${no()}  납품 회사 : $vendorName'),
        numbered('${no()}  납품 담당 : ${r.senderManager ?? "-"}'),
        pw.Spacer(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('상기물품을 정히 인수하였음을 확인함.',
                    style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Text(_koreanDate(c.options.issuedAt, r.issuedAt),
                    style: const pw.TextStyle(fontSize: 11)),
              ]),
        ),
        pw.SizedBox(height: 12),
        signLine('납품', vendorName, c.sigVendor, r.signVendorName),
        signLine('수령', '${r.receiverCompany ?? "-"}(헬프데스크)', c.sigHelp,
            c.helpName),
        signLine('확인', r.receiverCompany ?? '-', c.sigIt, c.itName),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ── ctok: 씨토크 입고 확인서 (금액 표기) ────────────────────────────

  static pw.Widget _bodyCtok(_Ctx c) {
    final r = c.r;
    final vendorName = r.vendor?.name ?? '-';
    final total = r.items.fold<int>(0, (s, it) => s + (it.amount ?? 0));
    pw.Widget infoRow(String label, pw.Widget value) => pw.Row(children: [
          pw.Container(
            width: 150,
            height: 28,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5), color: PdfColors.grey100),
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 28,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              alignment: pw.Alignment.centerLeft,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: value,
            ),
          ),
        ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(vendorName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
              child: pw.Text('입 고  확 인 서',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
            child: pw.Column(children: [
              pw.Text('작성일자',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(_dateText(c.options.issuedAt, r.issuedAt),
                  style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.4),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(40),
            3: const pw.FlexColumnWidth(1.6),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('구분', header: true),
                _cell('제품 및 주요사양', header: true),
                _cell('수량', header: true),
                _cell('합계', header: true),
              ],
            ),
            ...r.items.map((it) => pw.TableRow(children: [
                  _cell(it.category ?? ''),
                  _cell([
                    if ((it.name ?? '').isNotEmpty) it.name!,
                    if ((it.sn ?? '').isNotEmpty) 'SN넘버 : ${it.sn}',
                    if ((it.note ?? '').isNotEmpty) it.note!,
                  ].join('\n')),
                  _cell('${it.qty}'),
                  _cell(it.amount != null ? _wonFmt.format(it.amount) : ''),
                ])),
            if (r.items.length < 3)
              for (int k = r.items.length; k < 3; k++)
                pw.TableRow(children: List.filled(4, _cell(''))),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _cell('합계', header: true),
                _cell(''),
                _cell(''),
                _cell(total > 0 ? _wonFmt.format(total) : ''),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text('위 제품의 개통과 납품(검수)를 확인 합니다.',
            style: const pw.TextStyle(fontSize: 11)),
        pw.Spacer(),
        infoRow('납품(검수) 장소',
            pw.Text(r.receiverCompany ?? '-',
                style: const pw.TextStyle(fontSize: 10))),
        infoRow('인수회사',
            pw.Text(r.receiverCompany ?? '-',
                style: const pw.TextStyle(fontSize: 10))),
        infoRow(
          '판매회사',
          pw.Row(children: [
            pw.Text(vendorName, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 8),
            if ((r.signVendorName ?? '').isNotEmpty)
              pw.Text(r.signVendorName!,
                  style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 4),
            if (c.sigVendor != null)
              pw.Image(c.sigVendor!, height: 22, fit: pw.BoxFit.contain),
            pw.Text(' (인)', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        infoRow(
          '납품(검수)확인자',
          pw.Row(children: [
            pw.Text('헬프데스크 ${c.helpName ?? ""}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 4),
            if (c.sigHelp != null)
              pw.Image(c.sigHelp!, height: 22, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 12),
            pw.Text('IT기획팀 ${c.itName ?? ""}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 4),
            if (c.sigIt != null)
              pw.Image(c.sigIt!, height: 22, fit: pw.BoxFit.contain),
          ]),
        ),
      ],
    );
  }

  // ── boim: 보임테크놀러지 물품 인수증 ────────────────────────────────

  static pw.Widget _bodyBoim(_Ctx c) {
    final r = c.r;
    final vendorName = r.vendor?.name ?? '-';
    pw.Widget pairCell(String label, String? company, String? name,
        pw.MemoryImage? sig) {
      pw.Widget box(String l, pw.Widget v) => pw.Row(children: [
            pw.Container(
              width: 55,
              height: 26,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                  color: PdfColors.grey100),
              child: pw.Text(l, style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 26,
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                alignment: pw.Alignment.centerLeft,
                decoration:
                    pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                child: v,
              ),
            ),
          ]);
      return pw.Expanded(
        child: pw.Row(children: [
          pw.Container(
            width: 50,
            height: 52,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5), color: PdfColors.grey100),
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Column(children: [
              box('회 사 명',
                  pw.Text(company ?? '', style: const pw.TextStyle(fontSize: 9))),
              box(
                '성    명',
                pw.Row(children: [
                  pw.Expanded(
                      child: pw.Text(name ?? '',
                          style: const pw.TextStyle(fontSize: 9))),
                  if (sig != null)
                    pw.Image(sig, height: 20, fit: pw.BoxFit.contain),
                  pw.Text('(인)', style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
            ]),
          ),
        ]),
      );
    }

    pw.Widget pairRow(
            {String? leftCompany,
            String? leftName,
            pw.MemoryImage? leftSig,
            String? rightCompany,
            String? rightName,
            pw.MemoryImage? rightSig}) =>
        pw.Row(children: [
          pairCell('인계자', leftCompany, leftName, leftSig),
          pairCell('인수자', rightCompany, rightName, rightSig),
        ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 20),
        pw.Text('물 품  인 수 증',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 30),
        pw.Text('아래 목록에 기재되어 있는 물품을 인수 하였음을 확인합니다.',
            style: const pw.TextStyle(fontSize: 12),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 16),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 60),
          child: pw.Table(
            border: pw.TableBorder.all(width: 0.8),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _cell('품명', header: true),
                  _cell('수량', header: true),
                ],
              ),
              ...r.items.map((it) => pw.TableRow(children: [
                    _cell([
                      if ((it.name ?? '').isNotEmpty) it.name!,
                      if ((it.sn ?? '').isNotEmpty) it.sn!,
                    ].join('\n')),
                    _cell('${it.qty} ea'),
                  ])),
              if (r.items.length < 2)
                for (int k = r.items.length; k < 2; k++)
                  pw.TableRow(children: List.filled(2, _cell(''))),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text('인 수 날 짜 :  ${_koreanDate(c.options.issuedAt, r.issuedAt)}',
            style: const pw.TextStyle(fontSize: 12),
            textAlign: pw.TextAlign.center),
        pw.Spacer(),
        pairRow(
            leftCompany: vendorName,
            leftName: r.signVendorName,
            leftSig: c.sigVendor),
        pairRow(
            rightCompany: '헬프데스크',
            rightName: c.helpName,
            rightSig: c.sigHelp),
        pairRow(
            rightCompany: r.receiverCompany ?? '-',
            rightName: c.itName,
            rightSig: c.sigIt),
        pw.SizedBox(height: 20),
      ],
    );
  }

  // ── 공통 위젯 ───────────────────────────────────────────────────────

  static pw.Widget _cell(String text, {bool header = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight:
                    header ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _sigBox(String label, pw.MemoryImage? img,
          {String? name}) =>
      pw.Expanded(
        child: pw.Container(
          height: 90,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
          child: pw.Stack(
            children: [
              if (img != null)
                pw.Center(
                  child: pw.Image(img, height: 54, fit: pw.BoxFit.contain),
                ),
              pw.Positioned(
                top: 0,
                left: 0,
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              if (name != null && name.isNotEmpty)
                pw.Positioned(
                  left: 0,
                  bottom: 0,
                  child:
                      pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
                ),
              pw.Positioned(
                right: 0,
                bottom: 0,
                child: pw.Text('(인)',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
}

/// variant 빌더에 넘기는 공통 컨텍스트
class _Ctx {
  final Receipt r;
  final ReceiptPrintOptions options;
  final pw.MemoryImage? sigVendor;
  final pw.MemoryImage? sigHelp;
  final pw.MemoryImage? sigIt;
  final String? helpName;
  final String? itName;
  final pw.MemoryImage? ajLogo;

  const _Ctx({
    required this.r,
    required this.options,
    this.sigVendor,
    this.sigHelp,
    this.sigIt,
    this.helpName,
    this.itName,
    this.ajLogo,
  });
}
