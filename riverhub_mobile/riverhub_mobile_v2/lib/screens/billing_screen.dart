import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../services/locale_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool _isAnnual = false;
  String _currentPlan = 'fleet-25'; // default selected

  // Tramos por unidad — deben coincidir siempre con config/pricing.js
  // (fuente unica de verdad del backend). Cada barcaza y cada remolcador
  // es su propia unidad facturable; no existe el concepto de "combo/set".
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'starter', 'name': 'Precio inicial', 'desc': 'De 1 a 9 unidades facturables',
      'monthly': 120, 'yearly': 108.0, 'unit': '/unidad/mes', 'unitYearly': '/unidad/mes',
      'icon': '🚢',
      'popular': false,
      'features': [
        {'name': 'Tracking GPS en tiempo real', 'enabled': true},
        {'name': 'Bitácora digital', 'enabled': true},
        {'name': 'Mantenimiento preventivo', 'enabled': true},
        {'name': 'Soporte estándar', 'enabled': true},
      ],
    },
    {
      'id': 'fleet-10', 'name': 'Flota 10+', 'desc': 'De 10 a 24 unidades facturables',
      'monthly': 110, 'yearly': 99.0, 'unit': '/unidad/mes', 'unitYearly': '/unidad/mes',
      'icon': '⚓',
      'popular': false,
      'features': [
        {'name': 'Todo lo de Precio Inicial', 'enabled': true},
        {'name': 'Gestión de tripulación', 'enabled': true},
        {'name': 'Armador de convoyes', 'enabled': true},
        {'name': 'Copiloto IA básico', 'enabled': true},
      ],
    },
    {
      'id': 'fleet-25', 'name': 'Flota 25+', 'desc': 'De 25 a 49 unidades facturables',
      'monthly': 100, 'yearly': 90.0, 'unit': '/unidad/mes', 'unitYearly': '/unidad/mes',
      'icon': '🏢',
      'popular': true,
      'features': [
        {'name': 'Todo lo de Flota 10+', 'enabled': true},
        {'name': 'Copiloto IA avanzado', 'enabled': true},
        {'name': 'Reportes avanzados', 'enabled': true},
        {'name': 'Soporte prioritario', 'enabled': true},
      ],
    },
    {
      'id': 'fleet-50', 'name': 'Flota 50+', 'desc': 'De 50 a 99 unidades facturables',
      'monthly': 92, 'yearly': 82.8, 'unit': '/unidad/mes', 'unitYearly': '/unidad/mes',
      'icon': '∞',
      'popular': false,
      'features': [
        {'name': 'Todo lo de Flota 25+', 'enabled': true},
        {'name': 'Usuarios ilimitados', 'enabled': true},
        {'name': 'Copiloto IA premium', 'enabled': true},
        {'name': 'Onboarding dedicado', 'enabled': true},
      ],
    },
    {
      'id': 'fleet-100', 'name': 'Flota 100+', 'desc': 'De 100 a 149 unidades facturables',
      'monthly': 85, 'yearly': 76.5, 'unit': '/unidad/mes', 'unitYearly': '/unidad/mes',
      'icon': '👑',
      'popular': false,
      'features': [
        {'name': 'Todo lo de Flota 50+', 'enabled': true},
        {'name': 'Embarcaciones ilimitadas', 'enabled': true},
        {'name': 'API integraciones', 'enabled': true},
        {'name': 'Account manager', 'enabled': true},
      ],
    },
  ];

  void _selectPlan(String planId) {
    setState(() => _currentPlan = planId);
  }

  // Abre el cliente de correo con una consulta comercial, igual que el
  // boton "Solicitar propuesta por email" de pricing.html. No hay pago
  // ni activacion simulada: la app nunca marca una suscripcion como
  // activa sin que exista una transaccion real.
  Future<void> _requestProposal() async {
    final plan = _plans.firstWhere((p) => p['id'] == _currentPlan);
    final price = _isAnnual ? plan['yearly'] : plan['monthly'];
    final cycle = _isAnnual ? 'Prepago anual (-10%)' : 'Pago mensual';
    final subject = Uri.encodeComponent(
      'Consulta de plan ViaBarcazas - ${plan['name']} - USD $price/unidad/mes - $cycle',
    );
    final mailUri = Uri.parse('mailto:info@viabarcazas.com?subject=$subject');

    Navigator.pop(context);

    final launched = await launchUrl(mailUri);
    if (!launched && mounted) {
      showCupertinoDialog(
        context: context,
        builder: (dCtx) => CupertinoAlertDialog(
          title: Text('No pudimos abrir tu app de correo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: Text('Escribinos directamente a info@viabarcazas.com para recibir tu propuesta.', style: GoogleFonts.inter()),
          actions: [
            CupertinoDialogAction(child: Text('Entendido', style: GoogleFonts.inter(fontWeight: FontWeight.w600)), onPressed: () => Navigator.pop(dCtx)),
          ],
        ),
      );
    }
  }

  void _confirmSubscription() {
    final plan = _plans.firstWhere((p) => p['id'] == _currentPlan);
    final price = _isAnnual ? plan['yearly'] : plan['monthly'];
    final unit = _isAnnual ? plan['unitYearly'] : plan['unit'];

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.separator, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(LocaleService.t('billing_confirmar_suscripcio'), style: GoogleFonts.newsreader(fontSize: 24, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.separator, width: 0.5),
              ),
              child: Column(children: [
                Text(plan['name'], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('USD $price$unit', style: GoogleFonts.newsreader(fontSize: 28, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
                if (_isAnnual) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                    child: Text(LocaleService.t('billing_ahorras_20_anual'), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.5)),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 6),
            Center(child: Text('Cada barcaza y remolcador cuenta como una unidad.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary))),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: _requestProposal,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('SOLICITAR PROPUESTA POR EMAIL', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.backgroundPrimary, letterSpacing: 0.5))),
              ),
            ),
            const SizedBox(height: 8),
            Text('Te contactamos con una propuesta comercial. Más de 150 unidades: propuesta personalizada.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundPrimary,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundSecondary.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
        leading: Navigator.of(context).canPop()
            ? CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.back, size: 22, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context))
            : CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.bars, size: 24, color: AppColors.textPrimary), onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
        middle: Text(LocaleService.t('billing_facturacion'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(LocaleService.t('billing_planes'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.1)),
            Text(LocaleService.t('billing_facturacion_1'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.1)),
            const SizedBox(height: 6),
            Text(LocaleService.t('billing_hidrovia_inteligente'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 20),

            // ── Period toggle ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.separator, width: 0.5),
              ),
              child: Row(children: [
                _toggleButton(LocaleService.t('dyn_key_55'), !_isAnnual, () => setState(() => _isAnnual = false)),
                _toggleButton('Prepago anual -10%', _isAnnual, () => setState(() => _isAnnual = true)),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Plans ─────────────────────────────────────
            ..._plans.map((plan) => _planCard(plan)),
            const SizedBox(height: 8),

            // ── Subscribe button ──────────────────────────
            GestureDetector(
              onTap: _confirmSubscription,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('SOLICITAR PROPUESTA', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.backgroundPrimary, letterSpacing: 0.5))),
              ),
            ),
            const SizedBox(height: 6),
            Center(child: Text('Cada barcaza y remolcador cuenta como una unidad.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary))),
            const SizedBox(height: 32),

            // ── FAQ section ────────────────────────────────
            Text(LocaleService.t('billing_preguntas_frecuentes'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _faqItem(LocaleService.t('dyn_key_26'), LocaleService.t('dyn_key_47')),
            _faqItem(LocaleService.t('dyn_key_50'), 'Tarjeta de crédito/débito, transferencia bancaria, y facturación corporativa.'),
            _faqItem(LocaleService.t('dyn_key_46'), LocaleService.t('dyn_key_42')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.textPrimary : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? AppColors.backgroundPrimary : AppColors.textSecondary))),
      ),
    ));
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final isSelected = _currentPlan == plan['id'];
    final price = _isAnnual ? plan['yearly'] : plan['monthly'];
    final unit = _isAnnual ? plan['unitYearly'] : plan['unit'];
    final features = plan['features'] as List<Map<String, dynamic>>;

    return GestureDetector(
      onTap: () => _selectPlan(plan['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary.withValues(alpha: 0.04) : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : AppColors.separator,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Radio
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, width: isSelected ? 6 : 1.5),
                color: AppColors.backgroundPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plan['name'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (plan['popular'] == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(4)),
                    child: Text(LocaleService.t('billing_popular_new'), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.backgroundPrimary, letterSpacing: 0.5)),
                  ),
                ],
              ]),
              Text(plan['desc'], style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('USD $price', style: GoogleFonts.newsreader(fontSize: 24, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
              Text(unit, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
            ]),
          ]),

          // Features (collapsed when not selected)
          if (isSelected) ...[
            const SizedBox(height: 14),
            Container(height: 0.5, color: AppColors.separator),
            const SizedBox(height: 12),
            Wrap(
              spacing: 0,
              runSpacing: 6,
              children: features.map((f) => SizedBox(
                width: double.infinity,
                child: Row(children: [
                  Icon(
                    f['enabled'] == true ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle,
                    size: 14,
                    color: f['enabled'] == true ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(f['name'], style: GoogleFonts.inter(fontSize: 12, color: f['enabled'] == true ? AppColors.textPrimary : AppColors.textTertiary)),
                ]),
              )).toList(),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(question, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(answer, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
      ]),
    );
  }
}
