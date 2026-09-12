import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:viabarcazas_mobile/theme/app_colors.dart';
import '../services/locale_service.dart';

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundPrimary,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundSecondary.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
        leading: CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.back, size: 22, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        middle: Text(LocaleService.t('reportes_reportes'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        trailing: CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.printer, color: AppColors.textSecondary, size: 20), onPressed: () {}),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(LocaleService.t('reportes_reportes_1'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.1)),
            Text(LocaleService.t('reportes_analytics'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.1)),
            const SizedBox(height: 24),

            // P&L KPIs - editorial monochrome
            Text(LocaleService.t('reportes_estado_de_resultados'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              _metricCard(LocaleService.t('dyn_key_209'), '\$2.4M', CupertinoIcons.arrow_up_right),
              const SizedBox(width: 10),
              _metricCard(LocaleService.t('dyn_key_215'), '\$1.8M', CupertinoIcons.arrow_down_right),
              const SizedBox(width: 10),
              _metricCard(LocaleService.t('dyn_key_216'), '25%', CupertinoIcons.chart_bar),
            ]),
            const SizedBox(height: 20),

            // Monthly bar chart
            _chartContainer('INGRESOS VS GASTOS — 6 MESES', _buildBarChart()),
            const SizedBox(height: 16),

            // Fuel chart
            Text(LocaleService.t('reportes_eficiencia_combustib'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _chartContainer('CONSUMO LT/KM POR EMBARCACIÓN', _buildFuelChart()),
            const SizedBox(height: 20),

            // Operational status
            Text(LocaleService.t('reportes_estado_operacional'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.separator, width: 0.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _pieSlice(LocaleService.t('dyn_key_214'), '60%'),
                _pieSlice(LocaleService.t('dyn_key_218'), '25%'),
                _pieSlice(LocaleService.t('dyn_key_212'), '10%'),
                _pieSlice(LocaleService.t('dyn_key_213'), '5%'),
              ]),
            ),
            const SizedBox(height: 20),

            // Report generation
            Text(LocaleService.t('reportes_generar_reporte'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _reportButton(LocaleService.t('dyn_key_208'), CupertinoIcons.doc_chart),
            _reportButton(LocaleService.t('dyn_key_211'), CupertinoIcons.drop),
            _reportButton(LocaleService.t('dyn_key_210'), CupertinoIcons.helm),
            _reportButton(LocaleService.t('dyn_key_217'), CupertinoIcons.money_dollar_circle),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.separator, width: 0.5),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.newsreader(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _chartContainer(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1)),
        const SizedBox(height: 14),
        chart,
      ]),
    );
  }

  Widget _buildBarChart() {
    final months = ['Oct', 'Nov', 'Dic', 'Ene', 'Feb', 'Mar'];
    final income = [350, 400, 380, 420, 390, 440];
    final expense = [280, 310, 300, 320, 295, 340];

    return SizedBox(
      height: 110,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(months.length, (i) {
        final incPct = income[i] / 500;
        final expPct = expense[i] / 500;
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(width: 8, height: 100 * incPct, decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 2),
              Container(width: 8, height: 100 * expPct, decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(2))),
            ]),
            const SizedBox(height: 6),
            Text(months[i], style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary)),
          ]),
        ));
      })),
    );
  }

  Widget _buildFuelChart() {
    final vessels = ['TB-PY01', 'HERCULES', 'CENTAURO', 'SOJA K.', 'ENERGY'];
    final values = [4.2, 5.1, 6.3, 3.8, 4.5];
    return Column(children: List.generate(vessels.length, (i) {
      final pct = values[i] / 8;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 66, child: Text(vessels[i], style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))),
          Expanded(child: Container(
            height: 12,
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(6)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft, widthFactor: pct,
              child: Container(decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6))),
            ),
          )),
          const SizedBox(width: 8),
          Text('${values[i]}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ]),
      );
    }));
  }

  Widget _pieSlice(String label, String pct) {
    return Column(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle, border: Border.all(color: AppColors.textPrimary, width: 1.5)),
        child: Center(child: Text(pct, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }

  Widget _reportButton(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary))),
        Icon(CupertinoIcons.arrow_right, color: AppColors.separator, size: 14),
      ]),
    );
  }
}
