import '../models/app_models.dart';
import 'formula_evaluator.dart';

class QuotationSpecFormatter {
  QuotationSpecFormatter._();

  static const List<String> aluminumThicknessChoices = [
    'ตามรายการ',
    '1.2 มม.',
    '1.5 มม.',
    '1.8 มม.',
    '2.0 มม.',
    'ไม่ระบุ',
  ];

  static const List<String> aluminumColorChoices = [
    'ไม่ระบุ',
    'สีดำ',
    'สีขาวอบ',
    'สีชา',
    'สีเทาซาฮาร่า',
    'สีแชมเปญเกรย์',
    'สีชุบขาว (NA)',
    'ลายไม้',
    'ตัวดิบ (MILL)',
  ];

  static const List<String> glassTypeChoices = [
    'ไม่ระบุ',
    'กระจกใส',
    'กระจกเขียวตัดแสง',
    'กระจกชาดำ',
    'กระจกฝ้า',
    'กระจกเงา',
    'กระจกเทมเปอร์ใส',
    'กระจกเทมเปอร์เขียวตัดแสง',
    'กระจกลามิเนต',
    'ไม่รวมกระจก',
  ];

  static const List<String> glassThicknessChoices = [
    'ไม่ระบุ',
    '5 มม.',
    '6 มม.',
    '8 มม.',
    '10 มม.',
    '12 มม.',
  ];

  /// Formats the primary line title, e.g. `01 · ประตูบานเปิดคู่` or `D1 · ประตูบานเปิดคู่`.
  static String formatLineTitle(SavedProjectItem item, int oneBasedIdx) {
    final tag = item.displayOrderTag(oneBasedIdx);
    return '$tag · ${item.patternTitle}';
  }

