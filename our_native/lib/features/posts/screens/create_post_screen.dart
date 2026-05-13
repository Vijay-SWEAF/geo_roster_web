import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../../../features/auth/providers/user_profile_provider.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/moderation_service.dart';
import '../models/post.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String postType;
  const CreatePostScreen({super.key, this.postType = 'memory'});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  PostType _postType = PostType.memory;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile == null || profile.communityId == null) {
      AppUtils.showSnack(
        context,
        'Set up your community profile before posting.',
        isError: true,
      );
      return;
    }

    if (!profile.isApproved) {
      AppUtils.showSnack(
        context,
        'Your profile is pending approval. Posting is enabled after approval.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // AI moderation check before submitting
      final textToCheck =
          '${_titleCtrl.text.trim()} ${_bodyCtrl.text.trim()}';
      final modResult =
          await ModerationService.instance.check(textToCheck);
      if (modResult.flagged) {
        if (!mounted) return;
        AppUtils.showSnack(
          context,
          modResult.reason ??
              'Post contains content that violates community guidelines.',
          isError: true,
        );
        return;
      }

      // Admin and moderators get their posts auto-approved
      final autoApprove = profile.role.name == 'admin' || profile.role.name == 'moderator';

      final insertedPost = await supabase
          .from('posts')
          .insert({
            'community_id': profile.communityId,
            'author_id': profile.id,
            'post_type': _postType.value,
            'title': _titleCtrl.text.trim(),
            'body': _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
            'status': autoApprove
                ? PostStatus.approved.value
                : PostStatus.pendingReview.value,
          })
          .select('id')
          .single();

      if (_imageFile != null) {
        final postId = insertedPost['id'] as String;
        final imageUrl = await StorageService.instance
            .uploadPostImage(postId, _imageFile!);
        await supabase.from('posts').update({
          'cover_image_url': imageUrl,
        }).eq('id', postId);
      }

      if (!mounted) return;
      AppUtils.showSnack(
        context,
        autoApprove ? 'Post published.' : 'Post submitted for review.',
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnack(
        context,
        'Could not submit post: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final canPost = profile?.isApproved ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: (_isLoading || !canPost) ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5),
                  )
                : Text('Post',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.primaryGreen)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Post Type', style: AppTextStyles.label),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: PostType.values.map((type) {
                    final isSelected = _postType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _postType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _typeColor(type)
                              : AppColors.backgroundBeige,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? _typeColor(type)
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          '${_typeEmoji(type)} ${type.displayName}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  hintText: _titleHint(_postType),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Details',
                  alignLabelWithHint: true,
                  hintText: _bodyHint(_postType),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundBeige,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                        width: 1.5),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                size: 40, color: AppColors.textHint),
                            const SizedBox(height: 6),
                            Text('Add photo (optional)',
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.textHint)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundBeige,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 16, color: AppColors.primaryBrown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All posts are moderated before publishing. Please follow community guidelines.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primaryBrown),
                      ),
                    ),
                  ],
                ),
              ),
              if (!canPost)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Posting is enabled after community admin approval.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(PostType type) {
    switch (type) {
      case PostType.memory:       return AppColors.primaryBrown;
      case PostType.story:        return const Color(0xFF7B4F2E);
      case PostType.elderWisdom:  return AppColors.accentGold;
      case PostType.helpRequest:  return AppColors.success;
      case PostType.event:        return AppColors.primaryGreen;
      case PostType.achievement:  return AppColors.info;
      case PostType.announcement: return AppColors.warning;
    }
  }

  String _typeEmoji(PostType type) {
    switch (type) {
      case PostType.memory:       return '📷';
      case PostType.story:        return '📖';
      case PostType.elderWisdom:  return '🙏';
      case PostType.helpRequest:  return '🤝';
      case PostType.event:        return '🎉';
      case PostType.achievement:  return '🏆';
      case PostType.announcement: return '📢';
    }
  }

  String _titleHint(PostType type) {
    switch (type) {
      case PostType.memory:       return 'e.g. Our village school in 1980s';
      case PostType.story:        return 'e.g. The legend of our village well';
      case PostType.elderWisdom:  return 'e.g. How to plant jowar in dry season';
      case PostType.helpRequest:  return 'e.g. Need blood donor O+ve in Latur';
      case PostType.event:        return 'e.g. Diwali mela at village ground';
      case PostType.achievement:  return 'e.g. Ramesh from our village cleared IAS!';
      case PostType.announcement: return 'e.g. Water supply off on 15th';
    }
  }

  String _bodyHint(PostType type) {
    switch (type) {
      case PostType.memory:       return 'Share the story, year, and who is in the photo...';
      case PostType.story:        return 'Tell the full story...';
      case PostType.elderWisdom:  return 'Explain the traditional knowledge in detail...';
      case PostType.helpRequest:  return 'Describe the situation, location, contact details...';
      case PostType.event:        return 'Date, time, location, what to bring...';
      case PostType.achievement:  return 'Tell us about this achievement and why it matters...';
      case PostType.announcement: return 'Full details of the announcement...';
    }
  }
}
