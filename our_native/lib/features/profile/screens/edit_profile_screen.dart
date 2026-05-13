import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/user_profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameCtrl;
  late TextEditingController _surnameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _currentLocationCtrl;
  late TextEditingController _nativeVillageCtrl;

  File? _pickedImage;
  bool _uploadingImage = false;
  bool _saving = false;

  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController();
    _surnameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _currentLocationCtrl = TextEditingController();
    _nativeVillageCtrl = TextEditingController();

    // Populate from provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).asData?.value;
      if (profile != null) _populateFrom(profile);
    });
  }

  void _populateFrom(UserProfile profile) {
    _profile = profile;
    _fullNameCtrl.text = profile.fullName;
    _surnameCtrl.text = profile.surname ?? '';
    _bioCtrl.text = profile.bio ?? '';
    _currentLocationCtrl.text = profile.currentLocation ?? '';
    _nativeVillageCtrl.text = profile.nativeVillage ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _surnameCtrl.dispose();
    _bioCtrl.dispose();
    _currentLocationCtrl.dispose();
    _nativeVillageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xfile == null) return;
    setState(() => _pickedImage = File(xfile.path));
  }

  Future<String?> _uploadAvatar(String userId) async {
    if (_pickedImage == null) return null;
    setState(() => _uploadingImage = true);
    try {
      final ext = _pickedImage!.path.split('.').last.toLowerCase();
      // path must start with userId/ to satisfy profile-photos RLS policy
      final path = '$userId/avatar.$ext';
      await supabase.storage.from('profile-photos').upload(
            path,
            _pickedImage!,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = supabase.storage.from('profile-photos').getPublicUrl(path);
      return url;
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profile == null) return;

    setState(() => _saving = true);
    try {
      String? photoUrl = _profile!.profilePhotoUrl;

      // Upload new avatar if picked
      if (_pickedImage != null) {
        photoUrl = await _uploadAvatar(_profile!.userId);
      }

      await supabase.from('user_profiles').update({
        'full_name': _fullNameCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim().isEmpty
            ? null
            : _surnameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'current_location': _currentLocationCtrl.text.trim().isEmpty
            ? null
            : _currentLocationCtrl.text.trim(),
        'native_village': _nativeVillageCtrl.text.trim().isEmpty
            ? null
            : _nativeVillageCtrl.text.trim(),
        // ignore: use_null_aware_elements
        if (photoUrl != null) 'profile_photo_url': photoUrl,
      }).eq('user_id', _profile!.userId);

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile != null && _profile == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _populateFrom(profile));
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildAvatarSection(profile),
                const SizedBox(height: 28),
                _field(
                  controller: _fullNameCtrl,
                  label: 'Full Name',
                  hint: 'e.g. Ramesh',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _surnameCtrl,
                  label: 'Surname / Family Name',
                  hint: 'e.g. Patil',
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _nativeVillageCtrl,
                  label: 'Native Village',
                  hint: 'Your home village name',
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _currentLocationCtrl,
                  label: 'Current Location',
                  hint: 'e.g. Pune, Mumbai, Nashik',
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _bioCtrl,
                  label: 'About Me',
                  hint: 'A short bio visible to community members',
                  maxLines: 4,
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(UserProfile? profile) {
    final hasLocalPick = _pickedImage != null;
    final networkUrl = profile?.profilePhotoUrl;
    final displayName = profile?.fullName ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
            backgroundImage: hasLocalPick
                ? FileImage(_pickedImage!)
                : (networkUrl != null ? NetworkImage(networkUrl) : null)
                    as ImageProvider?,
            child: (!hasLocalPick && networkUrl == null)
                ? Text(initials,
                    style: AppTextStyles.h2
                        .copyWith(color: AppColors.primaryGreen))
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _uploadingImage ? null : _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _uploadingImage
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