  /// Resolves the exact human-readable profile brand & series name for quotations.
  static String formatProfileSeriesName(SavedProjectItem item) {
    final brandKey = item.priceBrandKey.toUpperCase();
    final bTitle = item.brandTitle.trim();
    final sTitle = item.systemTitle.trim();
    final opts = item.selectedOptions;

    switch (brandKey) {
      case 'MARKET':
        if (sTitle.contains('ยูเนี่ยน')) {
          return 'โปรไฟล์ชุดตลาด ยูเนี่ยน (ALUMET)';
        }
        if (sTitle.contains('สวิง')) {
          return 'โปรไฟล์ชุดตลาด บานสวิง (ALUMET)';
        }
        if (sTitle.contains('รางแขวน')) {
          return 'โปรไฟล์ชุดตลาด รางแขวนบน (ALUMET)';
        }
        final fMode = opts['frame_mode'];
        if (fMode == 'plain') {
          return 'โปรไฟล์ชุดตลาด ALUMET (เฟรมไม่ติดกล่อง)';
        }
        if (fMode == 'smooth_box') {
          return 'โปรไฟล์ชุดตลาด ALUMET (เฟรมกล่องเรียบ)';
        }
        if (fMode == 'box_frame') {
          return 'โปรไฟล์ชุดตลาด ALUMET (เฟรมติดกล่อง)';
        }
        return 'โปรไฟล์ชุดตลาด ALUMET';

      case 'SCHIMMER':
        if (sTitle.contains('HOMELIFE 200')) {
          return 'โปรไฟล์ SMS SCHIMMER รุ่น HOMELIFE 200';
        }
        if (sTitle.contains('HOMELIFE 250')) {
          return 'โปรไฟล์ SMS SCHIMMER รุ่น HOMELIFE 250';
        }
        if (sTitle.contains('HOMELIFE 260')) {
          return 'โปรไฟล์ SMS SCHIMMER รุ่น HOMELIFE 260';
        }
        if (sTitle.contains('240') ||
            bTitle.contains('240') ||
            item.patternId.contains('240') ||
            item.patternId.contains('sch_fold')) {
          return 'โปรไฟล์บานเฟี้ยม SMS SCHIMMER รุ่น HOMELIFE 240';
        }
        return 'โปรไฟล์ SMS SCHIMMER';

      case 'ALUMET':
        if (bTitle.contains('NEX') ||
            sTitle.contains('เน็กซ์') ||
            item.patternId.startsWith('c2_nex_')) {
          if (opts['nex_series'] == 'nex100' ||
              opts['lock_system'] == 'nex100') {
            return 'โปรไฟล์ ALUMET รุ่น NEX 100';
          }
          return 'โปรไฟล์ ALUMET รุ่น NEX 200';
        }
        if (bTitle.contains('Iconiq') || sTitle.contains('ICONIQ')) {
          return 'โปรไฟล์ยูโร ALUMET รุ่น ICONIQ Series';
        }
        if (bTitle.contains('Folding') || item.patternId.contains('fold')) {
          return 'โปรไฟล์บานเฟี้ยม ALUMET รุ่น Smart X Folding';
        }
        if (bTitle.contains('Smart X') || sTitle.contains('Smart X')) {
          if (opts['sash_angle'] == '45') {
            return 'โปรไฟล์ ALUMET รุ่น Smart X (กรอบบาน 45°)';
          }
          return 'โปรไฟล์ ALUMET รุ่น Smart X';
        }
        return 'โปรไฟล์ ALUMET';

      case 'ORM':
        if (bTitle.contains('Folding') || item.patternId.contains('fold_orm')) {
          if (sTitle.contains('101.6')) {
            return 'โปรไฟล์บานเฟี้ยม ORM Pano Suit (เฟรม 101.6 มม.)';
          }
          return 'โปรไฟล์บานเฟี้ยม ORM Pano Suit (เฟรม 90 มม.)';
        }
        if (bTitle.contains('Pano Suit') || sTitle.contains('Pano Suit')) {
          return 'โปรไฟล์ยูโร ORM รุ่น Pano Suit';
        }
        if (bTitle.contains('Asian Trop')) {
          return 'โปรไฟล์ ORM รุ่น Asian Trop';
        }
        return 'โปรไฟล์ ORM';

      case 'SMART_PLUS':
        if (bTitle.contains('บานเฟี้ยม') || item.patternId.contains('fold')) {
          return 'โปรไฟล์บานเฟี้ยม SMART PLUS รุ่น EURO';
        }
        if (bTitle.contains('Semi Euro')) {
          return 'โปรไฟล์ SMART PLUS รุ่น Semi Euro';
        }
        if (sTitle.contains('45°')) {
          return 'โปรไฟล์ยูโร SMART PLUS รุ่น EURO (เฟรม 45°)';
        }
        if (sTitle.contains('90°')) {
          return 'โปรไฟล์ยูโร SMART PLUS รุ่น EURO (เฟรม 90°)';
        }
        return 'โปรไฟล์ยูโร SMART PLUS รุ่น EURO';

      case 'FUJI':
        if (bTitle.contains('Folding') || item.patternId.contains('fold')) {
          if (sTitle.contains('ราง U')) {
            return 'โปรไฟล์บานเฟี้ยม Fuji Eurotech (ราง U)';
          }
          return 'โปรไฟล์บานเฟี้ยม Fuji Eurotech (รางมาตรฐาน)';
        }
        return 'โปรไฟล์ยูโร Fuji Eurotech';

      case 'UAI':
        if (sTitle.contains('Super Frame')) {
          return 'โปรไฟล์ UAI รุ่น Super Frame';
        }
        if (sTitle.contains('UAI-0024')) {
          return 'โปรไฟล์ UAI รุ่น UAI-0024';
        }
        if (sTitle.contains('UAI-0025')) {
          return 'โปรไฟล์ UAI รุ่น UAI-0025';
        }
        return 'โปรไฟล์ UAI';

      case 'ALUFRAME':
        return 'โปรไฟล์ยูโร ALUFRAME (อลูเฟรม)';

      default:
        if (bTitle.isNotEmpty &&
            sTitle.isNotEmpty &&
            !bTitle.toLowerCase().contains(sTitle.toLowerCase())) {
          return 'โปรไฟล์ $bTitle รุ่น $sTitle';
        }
        return bTitle.isNotEmpty ? 'โปรไฟล์ $bTitle' : 'โปรไฟล์อลูมิเนียม';
    }
  }

