import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../main.dart' show themeModeProvider;
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _notificationsEnabled = true;

  final _nameCtrl = TextEditingController();
  final _barNumCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barNumCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _startEditing() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    _nameCtrl.text = user.fullName;
    _barNumCtrl.text = user.barNumber ?? '';
    _phoneCtrl.text = user.phone ?? '';
    _addressCtrl.text = user.address ?? '';
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put(ApiEndpoints.usersMe, data: {
        'full_name': _nameCtrl.text.trim(),
        'bar_number': _barNumCtrl.text.trim().isEmpty ? null : _barNumCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      });
      await ref.read(authProvider.notifier).loadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (image == null) return;
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path, filename: 'profile.jpg'),
      });
      await dio.post(ApiEndpoints.usersMePhoto, data: formData);
      await ref.read(authProvider.notifier).loadUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final theme = Theme.of(context);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary.withAlpha(25),
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(user.fullName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 36, color: AppColors.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    onPressed: _pickPhoto,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_isEditing) ...[
          Text(user.fullName, textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(user.email, textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          if (user.barNumber != null)
            Text('Bar #: ${user.barNumber}', textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (user.phone != null) _infoRow(Icons.phone, user.phone!),
                  if (user.address != null) _infoRow(Icons.location_on, user.address!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barNumCtrl,
            decoration: const InputDecoration(labelText: 'Bar Number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Settings', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Receive hearing reminders & updates'),
                value: _notificationsEnabled,
                onChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme'),
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (v) {
                  ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
                  context.go('/');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!_isEditing)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Logout', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
