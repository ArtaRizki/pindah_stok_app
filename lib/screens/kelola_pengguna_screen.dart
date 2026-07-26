import 'package:flutter/material.dart';
import '../services/api_service.dart';

class KelolaPenggunaScreen extends StatefulWidget {
  const KelolaPenggunaScreen({super.key});

  @override
  State<KelolaPenggunaScreen> createState() => _KelolaPenggunaScreenState();
}

class _KelolaPenggunaScreenState extends State<KelolaPenggunaScreen> {
  List<Map<String, String>> _admins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    setState(() => _loading = true);
    try {
      final admins = await ApiService.getAdmin();
      if (mounted) setState(() { _admins = admins; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Future<void> _dialogTambah() async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'admin';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Tambah Admin Baru'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin Biasa')),
                    DropdownMenuItem(value: 'superadmin', child: Text('Superadmin')),
                  ],
                  onChanged: (v) => setDlgState(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    setState(() => _loading = true);
    try {
      final res = await ApiService.tambahAdmin(
        username: usernameCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
        role: selectedRole,
      );
      if (res['success'] == true) {
        _showSuccess(res['message'] ?? 'Berhasil ditambahkan');
        _fetchAdmins();
      } else {
        setState(() => _loading = false);
        _showError(res['message'] ?? 'Gagal menambah admin');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  Future<void> _dialogEdit(Map<String, String> admin) async {
    final passwordCtrl = TextEditingController();
    String selectedRole = admin['role'] ?? 'admin';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Edit Admin: ${admin['username']}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password Baru',
                    hintText: 'Kosongkan jika tidak diubah',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin Biasa')),
                    DropdownMenuItem(value: 'superadmin', child: Text('Superadmin')),
                  ],
                  onChanged: (v) => setDlgState(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final newPass = passwordCtrl.text.trim();
    setState(() => _loading = true);
    try {
      final res = await ApiService.editAdmin(
        username: admin['username']!,
        newPassword: newPass.isNotEmpty ? newPass : null,
        newRole: selectedRole,
      );
      if (res['success'] == true) {
        _showSuccess(res['message'] ?? 'Berhasil diperbarui');
        _fetchAdmins();
      } else {
        setState(() => _loading = false);
        _showError(res['message'] ?? 'Gagal memperbarui admin');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  Future<void> _hapus(Map<String, String> admin) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Admin?'),
        content: Text('Admin "${admin['username']}" akan dihapus secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    setState(() => _loading = true);
    try {
      final res = await ApiService.hapusAdmin(username: admin['username']!);
      if (res['success'] == true) {
        _showSuccess(res['message'] ?? 'Berhasil dihapus');
        _fetchAdmins();
      } else {
        setState(() => _loading = false);
        _showError(res['message'] ?? 'Gagal menghapus admin');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAdmins,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _dialogTambah,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Admin'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? const Center(child: Text('Belum ada admin.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _admins.length,
                  separatorBuilder: (_, _1) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final admin = _admins[i];
                    final isSuperadmin = (admin['role'] ?? 'admin') == 'superadmin';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSuperadmin
                              ? const Color(0xFFFFF3CD)
                              : const Color(0xFFEFF6FF),
                          child: Icon(
                            isSuperadmin ? Icons.star_rounded : Icons.person_rounded,
                            color: isSuperadmin ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                          ),
                        ),
                        title: Text(
                          admin['username'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isSuperadmin ? 'Superadmin' : 'Admin Biasa',
                          style: TextStyle(
                            color: isSuperadmin ? const Color(0xFFD97706) : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              tooltip: 'Edit',
                              onPressed: () => _dialogEdit(admin),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Hapus',
                              onPressed: () => _hapus(admin),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
