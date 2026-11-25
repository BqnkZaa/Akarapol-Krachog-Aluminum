import '../models/app_models.dart';
import 'seed_repository.dart';

class CatalogDefinitions {
  CatalogDefinitions._();

  /// Universal 3-type mosquito screen selector injected automatically on every
  /// operable door/window profile across all categories EXCEPT fixed windows
  /// (`บานติดตาย`) and frameless shower systems.
  static const OptionGroupDef universalMosquitoOptionGroup = OptionGroupDef(
    id: 'mosquito',
    title: 'ประเภทมุ้งลวด (เลือกเสริมได้ 3 แบบ)',
    choices: [
      OptionChoice(id: 'none', label: 'ไม่มีมุ้ง'),
      OptionChoice(id: 'fiber', label: 'มุ้งไฟเบอร์'),
      OptionChoice(id: 'pleated', label: 'มุ้งจีบ'),
      OptionChoice(id: 'security', label: 'มุ้งนิรภัย'),
    ],
    defaultValue: 'none',
  );

  /// Returns `true` when [pattern] represents a pure fixed window / transom /
  /// frameless shower system that MUST NOT include mosquito screen options.
  static bool isFixedOnlyPattern(
    PatternCardDef pattern, {
    String? categoryId,
    String? systemId,
  }) {
    if (categoryId == 'cat5_shower') return true;
    final sys = (systemId ?? '').toLowerCase();
    if (sys.contains('fixed') || sys.endsWith('_fix') || sys.contains('_fix_')) {
      return true;
    }
    final pid = pattern.id.toLowerCase();
    if (pid.contains('_fix')) {
      return true;
    }
    final title = pattern.title.toLowerCase();
    final hasOperableWord = title.contains('เลื่อน') ||
        title.contains('เปิด') ||
        title.contains('กระทุ้ง') ||
        title.contains('เฟี้ยม') ||
        title.contains('สวิง') ||
        title.contains('รางแขวน') ||
        title.contains('ชุดผสม');
    if (!hasOperableWord &&
        (title.contains('ติดตาย') ||
            title.contains('ช่องแสงเดี่ยว') ||
            title.contains('ช่องแสงแบ่ง') ||
            title.contains('บานฟิก') ||
            title.contains('fixed'))) {
      return true;
    }
    return false;
  }

  /// Returns the effective list of [OptionGroupDef]s for [pattern],
  /// automatically appending [universalMosquitoOptionGroup] to every operable
  /// profile (except fixed windows & shower systems).
  static List<OptionGroupDef> effectiveOptionGroupsFor(
    PatternCardDef pattern, {
    String? categoryId,
    String? systemId,
  }) {
    if (isFixedOnlyPattern(
      pattern,
      categoryId: categoryId,
      systemId: systemId,
    )) {
      return pattern.optionGroups;
    }
    if (pattern.optionGroups.any((g) => g.id == 'mosquito')) {
      return pattern.optionGroups;
    }
    return [...pattern.optionGroups, universalMosquitoOptionGroup];
  }

  /// Looks up a [PatternCardDef] and its full catalog ancestry by [patternId],
  /// searching both built-in catalogs and user-defined Custom Studio systems.
  static ({
    CategoryDef category,
    BrandDef? brand,
    SubSystemDef? system,
    PatternCardDef pattern,
  })? findPatternById(
    String patternId, [
    List<CustomProfileSystem>? customOverride,
  ]) {
    final cats = mergedCategories(customOverride);
    for (final cat in cats) {
      for (final sys in cat.directSystems) {
        for (final pat in sys.patterns) {
          if (pat.id == patternId) {
            return (category: cat, brand: null, system: sys, pattern: pat);
          }
        }
        for (final tab in sys.subTabs) {
          for (final pat in tab.patterns) {
            if (pat.id == patternId) {
              return (category: cat, brand: null, system: tab, pattern: pat);
            }
          }
        }
      }
      for (final br in cat.brands) {
        for (final pat in br.directPatterns) {
          if (pat.id == patternId) {
            return (category: cat, brand: br, system: null, pattern: pat);
          }
        }
        for (final sys in br.systems) {
          for (final pat in sys.patterns) {
            if (pat.id == patternId) {
              return (category: cat, brand: br, system: sys, pattern: pat);
            }
          }
          for (final tab in sys.subTabs) {
            for (final pat in tab.patterns) {
              if (pat.id == patternId) {
                return (category: cat, brand: br, system: tab, pattern: pat);
              }
            }
          }
        }
      }
    }
    return null;
  }

  /// Merges built-in categories with any user-created [CustomProfileSystem]s.
  static List<CategoryDef> mergedCategories([
    List<CustomProfileSystem>? customOverride,
  ]) {
    final customs = customOverride ?? SeedRepository.instance.customSystems;
    if (customs.isEmpty) return categories;

    return categories.map((cat) {
      final forCat = customs.where((c) => c.categoryId == cat.id).toList();
      if (forCat.isEmpty) return cat;

      // Category 1 uses directSystems (no brand layer)
      if (cat.directSystems.isNotEmpty && cat.brands.isEmpty) {
        final nextSystems = List<SubSystemDef>.from(cat.directSystems);
        for (final cs in forCat) {
          final pat = cs.toPatternCardDef();
          final sysTitle = cs.systemTitle.trim().isEmpty
              ? 'ชุดตลาดเพิ่มเติม'
              : cs.systemTitle.trim();
          final idx = nextSystems.indexWhere((s) => s.title == sysTitle);
          if (idx >= 0) {
            final existing = nextSystems[idx];
            nextSystems[idx] = SubSystemDef(
              id: existing.id,
              title: existing.title,
              subtitle: existing.subtitle,
              enabled: true,
              patterns: [...existing.patterns, pat],
              subTabs: existing.subTabs,
            );
          } else {
            nextSystems.add(
              SubSystemDef(
                id: 'cust_sys_${cs.id}',
                title: sysTitle,
                subtitle: cs.brandTitle.isNotEmpty
                    ? cs.brandTitle
                    : 'ชุดโปรไฟล์ที่เพิ่มเอง',
                patterns: [pat],
              ),
            );
          }
        }
        return CategoryDef(
          id: cat.id,
          title: cat.title,
          subtitle: cat.subtitle,
          enabled: true,
          directSystems: nextSystems,
        );
      }

      // Categories 2–5 use brands
      final nextBrands = List<BrandDef>.from(cat.brands);
      for (final cs in forCat) {
        final pat = cs.toPatternCardDef();
        final bIdx = nextBrands.indexWhere(
          (b) =>
              b.id == cs.brandId ||
              b.title.toLowerCase() == cs.brandTitle.trim().toLowerCase(),
        );
        final sysTitle = cs.systemTitle.trim().isEmpty
            ? 'ชุดระบบโปรไฟล์'
            : cs.systemTitle.trim();

        if (bIdx >= 0) {
          final existingB = nextBrands[bIdx];
          if (existingB.directPatterns.isNotEmpty && existingB.systems.isEmpty) {
            nextBrands[bIdx] = BrandDef(
              id: existingB.id,
              title: existingB.title,
              subtitle: existingB.subtitle,
              priceBrandKey: existingB.priceBrandKey,
              enabled: true,
              directPatterns: [...existingB.directPatterns, pat],
            );
          } else {
            final nextSys = List<SubSystemDef>.from(existingB.systems);
            final sIdx = nextSys.indexWhere((s) => s.title == sysTitle);
            if (sIdx >= 0) {
              final exSys = nextSys[sIdx];
              nextSys[sIdx] = SubSystemDef(
                id: exSys.id,
                title: exSys.title,
                subtitle: exSys.subtitle,
                enabled: true,
                patterns: [...exSys.patterns, pat],
                subTabs: exSys.subTabs,
              );
            } else {
              nextSys.add(
                SubSystemDef(
                  id: 'cust_sub_${cs.id}',
                  title: sysTitle,
                  subtitle: 'ชุดโปรไฟล์ที่เพิ่มเอง',
                  patterns: [pat],
                ),
              );
            }
            nextBrands[bIdx] = BrandDef(
              id: existingB.id,
              title: existingB.title,
              subtitle: existingB.subtitle,
              priceBrandKey: existingB.priceBrandKey,
              enabled: true,
              systems: nextSys,
            );
          }
        } else {
          nextBrands.add(
            BrandDef(
              id: cs.brandId,
              title: cs.brandTitle.trim(),
              subtitle: sysTitle,
              priceBrandKey: cs.priceBrandKey.trim().toUpperCase(),
              enabled: true,
              systems: [
                SubSystemDef(
                  id: 'cust_sub_${cs.id}',
                  title: sysTitle,
                  subtitle: 'ชุดโปรไฟล์ที่เพิ่มเอง',
                  patterns: [pat],
                ),
              ],
            ),
          );
        }
      }

      return CategoryDef(
        id: cat.id,
        title: cat.title,
        subtitle: cat.subtitle,
        enabled: true,
        brands: nextBrands,
      );
    }).toList();
  }

  // ===========================================================================
  // Reusable Option Groups (Verbatim Thai Labels from Toolkit v0.1.7)
  // ===========================================================================
  static const List<OptionGroupDef> marketSlidingOptions = [
    OptionGroupDef(
      id: 'usage_type',
      title: 'ประเภทงาน',
      choices: [
        OptionChoice(
            id: 'window',
            label: 'หน้าต่าง',
            subtitle: 'ใช้สูตรมาตรฐานตามประเภทงาน'),
        OptionChoice(
            id: 'door',
            label: 'ประตู',
            subtitle: 'ใช้สูตรมาตรฐานตามประเภทงาน'),
        OptionChoice(
            id: 'ext_door',
            label: 'ประตูภายนอก',
            subtitle: 'แทนมือจับล็อกธรรมดา 1 ชุดด้วยรุ่นมีกุญแจ'),
      ],
      defaultValue: 'window',
    ),
    OptionGroupDef(
      id: 'frame_mode',
      title: 'ระบบเฟรม',
      choices: [
        OptionChoice(
            id: 'plain',
            label: 'เฟรมไม่ติดกล่อง',
            subtitle: 'สูตรเจ้าของโครงการ (พร้อมใช้งาน)'),
        OptionChoice(
            id: 'smooth_box',
            label: 'เฟรมไม่ติดกล่อง + กล่องเรียบ',
            subtitle: 'สูตรเจ้าของโครงการ (พร้อมใช้งาน)'),
        OptionChoice(
            id: 'box_frame',
            label: 'เฟรมติดกล่อง',
            subtitle: 'สูตรเจ้าของโครงการ (พร้อมใช้งาน)'),
      ],
      defaultValue: 'plain',
    ),
    OptionGroupDef(
      id: 'bumper_rubber',
      title: 'ยางกันกระแทก',
      choices: [
        OptionChoice(id: 'round', label: 'ยางกันกระแทกแบบกลม'),
        OptionChoice(id: 'square', label: 'ยางกันกระแทกแบบสี่เหลี่ยม'),
      ],
      defaultValue: 'round',
    ),
  ];

