import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:viabarcazas_mobile/theme/app_colors.dart';
import '../services/locale_service.dart';

class DraftScreen extends StatefulWidget {
  const DraftScreen({super.key});

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> {
  bool _isLoading = true;
  String _timestamp = '';
  int _stationCount = 0;
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  String _selectedRiver = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchINA();
  }

  Future<void> _fetchINA() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('https://viabarcazas.com/api/hydrology/ina');
      final res = await http.get(url).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final stations = (data['stations'] as List?) ?? [];
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final s in stations) {
          final river = (s['river'] ?? 'Otro') as String;
          grouped.putIfAbsent(river, () => []);
          grouped[river]!.add({
            'name': s['name'] ?? '',
            'river': river,
            'seriesId': s['seriesId'] ?? 0,
            'level': s['currentLevel'] != null ? (s['currentLevel'] as num).toDouble() : null,
            'status': s['status'] ?? 'SIN_DATOS',
            'alertLevel': s['alertLevel'] != null ? (s['alertLevel'] as num).toDouble() : null,
            'evacLevel': s['evacLevel'] != null ? (s['evacLevel'] as num).toDouble() : null,
            'lowLevel': s['lowLevel'] != null ? (s['lowLevel'] as num).toDouble() : null,
            'timestamp': s['timestamp'],
            'obsCount': s['obsCount'] ?? 0,
          });
        }
        setState(() {
          _grouped = grouped;
          _timestamp = data['timestamp'] ?? '';
          _stationCount = stations.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('INA fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'NORMAL': return const Color(0xFF10B981);
      case 'ALERTA': return const Color(0xFFF59E0B);
      case 'EVACUACION': return const Color(0xFFEF4444);
      case 'AGUAS_BAJAS': return const Color(0xFF3B82F6);
      default: return AppColors.textTertiary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'NORMAL': return CupertinoIcons.check_mark_circled_solid;
      case 'ALERTA': return CupertinoIcons.exclamationmark_triangle_fill;
      case 'EVACUACION': return CupertinoIcons.xmark_circle_fill;
      case 'AGUAS_BAJAS': return CupertinoIcons.arrow_down_circle_fill;
      default: return CupertinoIcons.question_circle_fill;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'NORMAL': return 'NORMAL';
      case 'ALERTA': return 'ALERTA';
      case 'EVACUACION': return 'EVACUACION';
      case 'AGUAS_BAJAS': return 'AGUAS BAJAS';
      default: return 'SIN DATOS';
    }
  }

  String _timeAgo(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _grouped.values.expand((l) => l).toList();
    final withData = all.where((s) => s['level'] != null).length;
    final alerts = all.where((s) => s['status'] == 'ALERTA' || s['status'] == 'EVACUACION').length;
    final lowWater = all.where((s) => s['status'] == 'AGUAS_BAJAS').length;

    // Filter stations
    List<Map<String, dynamic>> displayStations;
    if (_selectedRiver == 'ALL') {
      displayStations = all;
    } else {
      displayStations = _grouped[_selectedRiver] ?? [];
    }

    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundPrimary,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundSecondary.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
        leading: CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.back, size: 22, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        middle: Text(LocaleService.t('draft_title'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: _fetchINA, child: Icon(CupertinoIcons.refresh, size: 20, color: AppColors.textPrimary)),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  // Header
                  Text(LocaleService.t('draft_header1'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.1)),
                  Text(LocaleService.t('draft_header2'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.1)),
                  const SizedBox(height: 20),

                  // KPI Row
                  Row(children: [
                    _kpi('$withData', '/$_stationCount', 'Con datos', CupertinoIcons.antenna_radiowaves_left_right, const Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    _kpi('$alerts', '', 'Alertas', CupertinoIcons.exclamationmark_triangle_fill, alerts > 0 ? const Color(0xFFEF4444) : AppColors.textTertiary),
                    const SizedBox(width: 10),
                    _kpi('$lowWater', '', 'Bajas', CupertinoIcons.arrow_down_circle_fill, lowWater > 0 ? const Color(0xFF3B82F6) : AppColors.textTertiary),
                  ]),
                  const SizedBox(height: 16),

                  // River filter chips
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('ALL', 'Todas ($_stationCount)'),
                        ..._grouped.entries.map((e) => _filterChip(e.key, '${e.key.replaceAll("Río ", "")} (${e.value.length})')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Station Grid — 2 columns
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.78,
                    children: displayStations.map((s) => _stationCard(s)).toList(),
                  ),

                  if (displayStations.isEmpty)
                    Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('No hay estaciones', style: GoogleFonts.inter(color: AppColors.textSecondary)))),

                  // Source footer
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(CupertinoIcons.globe, size: 13, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('INA Argentina \u2014 Sistema de Alerta Hidrologico', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w500))),
                    ]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _selectedRiver == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedRiver = key),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.textPrimary : AppColors.separator, width: 0.5),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? AppColors.backgroundPrimary : AppColors.textSecondary)),
      ),
    );
  }

  Widget _kpi(String val, String suffix, String label, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.separator, width: 0.5)),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        RichText(text: TextSpan(children: [
          TextSpan(text: val, style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w400, color: color)),
          if (suffix.isNotEmpty) TextSpan(text: suffix, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
        ])),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _stationCard(Map<String, dynamic> s) {
    final status = s['status'] as String;
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    final label = _statusLabel(status);
    final level = s['level'] as double?;
    final alert = s['alertLevel'] as double?;
    final low = s['lowLevel'] as double?;
    final name = s['name'] as String;
    final river = s['river'] as String;
    final ts = s['timestamp'] as String?;
    final seriesId = s['seriesId'];

    double alertPct = 0;
    if (alert != null && level != null && alert > 0) {
      alertPct = (level / alert).clamp(0.0, 1.0);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + name
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(child: Icon(icon, size: 14, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),

                  // River + series
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(5)),
                    child: Text('Serie #$seriesId', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),

                  // Level value
                  Text(
                    level != null ? '${level.toStringAsFixed(2)} m' : '-- m',
                    style: GoogleFonts.newsreader(fontSize: 24, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
                  ),

                  // Alert bar
                  if (alert != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 4,
                        child: Stack(children: [
                          Container(color: AppColors.separator),
                          FractionallySizedBox(widthFactor: alertPct, child: Container(color: color)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${low ?? "--"}m', style: GoogleFonts.inter(fontSize: 8, color: AppColors.textTertiary)),
                      Text('${alert}m', style: GoogleFonts.inter(fontSize: 8, color: AppColors.textTertiary)),
                    ]),
                  ],
                  const SizedBox(height: 6),

                  // Status badge + time
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5)),
                      child: Text(label, style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
                    ),
                    const Spacer(),
                    if (ts != null && _timeAgo(ts).isNotEmpty) ...[
                      Icon(CupertinoIcons.clock, size: 9, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text(_timeAgo(ts), style: GoogleFonts.inter(fontSize: 8, color: AppColors.textTertiary)),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
