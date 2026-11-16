import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/seed_repository.dart';
import 'catalog_and_input_screens.dart';
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
                              label: 'กำหนด/แก้ไขราคาเส้นเอง',
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
            subtitle: 'ข้อมูลอุปกรณ์ประกอบและแคตตาล็อกโปรไฟล์',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HardwareEmptyScreen()),
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

class HardwareEmptyScreen extends StatelessWidget {
  const HardwareEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ฮาร์ดแวร์ & แคตตาล็อก')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 52, color: ToolkitColors.slateMuted),
            SizedBox(height: 12),
            Text(
              'ยังไม่มีแคตตาล็อกที่เผยแพร่',
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