  static const List<OptionGroupDef> marketUnionOptions = [
    OptionGroupDef(
      id: 'hinge_size',
      title: 'ขนาดบานพับกระทุ้งยูเนี่ยน',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '4 นิ้ว', label: '4 นิ้ว'),
        OptionChoice(id: '6 นิ้ว', label: '6 นิ้ว'),
        OptionChoice(id: '8 นิ้ว', label: '8 นิ้ว'),
      ],
      defaultValue: '6 นิ้ว',
    ),
    OptionGroupDef(
      id: 'handle_side',
      title: 'ทิศทางมือจับ',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: 'ซ้าย', label: 'ซ้าย'),
        OptionChoice(id: 'ขวา', label: 'ขวา'),
      ],
      defaultValue: 'ซ้าย',
    ),
  ];

  static const List<OptionGroupDef> ormAsianSlidingOptions = [
    OptionGroupDef(
      id: 'usage_type',
      title: 'ประเภทงาน',
      choices: [
        OptionChoice(id: 'door', label: 'ประตู'),
        OptionChoice(id: 'window', label: 'หน้าต่าง'),
      ],
      defaultValue: 'door',
    ),
    OptionGroupDef(
      id: 'stile_size',
      title: 'ขนาดเสา',
      choices: [
        OptionChoice(id: '53', label: '53 มม.'),
        OptionChoice(id: '65', label: '65 มม.'),
        OptionChoice(id: '75', label: '75 มม.'),
      ],
      defaultValue: '53',
    ),
    OptionGroupDef(
      id: 'jamb_size',
      title: 'เฟรมข้าง',
      choices: [
        OptionChoice(id: '20', label: '20 มม.'),
        OptionChoice(id: '30', label: '30 มม.'),
      ],
      defaultValue: '20',
    ),
    OptionGroupDef(
      id: 'sill_type',
      title: 'ธรณีล่าง',
      choices: [
        OptionChoice(id: 'low', label: 'ธรณีต่ำ'),
        OptionChoice(id: 'high', label: 'ธรณีสูง'),
      ],
      defaultValue: 'low',
    ),
  ];

  static const List<OptionGroupDef> ormAsianCasementOptions = [
    OptionGroupDef(
      id: 'open_mode',
      title: 'ประเภทบาน',
      choices: [
        OptionChoice(id: 'awning', label: 'บานกระทุ้ง'),
        OptionChoice(id: 'casement', label: 'บานเปิด'),
      ],
      defaultValue: 'awning',
    ),
    OptionGroupDef(
      id: 'outer_frame',
      title: 'วงกบนอก',
      choices: [
        OptionChoice(id: '803-01', label: '803-01 · 9 ซม.'),
        OptionChoice(id: '802-06', label: '802-06 · 4 นิ้ว'),
      ],
      defaultValue: '803-01',
    ),
    OptionGroupDef(
      id: 'bead_code',
      title: 'ร่องกระจก / คิ้ว',
      choices: [
        OptionChoice(id: '803-04', label: '12.6 mm · 803-04'),
        OptionChoice(id: '803-05', label: '16.9 mm · 803-05'),
      ],
      defaultValue: '803-04',
    ),
    OptionGroupDef(
      id: 'striker_code',
      title: 'จุดรับล็อค',
      choices: [
        OptionChoice(id: 'HD-1100', label: 'HD-1100 · รุ่นเจาะ'),
        OptionChoice(id: 'HD-1101', label: 'HD-1101 · รุ่นสกรู'),
      ],
      defaultValue: 'HD-1100',
    ),
  ];

  static const List<OptionGroupDef> schimmer250Options = [
    OptionGroupDef(
      id: 'glass_thick',
      title: 'ความหนากระจก',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '5', label: 'กระจก 5 มม.'),
        OptionChoice(id: '6', label: 'กระจก 6 มม.'),
      ],
      defaultValue: '5',
    ),
    OptionGroupDef(
      id: 'handle_set',
      title: 'ชุดมือจับ',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(
            id: '00-024', label: '00-024 · มือจับมอร์ทิสล็อกสเตนเลสแบบโค้ง'),
      ],
      defaultValue: '00-024',
    ),
    OptionGroupDef(
      id: 'sash_seal',
      title: 'ซีลกรอบบาน',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '02-031', label: '02-031 · ซีลกรอบบานโฟม'),
      ],
      defaultValue: '02-031',
    ),
  ];

  static const List<OptionGroupDef> schimmer260Options = [
    OptionGroupDef(
      id: 'glass_thick',
      title: 'ความหนากระจก',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '5', label: 'กระจก 5 มม.'),
        OptionChoice(id: '6', label: 'กระจก 6 มม.'),
      ],
      defaultValue: '5',
    ),
    OptionGroupDef(
      id: 'hinge_family',
      title: 'ตระกูลบานพับแขนค้ำ',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '03-001', label: 'บานพับแขนค้ำ 03-001-XX'),
        OptionChoice(id: '03-006', label: 'บานพับแขนค้ำ 03-006-XX'),
      ],
      defaultValue: '03-001',
    ),
    OptionGroupDef(
      id: 'hinge_size',
      title: 'ขนาดบานพับแขนค้ำ',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '08', label: '8 นิ้ว'),
        OptionChoice(id: '10', label: '10 นิ้ว'),
        OptionChoice(id: '12', label: '12 นิ้ว'),
        OptionChoice(id: '14', label: '14 นิ้ว'),
        OptionChoice(id: '16', label: '16 นิ้ว'),
        OptionChoice(id: '18', label: '18 นิ้ว'),
      ],
      defaultValue: '08',
    ),
    OptionGroupDef(
      id: 'handle',
      title: 'มือจับ',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(
            id: '00-017-R · มือจับสี่เหลี่ยม · ขวา',
            label: '00-017-R · มือจับสี่เหลี่ยม · ขวา'),
        OptionChoice(
            id: '00-017-L · มือจับสี่เหลี่ยม · ซ้าย',
            label: '00-017-L · มือจับสี่เหลี่ยม · ซ้าย'),
        OptionChoice(
            id: '00-018-R · มือจับโค้ง · ขวา',
            label: '00-018-R · มือจับโค้ง · ขวา'),
        OptionChoice(
            id: '00-018-L · มือจับโค้ง · ซ้าย',
            label: '00-018-L · มือจับโค้ง · ซ้าย'),
      ],
      defaultValue: '00-017-L · มือจับสี่เหลี่ยม · ซ้าย',
    ),
    OptionGroupDef(
      id: 'drip_tray',
      title: 'ถาดรองน้ำ (ตัวเลือก)',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: 'none', label: 'ไม่ใช้ถาดรองน้ำ'),
        OptionChoice(id: 'B10016', label: 'B10016 · ถาดรองน้ำ 112 มม.'),
        OptionChoice(id: 'B10019', label: 'B10019 · ถาดรองน้ำ 105 มม.'),
        OptionChoice(id: 'B10023', label: 'B10023 · ถาดรองน้ำ 101.6 มม.'),
      ],
      defaultValue: 'none',
    ),
    OptionGroupDef(
      id: 'add_backing_plate',
      title: 'เพิ่มแผ่นรองบานพับแขนค้ำ 03-007-XX',
      controlType: OptionControlType.checkbox,
      choices: [
        OptionChoice(id: 'false', label: 'ไม่เพิ่ม'),
        OptionChoice(id: 'true', label: 'เพิ่มแผ่นรองบานพับแขนค้ำ 03-007-XX'),
      ],
      defaultValue: 'false',
    ),
    OptionGroupDef(
      id: 'add_rivet',
      title: 'เพิ่มรีเวท 4.8 มม. (ตัวเลือก)',
      controlType: OptionControlType.checkbox,
      choices: [
        OptionChoice(id: 'false', label: 'ไม่เพิ่ม'),
        OptionChoice(id: 'true', label: 'เพิ่มรีเวท 4.8 มม. (ตัวเลือก)'),
      ],
      defaultValue: 'false',
    ),
  ];

  static const List<OptionGroupDef> alumetSmartXSlidingOptions = [
    OptionGroupDef(
      id: 'thickness',
      title: 'ความหนาอะลูมิเนียม',
      choices: [
        OptionChoice(id: '1.2', label: '1.2 มม.'),
        OptionChoice(id: '1.5', label: '1.5 มม.'),
      ],
      defaultValue: '1.2',
    ),
    OptionGroupDef(
      id: 'sash_angle',
      title: 'ประเภทกรอบบาน',
      choices: [
        OptionChoice(id: '90', label: 'กรอบบาน 90°'),
        OptionChoice(id: '45', label: 'กรอบบาน 45°'),
      ],
      defaultValue: '90',
    ),
    OptionGroupDef(
      id: 'roller_type',
      title: 'ชนิดล้อกรอบบาน',
      choices: [
        OptionChoice(id: 'cartridge', label: 'ล้อตลับ'),
        OptionChoice(id: 'market', label: 'ล้อตลาด'),
      ],
      defaultValue: 'cartridge',
    ),
    OptionGroupDef(
      id: 'mosquito',
      title: 'ประเภทมุ้งลวด (เลือกเสริมได้ 3 แบบ)',
      choices: [
        OptionChoice(id: 'none', label: 'ไม่มีมุ้ง'),
        OptionChoice(id: 'small_mkt', label: 'มุ้งไฟเบอร์ (ตลาดเล็ก)'),
        OptionChoice(id: 'pleated', label: 'มุ้งจีบ'),
        OptionChoice(id: 'security', label: 'มุ้งนิรภัย'),
      ],
      defaultValue: 'none',
    ),
  ];

  static const List<OptionGroupDef> alumetNexSlidingOptions = [
    OptionGroupDef(
      id: 'nex_series',
      title: 'รุ่นระบบ อลูเม็ท เน็กซ์',
      choices: [
        OptionChoice(
          id: 'nex200',
          label: 'เน็กซ์ 200 (ทั้งระบบ)',
          subtitle: 'เสากุญแจ PS-0206 / PS-0209 · เสาเกี่ยว PS-0208 · เสริมรับล็อก PS-0111',
        ),
        OptionChoice(
          id: 'nex100',
          label: 'เน็กซ์ 100 (วงกบเน็กซ์ + เสามาตรฐาน)',
          subtitle: 'ใช้เสากุญแจ 4011 · เสาเกี่ยว 4012 ร่วมกับวงกบเน็กซ์',
        ),
      ],
      defaultValue: 'nex200',
    ),
    OptionGroupDef(
      id: 'usage_type',
      title: 'ประเภทบาน (ขนาดเสากุญแจ)',
      choices: [
        OptionChoice(id: 'door', label: 'ประตู (เสา 55.5 มม.)'),
        OptionChoice(id: 'window', label: 'หน้าต่าง (เสา 40 มม.)'),
      ],
      defaultValue: 'door',
    ),
    OptionGroupDef(
      id: 'roller_type',
      title: 'ชนิดขวางบน-ล่างและล้อ',
      choices: [
        OptionChoice(id: 'cartridge', label: 'ล้อตลับ (PS-0207 · 51 มม.)'),
        OptionChoice(id: 'market', label: 'ล้อตลาด (PS-0210 · 59.4 มม.)'),
      ],
      defaultValue: 'cartridge',
    ),
    OptionGroupDef(
      id: 'mosquito',
      title: 'ประเภทมุ้งลวด (เลือกเสริมได้ 3 แบบ)',
      choices: [
        OptionChoice(id: 'none', label: 'ไม่มีมุ้ง'),
        OptionChoice(id: 'fiber', label: 'มุ้งไฟเบอร์ (กรอบ 2006 + 4017)'),
        OptionChoice(id: 'pleated', label: 'มุ้งจีบ'),
        OptionChoice(id: 'security', label: 'มุ้งนิรภัย'),
      ],
      defaultValue: 'none',
    ),
  ];

  static const List<OptionGroupDef> alumetNexCasementOptions = [
    OptionGroupDef(
      id: 'lock_system',
      title: 'ระบบล็อก อลูเม็ท เน็กซ์',
      choices: [
        OptionChoice(
          id: 'nex200',
          label: 'เน็กซ์ 200 · มัลติพอยท์ล็อก',
          subtitle: 'เฟรม PC-0104 / PC-0105 · กรอบบาน PC-0204',
        ),
        OptionChoice(
          id: 'nex100',
          label: 'เน็กซ์ 100 · ซิงเกิลล็อก',
          subtitle: 'กล่องก้าน 030065 · กรอบบาน PC-0203',
        ),
      ],
      defaultValue: 'nex200',
    ),
    OptionGroupDef(
      id: 'open_mode',
      title: 'รูปแบบการเปิด',
      choices: [
        OptionChoice(id: 'awning', label: 'บานกระทุ้ง'),
        OptionChoice(id: 'casement', label: 'บานเปิด'),
      ],
      defaultValue: 'awning',
    ),
  ];

  static const List<OptionGroupDef> ormPanoSlidingOptions = [
    OptionGroupDef(
      id: 'sash_code',
      title: 'หน้าตัดกรอบบาน',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '804-20', label: '804-20'),
        OptionChoice(id: '804-15', label: '804-15'),
      ],
      defaultValue: '804-20',
    ),
  ];

  static const List<OptionGroupDef> fujiSlidingOptions = [
    OptionGroupDef(
      id: 'sash_code',
      title: 'กรอบบาน',
      choices: [
        OptionChoice(id: 'F7980', label: 'F7980 · ประตู'),
        OptionChoice(id: 'F7981', label: 'F7981 · หน้าต่าง'),
      ],
      defaultValue: 'F7980',
    ),
    OptionGroupDef(
      id: 'track_mode',
      title: 'ระบบราง',
      choices: [
        OptionChoice(id: '3t', label: 'ระบบ 3 ราง'),
        OptionChoice(id: '2t', label: 'ระบบ 2 ราง'),
      ],
      defaultValue: '3t',
    ),
    OptionGroupDef(
      id: 'mosquito',
      title: 'ประเภทมุ้งลวด (เลือกเสริมได้ 3 แบบ)',
      choices: [
        OptionChoice(id: 'none', label: 'ไม่มีมุ้ง'),
        OptionChoice(id: 'true', label: 'มุ้งไฟเบอร์ (กรอบ F7982)'),
        OptionChoice(id: 'pleated', label: 'มุ้งจีบ'),
        OptionChoice(id: 'security', label: 'มุ้งนิรภัย'),
      ],
      defaultValue: 'none',
    ),
  ];

  static const List<OptionGroupDef> iconiqSlidingOptions = [
    OptionGroupDef(
      id: 'location_type',
      title: 'ตำแหน่งใช้งาน',
      choices: [
        OptionChoice(id: 'ext', label: 'ภายนอก'),
        OptionChoice(id: 'int', label: 'ภายใน'),
      ],
      defaultValue: 'ext',
    ),
    OptionGroupDef(
      id: 'bead_code',
      title: 'คิ้วกระจก',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: 'iS-0202', label: 'iS-0202 · มาตรฐาน'),
        OptionChoice(
            id: 'iS-0204', label: 'iS-0204 · กระจกทางเลือก (ระยะตัดรอยืนยัน)'),
      ],
      defaultValue: 'iS-0202',
    ),
  ];

  static const List<OptionGroupDef> smartPlusEuroSlidingOptions = [
    OptionGroupDef(
      id: 'sash_code',
      title: 'กรอบบานเลื่อน',
      controlType: OptionControlType.dropdown,
      choices: [
        OptionChoice(id: '15146', label: '15146 กรอบบานเลื่อน 70 มม.'),
        OptionChoice(
            id: '15147', label: '15147 กรอบบานเลื่อนเปิดคิ้ว 70 มม.'),
        OptionChoice(id: '15209', label: '15209 กรอบบานเลื่อน 95 มม.'),
      ],
      defaultValue: '15146',
    ),
  ];

  static const List<OptionGroupDef> smartPlusEuroWinOptions = [
    OptionGroupDef(
      id: 'sash_code',
      title: 'ความหนาและรหัสกรอบบาน',
      choices: [
        OptionChoice(id: '15117', label: '1.2 มม. — 15117'),
        OptionChoice(id: '15141', label: '1.5 มม. — 15141'),
      ],
      defaultValue: '15117',
    ),
  ];

  static const List<OptionGroupDef> smartPlusEuroWinTopOptions = [
    OptionGroupDef(
      id: 'sash_code',
      title: 'ความหนาและรหัสกรอบบาน',
      choices: [
        OptionChoice(id: '15117', label: '1.2 มม. — 15117'),
        OptionChoice(id: '15141', label: '1.5 มม. — 15141'),
      ],
      defaultValue: '15117',
    ),
    OptionGroupDef(
      id: 'transom_cols',
      title: 'แบ่งช่องแสงบน',
      choices: [
        OptionChoice(id: '1', label: '1 ช่อง'),
        OptionChoice(id: '2', label: '2 ช่อง'),
        OptionChoice(id: '3', label: '3 ช่อง'),
        OptionChoice(id: '4', label: '4 ช่อง'),
      ],
      defaultValue: '1',
    ),
  ];

  static const List<OptionGroupDef> smartPlusEuroDoorOptions = [
    OptionGroupDef(
      id: 'sash_code',
      title: 'กรอบบานประตู',
      choices: [
        OptionChoice(id: '15141', label: '15141 — กรอบบานกระทุ้ง 80 มิล'),
        OptionChoice(id: '15144', label: '15144 — กรอบบานกระทุ้ง 100 มิล'),
      ],
      defaultValue: '15141',
    ),
  ];

  static const List<OptionGroupDef> aluframeSlidingOptions = [
    OptionGroupDef(
      id: 'stile_width',
      title: 'ขนาดเสากุญแจ',
      choices: [
        OptionChoice(id: '77', label: '77 มม.'),
        OptionChoice(id: '87', label: '87 มม.'),
      ],
      defaultValue: '77',
    ),
  ];

  // ===========================================================================
  // Helper builders for Category 4 (All 136 Active Folding Cards!)
  // ===========================================================================
  static List<PatternCardDef> _buildOrmFoldingCards(
      {required bool is101Mm}) {
    const layouts = [
      [2, 2, 0],
      [3, 2, 1],
      [4, 3, 1],
      [4, 2, 2],
      [5, 4, 1],
      [5, 3, 2],
      [6, 5, 1],
      [6, 4, 2],
      [6, 3, 3],
      [7, 6, 1],
      [7, 5, 2],
      [7, 4, 3],
      [8, 7, 1],
      [8, 6, 2],
      [8, 5, 3],
      [8, 4, 4],
    ];
    final fam = is101Mm ? 'orm101' : 'orm90';
    final sizeLabel = is101Mm ? '101.6 mm' : '90 mm';
    return layouts.map((cfg) {
      final n = cfg[0], l = cfg[1], r = cfg[2];
      final code = '$n-$l-$r';
      return PatternCardDef(
        id: 'fold_${fam}_$code',
        title: 'บานเฟี้ยม $code',
        subtitle: 'เฟรม $sizeLabel · พับซ้าย $l ขวา $r',
        foldingFamily: fam,
        foldingTotalPanels: n,
        foldingLeftPanels: l,
        foldingRightPanels: r,
        optionGroups: const [
          OptionGroupDef(
            id: 'sill_mode',
            title: 'รูปแบบเฟรมล่าง',
            choices: [
              OptionChoice(id: 'std', label: 'เฟรมล่างมาตรฐาน'),
              OptionChoice(id: 'low', label: 'รางธรณีต่ำ'),
            ],
            defaultValue: 'std',
          ),
        ],
      );
    }).toList();
  }

  static List<PatternCardDef> _buildFujiFoldingCards({required bool isUTrack}) {
    const layouts = [
      [2, 2, 0],
      [3, 3, 0],
      [3, 2, 1],
      [4, 4, 0],
      [4, 3, 1],
      [4, 2, 2],
      [5, 5, 0],
      [5, 4, 1],
      [5, 3, 2],
      [6, 6, 0],
      [6, 5, 1],
      [6, 4, 2],
      [6, 3, 3],
      [7, 7, 0],
      [7, 6, 1],
      [7, 5, 2],
      [7, 4, 3],
      [8, 8, 0],
      [8, 7, 1],
      [8, 6, 2],
      [8, 5, 3],
      [8, 4, 4],
      [9, 8, 1],
      [9, 7, 2],
      [9, 6, 3],
      [9, 5, 4],
      [10, 9, 1],
      [10, 8, 2],
      [10, 7, 3],
      [10, 6, 4],
      [10, 5, 5],
      [10, 10, 0],
    ];
    final fam = isUTrack ? 'fuji_u' : 'fuji_std';
    final suffix = isUTrack ? '-u' : '';
    final trackDesc = isUTrack ? 'ราง U (F7932)' : 'รางมาตรฐาน (F7969)';
    return layouts.map((cfg) {
      final n = cfg[0], l = cfg[1], r = cfg[2];
      final code = '$n-$l-$r$suffix';
      return PatternCardDef(
        id: 'fold_${fam}_${n}_${l}_$r',
        title: 'บานเฟี้ยม $code',
        subtitle: '$trackDesc · $n บาน (ซ้าย $l / ขวา $r)',
        foldingFamily: fam,
        foldingTotalPanels: n,
        foldingLeftPanels: l,
        foldingRightPanels: r,
      );
    }).toList();
  }

  static List<PatternCardDef> _buildSmartPlusFoldingCards() {
    const layouts = [
      [2, 2, 0],
      [3, 2, 1],
      [3, 3, 0],
      [4, 3, 1],
      [4, 2, 2],
      [4, 4, 0],
      [5, 4, 1],
      [5, 3, 2],
      [5, 5, 0],
      [6, 5, 1],
      [6, 4, 2],
      [6, 3, 3],
      [7, 6, 1],
      [7, 5, 2],
      [7, 4, 3],
      [8, 7, 1],
      [8, 6, 2],
      [8, 5, 3],
      [8, 4, 4],
    ];
    final cards = layouts.map((cfg) {
      final n = cfg[0], l = cfg[1], r = cfg[2];
      final code = '$n-$l-$r';
      return PatternCardDef(
        id: 'fold_sp_$code',
        title: 'ชุดบานเฟี้ยม $code',
        subtitle: 'SMART PLUS EURO · พับซ้าย $l ขวา $r',
        foldingFamily: 'sp_fold',
        foldingTotalPanels: n,
        foldingLeftPanels: l,
        foldingRightPanels: r,
      );
    }).toList();

    // Exact 2 disabled corner cards at bottom of SMART PLUS Folding
    cards.addAll(const [
      PatternCardDef(
        id: 'fold_sp_corner_1',
        title: 'บานเฟี้ยมเข้ามุม 90° (แบบที่ 1)',
        enabled: false,
        disabledBadge: 'ข้อมูลสัดส่วนรออัปเดต',
      ),
      PatternCardDef(
        id: 'fold_sp_corner_2',
        title: 'บานเฟี้ยมเข้ามุม 90° (แบบที่ 2)',
        enabled: false,
        disabledBadge: 'ข้อมูลสัดส่วนรออัปเดต',
      ),
    ]);
    return cards;
  }

  static List<PatternCardDef> _buildAlumetFoldingCards() {
    const specs = [
      [2, 2, 0, '2 Left • 0 Right (2-2-0)'],
      [3, 2, 1, '2 Left • 1 Right (3-2-1)'],
      [3, 3, 0, '3 Left • 0 Right (3-3-0)'],
      [4, 2, 2, '2 Left • 2 Right (4-2-2)'],
      [4, 3, 1, '3 Left • 1 Right (4-3-1)'],
      [4, 4, 0, '4-4-0 (Interior – No Threshold)'],
      [5, 5, 0, '5 Left • 0 Right (5-5-0)'],
      [5, 4, 1, '4 Left • 1 Right (5-4-1)'],
      [5, 3, 2, '3 Left • 2 Right (5-3-2)'],
      [6, 5, 1, '5 Left • 1 Right (6-5-1)'],
      [6, 4, 2, '4 Left • 2 Right (6-4-2)'],
      [6, 3, 3, '6-3-3 (Interior – No Floor Groove)'],
      [7, 6, 1, '6 Left • 1 Right (7-6-1)'],
      [7, 5, 2, '5 Left • 2 Right (7-5-2)'],
      [7, 4, 3, '4 Left • 3 Right (7-4-3)'],
      [8, 4, 4, '4 Left • 4 Right (8-4-4)'],
    ];
    return specs.map((s) {
      final n = s[0] as int, l = s[1] as int, r = s[2] as int;
      final label = s[3] as String;
      return PatternCardDef(
        id: 'fold_alu_${n}_${l}_$r',
        title: label,
        subtitle: 'ALUMET Smart X Folding',
        foldingFamily: 'alu_fold',
        foldingTotalPanels: n,
        foldingLeftPanels: l,
        foldingRightPanels: r,
        optionGroups: const [
          OptionGroupDef(
            id: 'sill_code',
            title: 'ชนิดรางล่าง',
            choices: [
              OptionChoice(id: 'SB-0116', label: 'เฟรมล่างบานเฟี้ยมภายใน · SB-0116'),
              OptionChoice(id: 'SB-0103', label: 'เฟรมล่างบานเฟี้ยมภายนอก · SB-0103'),
              OptionChoice(id: 'SB-0115', label: 'เฟรมยูฝังพื้น · SB-0115'),
            ],
            defaultValue: 'SB-0116',
          ),
        ],
      );
    }).toList();
  }

  // ===========================================================================
  // Helper builders for ALUMET 6-Album Pattern Expansion (v0.1.12)
  // Applied across ALUMET Smart X (sx), ALUMET NEX (nex), ALUMET Iconiq (iq)
  // NOTE: Swing Door 11-pattern suite is strictly ICONIQ ONLY per customer req!
  // ===========================================================================
  static List<PatternCardDef> _buildAlumetExtendedSlidingCards({
    required String prefix,
    required String seriesKey,
    required List<OptionGroupDef> slidingOptions,
    List<OptionGroupDef> comboOptions = const [],
    bool includeS3Top = false,
    bool includeS4Top = false,
  }) {
    return [
      PatternCardDef(
        id: '${prefix}_s3_1f2s_card',
        title: 'บานเลื่อนแบ่ง 3 (ติดตาย 1 + เลื่อน 2)',
        subtitle: 'เลื่อน 2 บาน + บานติดตายข้าง 1 บาน',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:s3_1f2s',
        optionGroups: slidingOptions,
      ),
      PatternCardDef(
        id: '${prefix}_s2_top2_card',
        title: 'บานเลื่อนสลับ 2 บาน + ช่องแสงบนแบ่ง 2 ช่อง',
        subtitle: 'บานเลื่อนสลับ 2 บาน พร้อมช่องแสงบนซอย 2 ช่อง',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:s2_top2',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
        optionGroups: slidingOptions,
      ),
      if (includeS3Top)
        PatternCardDef(
          id: '${prefix}_s3_top_card',
          title: 'บานเลื่อนแบ่ง 3 บาน + ช่องแสงบน',
          subtitle: 'บานเลื่อน 3 บาน พร้อมช่องแสงบนเต็มแนว',
          baseFormulaKey: 'alu_ext:$seriesKey:slide:s3_top',
          auxType: AuxDimensionType.refHeightH1,
          auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
          optionGroups: slidingOptions,
        ),
      if (includeS4Top)
        PatternCardDef(
          id: '${prefix}_s4_top_card',
          title: 'บานเลื่อนแบ่ง 4 เปิดกลาง + ช่องแสงบน',
          subtitle: 'บานเลื่อน 4 บานเปิดกลาง พร้อมช่องแสงบน',
          baseFormulaKey: 'alu_ext:$seriesKey:slide:s4_top',
          auxType: AuxDimensionType.refHeightH1,
          auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
          optionGroups: slidingOptions,
        ),
      PatternCardDef(
        id: '${prefix}_s4_top4_card',
        title: 'บานเลื่อนแบ่ง 4 + ช่องแสงบนแบ่ง 4 ช่อง',
        subtitle: 'บานเลื่อน 4 บานเปิดกลาง + ช่องแสงบนซอย 4 ช่อง',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:s4_top4',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
        optionGroups: slidingOptions,
      ),
      PatternCardDef(
        id: '${prefix}_s4_arch_card',
        title: 'บานเลื่อนแบ่ง 4 + ช่องแสงโค้งครึ่งวงกลม',
        subtitle: 'ช่องแสงบนดัดโค้ง 4 ช่อง (กระจกโค้งวัดตัดหน้างาน)',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:s4_arch',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานเลื่อนถึงฐานโค้ง (มม.)',
        optionGroups: slidingOptions,
      ),
      PatternCardDef(
        id: '${prefix}_s3_1f2s_tb_asym_card',
        title: 'บานเลื่อน 3 ช่อง (ติดตายซ้ายเต็ม + เลื่อน 2 ช่องแสงบน) + ช่องแสงล่าง',
        subtitle: 'บานติดตายซ้ายสูงเต็ม + บานเลื่อน 2 บานพร้อมช่องแสงบน-ล่าง',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:s3_1f2s_tb_asym',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
        optionGroups: slidingOptions,
      ),
      PatternCardDef(
        id: '${prefix}_s3_1f2s_tb_card',
        title: 'บานเลื่อน 3 ช่อง (ติดตาย 1 + เลื่อน 2) + ช่องแสงบน-ล่าง',
        subtitle: 'ช่องแสงบน 3 ช่อง + บานเลื่อน 3 ช่อง + ช่องแสงล่าง 3 ช่อง',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:s3_1f2s_tb',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
        optionGroups: slidingOptions,
      ),
      PatternCardDef(
        id: '${prefix}_combo_c2_f3_card',
        title: 'ชุดผสม บานเปิดข้างซ้าย-ขวา + บานติดตายกลาง 3 ช่อง',
        subtitle: 'หน้าต่างบานเปิดข้าง 2 ข้าง + บานติดตายกลาง 3 ช่อง',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:combo_c2_f3',
        optionGroups: comboOptions,
      ),
      PatternCardDef(
        id: '${prefix}_combo_c2_f3_bot_card',
        title: 'ชุดผสม บานเปิดข้างซ้าย-ขวา + ช่องแสงล่าง + บานติดตายกลาง 3 ช่อง',
        subtitle: 'บานเปิดข้างพร้อมช่องแสงล่าง + บานติดตายกลาง 3 ช่อง',
        baseFormulaKey: 'alu_ext:$seriesKey:slide:combo_c2_f3_bot',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานเปิด (มม.)',
        optionGroups: comboOptions,
      ),
    ];
  }

  static List<SubSystemDef> _buildAlumetCasementSubTabs({
    required String prefix,
    required String seriesKey,
    String tabPrefix = '',
    List<OptionGroupDef> options = const [],
    Map<String, PatternCardDef> existingBySlot = const {},
  }) {
    const groups = [
      ('plain', 'ไม่มีช่องแสง', '', AuxDimensionType.none),
      ('top', '+ ช่องแสงบน', ' + ช่องแสงบน', AuxDimensionType.refHeightH1),
      ('bot', '+ ช่องแสงล่าง', ' + ช่องแสงล่าง', AuxDimensionType.refHeightH1),
      ('tb', '+ ช่องแสงบน-ล่าง', ' + ช่องแสงบน-ล่าง', AuxDimensionType.refHeightH1),
    ];
    return groups.map((g) {
      final modeKey = g.$1;
      final tabTitle = '$tabPrefix${g.$2}';
      final titleSuffix = g.$3;
      final aux = g.$4;
      return SubSystemDef(
        id: '${prefix}_case_tab_$modeKey',
        title: tabTitle,
        patterns: [
          for (int n = 1; n <= 5; n++)
            existingBySlot['${n}_$modeKey'] ??
                PatternCardDef(
                  id: '${prefix}_case_${n}_${modeKey}_card',
                  title: n == 1
                      ? 'หน้าต่างบานเปิดเดี่ยว$titleSuffix'
                      : (n == 2
                          ? 'หน้าต่างบานเปิดคู่ (2 บาน)$titleSuffix'
                          : 'หน้าต่างบานเปิด $n บาน$titleSuffix'),
                  subtitle: modeKey == 'tb'
                      ? 'บานเปิด $n บาน พร้อมช่องแสงบน-ล่าง ($n ช่องบน / $n ช่องล่าง)'
                      : (modeKey == 'plain'
                          ? 'หน้าต่างบานเปิด $n บานเต็มความสูง'
                          : 'บานเปิด $n บาน พร้อม${g.$2} ($n ช่อง)'),
                  baseFormulaKey: 'alu_ext:$seriesKey:case:$n:$modeKey',
                  auxType: aux,
                  auxLabel: aux == AuxDimensionType.refHeightH1
                      ? 'H1 ความสูงส่วนบานเปิด (มม.)'
                      : null,
                  optionGroups: options,
                ),
        ],
      );
    }).toList();
  }

  static List<SubSystemDef> _buildAlumetAwningSubTabs({
    required String prefix,
    required String seriesKey,
    String tabPrefix = '',
    List<OptionGroupDef> options = const [],
    Map<String, PatternCardDef> existingBySlot = const {},
  }) {
    const groups = [
      ('plain', 'ไม่มีช่องแสง', '', AuxDimensionType.none, 5),
      ('top', '+ ช่องแสงบน', ' + ช่องแสงบน', AuxDimensionType.refHeightH1, 5),
      ('bot', '+ ช่องแสงล่าง', ' + ช่องแสงล่าง', AuxDimensionType.refHeightH1, 4),
    ];
    return groups.map((g) {
      final modeKey = g.$1;
      final tabTitle = '$tabPrefix${g.$2}';
      final titleSuffix = g.$3;
      final aux = g.$4;
      final maxN = g.$5;
      return SubSystemDef(
        id: '${prefix}_awn_tab_$modeKey',
        title: tabTitle,
        patterns: [
          for (int n = 1; n <= maxN; n++)
            existingBySlot['${n}_$modeKey'] ??
                PatternCardDef(
                  id: '${prefix}_awn_${n}_${modeKey}_card',
                  title: n == 1
                      ? 'หน้าต่างบานกระทุ้งเดี่ยว$titleSuffix'
                      : (n == 2
                          ? 'หน้าต่างบานกระทุ้งคู่ (2 บาน)$titleSuffix'
                          : 'หน้าต่างบานกระทุ้ง $n บาน$titleSuffix'),
                  subtitle: modeKey == 'plain'
                      ? 'หน้าต่างบานกระทุ้ง $n บานเต็มความสูง'
                      : 'บานกระทุ้ง $n บาน พร้อม${g.$2} ($n ช่อง)',
                  baseFormulaKey: 'alu_ext:$seriesKey:awn:$n:$modeKey',
                  auxType: aux,
                  auxLabel: aux == AuxDimensionType.refHeightH1
                      ? 'H1 ความสูงส่วนบานกระทุ้ง (มม.)'
                      : null,
                  optionGroups: options,
                ),
        ],
      );
    }).toList();
  }

  static List<SubSystemDef> _buildAlumetFixedSubTabs({
    required String prefix,
    required String seriesKey,
    Map<String, PatternCardDef> existingBySlot = const {},
    List<PatternCardDef> extraPlainCards = const [],
  }) {
    const groups = [
      ('plain', 'บานติดตายแถวเดียว', '', AuxDimensionType.none, 5),
      ('top', '+ ช่องแสงบน', ' + ช่องแสงบน', AuxDimensionType.refHeightH1, 5),
      ('tb', '+ ช่องแสงบน-ล่าง', ' + ช่องแสงบน-ล่าง', AuxDimensionType.refHeightH1, 4),
    ];
    return groups.map((g) {
      final modeKey = g.$1;
      final tabTitle = g.$2;
      final titleSuffix = g.$3;
      final aux = g.$4;
      final maxN = g.$5;
      return SubSystemDef(
        id: '${prefix}_fix_tab_$modeKey',
        title: tabTitle,
        patterns: [
          for (int n = 1; n <= maxN; n++)
            existingBySlot['${n}_$modeKey'] ??
                PatternCardDef(
                  id: '${prefix}_fix_${n}_${modeKey}_card',
                  title: n == 1
                      ? 'บานติดตาย 1 ช่อง$titleSuffix'
                      : 'บานติดตายแบ่ง $n ช่อง$titleSuffix',
                  subtitle: modeKey == 'tb'
                      ? 'บานติดตาย $n ช่อง พร้อมช่องแสงบน-ล่าง'
                      : (modeKey == 'top'
                          ? 'บานติดตาย $n ช่อง พร้อมช่องแสงบน $n ช่อง'
                          : 'บานติดตาย / ช่องแสงแบ่ง $n ช่อง'),
                  baseFormulaKey: 'alu_ext:$seriesKey:fix:$n:$modeKey',
                  auxType: aux,
                  auxLabel: aux == AuxDimensionType.refHeightH1
                      ? 'H1 ความสูงช่องบานติดตายหลัก (มม.)'
                      : null,
                ),
          if (modeKey == 'plain') ...extraPlainCards,
        ],
      );
    }).toList();
  }

  /// ICONIQ-ONLY 11 Swing Door Patterns (per customer instruction 16:18)
  static List<PatternCardDef> _buildIconiqSwingDoorCards() {
    return const [
      PatternCardDef(
        id: 'c3_alu_d1_card',
        title: 'ประตูบานเปิดเดี่ยว (กระจก)',
        subtitle: 'กรอบบานประตู iO-0201 · กระจกเต็มบาน',
        baseFormulaKey: 'c3_alu_d1',
      ),
      PatternCardDef(
        id: 'c3_alu_d1_louver_card',
        title: 'ประตูบานเปิดเดี่ยว (เกล็ด/ลูกฟักอลูมิเนียม ทึบ)',
        subtitle: 'กรอบบานประตู iO-0201 + ใบเกล็ดอลูมิเนียม iO-0205 เต็มบาน',
        baseFormulaKey: 'alu_ext:iq:door:1_louver',
      ),
      PatternCardDef(
        id: 'c3_alu_d1_louver_frame_card',
        title: 'ประตูบานเปิดเดี่ยว (เกล็ด/ลูกฟัก ขอบแบ่ง)',
        subtitle: 'กรอบบานประตู iO-0201 + คิ้วกรอบลูกฟัก + ใบเกล็ด iO-0205',
        baseFormulaKey: 'alu_ext:iq:door:1_louver_frame',
      ),
      PatternCardDef(
        id: 'c3_alu_d1_side1_card',
        title: 'ประตูบานเปิดเดี่ยว + ช่องแสงข้าง 1 ช่อง',
        subtitle: 'ประตูบานเปิดเดี่ยวพร้อมช่องแสงกระจกข้าง 1 ช่อง',
        baseFormulaKey: 'alu_ext:iq:door:1_side1',
        auxType: AuxDimensionType.sideFixWf,
        auxLabel: 'W_f ความกว้างส่วนบานประตู (มม.)',
      ),
      PatternCardDef(
        id: 'c3_alu_d2_card',
        title: 'ประตูบานเปิดคู่ (กระจก)',
        subtitle: 'กรอบบานประตู iO-0201 เปิดคู่ · เสาเสริม SC-0212',
        baseFormulaKey: 'c3_alu_d2',
      ),
      PatternCardDef(
        id: 'c3_alu_d2_louver_card',
        title: 'ประตูบานเปิดคู่ (เกล็ด/ลูกฟักอลูมิเนียม ทึบ)',
        subtitle: 'ประตูคู่ iO-0201 + ใบเกล็ดอลูมิเนียม iO-0205 เต็มบาน',
        baseFormulaKey: 'alu_ext:iq:door:2_louver',
      ),
      PatternCardDef(
        id: 'c3_alu_d2_louver_frame_card',
        title: 'ประตูบานเปิดคู่ (เกล็ด/ลูกฟัก ขอบแบ่ง)',
        subtitle: 'ประตูคู่ iO-0201 + คิ้วกรอบลูกฟัก + ใบเกล็ด iO-0205',
        baseFormulaKey: 'alu_ext:iq:door:2_louver_frame',
      ),
      PatternCardDef(
        id: 'c3_alu_d2_top_card',
        title: 'ประตูบานเปิดคู่ + ช่องแสงบน',
        subtitle: 'ประตูบานเปิดคู่กระจก พร้อมช่องแสงบนเต็มแนว',
        baseFormulaKey: 'alu_ext:iq:door:2_top',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานประตู (มม.)',
      ),
      PatternCardDef(
        id: 'c3_alu_d2_arch_card',
        title: 'ประตูบานเปิดคู่ + ช่องแสงโค้งครึ่งวงกลม',
        subtitle: 'ประตูบานเปิดคู่ + เฟรมดัดโค้งครึ่งวงกลม (กระจกโค้งวัดตัดหน้างาน)',
        baseFormulaKey: 'alu_ext:iq:door:2_arch',
        auxType: AuxDimensionType.refHeightH1,
        auxLabel: 'H1 ความสูงส่วนบานประตูถึงฐานโค้ง (มม.)',
      ),
      PatternCardDef(
        id: 'c3_alu_d2_louver_side2_glass_card',
        title: 'ประตูบานเปิดคู่ (เกล็ดอลูมิเนียม) + ช่องแสงกระจกซ้าย-ขวา',
        subtitle: 'ประตูคู่เกล็ดอลูมิเนียม + ช่องแสงกระจกขนาบซ้าย-ขวา',
        baseFormulaKey: 'alu_ext:iq:door:2_louver_side2_glass',
        auxType: AuxDimensionType.sideFixWf,
        auxLabel: 'W_f ความกว้างส่วนประตูคู่กลาง (มม.)',
      ),
      PatternCardDef(
        id: 'c3_alu_d2_louver_side2_louver_card',
        title: 'ประตูบานเปิดคู่ (เกล็ดอลูมิเนียม) + ช่องเกล็ดซ้าย-ขวา',
        subtitle: 'ประตูคู่เกล็ดอลูมิเนียม + ช่องเกล็ดอลูมิเนียมขนาบซ้าย-ขวา',
        baseFormulaKey: 'alu_ext:iq:door:2_louver_side2_louver',
        auxType: AuxDimensionType.sideFixWf,
        auxLabel: 'W_f ความกว้างส่วนประตูคู่กลาง (มม.)',
      ),
    ];
  }

  // ===========================================================================
  // Complete 5-Category Catalog Tree (1:1 with Toolkit v0.1.7 VIP)
  // ===========================================================================
  static final List<CategoryDef> categories = [
    // -------------------------------------------------------------------------
    // CATEGORY 1: ชุดตลาด
    // -------------------------------------------------------------------------
    const CategoryDef(
      id: 'cat1_market',
      title: 'ชุดตลาด',
      subtitle: 'อลูมิเนียมชุดมาตรฐานท้องตลาดทั่วไป',
      directSystems: [
        SubSystemDef(
          id: 'c1_sys_sliding',
          title: 'บานเลื่อน',
          subtitle: 'เลือกได้ทั้งเฟรมไม่ติดกล่อง กล่องเรียบ และเฟรมติดกล่อง',
          patterns: [
            PatternCardDef(
              id: 'c1_pat_s2_alt',
              title: 'บานเลื่อนแบ่ง 2 สลับ',
              subtitle: 'เลื่อนสลับ 2 บาน',
              baseFormulaKey: 'c1_s2_boxframe',
              optionGroups: marketSlidingOptions,
            ),
            PatternCardDef(
              id: 'c1_pat_s2_1s1f',
              title: 'บานเลื่อนแบ่ง 2 เลื่อน 1 ตาย 1',
              subtitle: 'บานเลื่อน 1 บาน + บานตาย 1 บาน',
              baseFormulaKey: 'c1_s2_1s1f',
              optionGroups: marketSlidingOptions,
            ),
            PatternCardDef(
              id: 'c1_pat_s4_ctr',
              title: 'บานเลื่อนแบ่ง 4 เปิดกลาง',
              subtitle: 'เลื่อนกลาง 2 บาน + บานตายซ้าย-ขวา',
              baseFormulaKey: 'c1_s4_center',
              optionGroups: marketSlidingOptions,
            ),
            PatternCardDef(
              id: 'c1_dis_s3',
              title: 'บานเลื่อนแบ่ง 3',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
            PatternCardDef(
              id: 'c1_dis_s2_top',
              title: 'บานเลื่อนแบ่ง 2 สลับ + ช่องแสงบน',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
            PatternCardDef(
              id: 'c1_dis_s2_bot',
              title: 'บานเลื่อนแบ่ง 2 สลับ + ช่องแสงล่าง',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
            PatternCardDef(
              id: 'c1_dis_1s1f_top',
              title: 'บานเลื่อน 1 ตาย 1 + ช่องแสงบน',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
            PatternCardDef(
              id: 'c1_dis_1s1f_bot',
              title: 'บานเลื่อน 1 ตาย 1 + ช่องแสงล่าง',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
            PatternCardDef(
              id: 'c1_dis_s4_top',
              title: 'บานเลื่อนแบ่ง 4 เปิดกลาง + ช่องแสงบน',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
            PatternCardDef(
              id: 'c1_dis_s4_bot',
              title: 'บานเลื่อนแบ่ง 4 เปิดกลาง + ช่องแสงล่าง',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
          ],
        ),
        SubSystemDef(
          id: 'c1_sys_swing',
          title: 'ประตูบานสวิง',
          subtitle: 'บานสวิงเดี่ยวและบานสวิงคู่',
          patterns: [
            PatternCardDef(
              id: 'c1_pat_swing1',
              title: 'บานสวิงเดี่ยว',
              baseFormulaKey: 'c1_swing_1_v2',
            ),
            PatternCardDef(
              id: 'c1_pat_swing2',
              title: 'บานสวิงคู่',
              baseFormulaKey: 'c1_swing_2_v2',
            ),
          ],
        ),
        SubSystemDef(
          id: 'c1_sys_hang',
          title: 'บานเลื่อนรางแขวนบน',
          subtitle: 'ชุดรางแขวนบนเดี่ยวและคู่',
          patterns: [
            PatternCardDef(
              id: 'c1_pat_hang1',
              title: 'บานเลื่อนรางแขวนบนเดี่ยว',
              baseFormulaKey: 'c1_hang_1_v2',
            ),
            PatternCardDef(
              id: 'c1_pat_hang2',
              title: 'บานเลื่อนรางแขวนบนคู่',
              baseFormulaKey: 'c1_hang_2_v2',
            ),
          ],
        ),
        SubSystemDef(
          id: 'c1_sys_union',
          title: 'บานเปิด / บานกระทุ้ง ยูเนี่ยน',
          subtitle: 'ชุดกรอบนอก-กรอบในยูเนี่ยน',
          patterns: [
            PatternCardDef(
              id: 'c1_pat_union_case1',
              title: 'บานเปิดยูเนี่ยน 1 บาน',
              baseFormulaKey: 'c1_union_case1_v2',
              optionGroups: marketUnionOptions,
            ),
            PatternCardDef(
              id: 'c1_pat_union_awn1',
              title: 'บานกระทุ้งยูเนี่ยน 1 บาน',
              baseFormulaKey: 'c1_union_awn1_v2',
              optionGroups: marketUnionOptions,
            ),
          ],
        ),
        SubSystemDef(
          id: 'c1_sys_fixed',
          title: 'บานตาย / ช่องแสง',
          enabled: false,
          disabledBadge: 'รออัปเดต',
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // CATEGORY 2: ชุดพัฒนา
    // -------------------------------------------------------------------------
    CategoryDef(
      id: 'cat2_pattana',
      title: 'ชุดพัฒนา',
      subtitle: 'ระบบโปรไฟล์พัฒนาตามแบรนด์ผู้ผลิต',
      brands: [
        const BrandDef(
          id: 'c2_orm',
          title: 'ORM (Asian Trop)',
          subtitle: 'ชุดบานเลื่อน บานกระทุ้ง/เปิด และประตูวงกบไม้',
          priceBrandKey: 'ORM',
          systems: [
            SubSystemDef(
              id: 'c2_orm_sliding',
              title: 'บานเลื่อน',
              patterns: [
                PatternCardDef(
                  id: 'c2_orm_s2_card',
                  title: 'บานเลื่อนสลับ 2 บาน',
                  baseFormulaKey: 'c2_orm_s2_win75',
                  optionGroups: ormAsianSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_s2_top_card',
                  title: 'บานเลื่อน 2 บาน + ช่องแสงบน',
                  baseFormulaKey: 'c2_orm_s2_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: ormAsianSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_s2_bot_card',
                  title: 'บานเลื่อน 2 บาน + ช่องแสงล่าง',
                  baseFormulaKey: 'c2_orm_s2_bot',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: ormAsianSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_s4_card',
                  title: 'บานเลื่อน 4 บาน',
                  baseFormulaKey: 'c2_orm_s4',
                  optionGroups: ormAsianSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_s4_top_card',
                  title: 'บานเลื่อน 4 บาน + ช่องแสงบน',
                  baseFormulaKey: 'c2_orm_s4_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: ormAsianSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_s4_bot_card',
                  title: 'บานเลื่อน 4 บาน + ช่องแสงล่าง',
                  baseFormulaKey: 'c2_orm_s4_bot',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: ormAsianSlidingOptions,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_orm_casement',
              title: 'บานกระทุ้ง / บานเปิด',
              patterns: [
                PatternCardDef(
                  id: 'c2_orm_case1_card',
                  title: 'บานเดี่ยว (ไม่มีช่องแสง)',
                  baseFormulaKey: 'c2_orm_case1',
                  optionGroups: ormAsianCasementOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_case1_top_card',
                  title: 'บานเดี่ยว + ช่องแสงบน',
                  baseFormulaKey: 'c2_orm_case1_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานหลัก (มม.)',
                  optionGroups: ormAsianCasementOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_case1_bot_card',
                  title: 'บานเดี่ยว + ช่องแสงล่าง',
                  baseFormulaKey: 'c2_orm_case1_bot',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานหลัก (มม.)',
                  optionGroups: ormAsianCasementOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_case_div2_card',
                  title: 'แบ่ง 2 บาน',
                  baseFormulaKey: 'c2_orm_case_div2',
                  optionGroups: ormAsianCasementOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_case_div3_card',
                  title: 'แบ่ง 3 บาน',
                  baseFormulaKey: 'c2_orm_case_div3',
                  optionGroups: ormAsianCasementOptions,
                ),
                PatternCardDef(
                  id: 'c2_orm_case_div4_card',
                  title: 'แบ่ง 4 บาน',
                  baseFormulaKey: 'c2_orm_case_div4',
                  optionGroups: ormAsianCasementOptions,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_orm_fixed',
              title: 'บานติดตาย / Fixed',
              patterns: [
                PatternCardDef(
                  id: 'c2_orm_fix1_card',
                  title: 'บานติดตาย / Fixed',
                  subtitle: 'วัดตามจริง · รหัสหน้าตัดรอยืนยัน',
                  baseFormulaKey: 'c2_orm_fix1',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_orm_wood',
              title: 'ประตูบานเปิดวงกบไม้',
              patterns: [
                PatternCardDef(
                  id: 'c2_orm_wood1_card',
                  title: 'ประตูบานเปิดวงกบไม้ · บานเดี่ยว',
                  baseFormulaKey: 'c2_orm_wood_active',
                ),
                PatternCardDef(
                  id: 'c2_orm_wood2_dis',
                  title: 'ประตูบานเปิดวงกบไม้ · บานเปิดคู่',
                  enabled: false,
                  disabledBadge: 'รออัปเดต',
                ),
                PatternCardDef(
                  id: 'c2_orm_wood_top_dis',
                  title: 'ประตูบานเปิดวงกบไม้ + ช่องแสงบน',
                  enabled: false,
                  disabledBadge: 'รออัปเดต',
                ),
              ],
            ),
          ],
        ),
        const BrandDef(
          id: 'c2_schimmer',
          title: 'SMS SCHIMMER',
          subtitle: 'HOMELIFE 200 · HOMELIFE 250 · HOMELIFE 260',
          priceBrandKey: 'SCHIMMER',
          systems: [
            SubSystemDef(
              id: 'c2_sch_200',
              title: 'HOMELIFE 200 (บานเลื่อน)',
              patterns: [
                PatternCardDef(
                  id: 'c2_sch_200_001_card',
                  title: 'SD 200-001 · บานเลื่อนสลับ 2 บาน',
                  baseFormulaKey: 'c2_sch_200_s2',
                ),
                PatternCardDef(
                  id: 'c2_sch_200_002_card',
                  title: 'SD 200-002 · บานเลื่อน 1 + ฟิกซ์ 1 (เลื่อนนอก)',
                  baseFormulaKey: 'c2_sch_200_003',
                ),
                PatternCardDef(
                  id: 'c2_sch_200_004_card',
                  title: 'SD 200-004 · ฟิกซ์-เลื่อน-ฟิกซ์ 3 ช่อง',
                  baseFormulaKey: 'c2_sch_200_004',
                ),
                PatternCardDef(
                  id: 'c2_sch_200_005_card',
                  title: 'SD 200-005 · บานเลื่อน 1 + ฟิกซ์ 1 (เลื่อนใน)',
                  baseFormulaKey: 'c2_sch_200_003',
                ),
                PatternCardDef(
                  id: 'c2_sch_200_006_card',
                  title: 'SD 200-006 · ฟิกซ์-เลื่อน-เลื่อน-ฟิกซ์ 4 ช่อง',
                  baseFormulaKey: 'c2_sch_200_006',
                ),
                PatternCardDef(
                  id: 'c2_sch_200_008_card',
                  title: 'SD 200-008 · เลื่อน-เลื่อน-ฟิกซ์ 3 ช่อง',
                  baseFormulaKey: 'c2_sch_200_008',
                ),
                PatternCardDef(
                  id: 'c2_sch_200_010_card',
                  title: 'SD 200-010 · ฟิกซ์-เลื่อน 4 บาน-ฟิกซ์ 6 ช่อง',
                  baseFormulaKey: 'c2_sch_200_010',
                ),
                PatternCardDef(
                  id: 'c2_sch_200_011_card',
                  title: 'SD 200-011 · บานเลื่อนเข้ามุม 90° เลื่อนนอก',
                  baseFormulaKey: 'c2_sch_200_011',
                  tableMode: InputTableMode.cornerW1W2,
                ),
                PatternCardDef(
                  id: 'c2_sch_200_012_card',
                  title: 'SD 200-012 · บานเลื่อนเข้ามุม 90° เลื่อนใน',
                  baseFormulaKey: 'c2_sch_200_012',
                  tableMode: InputTableMode.cornerW1W2,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_sch_250',
              title: 'HOMELIFE 250 (ประตูบานเปิด)',
              patterns: [
                PatternCardDef(
                  id: 'c2_sch_250_002_card',
                  title: '250-002 · ประตูบานเปิดเดี่ยว',
                  baseFormulaKey: 'c2_sch_250_d1',
                  tableMode: InputTableMode.singleSet,
                  optionGroups: schimmer250Options,
                ),
                PatternCardDef(
                  id: 'c2_sch_250_004_card',
                  title: '250-004-CG · ประตูบานเปิดคู่ช่องกระจกบานตาย',
                  baseFormulaKey: 'c2_sch_250_004cg',
                  tableMode: InputTableMode.singleSet,
                  auxType: AuxDimensionType.sideFixWf,
                  auxLabel: 'W_f ความกว้างช่องแสงบานตายข้าง (มม.)',
                  optionGroups: schimmer250Options,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_sch_260',
              title: 'HOMELIFE 260 (หน้าต่างบานเปิด / กระทุ้ง)',
              patterns: [
                PatternCardDef(
                  id: 'c2_sch_260_001_card',
                  title: '260-001 · หน้าต่างบานเปิดเดี่ยว',
                  baseFormulaKey: 'c2_sch_260_w1',
                  tableMode: InputTableMode.singleSet,
                  optionGroups: schimmer260Options,
                ),
                PatternCardDef(
                  id: 'c2_sch_260_cm_card',
                  title: '260-002-CM · หน้าต่างบานเปิดคู่ เฟรมประกบกลาง',
                  baseFormulaKey: 'c2_sch_260_cm',
                  tableMode: InputTableMode.singleSet,
                  auxType: AuxDimensionType.secondWidthW2,
                  auxLabel: 'W2 ความกว้างบานที่ 2 (มม.)',
                  optionGroups: schimmer260Options,
                ),
                PatternCardDef(
                  id: 'c2_sch_260_fm_card',
                  title: '260-002-FM · หน้าต่างบานเปิดคู่ เสาแบ่งกลาง',
                  baseFormulaKey: 'c2_sch_260_cm',
                  tableMode: InputTableMode.singleSet,
                  auxType: AuxDimensionType.secondWidthW2,
                  auxLabel: 'W2 ความกว้างบานที่ 2 (มม.)',
                  optionGroups: schimmer260Options,
                ),
                PatternCardDef(
                  id: 'c2_sch_260_nm_card',
                  title: '260-002-NM · หน้าต่างบานเปิดคู่ ไม่มีเสากลาง',
                  baseFormulaKey: 'c2_sch_260_cm',
                  tableMode: InputTableMode.singleSet,
                  auxType: AuxDimensionType.secondWidthW2,
                  auxLabel: 'W2 ความกว้างบานที่ 2 (มม.)',
                  optionGroups: schimmer260Options,
                ),
              ],
            ),
          ],
        ),
        BrandDef(
          id: 'c2_alumet',
          title: 'ALUMET (Smart X)',
          subtitle: 'บานเลื่อน บานเปิด บานกระทุ้ง บานติดตาย และประตู Smart X',
          priceBrandKey: 'ALUMET',
          systems: [
            SubSystemDef(
              id: 'c2_alu_sliding',
              title: 'บานเลื่อน Smart X',
              subtitle: '18 แบบ · บานเลื่อน 2–4 บาน · ช่องแสง · ช่องแสงโค้ง · ชุดผสม · เข้ามุม 90°',
              patterns: [
                const PatternCardDef(
                  id: 'c2_alu_s2_card',
                  title: 'บานเลื่อนสลับ 2 บาน',
                  baseFormulaKey: 'c2_alu_s2',
                  optionGroups: alumetSmartXSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_alu_s2_top_card',
                  title: 'บานเลื่อนสลับ 2 บาน + ช่องแสงบน',
                  baseFormulaKey: 'c2_alu_s2_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: alumetSmartXSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_alu_s3_card',
                  title: 'บานเลื่อนแบ่ง 3 บาน',
                  baseFormulaKey: 'c2_alu_s3',
                  optionGroups: alumetSmartXSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_alu_s3_top_card',
                  title: 'บานเลื่อนแบ่ง 3 บาน + ช่องแสงบน',
                  baseFormulaKey: 'c2_alu_s3_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: alumetSmartXSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_alu_s4_card',
                  title: 'บานเลื่อนแบ่ง 4 เปิดกลาง',
                  baseFormulaKey: 'c2_alu_s4',
                  optionGroups: alumetSmartXSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_alu_s4_top_card',
                  title: 'บานเลื่อนแบ่ง 4 เปิดกลาง + ช่องแสงบน',
                  baseFormulaKey: 'c2_alu_s4_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: alumetSmartXSlidingOptions,
                ),
                ..._buildAlumetExtendedSlidingCards(
                  prefix: 'c2_alu',
                  seriesKey: 'sx',
                  slidingOptions: alumetSmartXSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_alu_corner22_card',
                  title: 'บานเลื่อนเข้ามุม 90° (2+2)',
                  baseFormulaKey: 'c2_alu_s4_corner',
                  tableMode: InputTableMode.cornerW1W2,
                ),
                const PatternCardDef(
                  id: 'c2_alu_corner23_card',
                  title: 'บานเลื่อนเข้ามุม 2+3',
                  baseFormulaKey: 'c2_alu_s5_23',
                  tableMode: InputTableMode.cornerW1W2,
                ),
                const PatternCardDef(
                  id: 'c2_alu_corner32_card',
                  title: 'บานเลื่อนเข้ามุม 3+2',
                  baseFormulaKey: 'c2_alu_s5_32',
                  tableMode: InputTableMode.cornerW1W2,
                ),
                const PatternCardDef(
                  id: 'c2_alu_corner33_card',
                  title: 'บานเลื่อนเข้ามุม 3+3',
                  baseFormulaKey: 'c2_alu_s6_33',
                  tableMode: InputTableMode.cornerW1W2,
                ),
                const PatternCardDef(
                  id: 'c2_alu_hang_dis',
                  title: 'บานเลื่อนรางแขวนบานเดี่ยว',
                  enabled: false,
                  disabledBadge: 'รอข้อมูลสูตร',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_alu_casement',
              title: 'หน้าต่างบานเปิด Smart X (20 แบบ)',
              subtitle: '1–5 บาน · ไม่มีช่องแสง / +ช่องแสงบน / +ช่องแสงล่าง / +บน-ล่าง',
              subTabs: _buildAlumetCasementSubTabs(
                prefix: 'c2_alu',
                seriesKey: 'sx',
                existingBySlot: const {
                  '1_plain': PatternCardDef(
                    id: 'c2_alu_win1_card',
                    title: 'หน้าต่างบานเปิดเดี่ยว',
                    baseFormulaKey: 'c2_alu_win_1',
                  ),
                  '2_top': PatternCardDef(
                    id: 'c2_alu_win3_card',
                    title: 'หน้าต่างบานเปิดคู่ + ช่องแสงบน',
                    baseFormulaKey: 'c2_alu_win_3',
                    auxType: AuxDimensionType.refHeightH1,
                    auxLabel: 'H1 ความสูงส่วนบานหน้าต่าง (มม.)',
                  ),
                },
              ),
            ),
            SubSystemDef(
              id: 'c2_alu_awning',
              title: 'หน้าต่างบานกระทุ้ง Smart X (14 แบบ)',
              subtitle: '1–5 บาน · ไม่มีช่องแสง / +ช่องแสงบน / +ช่องแสงล่าง',
              subTabs: _buildAlumetAwningSubTabs(
                prefix: 'c2_alu',
                seriesKey: 'sx',
                existingBySlot: const {
                  '1_plain': PatternCardDef(
                    id: 'c2_alu_win4_card',
                    title: 'หน้าต่างบานกระทุ้งเดี่ยว',
                    baseFormulaKey: 'c2_alu_win_4',
                  ),
                  '1_top': PatternCardDef(
                    id: 'c2_alu_win5_card',
                    title: 'หน้าต่างบานกระทุ้งเดี่ยว + ช่องแสงบน',
                    baseFormulaKey: 'c2_alu_win_5',
                    auxType: AuxDimensionType.refHeightH1,
                    auxLabel: 'H1 ความสูงส่วนบานหน้าต่าง (มม.)',
                  ),
                  '2_plain': PatternCardDef(
                    id: 'c2_alu_win6_card',
                    title: 'หน้าต่างบานกระทุ้งคู่',
                    baseFormulaKey: 'c2_alu_win_6',
                  ),
                  '2_top': PatternCardDef(
                    id: 'c2_alu_win7_card',
                    title: 'หน้าต่างบานกระทุ้งคู่ + ช่องแสงบน',
                    baseFormulaKey: 'c2_alu_win_7',
                    auxType: AuxDimensionType.refHeightH1,
                    auxLabel: 'H1 ความสูงส่วนบานหน้าต่าง (มม.)',
                  ),
                },
              ),
            ),
            const SubSystemDef(
              id: 'c2_alu_doors',
              title: 'ประตูบานเปิด',
              patterns: [
                PatternCardDef(
                  id: 'c2_alu_d1_card',
                  title: 'ประตูบานเปิดเดี่ยว',
                  baseFormulaKey: 'c2_alu_d1',
                ),
                PatternCardDef(
                  id: 'c2_alu_d2_card',
                  title: 'ประตูบานเปิดคู่ แม่-ลูก',
                  baseFormulaKey: 'c2_alu_d2_mc',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_alu_fixed',
              title: 'บานติดตาย / ช่องแสง Smart X (14 แบบ)',
              subtitle: '1–5 ช่อง · แถวเดียว / +ช่องแสงบน / +ช่องแสงบน-ล่าง',
              subTabs: _buildAlumetFixedSubTabs(
                prefix: 'c2_alu',
                seriesKey: 'sx',
              ),
            ),
          ],
        ),
        BrandDef(
          id: 'c2_alumet_nex',
          title: 'ALUMET (NEX)',
          subtitle: 'อลูเม็ท เน็กซ์ 100 / 200 · บานเลื่อน บานเปิด บานกระทุ้ง บานติดตาย',
          priceBrandKey: 'ALUMET',
          systems: [
            SubSystemDef(
              id: 'c2_nex_sliding',
              title: 'บานเลื่อน อลูเม็ท เน็กซ์ (14 แบบ)',
              subtitle: 'รองรับ เน็กซ์ 200 & เน็กซ์ 100 · ล้อตลับ / ล้อตลาด · มุ้ง 3 แบบ',
              patterns: [
                const PatternCardDef(
                  id: 'c2_nex_s2_card',
                  title: 'บานเลื่อนสลับ 2 บาน',
                  subtitle: 'เฟรม 2 ราง PS-0107 / PS-0108 · วงกบสลิม 20 มม.',
                  baseFormulaKey: 'c2_nex_s2',
                  optionGroups: alumetNexSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_nex_s2_top_card',
                  title: 'บานเลื่อนสลับ 2 บาน + ช่องแสงบน',
                  subtitle: 'ต่อช่องแสงบนด้วยกล่องร่องสลิม PF-0103 + PS-0112',
                  baseFormulaKey: 'c2_nex_s2_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: alumetNexSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_nex_s3_card',
                  title: 'บานเลื่อนแบ่ง 3 บาน (3 ราง)',
                  subtitle: 'เฟรม 3 ราง PS-0113 / PS-0114 · วงกบสลิม 20 มม.',
                  baseFormulaKey: 'c2_nex_s3',
                  optionGroups: alumetNexSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c2_nex_s4_card',
                  title: 'บานเลื่อนแบ่ง 4 เปิดกลาง',
                  subtitle: 'เฟรม 2 ราง PS-0107 / PS-0108 · เปิดกลาง 4 บาน',
                  baseFormulaKey: 'c2_nex_s4',
                  optionGroups: alumetNexSlidingOptions,
                ),
                ..._buildAlumetExtendedSlidingCards(
                  prefix: 'c2_nex',
                  seriesKey: 'nex',
                  slidingOptions: alumetNexSlidingOptions,
                  comboOptions: alumetNexCasementOptions,
                  includeS3Top: true,
                  includeS4Top: true,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_nex_windows',
              title: 'บานเปิด - บานกระทุ้ง อลูเม็ท เน็กซ์ (34 แบบ)',
              subtitle: 'รองรับ เน็กซ์ 200 มัลติพอยท์ & เน็กซ์ 100 ซิงเกิลล็อก · บานเปิด 20 แบบ + กระทุ้ง 14 แบบ',
              subTabs: [
                ..._buildAlumetCasementSubTabs(
                  prefix: 'c2_nex_win',
                  seriesKey: 'nex',
                  tabPrefix: 'บานเปิด · ',
                  options: alumetNexCasementOptions,
                  existingBySlot: const {
                    '1_plain': PatternCardDef(
                      id: 'c2_nex_win1_card',
                      title: 'หน้าต่างบานกระทุ้ง / บานเปิด เดี่ยว',
                      subtitle: 'เฟรม PC-0104 / PC-0105 · กรอบบาน 45° PC-0204',
                      baseFormulaKey: 'c2_nex_win1',
                      optionGroups: alumetNexCasementOptions,
                    ),
                    '1_top': PatternCardDef(
                      id: 'c2_nex_win1_top_card',
                      title: 'หน้าต่างบานกระทุ้ง / บานเปิด เดี่ยว + ช่องแสงบน',
                      subtitle: 'ต่อช่องแสงบนด้วย ซอยเฟรม PC-0106 + คิ้ว A30274',
                      baseFormulaKey: 'c2_nex_win1_top',
                      auxType: AuxDimensionType.refHeightH1,
                      auxLabel: 'H1 ความสูงส่วนบานเปิด-กระทุ้ง (มม.)',
                      optionGroups: alumetNexCasementOptions,
                    ),
                    '1_bot': PatternCardDef(
                      id: 'c2_nex_win1_bot_card',
                      title: 'หน้าต่างบานกระทุ้ง / บานเปิด เดี่ยว + ช่องแสงล่าง',
                      subtitle: 'ต่อช่องแสงล่างด้วย ตบเฟรม PC-0107 + คิ้ว A30274',
                      baseFormulaKey: 'c2_nex_win1_bot',
                      auxType: AuxDimensionType.refHeightH1,
                      auxLabel: 'H1 ความสูงส่วนบานเปิด-กระทุ้ง (มม.)',
                      optionGroups: alumetNexCasementOptions,
                    ),
                    '2_plain': PatternCardDef(
                      id: 'c2_nex_win2_card',
                      title: 'หน้าต่างบานเปิดคู่',
                      subtitle: 'พร้อมเสาเสริมบานเปิดคู่ PC-0205',
                      baseFormulaKey: 'c2_nex_win2',
                      optionGroups: alumetNexCasementOptions,
                    ),
                  },
                ),
                ..._buildAlumetAwningSubTabs(
                  prefix: 'c2_nex_win',
                  seriesKey: 'nex',
                  tabPrefix: 'กระทุ้ง · ',
                  options: alumetNexCasementOptions,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_nex_fixed',
              title: 'ช่องแสง / บานติดตาย อลูเม็ท เน็กซ์ 200 (15 แบบ)',
              subtitle: 'กล่องร่อง PF-0103 · กล่องเปิด PF-0101 · ฝาปิด PF-0102 · 1–5 ช่องครบชุด',
              subTabs: _buildAlumetFixedSubTabs(
                prefix: 'c2_nex',
                seriesKey: 'nex',
                existingBySlot: const {
                  '1_plain': PatternCardDef(
                    id: 'c2_nex_fix1_card',
                    title: 'ช่องแสงเดี่ยว (1 ช่อง)',
                    subtitle: 'กล่องร่องสลิม 25.4 มม. · ประกอบง่ายไม่ใช้ฉาก',
                    baseFormulaKey: 'c2_nex_fix1',
                  ),
                  '2_plain': PatternCardDef(
                    id: 'c2_nex_fix2_card',
                    title: 'ช่องแสงแบ่งซอย 2 ช่อง',
                    subtitle: 'ซอยกลางด้วยกล่องร่อง PF-0103 + ตบร่อง A10261',
                    baseFormulaKey: 'c2_nex_fix2',
                  ),
                  '3_plain': PatternCardDef(
                    id: 'c2_nex_fix3_card',
                    title: 'ช่องแสงแบ่งซอย 3 ช่อง',
                    subtitle: 'ซอย 3 ช่องด้วยกล่องร่อง PF-0103 + ตบร่อง A10261',
                    baseFormulaKey: 'c2_nex_fix3',
                  ),
                },
                extraPlainCards: const [
                  PatternCardDef(
                    id: 'c2_nex_fix4_card',
                    title: 'บานช่องแสงแบ่งซอย 4 ช่อง (2×2)',
                    subtitle: 'แบบมาตรฐานแคตตาล็อก NEX 200 หน้า 13',
                    baseFormulaKey: 'c2_nex_fix4',
                  ),
                ],
              ),
            ),
          ],
        ),
        const BrandDef(
          id: 'c2_smartplus',
          title: 'SMART PLUS (Semi Euro)',
          subtitle: 'ชุดบานเลื่อน บานเปิด และบานกระทุ้ง Semi Euro',
          priceBrandKey: 'SMART_PLUS',
          systems: [
            SubSystemDef(
              id: 'c2_sp_sliding',
              title: 'ชุดบานเลื่อน',
              patterns: [
                PatternCardDef(
                  id: 'c2_sp_s2_card',
                  title: '2 ราง แบ่ง 2',
                  baseFormulaKey: 'c2_sp_s2',
                  optionGroups: [
                    OptionGroupDef(
                      id: 'sill_height',
                      title: 'ชนิดเฟรมล่าง',
                      choices: [
                        OptionChoice(id: 'low', label: 'ขาเตี้ย'),
                        OptionChoice(id: 'high', label: 'ขาสูง'),
                      ],
                      defaultValue: 'low',
                    ),
                  ],
                ),
                PatternCardDef(
                  id: 'c2_sp_s4_card',
                  title: '2 ราง แบ่ง 4',
                  baseFormulaKey: 'c2_sp_s4_2t',
                ),
                PatternCardDef(
                  id: 'c2_sp_s3_card',
                  title: '3 ราง แบ่ง 3',
                  baseFormulaKey: 'c2_sp_s3_3t',
                ),
                PatternCardDef(
                  id: 'c2_sp_s2_sec_card',
                  title: '3 ราง แบ่ง 2 มุ้งนิรภัย',
                  baseFormulaKey: 'c2_sp_s2_3t_sec',
                ),
                PatternCardDef(
                  id: 'c2_sp_more_dis',
                  title: 'รูปแบบเพิ่มเติม',
                  enabled: false,
                  disabledBadge: 'รออัปเดตเวอร์ชันถัดไป',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_sp_case',
              title: 'บานเปิด',
              patterns: [
                PatternCardDef(
                  id: 'c2_sp_case1_card',
                  title: 'บานเปิดเดี่ยว',
                  baseFormulaKey: 'c2_sp_case1',
                ),
                PatternCardDef(
                  id: 'c2_sp_case1_top_card',
                  title: 'บานเปิดเดี่ยว + ช่องแสงบน',
                  baseFormulaKey: 'c2_sp_case1',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเปิด (มม.)',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_sp_awn',
              title: 'บานกระทุ้ง',
              patterns: [
                PatternCardDef(
                  id: 'c2_sp_awn1_card',
                  title: 'บานกระทุ้งเดี่ยว',
                  baseFormulaKey: 'c2_sp_awn1',
                ),
                PatternCardDef(
                  id: 'c2_sp_awn1_top_card',
                  title: 'บานกระทุ้งเดี่ยว + ช่องแสงบน',
                  baseFormulaKey: 'c2_sp_awn1',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานกระทุ้ง (มม.)',
                ),
              ],
            ),
          ],
        ),
        const BrandDef(
          id: 'c2_uai',
          title: 'UAI (ยูเอไอ)',
          subtitle: 'ระบบบานเลื่อน Super Frame',
          priceBrandKey: 'UAI',
          systems: [
            SubSystemDef(
              id: 'c2_uai_sf',
              title: 'บานเลื่อน Super Frame',
              patterns: [
                PatternCardDef(
                  id: 'c2_uai_s2_card',
                  title: 'บานเลื่อนแบ่งสอง',
                  baseFormulaKey: 'c2_uai_s2_real',
                  optionGroups: [
                    OptionGroupDef(
                      id: 'mosq_sash',
                      title: 'ใช้กรอบบานเป็นกรอบมุ้งลวด',
                      controlType: OptionControlType.switchToggle,
                      choices: [
                        OptionChoice(id: 'false', label: 'ปิด'),
                        OptionChoice(id: 'true', label: 'เปิด'),
                      ],
                      defaultValue: 'false',
                    ),
                  ],
                ),
                PatternCardDef(
                  id: 'c2_uai_s3_dis',
                  title: 'บานเลื่อนแบ่ง 3',
                  enabled: false,
                  disabledBadge: 'รออัปเดต',
                ),
                PatternCardDef(
                  id: 'c2_uai_s4_card',
                  title: 'บานเลื่อนแบ่ง 4',
                  baseFormulaKey: 'c2_uai_s4',
                ),
                PatternCardDef(
                  id: 'c2_uai_s6_card',
                  title: 'บานเลื่อนแบ่ง 6',
                  baseFormulaKey: 'c2_uai_s6',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c2_uai_0024',
              title: 'บานเปิด / บานกระทุ้ง (UAI-0024)',
              patterns: [
                PatternCardDef(
                    id: 'c2_uai_24_1',
                    title: 'บานกระทุ้งเดี่ยว',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c2_uai_24_2',
                    title: 'บานเปิดเดี่ยว',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c2_uai_24_3',
                    title: 'บานเปิดคู่',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
              ],
            ),
            SubSystemDef(
              id: 'c2_uai_doors',
              title: 'ประตูบานเปิด',
              emptyMessage: 'ยังไม่มีระบบที่เปิดใช้งาน',
            ),
            SubSystemDef(
              id: 'c2_uai_0025',
              title: 'ช่องแสง FIX / ชุดผสม (UAI-0025)',
              patterns: [
                PatternCardDef(
                    id: 'c2_uai_25_1',
                    title: 'ช่องแสงเดี่ยว',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c2_uai_25_2',
                    title: 'ช่องแสงแบ่ง 2',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c2_uai_25_3',
                    title: 'ช่องแสงแบ่ง 3',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c2_uai_25_4',
                    title: 'ชุดผสมช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c2_uai_25_5',
                    title: 'ชุดผสมช่องแสงล่าง',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c2_uai_25_6',
                    title: 'ชุดผสมช่องแสงซ้าย-ขวา',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
              ],
            ),
          ],
        ),
        const BrandDef(
          id: 'c2_aluframe_dis',
          title: 'ALUFRAME (อลูเฟรม)',
          subtitle: 'ชุดพัฒนาอลูเฟรม',
          priceBrandKey: 'ALUFRAME',
          enabled: false,
          disabledBadge: 'รออัปเดต',
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // CATEGORY 3: ชุดยูโรโปรไฟล์
    // -------------------------------------------------------------------------
    CategoryDef(
      id: 'cat3_euro',
      title: 'ชุดยูโรโปรไฟล์',
      subtitle: 'ระบบโปรไฟล์มาตรฐานยูโรร่อง C-Groove',
      brands: [
        BrandDef(
          id: 'c3_orm_pano',
          title: 'ORM (Pano Suit)',
          subtitle: 'ระบบยูโรโปรไฟล์ Pano Suit',
          priceBrandKey: 'ORM',
          systems: [
            SubSystemDef(
              id: 'c3_orm_sliding',
              title: 'บานเลื่อน Pano Suit',
              patterns: [
                PatternCardDef(
                  id: 'c3_orm_s2_card',
                  title: 'บานเลื่อน 2 บาน',
                  baseFormulaKey: 'c3_orm_s2',
                  optionGroups: ormPanoSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_orm_s3_card',
                  title: 'บานเลื่อน 3 บาน',
                  baseFormulaKey: 'c3_orm_s3',
                  optionGroups: ormPanoSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_orm_s4_ctr_card',
                  title: 'บานเลื่อน 4 บาน เปิดกลาง',
                  baseFormulaKey: 'c3_orm_s4_center',
                  optionGroups: ormPanoSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_orm_s4_1w_card',
                  title: 'บานเลื่อน 4 บาน เปิดทางเดียว',
                  baseFormulaKey: 'c3_orm_s4_oneway',
                  optionGroups: ormPanoSlidingOptions,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c3_orm_case',
              title: 'บานเปิด',
              patterns: [
                PatternCardDef(
                  id: 'c3_orm_case1_card',
                  title: 'บานเปิด · บานเดี่ยว',
                  baseFormulaKey: 'c3_orm_case1_chk',
                ),
                PatternCardDef(
                  id: 'c3_orm_case2_dis',
                  title: 'บานเปิด · บานคู่',
                  enabled: false,
                  disabledBadge: 'รออัปเดต',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c3_orm_awn',
              title: 'บานกระทุ้ง',
              patterns: [
                PatternCardDef(
                  id: 'c3_orm_awn1_card',
                  title: 'บานกระทุ้ง · บานเดี่ยว',
                  baseFormulaKey: 'c3_orm_awn1_chk',
                ),
                PatternCardDef(
                  id: 'c3_orm_awn2_dis',
                  title: 'บานกระทุ้ง · บานคู่',
                  enabled: false,
                  disabledBadge: 'รออัปเดต',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c3_orm_fixed_dis',
              title: 'บานตาย / ช่องแสง',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
            SubSystemDef(
              id: 'c3_orm_cw_dis',
              title: 'ผนังกระจก',
              enabled: false,
              disabledBadge: 'รออัปเดต',
            ),
          ],
        ),
        BrandDef(
          id: 'c3_fuji',
          title: 'Fuji Eurotech',
          subtitle: 'ระบบยูโรโปรไฟล์ Fuji Eurotech',
          priceBrandKey: 'FUJI',
          systems: [
            SubSystemDef(
              id: 'c3_fuji_sliding',
              title: 'บานเลื่อน',
              patterns: [
                PatternCardDef(
                  id: 'c3_fuji_s2_card',
                  title: 'บานเลื่อนสลับ 2 บาน',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                  optionGroups: fujiSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_fuji_s2_1s1f_card',
                  title: 'บานเลื่อน 2 บาน (เลื่อน 1 + ตาย 1)',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                  optionGroups: fujiSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_fuji_s3_card',
                  title: 'บานเลื่อน 3 บาน',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                  optionGroups: fujiSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_fuji_s4_ctr_card',
                  title: 'บานเลื่อนแบ่ง 4 เปิดกลาง',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                  optionGroups: fujiSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_fuji_4t_int_card',
                  title: 'บานเลื่อน 4 ราง ภายใน',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                  id: 'c3_fuji_5t_int_card',
                  title: 'บานเลื่อน 5 ราง ภายใน',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                  id: 'c3_fuji_s4_2t_card',
                  title: 'บานเลื่อน 4 บาน (2 ราง)',
                  baseFormulaKey: 'c3_fuji_s2_f7981_2t',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                  id: 'c3_fuji_s4_3t_card',
                  title: 'บานเลื่อน 4 บาน (3 ราง)',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                  id: 'c3_fuji_s5_card',
                  title: 'บานเลื่อน 5 บาน',
                  baseFormulaKey: 'c3_fuji_s2_final',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                    id: 'c3_fuji_dis_1',
                    title: 'บานเลื่อนสลับ 2 + ช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_2',
                    title: 'บานเลื่อนสลับ 2 + ช่องแสงล่าง',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_3',
                    title: 'บานเลื่อน 3 บาน + ช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_4',
                    title: 'บานเลื่อน 3 บาน + ช่องแสงล่าง',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_5',
                    title: 'บานเลื่อนแบ่ง 4 + ช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_6',
                    title: 'บานเลื่อนแบ่ง 4 + ช่องแสงล่าง',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_7',
                    title: 'บานเลื่อน + บานตายข้างซ้าย',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_8',
                    title: 'บานเลื่อน + บานตายข้างขวา',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_9',
                    title: 'บานเลื่อนเข้ามุม 90° (2+2)',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_dis_10',
                    title: 'บานเลื่อนเข้ามุม 90° (3+3)',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
              ],
            ),
            SubSystemDef(
              id: 'c3_fuji_windows',
              title: 'บานกระทุ้ง / บานเปิด',
              patterns: [
                PatternCardDef(
                  id: 'c3_fuji_w1_card',
                  title: 'บานกระทุ้ง 1 บาน',
                  baseFormulaKey: 'c3_fuji_w1',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                  id: 'c3_fuji_w2_card',
                  title: 'บานกระทุ้ง 2 บาน / บานเปิดคู่',
                  baseFormulaKey: 'c3_fuji_w2',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                  id: 'c3_fuji_w1_mosq_card',
                  title: 'บานเปิด 1 บาน + มุ้งลวด',
                  baseFormulaKey: 'c3_fuji_w1_mosq',
                  tableMode: InputTableMode.fujiFourRow,
                ),
                PatternCardDef(
                  id: 'c3_fuji_w1_bot_card',
                  title: 'บานกระทุ้ง 1 บาน + บานตายล่าง',
                  baseFormulaKey: 'c3_fuji_w1_fixbot',
                  tableMode: InputTableMode.fujiFourRow,
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเปิด/กระทุ้ง (มม.)',
                ),
                PatternCardDef(
                  id: 'c3_fuji_w2_bot_card',
                  title: 'บานกระทุ้ง 2 บาน + บานตายล่าง',
                  baseFormulaKey: 'c3_fuji_w2_fixbot',
                  tableMode: InputTableMode.fujiFourRow,
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเปิด/กระทุ้ง (มม.)',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c3_fuji_doors_dis',
              title: 'ประตูบานเปิด',
              patterns: [
                PatternCardDef(
                    id: 'c3_fuji_d_dis1',
                    title: 'ประตูบานเปิดเดี่ยว',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_d_dis2',
                    title: 'ประตูบานเปิดคู่',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_d_dis3',
                    title: 'ประตูบานเปิดเดี่ยว + ช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_d_dis4',
                    title: 'ประตูบานเปิดคู่ + ช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_d_dis5',
                    title: 'ประตูบานเปิด + ช่องแสงข้าง',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_d_dis6',
                    title: 'ประตูบานเปิดคู่ + ช่องแสงข้าง',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
              ],
            ),
            SubSystemDef(
              id: 'c3_fuji_fix_dis',
              title: 'บานฟิกตาย',
              patterns: [
                PatternCardDef(
                    id: 'c3_fuji_f_dis1',
                    title: 'บานฟิกเดี่ยว',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_f_dis2',
                    title: 'บานฟิกแบ่ง 2',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_f_dis3',
                    title: 'บานฟิกแบ่ง 3',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_f_dis4',
                    title: 'บานฟิกแบ่ง 4',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
                PatternCardDef(
                    id: 'c3_fuji_f_dis5',
                    title: 'บานฟิกเข้ามุม 90°',
                    enabled: false,
                    disabledBadge: 'รอสูตรคำนวณ'),
              ],
            ),
            SubSystemDef(
              id: 'c3_fuji_wood_dis',
              title: 'ประตูวงกบไม้',
              enabled: false,
              disabledBadge: 'ระบบนี้อยู่ระหว่างจัดทำ',
            ),
          ],
        ),
        BrandDef(
          id: 'c3_alumet_iconiq',
          title: 'ALUMET (Iconiq Euro)',
          subtitle: 'ระบบยูโรโปรไฟล์ ICONIQ · บานเลื่อน บานเปิด กระทุ้ง ประตู 11 แบบ บานติดตาย',
          priceBrandKey: 'ALUMET',
          systems: [
            SubSystemDef(
              id: 'c3_alu_sliding',
              title: 'บานเลื่อน ICONIQ (17 แบบ)',
              patterns: [
                const PatternCardDef(
                  id: 'c3_alu_s2_card',
                  title: 'บานเลื่อนสลับ 2 บาน',
                  baseFormulaKey: 'c3_alu_s2',
                  optionGroups: iconiqSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s2_in_mosq_card',
                  title: 'ประตูบานเลื่อนภายใน + มุ้ง',
                  baseFormulaKey: 'c3_alu_s2_door_in_mosq',
                  optionGroups: iconiqSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s2_top_card',
                  title: 'บานเลื่อนสลับ 2 บาน + ช่องแสงบน',
                  baseFormulaKey: 'c3_alu_s2_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: iconiqSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s3_card',
                  title: 'บานเลื่อน 3 บาน',
                  baseFormulaKey: 'c3_alu_s3',
                  optionGroups: iconiqSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s4_ctr_card',
                  title: 'บานเลื่อนแบ่ง 4 เปิดกลาง',
                  baseFormulaKey: 'c3_alu_s4_ctr',
                  optionGroups: iconiqSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s4_ctr_top_card',
                  title: 'บานเลื่อนแบ่ง 4 เปิดกลาง + ช่องแสงบน',
                  baseFormulaKey: 'c3_alu_s4_ctr_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: iconiqSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s4_1w_card',
                  title: 'บานเลื่อน 4 บาน เปิดทางเดียว',
                  baseFormulaKey: 'c3_alu_s4_1w',
                  optionGroups: iconiqSlidingOptions,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s4_1w_top_card',
                  title: 'บานเลื่อน 4 บาน เปิดทางเดียว + ช่องแสงบน',
                  baseFormulaKey: 'c3_alu_s4_1w_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเลื่อน (มม.)',
                  optionGroups: iconiqSlidingOptions,
                ),
                ..._buildAlumetExtendedSlidingCards(
                  prefix: 'c3_alu',
                  seriesKey: 'iq',
                  slidingOptions: iconiqSlidingOptions,
                  includeS3Top: true,
                ),
                const PatternCardDef(
                  id: 'c3_alu_s6_corner_dis',
                  title: 'บานเลื่อนแบ่ง 6 เปิดกลางชนมุม 90°',
                  enabled: false,
                  disabledBadge: 'รออัปเดต',
                ),
              ],
            ),
            SubSystemDef(
              id: 'c3_alu_casement',
              title: 'หน้าต่างบานเปิด ICONIQ (20 แบบ)',
              subtitle: '1–5 บาน · ไม่มีช่องแสง / +ช่องแสงบน / +ช่องแสงล่าง / +บน-ล่าง',
              subTabs: _buildAlumetCasementSubTabs(
                prefix: 'c3_alu',
                seriesKey: 'iq',
                existingBySlot: const {
                  '1_plain': PatternCardDef(
                    id: 'c3_alu_case1_card',
                    title: 'หน้าต่างบานเปิดเดี่ยว',
                    baseFormulaKey: 'c3_alu_case1',
                  ),
                  '2_plain': PatternCardDef(
                    id: 'c3_alu_case2_card',
                    title: 'หน้าต่างบานเปิดคู่ · เปิดกลางโล่ง',
                    baseFormulaKey: 'c3_alu_case2',
                  ),
                },
              ),
            ),
            SubSystemDef(
              id: 'c3_alu_awning',
              title: 'หน้าต่างบานกระทุ้ง ICONIQ (14 แบบ)',
              subtitle: '1–5 บาน · ไม่มีช่องแสง / +ช่องแสงบน / +ช่องแสงล่าง',
              subTabs: _buildAlumetAwningSubTabs(
                prefix: 'c3_alu',
                seriesKey: 'iq',
                existingBySlot: const {
                  '1_plain': PatternCardDef(
                    id: 'c3_alu_awn1_card',
                    title: 'บานกระทุ้ง 1 บาน',
                    baseFormulaKey: 'c3_alu_awn1',
                  ),
                  '1_bot': PatternCardDef(
                    id: 'c3_alu_awn1_bot_card',
                    title: 'บานกระทุ้งเดี่ยว + ช่องแสงล่าง',
                    baseFormulaKey: 'c3_alu_awn1_bot',
                    auxType: AuxDimensionType.refHeightH1,
                    auxLabel: 'H1 ความสูงส่วนบานกระทุ้ง (มม.)',
                  ),
                },
              ),
            ),
            SubSystemDef(
              id: 'c3_alu_doors',
              title: 'ประตูบานเปิด ICONIQ (11 แบบ)',
              subtitle: 'ประตูเดี่ยว-คู่ · กระจก / เกล็ดอลูมิเนียม · ช่องแสงข้าง / บน / โค้งครึ่งวงกลม',
              patterns: _buildIconiqSwingDoorCards(),
            ),
            SubSystemDef(
              id: 'c3_alu_fixed',
              title: 'บานติดตาย / ช่องแสง ICONIQ (14 แบบ)',
              subtitle: '1–5 ช่อง · แถวเดียว / +ช่องแสงบน / +ช่องแสงบน-ล่าง',
              subTabs: _buildAlumetFixedSubTabs(
                prefix: 'c3_alu',
                seriesKey: 'iq',
              ),
            ),
          ],
        ),
        BrandDef(
          id: 'c3_smartplus_euro',
          title: 'SMART PLUS (Euro)',
          subtitle: 'ระบบบานเลื่อน บานเปิด และประตู EURO PROFILE',
          priceBrandKey: 'SMART_PLUS',
          systems: [
            SubSystemDef(
              id: 'c3_sp_sliding_hub',
              title: 'ชุดบานเลื่อน EURO',
              subTabs: [
                SubSystemDef(
                  id: 'c3_sp_45_tab',
                  title: 'เฟรมประกอบ 45°',
                  patterns: [
                    PatternCardDef(
                      id: 'c3_sp_s2_2t_card',
                      title: 'บานเลื่อน 2 ราง แบ่ง 2',
                      baseFormulaKey: 'c3_sp_s2',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_s4_2t_card',
                      title: 'บานเลื่อน 2 ราง แบ่ง 4',
                      baseFormulaKey: 'c3_sp_s4_2t',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_s2_3t_45_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 2',
                      baseFormulaKey: 'c3_sp_s2_3t',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_s3_3t_euro_card',
                      title: 'ชุดบานเลื่อน EURO 3 ราง แบ่ง 3',
                      baseFormulaKey: 'c3_sp_s3_3t_euro',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_s4_3t_45_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 4',
                      baseFormulaKey: 'c3_sp_s4_3t',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_s4_4t_card',
                      title: 'บานเลื่อน 4 ราง แบ่ง 4',
                      baseFormulaKey: 'c3_sp_s4_4t',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_s2_3t_sec_card',
                      title: 'ชุดบานเลื่อน EURO 3 ราง (มุ้งนิรภัย) แบ่ง 2',
                      baseFormulaKey: 'c3_sp_s2_3t_sec',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_s4_3t_sec_card',
                      title: 'ชุดบานเลื่อน EURO 3 ราง (มุ้งนิรภัย) แบ่ง 4',
                      baseFormulaKey: 'c3_sp_s4_3t_sec',
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_corner_dis',
                      title: 'บานเลื่อน 3 ราง เข้ามุม 90°',
                      enabled: false,
                      disabledBadge: 'รออัปเดต',
                    ),
                  ],
                ),
                SubSystemDef(
                  id: 'c3_sp_90_tab',
                  title: 'เฟรมประกอบ 90°',
                  patterns: [
                    PatternCardDef(
                      id: 'c3_sp_90_s2_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 2',
                      baseFormulaKey: 'c3_sp_90_s2',
                      tableMode: InputTableMode.smartPlus90FourCol,
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_90_s2_top_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 2 + ช่องแสงบน',
                      baseFormulaKey: 'c3_sp_90_s2_top',
                      tableMode: InputTableMode.smartPlus90FourCol,
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_90_s3_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 3',
                      baseFormulaKey: 'c3_sp_90_s3',
                      tableMode: InputTableMode.smartPlus90FourCol,
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_90_s3_top_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 3 + ช่องแสงบน',
                      baseFormulaKey: 'c3_sp_90_s3_top',
                      tableMode: InputTableMode.smartPlus90FourCol,
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_90_s4_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 4',
                      baseFormulaKey: 'c3_sp_s4_3t',
                      tableMode: InputTableMode.smartPlus90FourCol,
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                    PatternCardDef(
                      id: 'c3_sp_90_s4_top_card',
                      title: 'บานเลื่อน 3 ราง แบ่ง 4 + ช่องแสงบน',
                      baseFormulaKey: 'c3_sp_90_s4_top',
                      tableMode: InputTableMode.smartPlus90FourCol,
                      optionGroups: smartPlusEuroSlidingOptions,
                    ),
                  ],
                ),
              ],
            ),
            SubSystemDef(
              id: 'c3_sp_windows',
              title: 'บานเปิด / กระทุ้ง EURO',
              patterns: [
                PatternCardDef(
                  id: 'c3_sp_win1_top_card',
                  title: 'บานเปิดเดี่ยว + ช่องแสงบน',
                  baseFormulaKey: 'c3_sp_win1_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเปิด (มม.)',
                  optionGroups: smartPlusEuroWinTopOptions,
                ),
                PatternCardDef(
                  id: 'c3_sp_win2_card',
                  title: 'บานเปิดคู่ไม่มีเสากลาง',
                  baseFormulaKey: 'c3_sp_win2',
                  optionGroups: smartPlusEuroWinOptions,
                ),
                PatternCardDef(
                  id: 'c3_sp_win2_top_card',
                  title: 'บานเปิดคู่ไม่มีเสากลาง + ช่องแสงบน',
                  baseFormulaKey: 'c3_sp_win2_top',
                  auxType: AuxDimensionType.refHeightH1,
                  auxLabel: 'H1 ความสูงส่วนบานเปิดคู่ (มม.)',
                  optionGroups: smartPlusEuroWinTopOptions,
                ),
                PatternCardDef(
                    id: 'c3_sp_w_sec1_dis',
                    title: 'หน้าต่างบานเปิดเดี่ยว มุ้งนิรภัย',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c3_sp_w_sec2_dis',
                    title: 'หน้าต่างบานเปิดคู่ มุ้งนิรภัย',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c3_sp_w_sec3_dis',
                    title: 'หน้าต่างบานกระทุ้ง มุ้งนิรภัย',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c3_sp_w_fix_dis',
                    title: 'บานติดตาย EURO',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
              ],
            ),
            SubSystemDef(
              id: 'c3_sp_doors',
              title: 'ประตูบานเปิด EURO',
              patterns: [
                PatternCardDef(
                  id: 'c3_sp_door1_card',
                  title: 'ประตูบานเปิดเดี่ยว',
                  baseFormulaKey: 'c3_sp_door1',
                  optionGroups: smartPlusEuroDoorOptions,
                ),
                PatternCardDef(
                  id: 'c3_sp_door2_card',
                  title: 'ประตูบานเปิดคู่ไม่มีเสากลาง',
                  baseFormulaKey: 'c3_sp_door2',
                  optionGroups: smartPlusEuroDoorOptions,
                ),
                PatternCardDef(
                    id: 'c3_sp_door1_top_dis',
                    title: 'ประตูบานเปิดเดี่ยว + ช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
                PatternCardDef(
                    id: 'c3_sp_door2_top_dis',
                    title: 'ประตูบานเปิดคู่ + ช่องแสงบน',
                    enabled: false,
                    disabledBadge: 'รออัปเดต'),
              ],
            ),
          ],
        ),
        BrandDef(
          id: 'c3_uai_euro_dis',
          title: 'UAI (Euro)',
          subtitle: 'ระบบยูโรโปรไฟล์ UAI',
          priceBrandKey: 'UAI',
          enabled: false,
          disabledBadge: 'รออัปเดต',
        ),
        BrandDef(
          id: 'c3_aluframe_euro',
          title: 'ALUFRAME (อลูเฟรม)',
          subtitle: 'ระบบบานเลื่อนและบานเปิด/กระทุ้งยูโร ALUFRAME',
          priceBrandKey: 'ALUFRAME',
          systems: [
            SubSystemDef(
              id: 'c3_af_sliding',
              title: 'บานเลื่อน ALUFRAME',
              patterns: [
                PatternCardDef(
                  id: 'c3_af_s2_card',
                  title: 'บานเลื่อนสลับ 2 บาน',
                  baseFormulaKey: 'c3_af_s2',
                  optionGroups: aluframeSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_af_s3_card',
                  title: 'บานเลื่อน 3 บาน',
                  baseFormulaKey: 'c3_af_s2',
                  optionGroups: aluframeSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_af_s4_ctr_card',
                  title: 'บานเลื่อนแบ่ง 4 เปิดกลาง',
                  baseFormulaKey: 'c3_af_s2',
                  optionGroups: aluframeSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_af_s4_std_card',
                  title: 'บานเลื่อนมาตรฐาน 4 บาน',
                  warningBadge: 'รางตบรอยืนยัน',
                  baseFormulaKey: 'c3_af_s2',
                  optionGroups: aluframeSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_af_s6_ctr_card',
                  title: 'บานเลื่อนแบ่ง 6 เปิดกลาง',
                  warningBadge: 'รางตบรอยืนยัน',
                  baseFormulaKey: 'c3_af_s2',
                  optionGroups: aluframeSlidingOptions,
                ),
                PatternCardDef(
                  id: 'c3_af_s4_flush_card',
                  title: 'บานเลื่อน 4 บาน รางฝังพื้น',
                  warningBadge: 'รางตบรอยืนยัน',
                  baseFormulaKey: 'c3_af_s2',
                  optionGroups: aluframeSlidingOptions,
                ),
              ],
            ),
            SubSystemDef(
              id: 'c3_af_casement_hub',
              title: 'บานกระทุ้ง / บานเปิด',
              subTabs: [
                SubSystemDef(
                  id: 'c3_af_tab_win',
                  title: 'หน้าต่าง',
                  patterns: [
                    PatternCardDef(
                      id: 'c3_af_w1_card',
                      title: 'บานเดี่ยวไม่มีช่องแสง',
                      baseFormulaKey: 'c3_af_w1',
                      tableMode: InputTableMode.singleSet,
                      optionGroups: [
                        OptionGroupDef(
                          id: 'frame_style',
                          title: 'รูปแบบวงกบ',
                          choices: [
                            OptionChoice(id: 'std', label: 'วงกบมาตรฐาน'),
                            OptionChoice(id: 'plaster', label: 'วงกบซับปลอก'),
                          ],
                          defaultValue: 'std',
                        ),
                      ],
                    ),
                    PatternCardDef(
                      id: 'c3_af_w1_top_card',
                      title: 'บานเดี่ยวพร้อมช่องแสงบน',
                      baseFormulaKey: 'c3_af_w1_top',
                      tableMode: InputTableMode.singleSet,
                      auxType: AuxDimensionType.refHeightH1,
                      auxLabel: 'H1 ความสูงส่วนบานกระทุ้ง/เปิด (มม.)',
                    ),
                  ],
                ),
                SubSystemDef(
                  id: 'c3_af_tab_case2',
                  title: 'บานเปิดคู่',
                  patterns: [
                    PatternCardDef(
                      id: 'c3_af_case2_card',
                      title: 'บานเปิดคู่ไม่มีช่องแสง',
                      baseFormulaKey: 'c3_af_case2',
                      tableMode: InputTableMode.singleSet,
                    ),
                    PatternCardDef(
                      id: 'c3_af_case2_top_card',
                      title: 'บานเปิดคู่พร้อมช่องแสงบน',
                      baseFormulaKey: 'c3_af_awn2_top',
                      tableMode: InputTableMode.singleSet,
                      auxType: AuxDimensionType.refHeightH1,
                      auxLabel: 'H1 ความสูงส่วนบานเปิดคู่ (มม.)',
                    ),
                  ],
                ),
                SubSystemDef(
                  id: 'c3_af_tab_awn2',
                  title: 'บานกระทุ้ง',
                  patterns: [
                    PatternCardDef(
                      id: 'c3_af_awn2_card',
                      title: 'บานกระทุ้งคู่ไม่มีช่องแสง',
                      baseFormulaKey: 'c3_af_awn2',
                      tableMode: InputTableMode.singleSet,
                    ),
                    PatternCardDef(
                      id: 'c3_af_awn2_top_card',
                      title: 'บานกระทุ้งคู่พร้อมช่องแสงบน',
                      baseFormulaKey: 'c3_af_awn2_top',
                      tableMode: InputTableMode.singleSet,
                      auxType: AuxDimensionType.refHeightH1,
                      auxLabel: 'H1 ความสูงส่วนบานกระทุ้งคู่ (มม.)',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // CATEGORY 4: ระบบบานเฟี้ยม (All 136 Active Cards + Disabled Badges!)
    // -------------------------------------------------------------------------
    CategoryDef(
      id: 'cat4_folding',
      title: 'ระบบบานเฟี้ยม',
      subtitle: 'ระบบบานเฟี้ยมยูโรและชุดพัฒนาครบทุกผังการจัดบาน',
      brands: [
        BrandDef(
          id: 'c4_orm_fold',
          title: 'ORM Euro Folding',
          subtitle: 'ORM PANO SUIT Folding (เฟรม 90 mm และ 101.6 mm)',
          priceBrandKey: 'ORM',
          systems: [
            SubSystemDef(
              id: 'c4_orm_90_sys',
              title: 'เฟรม 90 mm (805-01 / 02 / 03)',
              subtitle: '16 รูปแบบการจัดบาน (2-2-0 ถึง 8-4-4)',
              patterns: _buildOrmFoldingCards(is101Mm: false),
            ),
            SubSystemDef(
              id: 'c4_orm_101_sys',
              title: 'เฟรม 101.6 mm (805-12 / 13 / 14)',
              subtitle: '16 รูปแบบการจัดบาน (2-2-0 ถึง 8-4-4)',
              patterns: _buildOrmFoldingCards(is101Mm: true),
            ),
          ],
        ),
        BrandDef(
          id: 'c4_fuji_fold',
          title: 'Fuji Eurotech Folding',
          subtitle: 'รางมาตรฐาน และ ราง U (2-2-0 ถึง 10-5-5)',
          priceBrandKey: 'FUJI',
          systems: [
            SubSystemDef(
              id: 'c4_fuji_std_sys',
              title: 'รางมาตรฐาน (F7969)',
              subtitle: '32 รูปแบบการจัดบาน',
              patterns: _buildFujiFoldingCards(isUTrack: false),
            ),
            SubSystemDef(
              id: 'c4_fuji_u_sys',
              title: 'ราง U (F7932)',
              subtitle: '32 รูปแบบการจัดบาน',
              patterns: _buildFujiFoldingCards(isUTrack: true),
            ),
          ],
        ),
        const BrandDef(
          id: 'c4_schimmer_fold',
          title: 'SMS SCHIMMER',
          subtitle: 'HOMELIFE 240 — บานเฟี้ยมเปิดออกนอก',
          priceBrandKey: 'SCHIMMER',
          directPatterns: [
            PatternCardDef(
              id: 'c4_sch_2l_card',
              title: 'บานเฟี้ยม 2 บาน เปิดซ้าย (2L)',
              baseFormulaKey: 'c4_sch',
            ),
            PatternCardDef(
              id: 'c4_sch_3_1l2r_card',
              title: 'บานเฟี้ยม 3 บาน ซ้าย 1 · ขวา 2 (1L-2R)',
              baseFormulaKey: 'c4_sch_3_1l2r',
            ),
            PatternCardDef(
              id: 'c4_sch_3_3l_card',
              title: 'บานเฟี้ยม 3 บาน เปิดซ้าย (3L)',
              baseFormulaKey: 'c4_sch_3_3l',
            ),
            PatternCardDef(
              id: 'c4_sch_4_1l3r_card',
              title: 'บานเฟี้ยม 4 บาน ซ้าย 1 · ขวา 3 (1L-3R)',
              baseFormulaKey: 'c4_sch_4_1l3r',
            ),
            PatternCardDef(
              id: 'c4_sch_4_2l2r_card',
              title: 'บานเฟี้ยม 4 บาน ซ้าย 2 · ขวา 2 (2L-2R)',
              baseFormulaKey: 'c4_sch_4_2l2r',
            ),
            PatternCardDef(
              id: 'c4_sch_4_4l_card',
              title: 'บานเฟี้ยม 4 บาน เปิดซ้าย (4L)',
              baseFormulaKey: 'c4_sch_4_4l',
            ),
            PatternCardDef(
              id: 'c4_sch_5_4l1r_card',
              title: 'บานเฟี้ยม 5 บาน ซ้าย 4 · ขวา 1 (4L-1R)',
              foldingFamily: 'sch240',
              foldingTotalPanels: 5,
              foldingLeftPanels: 4,
              foldingRightPanels: 1,
            ),
          ],
        ),
        BrandDef(
          id: 'c4_smartplus_fold',
          title: 'SMART PLUS (บานเฟี้ยม EURO)',
          subtitle: 'ชุดบานเฟี้ยม EURO 19 รูปแบบ',
          priceBrandKey: 'SMART_PLUS',
          directPatterns: _buildSmartPlusFoldingCards(),
        ),
        BrandDef(
          id: 'c4_alumet_fold',
          title: 'ALUMET (Smart X Folding)',
          subtitle: 'Smart X Folding 14 รูปแบบ',
          priceBrandKey: 'ALUMET',
          directPatterns: _buildAlumetFoldingCards(),
        ),
        const BrandDef(
          id: 'c4_uai_fold_dis',
          title: 'UAI Folding',
          subtitle: 'ระบบบานเฟี้ยม UAI',
          priceBrandKey: 'UAI',
          enabled: false,
          disabledBadge: 'กำหนดทดสอบ 23 ต.ค. 2569',
        ),
      ],
    ),

    // -------------------------------------------------------------------------
    // CATEGORY 5: บานเปลือย / Shower (All 3 Brands = รอ Open Beta)
    // -------------------------------------------------------------------------
    const CategoryDef(
      id: 'cat5_shower',
      title: 'บานเปลือย / Shower',
      subtitle: 'ระบบอุปกรณ์ฟิตติ้งกระจกเปลือยและฉากกั้นอาบน้ำ',
      brands: [
        BrandDef(
          id: 'c5_pbm_dis',
          title: 'PBM',
          subtitle: 'ชุดฟิตติ้งบานเปลือยและฉากกั้นอาบน้ำ PBM',
          priceBrandKey: 'PBM',
          enabled: false,
          disabledBadge: 'รอ Open Beta',
        ),
        BrandDef(
          id: 'c5_hyda_dis',
          title: 'HYDA',
          subtitle: 'ชุดอุปกรณ์ฮาร์ดแวร์บานเปลือย HYDA',
          priceBrandKey: 'HYDA',
          enabled: false,
          disabledBadge: 'รอ Open Beta',
        ),
        BrandDef(
          id: 'c5_rp_dis',
          title: 'RP Steelglass',
          subtitle: 'ชุดสเตนเลสและฉากกั้นอาบน้ำ RP Steelglass',
          priceBrandKey: 'RP',
          enabled: false,
          disabledBadge: 'รอ Open Beta',
        ),
      ],
    ),
  ];
}
