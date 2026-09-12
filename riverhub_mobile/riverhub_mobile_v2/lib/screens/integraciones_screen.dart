import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:viabarcazas_mobile/theme/app_colors.dart';
import '../services/locale_service.dart';

class IntegracionesScreen extends StatefulWidget {
  const IntegracionesScreen({super.key});

  @override
  State<IntegracionesScreen> createState() => _IntegracionesScreenState();
}

class _IntegracionesScreenState extends State<IntegracionesScreen> {
  bool _loading = true;
  String _generatedKey = '';

  final List<Map<String, dynamic>> _apis = [
    {
      'name': 'AISStream',
      'desc': 'AIS & Tracking Global',
      'url': 'https://stream.aisstream.io',
      'status': 'checking',
      'latency': '--',
    },
    {
      'name': 'Open-Meteo',
      'desc': LocaleService.t('dyn_key_143'),
      'url': 'https://api.open-meteo.com/v1/forecast?latitude=-25.3&longitude=-57.6&current=temperature_2m',
      'status': 'checking',
      'latency': '--',
    },
    {
      'name': 'Flood API',
      'desc': 'River Discharge Data',
      'url': 'https://flood-api.open-meteo.com/v1/flood?latitude=-25.3&longitude=-57.6&daily=river_discharge&past_days=1',
      'status': 'checking',
      'latency': '--',
    },
    {
      'name': 'Supabase',
      'desc': LocaleService.t('dyn_key_3'),
      'url': 'https://nfybnnpdrvyxucgpqmmo.supabase.co/rest/v1/',
      'status': 'checking',
      'latency': '--',
    },
    {
      'name': 'Gemini AI',
      'desc': 'AI Copilot Engine',
      'url': 'https://generativelanguage.googleapis.com',
      'status': 'checking',
      'latency': '--',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pingAllApis();
  }

  Future<void> _pingAllApis() async {
    setState(() => _loading = true);

    for (int i = 0; i < _apis.length; i++) {
      final api = _apis[i];
      try {
        final sw = Stopwatch()..start();
        final response = await http.get(
          Uri.parse(api['url']),
        ).timeout(const Duration(seconds: 5));
        sw.stop();

        if (mounted) {
          setState(() {
            _apis[i]['latency'] = '${sw.elapsedMilliseconds}ms';
            _apis[i]['status'] = response.statusCode < 500 ? 'online' : 'offline';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _apis[i]['latency'] = 'timeout';
            _apis[i]['status'] = 'offline';
          });
        }
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _apis.where((a) => a['status'] == 'online').length;
    final offlineCount = _apis.where((a) => a['status'] == 'offline').length;
    final checkingCount = _apis.where((a) => a['status'] == 'checking').length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundPrimary,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundSecondary.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
        leading: CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.back, size: 22, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        middle: Text(LocaleService.t('integraciones_integraciones'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: _pingAllApis, child: Icon(CupertinoIcons.refresh, size: 20, color: AppColors.textPrimary)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(LocaleService.t('integraciones_integraciones'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.1)),
            Text(LocaleService.t('integraciones_api'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.1)),
            const SizedBox(height: 24),

            Row(children: [
              _kpi('$onlineCount', LocaleService.t('dyn_key_141'), AppColors.success),
              const SizedBox(width: 10),
              _kpi('$offlineCount', 'Offline', AppColors.error),
              if (checkingCount > 0) ...[
                const SizedBox(width: 10),
                _kpi('$checkingCount', 'Checking', AppColors.textSecondary),
              ],
            ]),
            const SizedBox(height: 24),

            Text(LocaleService.t('integraciones_servicios_conectados'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            ..._apis.map((a) => _apiCard(a)),
            const SizedBox(height: 24),

            Text(LocaleService.t('integraciones_api_key'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.separator, width: 0.5),
              ),
              child: Column(children: [
                if (_generatedKey.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(_generatedKey, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textPrimary, letterSpacing: -0.3), overflow: TextOverflow.ellipsis)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: AppColors.accent),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedKey));
                          // ignore: use_build_context_synchronously
                          if (mounted) {
                            showCupertinoDialog(
                              context: context,
                              builder: (c) => CupertinoAlertDialog(
                                title: const Text('Copiado'),
                                content: const Text('API Key copiada al portapapeles'),
                                actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(c))],
                              ),
                            );
                          }
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Row(children: [
                    Expanded(child: Text(LocaleService.t('integraciones_sk_live'), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
                    Icon(CupertinoIcons.eye, color: AppColors.textSecondary, size: 18),
                  ]),
                  const SizedBox(height: 14),
                ],
                SizedBox(width: double.infinity, child: CupertinoButton(
                  color: AppColors.textPrimary, borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(LocaleService.t('integraciones_generar_nueva_key'), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textOnAccent)),
                  onPressed: () {
                    setState(() => _generatedKey = _generateUuid());
                  },
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String val, String label, Color accentColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(children: [
        Text(val, style: GoogleFonts.newsreader(fontSize: 28, fontWeight: FontWeight.w400, color: accentColor)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _apiCard(Map<String, dynamic> a) {
    final online = a['status'] == 'online';
    final checking = a['status'] == 'checking';
    final dotColor = checking ? AppColors.warning : (online ? AppColors.success : AppColors.error);
    final statusText = checking ? 'CHECKING...' : (online ? 'ONLINE' : 'OFFLINE');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(children: [
        checking
          ? const CupertinoActivityIndicator(radius: 4)
          : Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a['name'], style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
          Text(a['desc'], style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(statusText, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: dotColor, letterSpacing: 0.5)),
          Text(a['latency'], style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}