  /// Detects item-specific aluminum thickness from calculation options if present.
  static String? detectItemIntrinsicThickness(SavedProjectItem item) {
    final opts = item.selectedOptions;
    final explicit = opts['spec_alu_thick']?.trim() ?? '';
    if (explicit.isNotEmpty && explicit != 'ไม่ระบุ' && explicit != 'ตามรายการ') {
      return explicit;
    }

    final rawThick = opts['thickness']?.trim() ?? '';
    if (rawThick.isNotEmpty) {
      return rawThick.endsWith('มม.') ? rawThick : '$rawThick มม.';
    }

    // Smart Plus Euro window sash codes encode thickness
    if (item.patternId.contains('sp_win')) {
      final sash = opts['sash_code'];
      if (sash == '15117') return '1.2 มม.';
      if (sash == '15141') return '1.5 มม.';
    }
    return null;
  }

  /// Normalizes pricing catalog color names to customer-friendly Thai labels.
  static String normalizePricingColorForQuotation(String? rawPricingColor) {
    final c = rawPricingColor?.trim() ?? '';
    if (c.isEmpty || c.contains('MILL') || c.contains('ตัวดิบ')) {
      return 'ไม่ระบุ';
    }
    if (c.contains('ซุปเปอร์แบล็ค') || c.contains('อบดำ') || c == 'สีดำ') {
      return 'สีดำ';
    }
    if (c.contains('คอตตอน ไวท์') || c.contains('อบขาว') || c == 'สีขาวอบ') {
      return 'สีขาวอบ';
    }
    if (c.contains('ชุบขาว')) return 'สีชุบขาว (NA)';
    if (c.contains('เทาซาฮาร่า')) return 'สีเทาซาฮาร่า';
    if (c.contains('ทรายซาฮาร่า') || c.contains('สีชา')) return 'สีชา';
    if (c.contains('แชมเปญเกรย์')) return 'สีแชมเปญเกรย์';
    if (c.contains('ลายไม้')) return 'ลายไม้';
    return c;
  }

  /// Detects item-specific glass type & thickness saved during calculation input.
  static ({String glassType, String glassThickness}) detectItemGlassSpec(
    SavedProjectItem item,
  ) {
    final opts = item.selectedOptions;
    final savedType = opts['spec_glass_type']?.trim() ?? '';
    final savedThick = opts['spec_glass_thick']?.trim() ?? '';

    String gThick = savedThick;
    if (gThick.isEmpty) {
      final calcGlassThick = opts['glass_thick']?.trim() ?? '';
      if (calcGlassThick.isNotEmpty) {
        gThick = calcGlassThick.endsWith('มม.')
            ? calcGlassThick
            : '$calcGlassThick มม.';
      }
    }

    return (
      glassType: savedType.isEmpty ? 'ไม่ระบุ' : savedType,
      glassThickness: gThick.isEmpty ? 'ไม่ระบุ' : gThick,
    );
  }

  /// Detects mosquito screen note from calculation options if selected.
  static String? detectMosquitoNote(SavedProjectItem item) {
    final mosq = item.selectedOptions['mosquito']?.trim() ?? '';
    if (mosq == 'pleated') return 'เสริมมุ้งจีบ';
    if (mosq == 'security') return 'เสริมมุ้งนิรภัย (ตาข่ายสแตนเลส)';
    if (mosq == 'fiber' || mosq == 'small_mkt' || mosq == 'true') {
      return 'เสริมมุ้งไฟเบอร์';
    }
    return null;
  }

