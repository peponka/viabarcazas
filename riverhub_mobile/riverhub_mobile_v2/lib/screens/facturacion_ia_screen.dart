import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:viabarcazas_mobile/theme/app_colors.dart';

/// Invoice Intelligence screen — paste text, take photo, or select from gallery.
/// Uses Gemini Vision for OCR when image is provided.
class FacturacionIAScreen extends StatefulWidget {
  const FacturacionIAScreen({super.key});

  @override
  State<FacturacionIAScreen> createState() => _FacturacionIAScreenState();
}

class _FacturacionIAScreenState extends State<FacturacionIAScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;
  File? _selectedImage;
  String? _imageBase64;
  String? _imageMime;

  static const String _apiBase = 'https://riverhub-elite-360.onrender.com';

  static const String _demoInvoice = '''FACTURA DE FLETE FLUVIAL
N\u00B0 0001-00004521
Fecha: 15/04/2026
Emisor: Transportes Fluviales del Paran\u00E1 S.A.
CUIT: 30-71234567-8
Cliente: Cargill S.A.C.I.

Detalle del servicio:
- Viaje: Convoy C-47 | Ruta: Asunci\u00F3n (PY) \u2192 Rosario (AR)
- Embarcaci\u00F3n: R/M H\u00C9RCULES + 6 barcazas
- Carga: 8.400 toneladas de soja a granel
- Distancia: 1.580 km

Conceptos:
1. Flete principal (8.400 ton x USD 12.50/ton)............ USD 105,000.00
2. Sobrestad\u00EDa puerto Rosario (3 d\u00EDas x USD 2,800/d\u00EDa).... USD   8,400.00
3. Combustible adicional (2.100 lt x USD 0.92/lt)......... USD   1,932.00
4. Seguro de carga (0.15% sobre valor declarado).......... USD   4,200.00
5. Servicio de practicaje.................................. USD   1,500.00

Subtotal:.............. USD 121,032.00
IVA 21%:............... USD  25,416.72
TOTAL:................. USD 146,448.72

Condici\u00F3n de pago: 30 d\u00EDas fecha factura
Cuenta: Banco Naci\u00F3n \u2014 CBU 0110012340001234567890''';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (image == null) return;

      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      final mime = image.mimeType ?? (image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');

      if (mounted) {
        setState(() {
          _selectedImage = file;
          _imageBase64 = base64;
          _imageMime = mime;
          _error = null;
          _result = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al seleccionar imagen: $e');
    }
  }

  void _showImageSourceSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Escanear Factura', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        message: Text('Seleccion\u00E1 el origen de la imagen', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          CupertinoActionSheetAction(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(CupertinoIcons.camera_fill, size: 18),
              const SizedBox(width: 8),
              Text('Tomar Foto', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            ]),
            onPressed: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
          ),
          CupertinoActionSheetAction(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(CupertinoIcons.photo_fill, size: 18),
              const SizedBox(width: 8),
              Text('Galer\u00EDa', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            ]),
            onPressed: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _imageBase64 == null) {
      setState(() => _error = 'Peg\u00E1 texto o subi una imagen primero.');
      return;
    }
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken ?? 'demo';
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 90);
      final uri = Uri.parse('$_apiBase/api/ai/invoice');
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');

      final body = <String, dynamic>{};
      if (text.isNotEmpty) body['invoiceText'] = text;
      if (_imageBase64 != null) {
        body['invoiceImage'] = {
          'data': _imageBase64,
          'mimeType': _imageMime ?? 'image/jpeg',
        };
      }

      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(const Duration(seconds: 120));
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data.containsKey('result') && data['result'] != null) {
        setState(() => _result = data['result'] as Map<String, dynamic>);
      } else if (data.containsKey('apiError') && data['apiError'] != null) {
        setState(() => _error = 'Gemini API: ${data['apiError']}');
      } else {
        setState(() => _error = data['raw']?.toString() ?? 'No se pudo procesar');
      }
    } catch (e) {
      setState(() => _error = 'Error de conexi\u00F3n: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundSecondary,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundPrimary,
        middle: Text('Invoice Intelligence', style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w500)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text('Demo', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
          onPressed: () => setState(() { _controller.text = _demoInvoice; _result = null; _error = null; }),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFF00C2A8), size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Peg\u00E1 texto, tom\u00E1 una foto o seleccion\u00E1 desde la galer\u00EDa. La IA extrae datos y detecta discrepancias.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // OCR Buttons
            Row(children: [
              Expanded(child: _actionBtn(CupertinoIcons.camera_fill, 'Escanear', const Color(0xFF7C3AED), _showImageSourceSheet)),
              const SizedBox(width: 10),
              Expanded(child: _actionBtn(CupertinoIcons.doc_text_fill, 'Demo', const Color(0xFF0066FF), () {
                setState(() { _controller.text = _demoInvoice; _result = null; _error = null; });
              })),
            ]),
            const SizedBox(height: 16),

            // Image preview
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.separator)),
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(top: 8, right: 8, child: GestureDetector(
                    onTap: () => setState(() { _selectedImage = null; _imageBase64 = null; _imageMime = null; }),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 14),
                    ),
                  )),
                  Positioned(bottom: 8, left: 8, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(6)),
                    child: Text('OCR Listo', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  )),
                ]),
              ),

            // Input
            _card(
              title: 'FACTURA A ANALIZAR',
              child: Column(children: [
                CupertinoTextField(
                  controller: _controller,
                  placeholder: 'Peg\u00E1 aqu\u00ED el texto de la factura...',
                  maxLines: 6,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                  placeholderStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.separator), borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _loading ? null : _analyze,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_loading ? CupertinoIcons.hourglass : CupertinoIcons.sparkles, size: 16),
                        const SizedBox(width: 8),
                        Text(_loading ? 'Analizando...' : 'Analizar con IA', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.separator,
                    child: const Icon(CupertinoIcons.trash, size: 16, color: Colors.black54),
                    onPressed: () => setState(() {
                      _controller.clear(); _result = null; _error = null;
                      _selectedImage = null; _imageBase64 = null; _imageMime = null;
                    }),
                  ),
                ]),
              ]),
            ),

            if (_loading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Column(children: [
                  const CupertinoActivityIndicator(radius: 14),
                  const SizedBox(height: 8),
                  Text('Gemini est\u00E1 analizando...', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ])),
              ),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B))),
              ),

            if (_result != null) ..._buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  List<Widget> _buildResults() {
    final inv = (_result!['invoice'] ?? {}) as Map<String, dynamic>;
    final val = (_result!['validation'] ?? {}) as Map<String, dynamic>;
    final sum = (_result!['summary'] ?? {}) as Map<String, dynamic>;
    final status = (sum['status'] ?? 'REVISAR').toString().toUpperCase();
    final isApproved = status.contains('APROB');
    final isRejected = status.contains('RECH');

    return [
      const SizedBox(height: 16),
      _card(title: 'RESULTADO', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isApproved ? const Color(0xFFDCFCE7) : isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: isApproved ? const Color(0xFF166534) : isRejected ? const Color(0xFF991B1B) : const Color(0xFF92400E),
          )),
        ),
        if (sum['confidence'] != null) ...[
          const SizedBox(height: 8),
          Text('Confianza: ${sum['confidence']}%', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ],
        if (sum['notes'] != null) ...[
          const SizedBox(height: 8),
          Text(sum['notes'].toString(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 16),
        _statRow('N\u00B0 Factura', inv['number']?.toString() ?? 'N/A'),
        _statRow('Proveedor', inv['supplier']?.toString() ?? 'N/A'),
        _statRow('Fecha', inv['date']?.toString() ?? 'N/A'),
        _statRow('Total', '${inv['currency'] ?? 'USD'} ${_formatNum(inv['total'])}'),
      ])),

      if ((inv['items'] as List?)?.isNotEmpty ?? false)
        _card(title: '\u00CDTEMS EXTRA\u00CDDOS', child: Column(
          children: (inv['items'] as List).map<Widget>((item) {
            final it = item as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF4F4F5)))),
              child: Row(children: [
                Expanded(child: Text(it['description']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 13))),
                Text(_formatNum(it['subtotal']), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            );
          }).toList(),
        )),

      if ((val['discrepancies'] as List?)?.isNotEmpty ?? false)
        _card(title: 'DISCREPANCIAS', child: Column(
          children: (val['discrepancies'] as List).map<Widget>((d) {
            final disc = d as Map<String, dynamic>;
            final sev = disc['severity']?.toString() ?? 'INFO';
            final color = sev == 'CRITICA' ? const Color(0xFFEF4444) : sev == 'ADVERTENCIA' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6);
            final bg = sev == 'CRITICA' ? const Color(0xFFFEE2E2) : sev == 'ADVERTENCIA' ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 14, backgroundColor: color, child: const Icon(CupertinoIcons.exclamationmark, size: 14, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${disc['field']}: ${disc['invoiceValue']} vs ${disc['systemValue']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (disc['note'] != null) Text(disc['note'].toString(), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ])),
              ]),
            );
          }).toList(),
        )),
    ];
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border.all(color: AppColors.separator),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        Flexible(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
      ]),
    );
  }

  String _formatNum(dynamic val) {
    if (val == null) return '0.00';
    final num n = val is num ? val : double.tryParse(val.toString()) ?? 0;
    return n.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');
  }
}
