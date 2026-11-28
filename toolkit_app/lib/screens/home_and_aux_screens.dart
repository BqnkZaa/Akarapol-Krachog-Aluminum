import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/alupro_image_registry.dart';
import '../data/app_database.dart';
import '../data/seed_repository.dart';
import '../engine/pricing_engine.dart';
import '../models/app_models.dart';
import 'alupro_thumbnail_widgets.dart';
import 'catalog_and_input_screens.dart';
import 'custom_system_studio_screens.dart';
import 'projects_and_quotation_screens.dart';
import 'result_and_pricing_screens.dart';
import 'theme_tokens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ToolkitColors.bgScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: ToolkitColors.cardBorder),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.asset(
                      'assets/images/app_logo_3d.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Toolkit',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ToolkitColors.slateDark,
                              ),
                            ),
                            SizedBox(width: 8),
                            _VipChip(),
                          ],
                        ),
                        SizedBox(height: 1),
                        Text(
                          'เครื่องมือช่างกระจกและอลูมิเนียม',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: ToolkitColors.slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'การแจ้งเตือน',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: ToolkitColors.slateDark,
                          size: 26,
                        ),
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Main Cards
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  // Hero Blue Card: ระบบคำนวณ
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategorySelectScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            ToolkitColors.royalBlue,
                            ToolkitColors.royalBlueDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: ToolkitColors.royalBlue.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.straighten_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ระบบคำนวณ',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'คำนวณสูตรตัดประกอบและถอดของ',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: Color(0xFFDBEAFE),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'เริ่มคำนวณ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ToolkitColors.royalBlue,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 17,
                                  color: ToolkitColors.royalBlue,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2-Column Row: โปรเจกต์ของฉัน | ความรู้ ทริค & ฮาร์ดแวร์
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _HomeSquareCard(
                            icon: Icons.folder_copy_outlined,
                            iconColor: ToolkitColors.royalBlue,
                            title: 'โปรเจกต์ของฉัน',
                            subtitle: 'งานที่บันทึกไว้',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyProjectsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HomeSquareCard(
                            icon: Icons.menu_book_rounded,
                            iconColor: const Color(0xFF0D9488),
                            title: 'ความรู้ ทริค & ฮาร์ดแวร์',
                            subtitle: 'เทคนิคสำหรับช่าง',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const KnowledgeHubScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Full-width Video Card
                  _HomeWideCard(
                    icon: Icons.play_circle_outline_rounded,
                    iconColor: const Color(0xFFEA580C),
                    title: 'เรียนรู้จากงานจริง (คลิปวิดีโอ)',
                    subtitle: 'วิดีโอสอนเทคนิคประกอบและติดตั้งหน้างาน',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VideoEmptyScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Full-width VIP Package Card
                  _HomeWideCard(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: ToolkitColors.vipGoldText,
                    title: 'เติมเงิน / ต่ออายุ VIP',
                    subtitle: 'ตรวจสอบสถานะแพ็กเกจและสิทธิ์การใช้งาน VIP',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MemberPackageScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // VIP Tools Quick Shortcuts Card
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ToolkitColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: ToolkitColors.vipGoldText,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ตั้งค่าระบบทำราคาและใบเสนอราคา (VIP)',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: ToolkitColors.slateDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ShortcutChip(
                              icon: Icons.storefront_outlined,
                              label: 'ข้อมูลร้านของฉัน',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ShopInfoScreen(),
                                  ),
                                );
                              },
                            ),
                            _ShortcutChip(
                              icon: Icons.price_change_outlined,
                              label: 'จัดการ/อัปเดตราคา',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CustomPriceScreen(),
                                  ),
                                );
                              },
                            ),
                            _ShortcutChip(
                              icon: Icons.handyman_outlined,
                              label: 'คลังอุปกรณ์ (ALUMET · VVP · RP)',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const HardwareCatalogScreen(),
                                  ),
                                );
                              },
                            ),
                            _ShortcutChip(
                              icon: Icons.architecture_rounded,
                              label: 'เพิ่มชุดโปรไฟล์ใหม่',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CustomSystemListScreen(),
                                  ),
                                );
                              },
                            ),
                            _ShortcutChip(
                              icon: Icons.handshake_outlined,
                              label: 'ตัวแทนจำหน่าย ORM',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OrmDealersScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Bottom Bar: ติดต่อเรา | บัญชีของฉัน
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ToolkitColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ToolkitColors.slateBody,
                        side: const BorderSide(color: ToolkitColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showContactBottomSheet(context),
                      icon: const Icon(Icons.support_agent_rounded, size: 19),
                      label: const Text(
                        'ติดต่อเรา',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ToolkitColors.deepNavy,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MemberPackageScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline_rounded, size: 19),
                      label: const Text(
                        'บัญชีของฉัน',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showContactBottomSheet(BuildContext context) {
    final email = SeedRepository.instance.staticContent['supportEmail']
            as String? ??
        'toolkitalutechsupport@gmail.com';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ติดต่อทีมงาน Toolkit',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ToolkitColors.slateDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'แจ้งปัญหาการใช้งาน เสนอแนะระบบโปรไฟล์ หรือสอบถามข้อมูลเพิ่มเติม',
              style: TextStyle(fontSize: 13.5, color: ToolkitColors.slateMuted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ToolkitColors.bgScaffold,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ToolkitColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined,
                      color: ToolkitColors.royalBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: email));
                      Navigator.pop(ctx);
                      showToolkitSnackBar(context, 'คัดลอกอีเมลแล้ว');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('คัดลอก'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipChip extends StatelessWidget {
  const _VipChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ToolkitColors.vipGoldBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ToolkitColors.vipGoldBorder),
      ),
      child: const Text(
        'VIP',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: ToolkitColors.vipGoldText,
        ),
      ),
    );
  }
}

