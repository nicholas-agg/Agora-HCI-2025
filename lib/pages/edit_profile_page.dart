import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _error = 'No user logged in.'; _loading = false; });
      return;
    }
    try {
      // Re-authenticate if changing email or password
      if (_emailController.text != user.email || _newPasswordController.text.isNotEmpty) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(cred);
      }
      // Update display name
      if (_nameController.text != user.displayName && _nameController.text.isNotEmpty) {
        await user.updateDisplayName(_nameController.text);
      }
      // Update email
      if (_emailController.text != user.email && _emailController.text.isNotEmpty) {
        await user.verifyBeforeUpdateEmail(_emailController.text);
      }
      // Update password
      if (_newPasswordController.text.isNotEmpty) {
        await user.updatePassword(_newPasswordController.text);
      }
      await user.reload();
      setState(() { _loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'An error occurred.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display Name'),
                validator: (val) => val == null || val.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val == null || !val.contains('@') ? 'Valid email required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
                validator: (val) {
                  if ((_emailController.text != FirebaseAuth.instance.currentUser?.email || _newPasswordController.text.isNotEmpty) && (val == null || val.isEmpty)) {
                    return 'Current password required to change email or password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password (optional)'),
                obscureText: true,
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _saveChanges,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
