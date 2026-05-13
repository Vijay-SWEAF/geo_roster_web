import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../models/help_request.dart';

class CreateHelpScreen extends ConsumerStatefulWidget {
  const CreateHelpScreen({super.key});

  @override
  ConsumerState<CreateHelpScreen> createState() => _CreateHelpScreenState();
}

class _CreateHelpScreenState extends ConsumerState<CreateHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  HelpType? _helpType;
  HelpUrgency _urgency = HelpUrgency.medium;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_helpType == null) {
      AppUtils.showSnack(context, 'Please select a help type');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (mounted) {
      AppUtils.showSnack(context, 'Help request submitted to the community!');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Help')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What kind of help do you need?', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HelpType.values.map((type) {
                  final isSelected = _helpType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _helpType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.backgroundBeige,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        '${type.emoji} ${type.displayName}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Request Title *',
                  hintText: 'e.g. Blood needed — O+ve urgently in Latur',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Provide more details — hospital name, timing, etc.',
                ),
              ),
              const SizedBox(height: 14),
              Text('Urgency', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: HelpUrgency.values.map((u) {
                  final isSelected = _urgency == u;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _urgency = u),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _urgencyColor(u)
                              : AppColors.backgroundBeige,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? _urgencyColor(u)
                                : AppColors.divider,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            u.name.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contactNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _contactPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (v != null && v.isNotEmpty && !AppUtils.isValidPhone(v)) {
                          return 'Invalid phone';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Post Help Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _urgencyColor(HelpUrgency u) {
    switch (u) {
      case HelpUrgency.low:      return AppColors.success;
      case HelpUrgency.medium:   return AppColors.warning;
      case HelpUrgency.high:     return AppColors.error;
      case HelpUrgency.critical: return const Color(0xFF8B0000);
    }
  }
}
