import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/supabase_service.dart';
import '../../../services/storage_service.dart';
import '../providers/user_profile_provider.dart';

// ── 3-step wizard constants ───────────────────────────────────────────────────
const _kTotalSteps = 3;

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _pageCtrl = PageController();
  int _currentStep = 0;

  // Step 1 — Identity
  final _step1Key = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  File? _photoFile;

  // Step 2 — Village
  final _step2Key = GlobalKey<FormState>();
  String? _selectedDistrictId;
  String? _selectedTalukaId;
  String? _selectedVillageId;
  String? _selectedVillageName;
  String? _selectedWadiId;
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _talukas = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _wadis = [];
  bool _loadingGeo = false;

  // Step 3 — About you
  final _step3Key = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _isLoading = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDistricts();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ── Step navigation ─────────────────────────────────────────────────────────

  void _goNext() {
    bool valid = false;
    switch (_currentStep) {
      case 0:
        valid = _step1Key.currentState?.validate() ?? false;
      case 1:
        if (_selectedVillageId == null) {
          AppUtils.showSnack(context, 'Please select your village', isError: true);
          return;
        }
        valid = true;
      case 2:
        valid = true;
    }
    if (!valid) return;

    if (_currentStep < _kTotalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfile();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Geography cascade ────────────────────────────────────────────────────────

  Future<void> _loadDistricts() async {
    if (!mounted) return;
    setState(() => _loadingGeo = true);
    try {
      final data = await supabase
          .from('districts')
          .select('id, name')
          .order('sort_order');
      if (mounted) {
        setState(() => _districts = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGeo = false);
    }
  }

  Future<void> _onDistrictChanged(String? id) async {
    setState(() {
      _selectedDistrictId = id;
      _selectedTalukaId = null;
      _selectedVillageId = null;
      _selectedVillageName = null;
      _selectedWadiId = null;
      _talukas = [];
      _villages = [];
      _wadis = [];
    });
    if (id == null) return;
    setState(() => _loadingGeo = true);
    try {
      final data = await supabase
          .from('talukas')
          .select('id, name')
          .eq('district_id', id)
          .order('sort_order');
      if (mounted) setState(() => _talukas = List<Map<String, dynamic>>.from(data));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGeo = false);
    }
  }

  Future<void> _onTalukaChanged(String? id) async {
    setState(() {
      _selectedTalukaId = id;
      _selectedVillageId = null;
      _selectedVillageName = null;
      _selectedWadiId = null;
      _villages = [];
      _wadis = [];
    });
    if (id == null) return;
    setState(() => _loadingGeo = true);
    try {
      final data = await supabase
          .from('villages')
          .select('id, name')
          .eq('taluka_id', id)
          .order('sort_order');
      if (mounted) setState(() => _villages = List<Map<String, dynamic>>.from(data));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGeo = false);
    }
  }

  Future<void> _onVillageChanged(String? id) async {
    final name = id == null
        ? null
        : (_villages.firstWhere((v) => v['id'] == id, orElse: () => {})['name']
            as String?);
    setState(() {
      _selectedVillageId = id;
      _selectedVillageName = name;
      _selectedWadiId = null;
      _wadis = [];
    });
    if (id == null) return;
    setState(() => _loadingGeo = true);
    try {
      final data = await supabase
          .from('reference_wadis')
          .select('id, name')
          .eq('village_id', id)
          .order('sort_order');
      if (mounted) setState(() => _wadis = List<Map<String, dynamic>>.from(data));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGeo = false);
    }
  }

  // ── Photo picker ─────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  // ── Save ──────────────────────────────────────────────────────────────────────

  String _friendlySaveError(Object error) {
    final raw = error.toString();
    final cleaned = raw.startsWith('Exception:')
        ? raw.replaceFirst('Exception:', '').trim()
        : raw;
    final lower = cleaned.toLowerCase();
    if (lower.contains('violates row-level security policy') &&
        lower.contains('table "communities"')) {
      return 'Unable to create/join community due to database policy setup. '
          'Please apply the latest Supabase migration SQL and try again.';
    }
    return cleaned;
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.instance.currentUser!.id;

      final rpcResult = await supabase.rpc(
        'create_or_join_community',
        params: {'p_village_id': _selectedVillageId},
      ) as Map<String, dynamic>;
      final communityId = rpcResult['community_id'] as String;
      final isCreator = rpcResult['is_creator'] as bool;

      String? photoUrl;
      if (_photoFile != null) {
        photoUrl = await StorageService.instance
            .uploadProfilePhoto(userId, _photoFile!);
      }

      await supabase.from('user_profiles').upsert(
        {
          'user_id': userId,
          'community_id': communityId,
          'full_name': _nameCtrl.text.trim(),
          'surname': _surnameCtrl.text.trim().isEmpty
              ? null
              : _surnameCtrl.text.trim(),
          'native_village': _selectedVillageName,
          'village_id': _selectedVillageId,
          'wadi_id': _selectedWadiId,
          'current_location': _locationCtrl.text.trim().isEmpty
              ? null
              : _locationCtrl.text.trim(),
          'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
          'phone':
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'profile_photo_url': photoUrl,
          'role': isCreator ? AppConstants.roleAdmin : AppConstants.roleMember,
          'is_approved': isCreator,
        },
        onConflict: 'user_id',
      );

      ref.invalidate(userProfileProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        AppUtils.showSnack(
          context,
          'Failed to save profile: ${_friendlySaveError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header with progress ─────────────────────────────────────────────────────

  Widget _buildHeader() {
    const stepTitles = ['Your identity', 'Your village', 'About you'];
    const stepIcons = [
      Icons.person_outline_rounded,
      Icons.home_outlined,
      Icons.edit_note_outlined,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_currentStep > 0)
                GestureDetector(
                  onTap: _goBack,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundBeige,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppColors.textPrimary),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of $_kTotalSteps',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primaryGreen),
                    ),
                    Text(
                      stepTitles[_currentStep],
                      style: AppTextStyles.h2,
                    ),
                  ],
                ),
              ),
              Icon(stepIcons[_currentStep],
                  size: 28, color: AppColors.primaryGreen.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented progress bar
          Row(
            children: List.generate(_kTotalSteps, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.only(right: i < _kTotalSteps - 1 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _currentStep
                        ? AppColors.primaryGreen
                        : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Footer with action button ────────────────────────────────────────────────

  Widget _buildFooter() {
    final isLast = _currentStep == _kTotalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _goNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  isLast ? 'Join Community 🌱' : 'Continue',
                  style: AppTextStyles.button,
                ),
        ),
      ),
    );
  }

  // ── Step 1: Identity ─────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo picker — centered, large, friendly
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.backgroundBeige,
                      backgroundImage:
                          _photoFile != null ? FileImage(_photoFile!) : null,
                      child: _photoFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_rounded,
                                    size: 32, color: AppColors.primaryGreen),
                                const SizedBox(height: 6),
                                Text('Add photo',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.primaryGreen)),
                              ],
                            )
                          : null,
                    ),
                    if (_photoFile != null)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.backgroundIvory, width: 2),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: Text(
                  _photoFile == null ? 'Optional — you can add it later' : 'Tap to change',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.textHint),
                ),
              ),
            ),
            _buildField(_nameCtrl, 'Full Name *', Icons.person_outline,
                required: true),
            const SizedBox(height: 16),
            _buildField(
                _surnameCtrl, 'Surname / Family Name', Icons.family_restroom_outlined),
            const SizedBox(height: 16),
            _buildField(_phoneCtrl, 'Phone Number (optional)',
                Icons.phone_outlined,
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Village ───────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primaryGreen, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your village connects you to your community. First members become admins.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
            if (_loadingGeo && _districts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            _buildDropdown(
              label: 'District *',
              icon: Icons.map_outlined,
              value: _selectedDistrictId,
              hint: 'Select district',
              items: _districts
                  .map((d) => DropdownMenuItem(
                        value: d['id'] as String,
                        child: Text(d['name'] as String),
                      ))
                  .toList(),
              onChanged: _loadingGeo ? null : _onDistrictChanged,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Taluka *',
              icon: Icons.location_city_outlined,
              value: _selectedTalukaId,
              hint: _selectedDistrictId == null
                  ? 'Select district first'
                  : 'Select taluka',
              items: _talukas
                  .map((t) => DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(t['name'] as String),
                      ))
                  .toList(),
              onChanged: (_selectedDistrictId == null || _loadingGeo)
                  ? null
                  : _onTalukaChanged,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Village *',
              icon: Icons.home_outlined,
              value: _selectedVillageId,
              hint: _selectedTalukaId == null
                  ? 'Select taluka first'
                  : 'Select village',
              items: _villages
                  .map((v) => DropdownMenuItem(
                        value: v['id'] as String,
                        child: Text(v['name'] as String),
                      ))
                  .toList(),
              onChanged: (_selectedTalukaId == null || _loadingGeo)
                  ? null
                  : _onVillageChanged,
            ),
            if (_wadis.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'Wadi / Sub-area',
                icon: Icons.holiday_village_outlined,
                value: _selectedWadiId,
                hint: 'Select your wadi (optional)',
                items: _wadis
                    .map((w) => DropdownMenuItem(
                          value: w['id'] as String,
                          child: Text(w['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedWadiId = v),
                isRequired: false,
              ),
            ],
            if (_loadingGeo)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: LinearProgressIndicator()),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Step 3: About you ─────────────────────────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Form(
        key: _step3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              _locationCtrl,
              'Current Location',
              Icons.location_on_outlined,
              hint: 'e.g. Mumbai, Pune, Gulf, USA',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Short Introduction',
                prefixIcon: Icon(Icons.edit_note_outlined),
                alignLabelWithHint: true,
                hintText: 'Tell your community about yourself...',
              ),
            ),
            const SizedBox(height: 20),
            // Summary card
            if (_selectedVillageName != null)
              _buildSummaryCard(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundBeige,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppColors.primaryBrown, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your profile will be reviewed by a community admin before you can post.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final name = _nameCtrl.text.trim();
    final surname = _surnameCtrl.text.trim();
    final displayName = [name, surname].where((s) => s.isNotEmpty).join(' ');

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ready to join?',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.primaryGreen)),
          const SizedBox(height: 10),
          _SummaryRow(
              icon: Icons.person_outline,
              label: displayName.isEmpty ? '—' : displayName),
          _SummaryRow(
              icon: Icons.home_outlined,
              label: _selectedVillageName ?? '—'),
          if (_photoFile != null)
            _SummaryRow(
                icon: Icons.photo_camera_outlined,
                label: 'Profile photo added ✓'),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          hintText: hint,
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      );

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
    String? hint,
    bool isRequired = true,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          hintText: hint,
        ),
        items: items,
        onChanged: onChanged,
        validator: isRequired
            ? (v) => v == null ? 'Please select $label' : null
            : null,
      );
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
