import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:viabarcazas_mobile/theme/app_colors.dart';
import '../services/locale_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundPrimary,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundSecondary.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
        leading: CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.back, size: 22, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        middle: Text(LocaleService.t('admin_administracion'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(LocaleService.t('admin_panel'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.1)),
            Text(LocaleService.t('admin_administrativo'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.1)),
            const SizedBox(height: 24),

            Row(children: [
              _kpi('12', LocaleService.t('dyn_key_4')),
              const SizedBox(width: 10),
              _kpi('48', LocaleService.t('dyn_key_6')),
              const SizedBox(width: 10),
              _kpi('32', LocaleService.t('dyn_key_8')),
            ]),
            const SizedBox(height: 28),

            Text(LocaleService.t('admin_administracion_1'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _menuItem(LocaleService.t('dyn_key_5'), CupertinoIcons.building_2_fill, '12 empresas registradas'),
            _menuItem(LocaleService.t('dyn_key_1'), CupertinoIcons.person_2, '48 usuarios activos'),
            _menuItem('Flota Global', CupertinoIcons.helm, '32 embarcaciones'),
            _menuItem('Tenants (Multi-org)', CupertinoIcons.square_stack_3d_up, '3 organizaciones'),
            _menuItem(LocaleService.t('dyn_key_2'), CupertinoIcons.doc_text, '156 este mes'),
            _menuItem(LocaleService.t('dyn_key_10'), CupertinoIcons.creditcard, '\$45,200 facturado'),
            _menuItem(LocaleService.t('dyn_key_12'), CupertinoIcons.shield, '2,340 eventos'),
            const SizedBox(height: 24),

            // System info
            Text(LocaleService.t('admin_sistema'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.separator, width: 0.5),
              ),
              child: Column(children: [
                _InfoRow(label: LocaleService.t('dyn_key_9'), value: 'v3.2.1 (ViaBarcazas)'),
                _InfoRow(label: LocaleService.t('dyn_key_3'), value: 'Supabase (PostgreSQL 15)'),
                _InfoRow(label: LocaleService.t('dyn_key_11'), value: 'Supabase Edge'),
                _InfoRow(label: LocaleService.t('dyn_key_7'), value: '18/04/2026'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String val, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(children: [
        Text(val, style: GoogleFonts.newsreader(fontSize: 28, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _menuItem(String title, IconData icon, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Icon(CupertinoIcons.chevron_right, color: AppColors.separator, size: 14),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ]),
    );
  }
}