class _HomeSquareCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeSquareCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ToolkitColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: ToolkitColors.slateDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: ToolkitColors.slateMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeWideCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeWideCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ToolkitColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: ToolkitColors.slateDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ToolkitColors.slateMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ToolkitColors.slateMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      backgroundColor: ToolkitColors.bgScaffold,
      side: const BorderSide(color: ToolkitColors.cardBorder),
      avatar: Icon(icon, size: 16, color: ToolkitColors.royalBlue),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ToolkitColors.slateBody,
        ),
      ),
      onPressed: onTap,
    );
  }
}

// =============================================================================
// Notifications Screen (การแจ้งเตือน — Exact 2 Items)
// =============================================================================
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rawList = (SeedRepository.instance.staticContent['notifications']
            as List<dynamic>? ??
        []);
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rawList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, idx) {
          final item = rawList[idx] as Map<String, dynamic>;
          final title = item['title'] as String? ?? '';
          final lines = (item['lines'] as List<dynamic>? ?? []).cast<String>();
          final date = item['date'] as String? ?? '';
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ToolkitColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ToolkitColors.slateDark,
                  ),
                ),
                const SizedBox(height: 6),
                ...lines.map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      l,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: ToolkitColors.slateBody,
                      ),
                    ),
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ToolkitColors.slateMuted,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Knowledge Hub -> Trick List & Hardware Empty Screen
// =============================================================================
class KnowledgeHubScreen extends StatelessWidget {
  const KnowledgeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกหมวดความรู้')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HomeWideCard(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: ToolkitColors.royalBlue,
            title: 'ทริคสำหรับช่าง',
            subtitle: 'เทคนิคการวัดช่องเปิด เผื่อระยะ และการประกอบติดตั้ง',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrickListScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeWideCard(
            icon: Icons.handyman_outlined,
            iconColor: const Color(0xFF0D9488),
            title: 'รู้จักฮาร์ดแวร์ & แคตตาล็อก',
            subtitle: 'คลังอุปกรณ์ ALUMET · VVP · RP Steel Glass (258 รายการ พร้อมรูป)',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HardwareCatalogScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class TrickListScreen extends StatelessWidget {
  const TrickListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final articles = (SeedRepository.instance.staticContent['trickArticles']
            as List<dynamic>? ??
        []);
    return Scaffold(
      appBar: AppBar(title: const Text('คลังความรู้ช่าง')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        itemBuilder: (ctx, i) {
          final a = articles[i] as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ToolkitColors.cardBorder),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 18),
              title: Text(
                a['title'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ToolkitColors.slateDark,
                ),
              ),
              subtitle: Text(
                a['subtitle'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: ToolkitColors.slateMuted,
                ),
              ),
              children: [
                const Divider(),
                const SizedBox(height: 6),
                Text(
                  a['body'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 13.8,
                    height: 1.55,
                    color: ToolkitColors.slateBody,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class HardwareEmptyScreen extends HardwareCatalogScreen {
  const HardwareEmptyScreen({super.key});
}

class HardwareCatalogScreen extends StatefulWidget {
  final String initialBrand;

  const HardwareCatalogScreen({super.key, this.initialBrand = 'ALUMET'});

  @override
  State<HardwareCatalogScreen> createState() => _HardwareCatalogScreenState();
}

class _HardwareCatalogScreenState extends State<HardwareCatalogScreen> {
  static final NumberFormat _bahtFmt = NumberFormat('#,##0.##', 'en_US');

  final TextEditingController _searchCtrl = TextEditingController();
  late String _selectedBrand; // 'ทั้งหมด' | 'ALUMET' | 'VVP' | 'RP'
  String _selectedSubCat = 'ทั้งหมด';
  Map<String, CustomMaterialRateOverride> _overrides = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.initialBrand;
    _loadOverrides();
  }

  Future<void> _loadOverrides() async {
    final map = await AppDatabase.instance.getAllCustomMaterialRates();
    if (!mounted) return;
    setState(() {
      _overrides = map;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MaterialRateItem> _mergedVisibleHardware() {
    return PricingEngine.mergeMaterialRates(
      SeedRepository.instance.visibleHardwareRates,
      _overrides,
      category: 'HARDWARE',
    );
  }

  List<String> _subCategoriesFor(List<MaterialRateItem> all) {
    final set = <String>{};
    for (final h in all) {
      if (_selectedBrand != 'ทั้งหมด' && h.brand != _selectedBrand) continue;
      if (h.subCategory.trim().isNotEmpty) set.add(h.subCategory.trim());
    }
    const preferredOrder = [
      'บานเลื่อน',
      'บานเปิด',
      'บานกระทุ้ง',
      'บานเฟี้ยม',
      'สกรู / ทั่วไป',
      'โช้คประตู (บานเปลือย)',
      'ตัวหนีบกระจก (บานเปลือย)',
      'บานพับชาวเวอร์',
      'ตัวหนีบกระจกชาวเวอร์',
      'มือจับ & ตัวยึดกันแกว่ง',
      'ตัวยึดกันแกว่ง & แป๊ป',
      'มือจับประตูห้องน้ำ',
      'กุญแจล็อค & ยางกันน้ำ',
    ];
    final out = <String>['ทั้งหมด'];
    for (final p in preferredOrder) {
      if (set.contains(p)) out.add(p);
    }
    for (final c in set) {
      if (!out.contains(c)) out.add(c);
    }
    return out;
  }

  Future<void> _editPriceDialog(MaterialRateItem item) async {
    final ctrl =
        TextEditingController(text: item.effectivePrice.toStringAsFixed(2));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.code.isNotEmpty ? '${item.code} · ${item.brand}' : item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.name}\nหมวด: ${item.subCategory.isNotEmpty ? item.subCategory : 'อุปกรณ์ทั่วไป'} · หน่วย: ${item.unit}',
              style: const TextStyle(fontSize: 12.5, color: ToolkitColors.slateMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'ราคาต่อ ${item.unit} (บาท)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (item.customPrice != null)
            TextButton(
              onPressed: () async {
                await AppDatabase.instance.deleteCustomMaterialRate(item.rateKey);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadOverrides();
              },
              child: const Text('คืนค่าราคาตั้งต้น'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val == null || val < 0) return;
              await AppDatabase.instance.upsertCustomMaterialRate(
                CustomMaterialRateOverride(
                  rateKey: item.rateKey,
                  category: 'HARDWARE',
                  code: item.code,
                  name: item.name,
                  unit: item.unit,
                  price: val,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadOverrides();
            },
            child: const Text('บันทึกราคา'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _mergedVisibleHardware();
    final aluCount = all.where((e) => e.brand == 'ALUMET').length;
    final vvpCount = all.where((e) => e.brand == 'VVP').length;
    final rpCount = all.where((e) => e.brand == 'RP').length;

    final subCats = _subCategoriesFor(all);
    if (!subCats.contains(_selectedSubCat)) {
      _selectedSubCat = 'ทั้งหมด';
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = all.where((h) {
      if (_selectedBrand != 'ทั้งหมด' && h.brand != _selectedBrand) {
        return false;
      }
      if (_selectedSubCat != 'ทั้งหมด' && h.subCategory != _selectedSubCat) {
        return false;
      }
      if (q.isEmpty) return true;
      return h.code.toLowerCase().contains(q) ||
          h.name.toLowerCase().contains(q) ||
          h.subCategory.toLowerCase().contains(q) ||
          (h.colorNote?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: ToolkitColors.bgScaffold,
      appBar: AppBar(
        title: const Text('คลังอุปกรณ์ & แคตตาล็อก'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ToolkitColors.softBlueBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${filtered.length} รายการ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ToolkitColors.royalBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Selector Strip with official logos
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _BrandCatalogTab(
                        label: 'ALUMET ($aluCount)',
                        logoAsset: 'assets/brands/brand_alumet.png',
                        selected: _selectedBrand == 'ALUMET',
                        onTap: () => setState(() {
                          _selectedBrand = 'ALUMET';
                          _selectedSubCat = 'ทั้งหมด';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _BrandCatalogTab(
                        label: 'VVP ($vvpCount)',
                        logoAsset: 'assets/brands/brand_vvp.png',
                        selected: _selectedBrand == 'VVP',
                        onTap: () => setState(() {
                          _selectedBrand = 'VVP';
                          _selectedSubCat = 'ทั้งหมด';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _BrandCatalogTab(
                        label: 'RP Steel Glass ($rpCount)',
                        logoAsset: 'assets/brands/brand_rp_steelglass.png',
                        selected: _selectedBrand == 'RP',
                        onTap: () => setState(() {
                          _selectedBrand = 'RP';
                          _selectedSubCat = 'ทั้งหมด';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _BrandCatalogTab(
                        label: 'ทั้งหมด (${all.length})',
                        selected: _selectedBrand == 'ทั้งหมด',
                        onTap: () => setState(() {
                          _selectedBrand = 'ทั้งหมด';
                          _selectedSubCat = 'ทั้งหมด';
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('hw_catalog_search'),
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ค้นหารหัสหรือชื่ออุปกรณ์ เช่น AKL, FC 34, RP-303, ล้อ, มือจับ...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded, size: 18),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: subCats.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, idx) {
                      final cat = subCats[idx];
                      final isSel = _selectedSubCat == cat;
                      return ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: ToolkitColors.softBlueBg,
                        onSelected: (_) =>
                            setState(() => _selectedSubCat = cat),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'ไม่พบอุปกรณ์ในหมวดที่ค้นหา',
                          style: TextStyle(
                            fontSize: 14,
                            color: ToolkitColors.slateMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final imgPath = item.imageAssetPath ??
                              AluproImageRegistry.instance.resolveHardwareAsset(
                                code: item.code,
                                name: item.name,
                              );
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _editPriceDialog(item),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: ToolkitColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  if (imgPath != null)
                                    AluproThumbnail(
                                      assetPath: imgPath,
                                      width: 64,
                                      height: 56,
                                      zoomTitle:
                                          '${item.code} · ${item.name}',
                                    )
                                  else
                                    Container(
                                      width: 64,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: ToolkitColors.softBlueBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.handyman_outlined,
                                        color: ToolkitColors.royalBlue,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 3,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              item.code,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: ToolkitColors.royalBlue,
                                              ),
                                            ),
                                            if (item.subCategory.isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: item.brand == 'VVP'
                                                      ? const Color(0xFFE0F2FE)
                                                      : (item.brand == 'RP'
                                                          ? const Color(
                                                              0xFFF1F5F9)
                                                          : ToolkitColors
                                                              .softBlueBg),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.subCategory,
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        ToolkitColors.slateDark,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: ToolkitColors.slateDark,
                                          ),
                                        ),
                                        if (item.colorNote != null &&
                                            item.colorNote!.trim().isNotEmpty)
                                          Text(
                                            'สี/รุ่น: ${item.colorNote}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: ToolkitColors.slateMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '฿${_bahtFmt.format(item.effectivePrice)}',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: ToolkitColors.slateDark,
                                        ),
                                      ),
                                      Text(
                                        'ต่อ ${item.unit}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: ToolkitColors.slateMuted,
                                        ),
                                      ),
                                      if (item.customPrice != null)
                                        const Text(
                                          'ราคาแก้เอง',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: ToolkitColors.vipGoldText,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _BrandCatalogTab extends StatelessWidget {
  final String label;
  final String? logoAsset;
  final bool selected;
  final VoidCallback onTap;

  const _BrandCatalogTab({
    required this.label,
    this.logoAsset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? ToolkitColors.softBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? ToolkitColors.royalBlue
                : ToolkitColors.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoAsset != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  logoAsset!,
                  width: 24,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? ToolkitColors.royalBlue
                    : ToolkitColors.slateDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoEmptyScreen extends StatelessWidget {
  const VideoEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('วิดีโอเทคนิคช่าง')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ondemand_video_rounded,
                size: 52, color: ToolkitColors.slateMuted),
            SizedBox(height: 12),
            Text(
              'ยังไม่มีวิดีโอที่เผยแพร่',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ToolkitColors.slateMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Member & VIP Package Screen (สมาชิกและแพ็กเกจ — Active Offline VIP)
// =============================================================================
class MemberPackageScreen extends StatelessWidget {
  const MemberPackageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const vipFeatures = [
      'ปลดล็อกระบบคำนวณครบทุกหมวดหมู่ (ชุดตลาด / ชุดพัฒนา / ชุดยูโร / บานเฟี้ยม)',
      'กรอกขนาดหลายชุดพร้อมกันในครั้งเดียว (+ เพิ่มขนาดอื่น)',
      'ระบบจัดเส้นอัตโนมัติ (1D Bin-Packing) คำนวณเศษคงเหลือและใบเลื่อย 4 มม.',
      'ระบบทำราคาอลูมิเนียมพร้อมฐานข้อมูลราคาเส้น ORM 1,139 รายการ และตั้งราคาเองได้',
      'บันทึกแฟ้มงานในโปรเจกต์ของฉัน จัดเส้นรวมทั้งโครงการ และส่งออก PDF 4 หมวด',
      'ออกใบเสนอราคา PDF (แยกรายการ / เหมาทั้งโครงการ) พร้อมโลโก้ร้านและประวัติเอกสาร',
      'ทำงานแบบ Offline 100% บนอุปกรณ์ ไม่ต้องเชื่อมต่ออินเทอร์เน็ต',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('สมาชิกและแพ็กเกจ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFFBBF24), size: 28),
                    SizedBox(width: 10),
                    Text(
                      'แพ็กเกจปัจจุบัน: VIP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'อัครพลกระจกอลูมิเนียม · เปิดใช้งานสิทธิ์ VIP ถาวรครบทุกฟีเจอร์ (Offline 100%)',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFFE2E8F0)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ToolkitColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ขอบเขตสิทธิ์การใช้งานสมาชิก VIP',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ToolkitColors.slateDark,
                  ),
                ),
                const SizedBox(height: 12),
                ...vipFeatures.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: ToolkitColors.successGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: ToolkitColors.slateBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