  /// Builds the structured multi-line specification subtitle for a quotation line item.
  static String buildItemSpecSubtitle({
    required SavedProjectItem item,
    required String globalAluThickness,
    required String globalAluColor,
    required String globalGlassType,
    required String globalGlassThickness,
    String customGlassNote = '',
  }) {
    final profileName = formatProfileSeriesName(item);

    // 1. Aluminum thickness resolution
    String? aluThick;
    if (globalAluThickness == 'ไม่ระบุ') {
      aluThick = null;
    } else if (globalAluThickness == 'ตามรายการ' || globalAluThickness.isEmpty) {
      aluThick = detectItemIntrinsicThickness(item);
    } else {
      // Even when global thickness is set, if the item itself explicitly forced 1.2/1.5 in formula, respect item's own spec_alu_thick if set, else global
      aluThick = globalAluThickness;
    }
    if (aluThick != null && aluThick.contains('ไม่ระบุ')) {
      aluThick = null;
    }

    // 2. Aluminum color resolution
    final itemColor = item.selectedOptions['spec_alu_color']?.trim() ?? '';
    String? aluColor;
    if (globalAluColor != 'ไม่ระบุ' && globalAluColor.trim().isNotEmpty) {
      aluColor = globalAluColor.trim();
    } else if (itemColor.isNotEmpty && itemColor != 'ไม่ระบุ') {
      aluColor = itemColor;
    }

    final line1Parts = <String>[
      profileName,
      if (aluThick != null && aluThick.isNotEmpty) 'ความหนา $aluThick',
      if (aluColor != null && aluColor.isNotEmpty) aluColor,
    ];

    // 3. Glass specification resolution
    final itemGlass = detectItemGlassSpec(item);
    final effGlassType =
        (globalGlassType != 'ไม่ระบุ' && globalGlassType.trim().isNotEmpty)
            ? globalGlassType.trim()
            : itemGlass.glassType;
    final effGlassThick = (globalGlassThickness != 'ไม่ระบุ' &&
            globalGlassThickness.trim().isNotEmpty)
        ? globalGlassThickness.trim()
        : itemGlass.glassThickness;

    String? glassPhrase;
    if (customGlassNote.trim().isNotEmpty) {
      glassPhrase = customGlassNote.trim();
    } else if (effGlassType == 'ไม่รวมกระจก') {
      glassPhrase = 'ไม่รวมกระจก';
    } else if (effGlassType != 'ไม่ระบุ' && effGlassThick != 'ไม่ระบุ') {
      glassPhrase = '$effGlassType หนา $effGlassThick';
    } else if (effGlassType != 'ไม่ระบุ') {
      glassPhrase = effGlassType;
    } else if (effGlassThick != 'ไม่ระบุ') {
      glassPhrase = 'กระจกหนา $effGlassThick';
    }

    final mosqNote = detectMosquitoNote(item);
    final line2Parts = <String>[
      if (glassPhrase != null && glassPhrase.isNotEmpty) glassPhrase,
      ?mosqNote,
    ];

    final outLines = <String>[
      line1Parts.join(' · '),
      if (line2Parts.isNotEmpty) line2Parts.join(' · '),
      if (item.installLocation.trim().isNotEmpty)
        'ตำแหน่งติดตั้ง: ${item.installLocation.trim()}',
    ];

    return outLines.join('\n');
  }

  /// Formats clean quotation dimensions in millimeters (`1500 × 2000 มม.`).
  static String formatQuotationSize(SavedProjectItem item) {
    if (item.sizeRows.isEmpty) return '-';
    final isCorner = item.patternId.contains('corner');
    if (item.sizeRows.length == 1) {
      final r = item.sizeRows.first;
      final wPart = (isCorner && r.auxMm != null)
          ? '${FormulaEvaluator.formatMm(r.widthMm)}+${FormulaEvaluator.formatMm(r.auxMm!)}'
          : FormulaEvaluator.formatMm(r.widthMm);
      return '$wPart × ${FormulaEvaluator.formatMm(r.heightMm)} มม.';
    }
    return item.sizeRows.map((r) {
      final wPart = (isCorner && r.auxMm != null)
          ? '${FormulaEvaluator.formatMm(r.widthMm)}+${FormulaEvaluator.formatMm(r.auxMm!)}'
          : FormulaEvaluator.formatMm(r.widthMm);
      return '$wPart × ${FormulaEvaluator.formatMm(r.heightMm)} มม. (${r.qty} ชุด)';
    }).join('\n');
  }
}
