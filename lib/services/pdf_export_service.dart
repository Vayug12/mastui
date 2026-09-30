import 'dart:convert';
import 'dart:typed_data';

import '../models/lead_model.dart';

class _PdfLinkAnnot {
  final double llx;
  final double lly;
  final double urx;
  final double ury;
  final String uri;

  const _PdfLinkAnnot({
    required this.llx,
    required this.lly,
    required this.urx,
    required this.ury,
    required this.uri,
  });
}

/// Lightweight, zero-dependency PDF 1.4 generator for GetLead reports.
/// Strictly conforms to Apple HIG & ChatGPT monochrome design language,
/// presenting leads in a clean Notion / Apple Keynote style editorial table
/// with fully interactive clickable hyperlinks (Email, Phone, Website, Profiles).
class PdfExportService {
  PdfExportService._();
  static final instance = PdfExportService._();

  /// Generates a complete PDF document byte array for the provided leads.
  Uint8List generateLeadReportPdf(List<Lead> leads, {String? niche}) {
    final pdfBuffer = BytesBuilder();
    List<int> objectOffsets = [];

    void writeString(String s) {
      pdfBuffer.add(utf8.encode(s));
    }

    int currentOffset() => pdfBuffer.length;

    // 1. PDF Header
    writeString('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');

    // Page setup (A4 standard: 595.28 x 841.89 pt)
    const double pageWidth = 595.28;
    const double pageHeight = 841.89;
    const double marginX = 36.0;
    const double tableWidth = pageWidth - (marginX * 2); // 523.28 pt
    const double rowHeight = 32.0;
    const double tableHeaderHeight = 20.0;
    const double footerCutoffY = 55.0;

    // Page 1 has executive summary banner
    const double page1TableTopY = 705.0;
    const double laterTableTopY = 785.0;

    // Column widths setup: Total = 523.28 pt
    const double col1X = marginX;
    const double col2X = marginX + 150.0;
    const double col3X = marginX + 305.0;
    const double col4X = marginX + 393.0;

    // Paginate rows
    final pages = <List<Lead>>[];
    if (leads.isEmpty) {
      pages.add([]);
    } else {
      var currentPageLeads = <Lead>[];
      var currentY = page1TableTopY - tableHeaderHeight;

      for (final lead in leads) {
        if (currentY - rowHeight < footerCutoffY) {
          pages.add(currentPageLeads);
          currentPageLeads = <Lead>[];
          currentY = laterTableTopY - tableHeaderHeight;
        }
        currentPageLeads.add(lead);
        currentY -= rowHeight;
      }
      if (currentPageLeads.isNotEmpty || pages.isEmpty) {
        pages.add(currentPageLeads);
      }
    }

    final totalPages = pages.length;

    // Build annotations and page content streams
    final pageAnnots = List<List<_PdfLinkAnnot>>.generate(totalPages, (_) => []);
    final pageContentStreams = <List<int>>[];

    final displayNiche = (niche != null && niche.trim().isNotEmpty)
        ? niche.trim()
        : 'All Categories';
    final dateStr = _formatDate(DateTime.now());
    final emailCount = leads.where((l) => l.email != null && l.email!.isNotEmpty).length;
    final phoneCount = leads.where((l) => l.phone != null && l.phone!.isNotEmpty).length;

    for (var i = 0; i < totalPages; i++) {
      final pageNum = i + 1;
      final pageLeads = pages[i];
      final currentAnnots = <_PdfLinkAnnot>[];

      final content = StringBuffer();

      // Clean White Canvas (#FFFFFF)
      content.writeln('1.0 1.0 1.0 rg 0 0 $pageWidth $pageHeight re f');

      double tableTopY;

      if (pageNum == 1) {
        // --- Page 1: Apple Keynote Style Minimalist Executive Header ---
        content.writeln('BT /F2 16 Tf 0.067 0.067 0.067 rg $marginX 798 Td (GetLead Agent) Tj ET');
        content.writeln('BT /F1 11 Tf 0.40 0.40 0.40 rg ${marginX + 130} 798 Td (|  Executive Discovery Report) Tj ET');

        final subtitle = _escapePdfText('Exported: $dateStr   -   Target Niche: $displayNiche', maxLength: 90);
        content.writeln('BT /F1 8.5 Tf 0.45 0.45 0.45 rg $marginX 782 Td ($subtitle) Tj ET');

        // Executive Summary Metrics Banner (#F7F7F8 container with #ECECEC hairline border)
        const double bannerTopY = 766.0;
        const double bannerHeight = 36.0;
        const double bannerBottomY = bannerTopY - bannerHeight;

        content.writeln('0.969 0.969 0.973 rg $marginX $bannerBottomY $tableWidth $bannerHeight re f');
        content.writeln('0.925 0.925 0.925 RG 0.75 w $marginX $bannerBottomY $tableWidth $bannerHeight re S');

        // Banner Metrics (4 Columns)
        final metricColW = tableWidth / 4;
        
        // Metric 1: Total Leads
        content.writeln('BT /F1 7.5 Tf 0.50 0.50 0.50 rg ${marginX + 12} ${bannerBottomY + 22} Td (TOTAL LEADS) Tj ET');
        content.writeln('BT /F2 11 Tf 0.067 0.067 0.067 rg ${marginX + 12} ${bannerBottomY + 8} Td (${leads.length}) Tj ET');

        // Metric 2: Verified Emails
        content.writeln('BT /F1 7.5 Tf 0.50 0.50 0.50 rg ${marginX + metricColW + 12} ${bannerBottomY + 22} Td (VERIFIED EMAILS) Tj ET');
        content.writeln('BT /F2 11 Tf 0.067 0.067 0.067 rg ${marginX + metricColW + 12} ${bannerBottomY + 8} Td ($emailCount) Tj ET');

        // Metric 3: Phone Contacts
        content.writeln('BT /F1 7.5 Tf 0.50 0.50 0.50 rg ${marginX + (metricColW * 2) + 12} ${bannerBottomY + 22} Td (PHONE CONTACTS) Tj ET');
        content.writeln('BT /F2 11 Tf 0.067 0.067 0.067 rg ${marginX + (metricColW * 2) + 12} ${bannerBottomY + 8} Td ($phoneCount) Tj ET');

        // Metric 4: Category
        final categoryDisplay = _escapePdfText(displayNiche, maxLength: 22);
        content.writeln('BT /F1 7.5 Tf 0.50 0.50 0.50 rg ${marginX + (metricColW * 3) + 12} ${bannerBottomY + 22} Td (CATEGORY) Tj ET');
        content.writeln('BT /F2 9.5 Tf 0.067 0.067 0.067 rg ${marginX + (metricColW * 3) + 12} ${bannerBottomY + 8} Td ($categoryDisplay) Tj ET');

        tableTopY = page1TableTopY;
      } else {
        // --- Subsequent Pages: Clean Minimalist Top Header ---
        content.writeln('BT /F2 9.5 Tf 0.067 0.067 0.067 rg $marginX 810 Td (GetLead Discovery Report) Tj ET');
        final headerMeta = _escapePdfText('- $displayNiche   |   Page $pageNum of $totalPages', maxLength: 80);
        content.writeln('BT /F1 8.5 Tf 0.45 0.45 0.45 rg ${marginX + 145} 810 Td ($headerMeta) Tj ET');
        content.writeln('0.925 0.925 0.925 RG 0.75 w $marginX 798 m ${pageWidth - marginX} 798 l S');

        tableTopY = laterTableTopY;
      }

      // --- Editorial Table Header Row ---
      final headerBottomY = tableTopY - tableHeaderHeight;
      content.writeln('0.969 0.969 0.973 rg $marginX $headerBottomY $tableWidth $tableHeaderHeight re f');
      content.writeln('0.900 0.900 0.900 RG 0.75 w $marginX $headerBottomY $tableWidth $tableHeaderHeight re S');

      const labelYOffset = 6.0;
      content.writeln('BT /F2 7.5 Tf 0.20 0.20 0.20 rg ${col1X + 8} ${headerBottomY + labelYOffset} Td (BUSINESS / DECISION MAKER) Tj ET');
      content.writeln('BT /F2 7.5 Tf 0.20 0.20 0.20 rg ${col2X + 8} ${headerBottomY + labelYOffset} Td (CONTACT DETAILS) Tj ET');
      content.writeln('BT /F2 7.5 Tf 0.20 0.20 0.20 rg ${col3X + 8} ${headerBottomY + labelYOffset} Td (PLATFORM / SOURCE) Tj ET');
      content.writeln('BT /F2 7.5 Tf 0.20 0.20 0.20 rg ${col4X + 8} ${headerBottomY + labelYOffset} Td (LOCATION & WEB) Tj ET');

      // --- Table Data Rows ---
      var rowCurrentTopY = headerBottomY;

      for (var j = 0; j < pageLeads.length; j++) {
        final lead = pageLeads[j];
        final rowBottomY = rowCurrentTopY - rowHeight;

        if (j % 2 == 1) {
          content.writeln('0.985 0.985 0.988 rg $marginX $rowBottomY $tableWidth $rowHeight re f');
        }

        // Hairline row divider (#ECECEC)
        content.writeln('0.925 0.925 0.925 RG 0.5 w $marginX $rowBottomY m ${pageWidth - marginX} $rowBottomY l S');

        // --- Cell 1: Business Name & Founder ---
        final businessTitle = _escapePdfText(lead.displayName, maxLength: 30);
        content.writeln(
          'BT /F2 8.5 Tf 0.067 0.067 0.067 rg ${col1X + 8} ${rowBottomY + 18} Td ($businessTitle) Tj ET',
        );
        final founderStr = (lead.decisionMakerName != null && lead.decisionMakerName!.isNotEmpty)
            ? '${lead.decisionMakerName!}${lead.decisionMakerRole != null ? ' (${lead.decisionMakerRole})' : ''}'
            : (lead.name.isNotEmpty && lead.name != lead.displayName ? lead.name : '-');
        final founderLine = _escapePdfText(founderStr, maxLength: 34);
        content.writeln(
          'BT /F1 7 Tf 0.50 0.50 0.50 rg ${col1X + 8} ${rowBottomY + 6} Td ($founderLine) Tj ET',
        );

        // --- Cell 2: Email & Phone (Clickable Links) ---
        final emailStr = (lead.email != null && lead.email!.isNotEmpty)
            ? lead.email!.trim()
            : '-';
        final emailLine = _escapePdfText(emailStr, maxLength: 32);
        content.writeln(
          'BT /F1 8 Tf 0.15 0.15 0.15 rg ${col2X + 8} ${rowBottomY + 18} Td ($emailLine) Tj ET',
        );

        if (lead.email != null && lead.email!.trim().isNotEmpty) {
          currentAnnots.add(
            _PdfLinkAnnot(
              llx: col2X + 6,
              lly: rowBottomY + 16,
              urx: col2X + 150,
              ury: rowBottomY + 28,
              uri: 'mailto:${lead.email!.trim()}',
            ),
          );
        }

        final phoneStr = (lead.phone != null && lead.phone!.isNotEmpty)
            ? lead.phone!.trim()
            : '-';
        final phoneLine = _escapePdfText(phoneStr, maxLength: 28);
        content.writeln(
          'BT /F1 7.5 Tf 0.45 0.45 0.45 rg ${col2X + 8} ${rowBottomY + 6} Td ($phoneLine) Tj ET',
        );

        if (lead.phone != null && lead.phone!.trim().isNotEmpty) {
          final cleanPhone = lead.phone!.replaceAll(RegExp(r'[^0-9+]'), '');
          if (cleanPhone.isNotEmpty) {
            currentAnnots.add(
              _PdfLinkAnnot(
                llx: col2X + 6,
                lly: rowBottomY + 4,
                urx: col2X + 150,
                ury: rowBottomY + 16,
                uri: 'tel:$cleanPhone',
              ),
            );
          }
        }

        // --- Cell 3: Platform / Source (Clickable Profile Link) ---
        final platformBadge = _escapePdfText(lead.platform.toUpperCase(), maxLength: 18);
        content.writeln(
          'BT /F2 8 Tf 0.067 0.067 0.067 rg ${col3X + 8} ${rowBottomY + 18} Td ($platformBadge) Tj ET',
        );

        if (lead.profileUrl.trim().isNotEmpty) {
          currentAnnots.add(
            _PdfLinkAnnot(
              llx: col3X + 6,
              lly: rowBottomY + 14,
              urx: col3X + 85,
              ury: rowBottomY + 28,
              uri: _ensureHttp(lead.profileUrl),
            ),
          );
        }

        final statusStr = (lead.isWorkEmail && lead.emailStatus == 'verified')
            ? 'Verified Work'
            : (lead.emailStatus == 'verified' ? 'Verified' : 'Public');
        final statusLine = _escapePdfText(statusStr, maxLength: 18);
        content.writeln(
          'BT /F1 7 Tf 0.50 0.50 0.50 rg ${col3X + 8} ${rowBottomY + 6} Td ($statusLine) Tj ET',
        );

        // --- Cell 4: Location & Web (Clickable Website Link) ---
        final locationStr = (lead.location != null && lead.location!.isNotEmpty)
            ? lead.location!
            : '-';
        final locationLine = _escapePdfText(locationStr, maxLength: 26);
        content.writeln(
          'BT /F1 7.5 Tf 0.25 0.25 0.25 rg ${col4X + 8} ${rowBottomY + 18} Td ($locationLine) Tj ET',
        );

        final targetWebUrl = (lead.website != null && lead.website!.trim().isNotEmpty)
            ? lead.website!.trim()
            : (lead.profileUrl.trim().isNotEmpty ? lead.profileUrl.trim() : '');
        final webLine = _escapePdfText(targetWebUrl.isNotEmpty ? targetWebUrl : '-', maxLength: 28);
        content.writeln(
          'BT /F1 7 Tf 0.50 0.50 0.50 rg ${col4X + 8} ${rowBottomY + 6} Td ($webLine) Tj ET',
        );

        if (targetWebUrl.isNotEmpty) {
          currentAnnots.add(
            _PdfLinkAnnot(
              llx: col4X + 6,
              lly: rowBottomY + 4,
              urx: col4X + 125,
              ury: rowBottomY + 16,
              uri: _ensureHttp(targetWebUrl),
            ),
          );
        }

        rowCurrentTopY -= rowHeight;
      }

      // Outer table border
      content.writeln('0.900 0.900 0.900 RG 0.75 w $marginX $rowCurrentTopY $tableWidth ${tableTopY - rowCurrentTopY} re S');

      // --- Footer (Apple HIG Minimal Footer) ---
      content.writeln('0.925 0.925 0.925 RG 0.75 w $marginX 46 m ${pageWidth - marginX} 46 l S');
      content.writeln(
        'BT /F1 7.5 Tf 0.50 0.50 0.50 rg $marginX 32 Td (GetLead Verified Discovery Report  |  Confidential) Tj ET',
      );
      final pageIndicator = _escapePdfText('Page $pageNum of $totalPages');
      content.writeln(
        'BT /F2 7.5 Tf 0.50 0.50 0.50 rg ${pageWidth - marginX - 60} 32 Td ($pageIndicator) Tj ET',
      );

      pageAnnots[i] = currentAnnots;
      pageContentStreams.add(utf8.encode(content.toString()));
    }

    // --- Compute Object IDs ---
    // Obj 1: Catalog
    // Obj 2: Pages Collection
    // Obj 3: Helvetica (F1)
    // Obj 4: Helvetica-Bold (F2)
    final pageObjIds = <int>[];
    final contentObjIds = <int>[];
    final annotObjIds = <List<int>>[];

    var nextId = 5;
    for (var i = 0; i < totalPages; i++) {
      pageObjIds.add(nextId++);
      contentObjIds.add(nextId++);
      final currentIds = <int>[];
      for (var k = 0; k < pageAnnots[i].length; k++) {
        currentIds.add(nextId++);
      }
      annotObjIds.add(currentIds);
    }

    final totalObjects = nextId - 1;
    objectOffsets = List<int>.filled(totalObjects + 1, 0);

    // --- Object 1: Catalog ---
    objectOffsets[1] = currentOffset();
    writeString('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // --- Object 2: Pages Collection ---
    final kidsList = pageObjIds.map((id) => '$id 0 R').join(' ');
    objectOffsets[2] = currentOffset();
    writeString(
      '2 0 obj\n'
      '<< /Type /Pages /Kids [$kidsList] /Count $totalPages >>\n'
      'endobj\n',
    );

    // --- Object 3: Helvetica (F1) ---
    objectOffsets[3] = currentOffset();
    writeString(
      '3 0 obj\n'
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n'
      'endobj\n',
    );

    // --- Object 4: Helvetica-Bold (F2) ---
    objectOffsets[4] = currentOffset();
    writeString(
      '4 0 obj\n'
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\n'
      'endobj\n',
    );

    // --- Page Objects, Streams, and Annotations ---
    for (var i = 0; i < totalPages; i++) {
      final pageObjId = pageObjIds[i];
      final contentObjId = contentObjIds[i];
      final streamBytes = pageContentStreams[i];
      final annots = pageAnnots[i];
      final currentAnnotIds = annotObjIds[i];

      final annotsRef = currentAnnotIds.isNotEmpty
          ? '/Annots [${currentAnnotIds.map((id) => '$id 0 R').join(' ')}]'
          : '';

      // Page Object
      objectOffsets[pageObjId] = currentOffset();
      writeString(
        '$pageObjId 0 obj\n'
        '<< /Type /Page /Parent 2 0 R '
        '/MediaBox [0 0 $pageWidth $pageHeight] '
        '/Contents $contentObjId 0 R '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '$annotsRef >>\n'
        'endobj\n',
      );

      // Content Stream Object
      objectOffsets[contentObjId] = currentOffset();
      writeString(
        '$contentObjId 0 obj\n'
        '<< /Length ${streamBytes.length} >>\n'
        'stream\n',
      );
      pdfBuffer.add(streamBytes);
      writeString('\nendstream\nendobj\n');

      // Link Annotation Objects
      for (var k = 0; k < annots.length; k++) {
        final annot = annots[k];
        final annotId = currentAnnotIds[k];
        final escapedUri = _escapePdfUri(annot.uri);

        objectOffsets[annotId] = currentOffset();
        writeString(
          '$annotId 0 obj\n'
          '<< /Type /Annot /Subtype /Link '
          '/Rect [${annot.llx.toStringAsFixed(2)} ${annot.lly.toStringAsFixed(2)} ${annot.urx.toStringAsFixed(2)} ${annot.ury.toStringAsFixed(2)}] '
          '/Border [0 0 0] '
          '/A << /Type /Action /S /URI /URI ($escapedUri) >> >>\n'
          'endobj\n',
        );
      }
    }

    // --- Cross Reference (XREF) Table ---
    final xrefOffset = currentOffset();
    writeString('xref\n0 ${totalObjects + 1}\n');
    writeString('0000000000 65535 f \n');

    for (var i = 1; i <= totalObjects; i++) {
      final offset = objectOffsets[i].toString().padLeft(10, '0');
      writeString('$offset 00000 n \n');
    }

    // --- Trailer ---
    writeString(
      'trailer\n'
      '<< /Size ${totalObjects + 1} /Root 1 0 R >>\n'
      'startxref\n'
      '$xrefOffset\n'
      '%%EOF\n',
    );

    return pdfBuffer.toBytes();
  }

  String _ensureHttp(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:') ||
        trimmed.startsWith('tel:')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String _escapePdfUri(String uri) {
    return uri
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  /// Cleans strings to standard printable ASCII, converting non-standard typography
  /// and escaping PDF special characters `(`, `)`, and `\`.
  String _escapePdfText(String text, {int maxLength = 100}) {
    var t = text.trim();
    if (t.length > maxLength) {
      t = '${t.substring(0, maxLength - 3)}...';
    }

    t = t
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('•', '-');

    final sb = StringBuffer();
    for (final codeUnit in t.codeUnits) {
      if (codeUnit >= 32 && codeUnit <= 126) {
        final char = String.fromCharCode(codeUnit);
        if (char == '(' || char == ')' || char == '\\') {
          sb.write('\\');
        }
        sb.write(char);
      } else {
        sb.write(' ');
      }
    }
    return sb.toString();
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month ${dt.day}, ${dt.year} $hour:$minute';
  }
}
