import 'dart:convert';
import 'dart:typed_data';

import '../models/lead_model.dart';

/// Lightweight, zero-dependency PDF 1.4 generator for GetLead reports.
/// Strictly conforms to PDF standard specifications, viewable in all native
/// PDF engines (Adobe Acrobat, Apple Preview, Google Chrome, WhatsApp, etc.).
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

    // Leads pagination setup
    // A4 size in points: 595.28 x 841.89
    const double pageWidth = 595.28;
    const double pageHeight = 841.89;
    const double marginX = 36.0;
    const double cardWidth = pageWidth - (marginX * 2); // 523.28 pt
    const double cardHeight = 62.0;
    const double cardGap = 8.0;

    // Page 1 has title banner (starts lower), later pages have mini header
    const double page1StartY = 735.0;
    const double laterStartY = 770.0;
    const double footerCutoffY = 65.0;

    final pages = <List<Lead>>[];
    if (leads.isEmpty) {
      pages.add([]);
    } else {
      var currentPageLeads = <Lead>[];
      var currentY = page1StartY;

      for (final lead in leads) {
        if (currentY - cardHeight < footerCutoffY) {
          pages.add(currentPageLeads);
          currentPageLeads = <Lead>[];
          currentY = laterStartY;
        }
        currentPageLeads.add(lead);
        currentY -= (cardHeight + cardGap);
      }
      if (currentPageLeads.isNotEmpty || pages.isEmpty) {
        pages.add(currentPageLeads);
      }
    }

    final totalPages = pages.length;

    // Object indexing:
    // Obj 1: Catalog
    // Obj 2: Pages tree
    // Obj 3: Font Helvetica (F1)
    // Obj 4: Font Helvetica-Bold (F2)
    // For each page i (0-based):
    //   Obj (5 + i*2): Page object
    //   Obj (6 + i*2): Content stream object
    final totalObjects = 4 + (totalPages * 2);

    // Placeholder offsets (1-indexed for convenience)
    objectOffsets = List<int>.filled(totalObjects + 1, 0);

    // --- Object 1: Catalog ---
    objectOffsets[1] = currentOffset();
    writeString('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // --- Object 2: Pages Collection ---
    final kidsList = <String>[];
    for (var i = 0; i < totalPages; i++) {
      kidsList.add('${5 + (i * 2)} 0 R');
    }
    objectOffsets[2] = currentOffset();
    writeString(
      '2 0 obj\n'
      '<< /Type /Pages /Kids [${kidsList.join(' ')}] /Count $totalPages >>\n'
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

    final displayNiche = (niche != null && niche.trim().isNotEmpty)
        ? niche.trim()
        : 'All Categories';
    final dateStr = _formatDate(DateTime.now());

    // --- Generate Pages & Content Streams ---
    for (var i = 0; i < totalPages; i++) {
      final pageNum = i + 1;
      final pageLeads = pages[i];
      final pageObjId = 5 + (i * 2);
      final contentObjId = 6 + (i * 2);

      // Prepare Page Content Stream
      final content = StringBuffer();

      // Background canvas: Pure White (#FFFFFF)
      content.writeln('1.0 1.0 1.0 rg 0 0 $pageWidth $pageHeight re f');

      // Top Apple HIG brand accent bar at top of page (3pt, OpenAI Green #10A37F)
      content.writeln('0.063 0.639 0.498 rg 0 ${pageHeight - 3} $pageWidth 3 re f');

      if (pageNum == 1) {
        // --- Page 1 Header Banner (Apple HIG Minimal Luxury Header) ---
        // Title: GetLead Agent (Pure Black #111111)
        content.writeln('BT /F2 18 Tf 0.067 0.067 0.067 rg $marginX 788 Td (GetLead Agent) Tj ET');
        // Accent Subtitle: Verified Lead Report (#10A37F)
        content.writeln('BT /F2 12 Tf 0.063 0.639 0.498 rg ${marginX + 148} 788 Td (- Lead Discovery Report) Tj ET');
        // Meta information (#666666)
        final metaText = _escapePdfText(
          'Niche: $displayNiche   |   Total Leads: ${leads.length}   |   Exported: $dateStr',
          maxLength: 100,
        );
        content.writeln('BT /F1 9 Tf 0.4 0.4 0.4 rg $marginX 768 Td ($metaText) Tj ET');

        // Hairline Divider (#ECECEC)
        content.writeln('0.925 0.925 0.925 RG 0.75 w $marginX 754 m ${pageWidth - marginX} 754 l S');
      } else {
        // --- Subsequent Pages Mini Header ---
        content.writeln('BT /F2 10 Tf 0.067 0.067 0.067 rg $marginX 806 Td (GetLead Agent) Tj ET');
        final headerMeta = _escapePdfText(
          '- $displayNiche   |   Page $pageNum of $totalPages',
          maxLength: 80,
        );
        content.writeln('BT /F1 9 Tf 0.4 0.4 0.4 rg ${marginX + 82} 806 Td ($headerMeta) Tj ET');
        // Hairline Divider (#ECECEC)
        content.writeln('0.925 0.925 0.925 RG 0.75 w $marginX 794 m ${pageWidth - marginX} 794 l S');
      }

      // --- Lead Cards ---
      var currentY = (pageNum == 1) ? page1StartY : laterStartY;

      for (var j = 0; j < pageLeads.length; j++) {
        final lead = pageLeads[j];
        final cardBottomY = currentY - cardHeight;

        // Card background fill (#F7F7F8 secondaryBackground)
        content.writeln('0.969 0.969 0.973 rg $marginX $cardBottomY $cardWidth $cardHeight re f');
        // Card border stroke (#ECECEC divider)
        content.writeln('0.925 0.925 0.925 RG 0.75 w $marginX $cardBottomY $cardWidth $cardHeight re S');
        // Left accent bar (#10A37F OpenAI Green)
        content.writeln('0.063 0.639 0.498 rg $marginX $cardBottomY 3 $cardHeight re f');

        // Line 1: Lead Title & Platform Badge
        final titleText = _escapePdfText(lead.displayName, maxLength: 55);
        content.writeln(
          'BT /F2 10.5 Tf 0.067 0.067 0.067 rg ${marginX + 10} ${cardBottomY + 45} Td ($titleText) Tj ET',
        );

        final platformBadge = _escapePdfText('[${lead.platform.toUpperCase()}]', maxLength: 20);
        content.writeln(
          'BT /F2 8 Tf 0.063 0.639 0.498 rg ${pageWidth - marginX - 75} ${cardBottomY + 45} Td ($platformBadge) Tj ET',
        );

        // Line 2: Email & Phone
        final emailStr = (lead.email != null && lead.email!.isNotEmpty)
            ? lead.email!
            : 'No email found';
        final phoneStr = (lead.phone != null && lead.phone!.isNotEmpty)
            ? lead.phone!
            : 'No phone found';
        final contactLine = _escapePdfText(
          'Email: $emailStr    |    Phone: $phoneStr',
          maxLength: 85,
        );
        content.writeln(
          'BT /F1 8.5 Tf 0.2 0.2 0.2 rg ${marginX + 10} ${cardBottomY + 29} Td ($contactLine) Tj ET',
        );

        // Line 3: Location, Website, & Category
        final locationStr = (lead.location != null && lead.location!.isNotEmpty)
            ? lead.location!
            : 'Location: Not specified';
        final webOrProfile = (lead.website != null && lead.website!.isNotEmpty)
            ? lead.website!
            : (lead.profileUrl.isNotEmpty ? lead.profileUrl : '');
        final webPart = webOrProfile.isNotEmpty ? '  |  Web: $webOrProfile' : '';
        final detailsLine = _escapePdfText(
          '$locationStr$webPart',
          maxLength: 95,
        );
        content.writeln(
          'BT /F1 8 Tf 0.45 0.45 0.45 rg ${marginX + 10} ${cardBottomY + 13} Td ($detailsLine) Tj ET',
        );

        currentY -= (cardHeight + cardGap);
      }

      // --- Footer (Apple HIG Minimal Footer) ---
      content.writeln('0.925 0.925 0.925 RG 0.75 w $marginX 46 m ${pageWidth - marginX} 46 l S');
      content.writeln(
        'BT /F1 8 Tf 0.54 0.54 0.54 rg $marginX 32 Td (GetLead Agent - Verified Business Lead Report) Tj ET',
      );
      final pageIndicator = _escapePdfText('Page $pageNum of $totalPages');
      content.writeln(
        'BT /F2 8 Tf 0.54 0.54 0.54 rg ${pageWidth - marginX - 60} 32 Td ($pageIndicator) Tj ET',
      );

      final streamBytes = utf8.encode(content.toString());

      // Write Page Object
      objectOffsets[pageObjId] = currentOffset();
      writeString(
        '$pageObjId 0 obj\n'
        '<< /Type /Page /Parent 2 0 R '
        '/MediaBox [0 0 $pageWidth $pageHeight] '
        '/Contents $contentObjId 0 R '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> >>\n'
        'endobj\n',
      );

      // Write Stream Object
      objectOffsets[contentObjId] = currentOffset();
      writeString(
        '$contentObjId 0 obj\n'
        '<< /Length ${streamBytes.length} >>\n'
        'stream\n',
      );
      pdfBuffer.add(streamBytes);
      writeString('\nendstream\nendobj\n');
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
