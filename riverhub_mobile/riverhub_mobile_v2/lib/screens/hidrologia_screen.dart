import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:viabarcazas_mobile/theme/app_colors.dart';
import '../services/locale_service.dart';

class HidrologiaScreen extends StatefulWidget {
  const HidrologiaScreen({super.key});

  @override
  State<HidrologiaScreen> createState() => _HidrologiaScreenState();
}

class _HidrologiaScreenState extends State<HidrologiaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _loading = true;

  double _temp = 0;
  double _wind = 0;
  int _humidity = 0;
  String _weatherDesc = '';
  int _weatherCode = 0;

  List<double> _chartData = [];
  List<String> _chartLabels = [];
  List<Map<String, dynamic>> _stations = [];
  
  // UKC State
  double _ukcDraft = 2.5;
  String _ukcOverallStatus = '';
  List<Map<String, dynamic>> _ukcStations = [];

  // INA Argentina State
  List<Map<String, dynamic>> _inaStations = [];
  bool _inaLoading = false;

  // INA Forecast State
  List<Map<String, dynamic>> _inaForecasts = [];
  bool _forecastLoading = false;
  String _forecastModel = '';
  int _corridaId = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _weatherDesc = LocaleService.t('hydro_loading');
    _fetchAllData();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  Future<void> _fetchAllData() async {
    setState(() => _loading = true);
    await Future.wait([_fetchWeather(), _fetchFloodData(), _fetchUKC(), _fetchINA(), _fetchINAForecast()]);
    if (mounted) {
      setState(() => _loading = false);
      _animController.forward();
    }
  }

  Future<void> _fetchUKC() async {
    try {
      // UKC is calculated locally from flood data using the same model as the backend
      // Reference depths per station (meters)
      final refDepths = {
        'Asunción': 7.0, 'Pilar': 5.5, 'Concepción': 6.0, 'Rosario': 10.36,
        'Corrientes': 10.0, 'Santa Fe': 8.5, 'Corumbá': 5.0,
      };
      final margin = 0.3;

      // Wait for stations to be populated
      await Future.delayed(const Duration(milliseconds: 100));

      List<Map<String, dynamic>> results = [];
      for (final st in _stations) {
        final name = st['name'] as String;
        final flow = (st['flow'] as num).toDouble();
        final refD = refDepths[name] ?? 6.0;
        final fallbackQ = (st['median'] as num?)?.toDouble() ?? flow;

        // Same formula as backend: depth = refDepth * (Q / baseQ)^0.3
        final ratio = fallbackQ > 0 ? flow / fallbackQ : 1.0;
        final estimatedDepth = refD * pow(ratio.clamp(0.3, 5.0), 0.3);
        final ukc = estimatedDepth - _ukcDraft - margin;

        String status = 'SAFE';
        if (ukc < 0) status = 'BLOCKED';
        else if (ukc < 0.5) status = 'CRITICAL';
        else if (ukc < 1.0) status = 'CAUTION';

        results.add({
          'name': name,
          'river': st['river'],
          'estimatedDepth': (estimatedDepth * 100).round() / 100.0,
          'ukc': (ukc * 100).round() / 100.0,
          'status': status,
        });
      }

      if (mounted) {
        setState(() {
          _ukcStations = results;
          _ukcOverallStatus = results.any((r) => r['status'] == 'BLOCKED') ? 'BLOCKED'
            : results.any((r) => r['status'] == 'CRITICAL') ? 'CRITICAL'
            : results.any((r) => r['status'] == 'CAUTION') ? 'CAUTION' : 'SAFE';
        });
      }
    } catch (e) {
      debugPrint('UKC error: $e');
    }
  }

  Future<void> _fetchINA() async {
    try {
      setState(() => _inaLoading = true);
      final url = Uri.parse('https://viabarcazas.com/api/hydrology/ina');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final stations = (data['stations'] as List?) ?? [];
        setState(() {
          _inaStations = stations.map<Map<String, dynamic>>((s) => {
            'name': s['name'] ?? '',
            'river': s['river'] ?? '',
            'level': s['currentLevel'] != null ? (s['currentLevel'] as num).toDouble() : null,
            'status': s['status'] ?? 'SIN_DATOS',
            'alertLevel': s['alertLevel'] != null ? (s['alertLevel'] as num).toDouble() : null,
            'evacLevel': s['evacLevel'] != null ? (s['evacLevel'] as num).toDouble() : null,
            'lowLevel': s['lowLevel'] != null ? (s['lowLevel'] as num).toDouble() : null,
            'timestamp': s['timestamp'],
            'obsCount': s['obsCount'] ?? 0,
          }).toList();
          _inaLoading = false;
        });
      }
    } catch (e) {
      debugPrint('INA fetch error: $e');
      if (mounted) setState(() => _inaLoading = false);
    }
  }



  Future<void> _fetchWeather() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=-25.286&longitude=-57.647'
        '&current=temperature_2m,wind_speed_10m,weather_code,relative_humidity_2m'
        '&timezone=America/Asuncion'
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final current = data['current'];
        if (current != null && mounted) {
          setState(() {
            _temp = (current['temperature_2m'] ?? 0).toDouble();
            _wind = (current['wind_speed_10m'] ?? 0).toDouble();
            _humidity = (current['relative_humidity_2m'] ?? 0).toInt();
            _weatherCode = (current['weather_code'] ?? 0).toInt();
            _weatherDesc = _weatherName(_weatherCode);
          });
        }
      }
    } catch (e) {
      debugPrint('Weather error: $e');
      if (mounted) setState(() { _temp = 28; _wind = 15; _humidity = 72; _weatherDesc = LocaleService.t('hydro_no_connection'); });
    }
  }

  Future<void> _fetchFloodData() async {
    try {
      final stations = [
        {'name': 'Asunción', 'river': 'Río Paraguay', 'lat': -25.3, 'lon': -57.7},
        {'name': 'Pilar', 'river': 'Bajo Paraguay', 'lat': -26.85, 'lon': -58.35},
        {'name': 'Concepción', 'river': 'Alto Paraguay', 'lat': -23.4, 'lon': -57.5},
        {'name': 'Rosario', 'river': 'Río Paraná', 'lat': -32.95, 'lon': -60.65},
      ];

      List<Map<String, dynamic>> loadedStations = [];

      for (final st in stations) {
        try {
          final url = Uri.parse(
            'https://flood-api.open-meteo.com/v1/flood'
            '?latitude=${st['lat']}&longitude=${st['lon']}'
            '&daily=river_discharge&past_days=7&forecast_days=7'
          );
          final res = await http.get(url);
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            final discharges = data['daily']?['river_discharge'] as List<dynamic>? ?? [];
            final dates = data['daily']?['time'] as List<dynamic>? ?? [];

            if (discharges.isNotEmpty) {
              final current = discharges.length > 7 ? discharges[7] : discharges.last;
              final previous = discharges.length > 6 ? discharges[6] : discharges.first;
              final median = discharges.map((d) => (d ?? 0).toDouble()).reduce((a, b) => a + b) / discharges.length;

              String trend = LocaleService.t('dyn_key_118');
              if ((current ?? 0) > (previous ?? 0) * 1.05) trend = LocaleService.t('dyn_key_117');
              if ((current ?? 0) < (previous ?? 0) * 0.95) trend = LocaleService.t('dyn_key_119');

              loadedStations.add({
                'name': st['name'],
                'river': st['river'],
                'flow': ((current ?? 0) as num).toDouble(),
                'median': median,
                'trend': trend,
              });

              if (st['name'] == 'Asunción') {
                setState(() {
                  _chartData = discharges.map((d) => (d ?? 0).toDouble()).toList().cast<double>();
                  _chartLabels = dates.map((d) => d.toString().substring(5)).toList().cast<String>();
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Station ${st['name']} error: $e');
        }
      }

      if (mounted) {
        setState(() {
          _stations = loadedStations.isNotEmpty ? loadedStations : [
            {'name': 'Asunción', 'river': 'Río Paraguay', 'flow': 2450.0, 'median': 2800.0, 'trend': LocaleService.t('dyn_key_119')},
            {'name': 'Rosario', 'river': 'Río Paraná', 'flow': 15200.0, 'median': 16500.0, 'trend': LocaleService.t('dyn_key_118')},
          ];
          if (_chartData.isEmpty) {
            _chartData = List.generate(14, (i) => 2000 + Random().nextDouble() * 1500);
          }
        });
      }
    } catch (e) {
      debugPrint('Flood error: $e');
    }
  }

  String _weatherName(int code) {
    if (code == 0 || code == 1) return LocaleService.t('hydro_clear');
    if (code == 2) return LocaleService.t('hydro_partly_cloudy');
    if (code == 3) return LocaleService.t('hydro_cloudy');
    if (code >= 45 && code <= 48) return LocaleService.t('hydro_fog');
    if (code >= 51 && code <= 55) return LocaleService.t('hydro_drizzle');
    if (code >= 61 && code <= 65) return LocaleService.t('hydro_rain');
    if (code >= 80 && code <= 82) return LocaleService.t('hydro_rain');
    if (code >= 95) return LocaleService.t('hydro_storm');
    return LocaleService.t('hydro_varied');
  }

  String _trendLabel(String trend) {
    switch (trend) {
      case 'CRECIENTE': return LocaleService.t('hydro_rising');
      case 'BAJANTE': return LocaleService.t('hydro_falling');
      default: return LocaleService.t('hydro_stable');
    }
  }

  IconData _weatherIcon(int code) {
    if (code == 0 || code == 1) return CupertinoIcons.sun_max;
    if (code == 2) return CupertinoIcons.cloud_sun;
    if (code == 3) return CupertinoIcons.cloud;
    if (code >= 45 && code <= 48) return CupertinoIcons.cloud_fog;
    if (code >= 51 && code <= 55) return CupertinoIcons.cloud_drizzle;
    if (code >= 61 && code <= 65) return CupertinoIcons.cloud_rain;
    if (code >= 71 && code <= 75) return CupertinoIcons.cloud_snow;
    if (code >= 80 && code <= 82) return CupertinoIcons.cloud_heavyrain;
    if (code >= 95) return CupertinoIcons.cloud_bolt;
    return CupertinoIcons.cloud;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundPrimary,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundSecondary.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
        leading: CupertinoButton(padding: EdgeInsets.zero, child: Icon(CupertinoIcons.back, size: 22, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        middle: Text(LocaleService.t('hydro_screen_title'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: _fetchAllData, child: Icon(CupertinoIcons.refresh, size: 20, color: AppColors.textPrimary)),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  Text(LocaleService.t('hydro_header1'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.1)),
                  Text(LocaleService.t('hydro_header2'), style: GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.1)),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.separator, width: 0.5)),
                    child: Row(children: [
                      Icon(_weatherIcon(_weatherCode), color: AppColors.textSecondary, size: 32),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_temp.round()}°C', style: GoogleFonts.newsreader(fontSize: 28, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
                        Text(_weatherDesc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${LocaleService.t('hydro_wind_label')}: ${_wind.round()} km/h', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        Text('${LocaleService.t('hydro_humidity_label')}: $_humidity%', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text('Asunción, PY', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  Text(LocaleService.t('hydro_chart_label'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Container(
                    height: 150, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.separator, width: 0.5)),
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) => CustomPaint(
                        painter: _BarChartPainter(_chartData, _animController.value),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  if (_chartLabels.length >= 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_chartLabels.first, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary)),
                          Text(LocaleService.t('hydro_today'), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          Text(_chartLabels.last, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),

                  Text(LocaleService.t('hydro_stations'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
                  Text(LocaleService.t('hydro_data_source'), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                    children: _stations.map((s) => _stationGridCard(s)).toList(),
                  ),
                  const SizedBox(height: 28),

                  // --- UKC NAVIGATOR ---
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('NAVEGABILIDAD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
                      Text('Under Keel Clearance', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
                    ]),
                    if (_ukcOverallStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _ukcStatusColor(_ukcOverallStatus).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_ukcOverallStatus, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _ukcStatusColor(_ukcOverallStatus))),
                      ),
                  ]),
                  const SizedBox(height: 14),

                  // Draft slider
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.separator, width: 0.5),
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Calado del buque', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        Text('${_ukcDraft.toStringAsFixed(1)} m', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ]),
                      CupertinoSlider(
                        value: _ukcDraft,
                        min: 0.5,
                        max: 8.0,
                        divisions: 75,
                        onChanged: (v) {
                          setState(() => _ukcDraft = v);
                          _fetchUKC();
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),

                  // UKC Station Cards
                  ..._ukcStations.map((u) => _ukcCard(u)),
                  const SizedBox(height: 36),

                  // --- INA ARGENTINA OFFICIAL DATA ---
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('INA ARGENTINA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
                      Text('Alturas hidrometricas oficiales', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${_inaStations.length} est.', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6))),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (_inaLoading)
                    const Center(child: CupertinoActivityIndicator(radius: 10))
                  else if (_inaStations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.separator, width: 0.5)),
                      child: Center(child: Text('Datos INA no disponibles', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary))),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                      children: _inaStations.map((s) => _inaGridCard(s)).toList(),
                    ),
                  const SizedBox(height: 36),

                  // --- INA FORECAST ---
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PRONOSTICO INA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
                      Text('Niveles oficiales proyectados', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary)),
                    ]),
                    if (_corridaId > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('Corrida #$_corridaId', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6))),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  if (_forecastLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CupertinoActivityIndicator(radius: 10)))
                  else if (_inaForecasts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.separator, width: 0.5)),
                      child: Center(child: Text('Sin pronosticos disponibles', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textTertiary))),
                    )
                  else
                    ..._inaForecasts.map((f) => _forecastCard(f)),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _stationGridCard(Map<String, dynamic> s) {
    final flow = (s['flow'] as num).toDouble();
    final median = (s['median'] as num).toDouble();
    final pct = median > 0 ? ((flow - median) / median * 100) : 0.0;
    final trend = s['trend'] as String;

    Color trendColor = AppColors.success;
    IconData trendIcon = CupertinoIcons.equal_circle;
    if (trend == LocaleService.t('dyn_key_117')) { trendColor = AppColors.accent; trendIcon = CupertinoIcons.arrow_up_circle_fill; }
    if (trend == LocaleService.t('dyn_key_119')) { trendColor = AppColors.error; trendIcon = CupertinoIcons.arrow_down_circle_fill; }

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
              color: trendColor,
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
                      decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                      child: Center(child: Icon(CupertinoIcons.waveform_path, size: 14, color: trendColor)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s['name'], style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(5)),
                    child: Text(s['river'] ?? '', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),
                  // Flow value
                  Text('${flow.toStringAsFixed(0)} m\u00B3/s', style: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w400, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  // Trend badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: trendColor.withValues(alpha: 0.3), width: 0.5)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(trendIcon, size: 10, color: trendColor),
                        const SizedBox(width: 3),
                        Text('${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: trendColor)),
                      ]),
                    ),
                    const SizedBox(width: 4),
                    Text(_trendLabel(trend), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w600, color: trendColor)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _ukcStatusColor(String status) {
    switch (status) {
      case 'SAFE': return AppColors.success;
      case 'CAUTION': return AppColors.warning;
      case 'CRITICAL': return AppColors.error;
      case 'BLOCKED': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  Widget _ukcCard(Map<String, dynamic> u) {
    final status = u['status'] as String;
    final color = _ukcStatusColor(status);
    final ukc = u['ukc'] as double;
    final depth = u['estimatedDepth'] as double;

    IconData statusIcon;
    switch (status) {
      case 'SAFE': statusIcon = CupertinoIcons.check_mark_circled_solid; break;
      case 'CAUTION': statusIcon = CupertinoIcons.exclamationmark_triangle_fill; break;
      default: statusIcon = CupertinoIcons.xmark_circle_fill;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(statusIcon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['name'], style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
            Text('Prof. est: ${depth}m', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${ukc >= 0 ? "+" : ""}${ukc}m', style: GoogleFonts.newsreader(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
          ]),
        ]),
      ),
    );
  }

  Color _inaStatusColor(String status) {
    switch (status) {
      case 'NORMAL': return AppColors.success;
      case 'ALERTA': return AppColors.warning;
      case 'EVACUACION': return AppColors.error;
      case 'AGUAS_BAJAS': return const Color(0xFF3B82F6);
      default: return AppColors.textTertiary;
    }
  }

  IconData _inaStatusIcon(String status) {
    switch (status) {
      case 'NORMAL': return CupertinoIcons.check_mark_circled_solid;
      case 'ALERTA': return CupertinoIcons.exclamationmark_triangle_fill;
      case 'EVACUACION': return CupertinoIcons.xmark_circle_fill;
      case 'AGUAS_BAJAS': return CupertinoIcons.arrow_down_circle_fill;
      default: return CupertinoIcons.question_circle_fill;
    }
  }

  String _inaStatusLabel(String status) {
    switch (status) {
      case 'NORMAL': return 'Normal';
      case 'ALERTA': return 'Alerta';
      case 'EVACUACION': return 'Evacuación';
      case 'AGUAS_BAJAS': return 'Aguas Bajas';
      default: return 'Sin datos';
    }
  }

  Future<void> _fetchINAForecast() async {
    setState(() => _forecastLoading = true);
    try {
      final url = Uri.parse('https://viabarcazas.com/api/hydrology/ina/forecast');
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final forecasts = (data['forecasts'] as List?) ?? [];
        setState(() {
          _inaForecasts = forecasts.map((f) => {
            'station': f['station'] ?? '',
            'seriesId': f['seriesId'] ?? 0,
            'forecast': ((f['forecast'] as List?) ?? []).map((p) => {
              't': p['t'] ?? '',
              'v': p['v'] != null ? (p['v'] as num).toDouble() : null,
            }).where((p) => p['v'] != null).toList().cast<Map<String, dynamic>>(),
          }).where((f) => (f['forecast'] as List).isNotEmpty).toList().cast<Map<String, dynamic>>();
          _forecastModel = data['model'] ?? '';
          _corridaId = data['corridaId'] ?? 0;
          _forecastLoading = false;
        });
      }
    } catch (e) {
      debugPrint('INA Forecast error: $e');
      if (mounted) setState(() => _forecastLoading = false);
    }
  }

  Widget _forecastCard(Map<String, dynamic> f) {
    final station = f['station'] as String;
    final points = (f['forecast'] as List<Map<String, dynamic>>)
        .where((p) => p['v'] != null)
        .toList();
    if (points.isEmpty) return const SizedBox.shrink();

    final vals = points.map((p) => p['v'] as double).toList();
    final mn = vals.reduce(min);
    final mx = vals.reduce(max);
    final rng = mx - mn > 0 ? mx - mn : 1.0;
    final diff = vals.last - vals.first;

    Color trendColor;
    IconData trendIcon;
    String trendLabel;
    if (diff > 0.1) {
      trendColor = const Color(0xFFEF4444);
      trendIcon = CupertinoIcons.arrow_up_circle_fill;
      trendLabel = 'Sube +${diff.toStringAsFixed(2)}m';
    } else if (diff < -0.1) {
      trendColor = const Color(0xFF10B981);
      trendIcon = CupertinoIcons.arrow_down_circle_fill;
      trendLabel = 'Baja ${diff.toStringAsFixed(2)}m';
    } else {
      trendColor = AppColors.textTertiary;
      trendIcon = CupertinoIcons.minus_circle;
      trendLabel = 'Estable';
    }

    final colors = [const Color(0xFF3B82F6), const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFF8B5CF6), const Color(0xFFEF4444), const Color(0xFF06B6D4), const Color(0xFFEC4899), const Color(0xFFF97316)];
    final idx = _inaForecasts.indexOf(f);
    final barColor = colors[idx % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top accent bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: barColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                  child: Center(child: Icon(CupertinoIcons.waveform_path, size: 14, color: barColor)),
                ),
                const SizedBox(width: 8),
                Text(station, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(trendIcon, size: 11, color: trendColor),
                  const SizedBox(width: 3),
                  Text(trendLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: trendColor)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            // Bar chart
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((p) {
                  final v = p['v'] as double;
                  final pct = ((v - mn) / rng).clamp(0.1, 1.0);
                  final dateStr = (p['t'] as String).length >= 10 ? (p['t'] as String).substring(0, 10) : '';
                  final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
                  final dayLabel = date != null ? '${date.day}/${date.month}' : '';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(v.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 3),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: pct,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [barColor, barColor.withValues(alpha: 0.5)]),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(dayLabel, style: GoogleFonts.inter(fontSize: 8, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Min/Max footer
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Min: ${mn.toStringAsFixed(2)}m', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary)),
              Text('Max: ${mx.toStringAsFixed(2)}m', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _inaGridCard(Map<String, dynamic> s) {
    final status = s['status'] as String;
    final color = _inaStatusColor(status);
    final icon = _inaStatusIcon(status);
    final label = _inaStatusLabel(status);
    final level = s['level'] as double?;
    final alert = s['alertLevel'] as double?;
    final low = s['lowLevel'] as double?;
    final name = s['name'] as String;

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
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                      child: Center(child: Icon(icon, size: 14, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(5)),
                    child: Text(s['river'] ?? '', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),
                  // Level
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
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5)),
                    child: Text(label, style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final double progress;
  _BarChartPainter(this.data, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce(max) * 1.1;
    final barWidth = size.width / data.length - 2;
    for (int i = 0; i < data.length; i++) {
      final val = data[i];
      final pct = (val / maxVal) * progress;
      final height = pct * size.height;
      final x = i * (barWidth + 2);
      final opacity = 0.15 + (val / maxVal) * 0.55;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - height, barWidth, height), const Radius.circular(2)),
        Paint()..color = AppColors.textPrimary.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) => old.progress != progress;
}
