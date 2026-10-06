import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';

class XtreamLoginScreen extends StatefulWidget {
  const XtreamLoginScreen({super.key});

  @override
  State<XtreamLoginScreen> createState() => _XtreamLoginScreenState();
}

class _XtreamLoginScreenState extends State<XtreamLoginScreen> {
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final c = await StorageService.loadXtreamCreds();
    if (c != null) {
      _hostCtrl.text = c['host'] ?? '';
      _userCtrl.text = c['username'] ?? '';
      _passCtrl.text = c['password'] ?? '';
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final host = _hostCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (host.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'جميع الحقول مطلوبة');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await XtreamService.testConnection(
      host: host,
      username: user,
      password: pass,
    );

    if (!ok) {
      setState(() {
        _loading = false;
        _error = 'فشل الاتصال. تأكد من بيانات الدخول والرابط';
      });
      return;
    }

    await StorageService.saveXtreamCreds(
      host: host,
      username: user,
      password: pass,
    );
    // امسح كاش القنوات القديم ليُعاد التحميل
    await StorageService.clearChannels();

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _logout() async {
    await StorageService.clearXtreamCreds();
    await StorageService.clearChannels();
    _hostCtrl.clear();
    _userCtrl.clear();
    _passCtrl.clear();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Xtream Codes'),
        backgroundColor: const Color(0xFF111827),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.vpn_key, color: Color(0xFF3B82F6), size: 64),
            const SizedBox(height: 16),
            const Text('تسجيل الدخول بـ Xtream Codes',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'سيتم جلب القنوات والأفلام والمسلسلات مباشرة من السيرفر',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _field(_hostCtrl, 'رابط السيرفر', Icons.link,
                'http://server.com:8080'),
            const SizedBox(height: 16),
            _field(_userCtrl, 'اسم المستخدم', Icons.person, 'username'),
            const SizedBox(height: 16),
            _field(_passCtrl, 'كلمة المرور', Icons.lock, '••••••••',
                obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('دخول',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white54),
              label: const Text('تسجيل خروج / حذف البيانات',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      String hint,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      keyboardType: obscure ? TextInputType.text : TextInputType.url,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1F2937),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
