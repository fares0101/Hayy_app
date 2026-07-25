import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/helpers/profile_image_helper.dart';
import '../../../../injection_container.dart';
import '../../../../core/storage/user_session_manager.dart';
import '../../../../data/user_app/datasources/comments_remote_data_source.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentAdded;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    this.onCommentAdded,
  });

  static void show(BuildContext context, String postId,
      {VoidCallback? onCommentAdded}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: postId,
        onCommentAdded: onCommentAdded,
      ),
    );
  }

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  // ── Reply state ───────────────────────────────────────────────────────────
  String? _replyingToCommentId;
  String? _replyingToName;

  // ── Edit state ────────────────────────────────────────────────────────────
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _extractCommentId(Map<String, dynamic> comment) =>
      _asString(comment['id'] ?? comment['commentId']);

  String _extractUserId(Map<String, dynamic> comment) {
    final user = comment['user'] ?? comment['author'];
    if (user is Map) {
      return _asString(user['id'] ?? user['userId']);
    }
    return _asString(comment['userId'] ?? comment['authorId']);
  }

  String _extractName(Map<String, dynamic> comment) {
    final user = comment['user'] ?? comment['author'];
    if (user is Map) {
      return _asString(user['name'] ?? user['userName'] ?? user['fullName']);
    }
    return _asString(comment['userName'] ?? comment['authorName']);
  }

  String _extractAvatar(Map<String, dynamic> comment) {
    final user = comment['user'] ?? comment['author'];
    String avatar = '';
    if (user is Map) {
      avatar = _asString(
        user['avatar'] ??
            user['profileImage'] ??
            user['imageUrl'] ??
            user['profileImageUrl'] ??
            user['profilePicture'] ??
            user['picture'] ??
            user['photo'] ??
            user['image'],
      );
    }
    if (avatar.isEmpty) {
      avatar = _asString(
        comment['userAvatar'] ??
            comment['authorAvatar'] ??
            comment['userProfileImage'] ??
            comment['userImage'] ??
            comment['profileImage'],
      );
    }

    final resolvedAvatar = ProfileImageHelper.resolve(avatar);
    if (resolvedAvatar.isNotEmpty) {
      return resolvedAvatar;
    }

    // If the server has no usable avatar for the logged-in user's comment,
    // fall back to the session profile image directly.
    if (_isOwnComment(comment)) {
      avatar = ProfileImageHelper.resolve(
        sl<UserSessionManager>().getUser()?.profileImagePath,
      );
    }

    return avatar;
  }

  String? _extractParentId(Map<String, dynamic> comment) {
    final raw = _asString(comment['parentCommentId'] ??
        comment['parentId'] ??
        comment['replyTo']);
    return raw.isEmpty ? null : raw;
  }

  bool _isOwnComment(Map<String, dynamic> comment) {
    final currentUserId = sl<UserSessionManager>().getUser()?.id.trim() ?? '';
    if (currentUserId.isEmpty) return false;
    return _extractUserId(comment).trim().toLowerCase() ==
        currentUserId.toLowerCase();
  }

  // ── Top-level vs replies ──────────────────────────────────────────────────

  List<Map<String, dynamic>> get _topLevelComments =>
      _comments.where((c) => _extractParentId(c) == null).toList();

  List<Map<String, dynamic>> _repliesFor(String parentId) =>
      _comments.where((c) => _extractParentId(c) == parentId).toList();

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      final comments = await dataSource.getComments(
        widget.postId,
        pageNumber: 1,
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── Post / Reply ──────────────────────────────────────────────────────────

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // If we are editing an existing comment instead of posting a new one
    if (_editingCommentId != null) {
      await _submitEdit(text);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      final newComment = await dataSource.addComment(
        postId: widget.postId,
        content: text,
        parentCommentId: _replyingToCommentId,
      );

      if (!mounted) return;

      _commentController.clear();
      FocusScope.of(context).unfocus();

      // The data source already injects the current user's name + avatar.
      // We add a local fallback here in case the response was empty.
      final currentUser = sl<UserSessionManager>().getUser();
      final realName = currentUser?.name.trim() ?? '';
      final realImage =
          ProfileImageHelper.resolve(currentUser?.profileImagePath);
      final realId = currentUser?.id.trim() ?? '';

      final commentUser = newComment['user'];
      final hasUserObj = commentUser is Map && commentUser.isNotEmpty;

      final commentToAdd = {
        // Use server response as base (may be empty on some APIs)
        if (newComment.isNotEmpty) ...newComment,
        // Ensure an 'id' exists
        if (newComment['id'] == null)
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        // Ensure 'content' is present
        'content': text,
        if (newComment['createdAt'] == null)
          'createdAt': DateTime.now().toIso8601String(),
        if (_replyingToCommentId != null)
          'parentCommentId': _replyingToCommentId,
        // Override user block to guarantee name + avatar are set
        'user': {
          if (hasUserObj) ...Map<String, dynamic>.from(commentUser),
          'id': realId,
          if (realName.isNotEmpty) 'name': realName,
          if (realImage.isNotEmpty) 'avatar': realImage,
        },
      };

      setState(() {
        _comments.add(commentToAdd);
        _isPosting = false;
        _replyingToCommentId = null;
        _replyingToName = null;
      });

      widget.onCommentAdded?.call();

      // Scroll to bottom to show new comment
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isPosting = false);
      _showError(e.response?.data?.toString() ?? e.message ?? 'Error');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPosting = false);
      _showError(e.toString());
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  void _startEdit(Map<String, dynamic> comment) {
    final content = _asString(comment['content'] ?? comment['text']);
    final commentId = _extractCommentId(comment);
    setState(() {
      _editingCommentId = commentId;
      _replyingToCommentId = null;
      _replyingToName = null;
    });
    _commentController.text = content;
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: content.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _submitEdit(String newText) async {
    if (_editingCommentId == null) return;
    setState(() => _isPosting = true);

    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      await dataSource.updateComment(
        commentId: _editingCommentId!,
        content: newText,
      );

      if (!mounted) return;

      // Update locally
      setState(() {
        final idx = _comments
            .indexWhere((c) => _extractCommentId(c) == _editingCommentId);
        if (idx != -1) {
          _comments[idx] = {
            ..._comments[idx],
            'content': newText,
            'text': newText,
          };
        }
        _editingCommentId = null;
        _isPosting = false;
      });

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _editingCommentId = null;
        _isPosting = false;
      });
      _showError('Failed to update comment: ${e.toString()}');
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _replyingToCommentId = null;
      _replyingToName = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteComment(String commentId) async {
    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      await dataSource.deleteComment(commentId);

      if (!mounted) return;

      setState(() {
        // Remove the comment and all its replies
        _comments.removeWhere(
          (c) =>
              _extractCommentId(c) == commentId ||
              _extractParentId(c) == commentId,
        );
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to delete comment: ${e.toString()}');
    }
  }

  // ── Long-press action sheet ───────────────────────────────────────────────

  void _showCommentActions(Map<String, dynamic> comment) {
    if (!_isOwnComment(comment)) return;
    final commentId = _extractCommentId(comment);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: Color(0xFF1A1A1A)),
              title: const Text(
                'Edit comment',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _startEdit(comment);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Delete comment',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.redAccent,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(commentId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text(
            'This comment and any replies to it will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteComment(commentId);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reply ─────────────────────────────────────────────────────────────────

  void _startReply(Map<String, dynamic> comment) {
    final name = _extractName(comment);
    final commentId = _extractCommentId(comment);
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToName = name.isNotEmpty ? name : 'User';
      _editingCommentId = null;
    });
    _focusNode.requestFocus();
  }

  // ── Snackbar helper ───────────────────────────────────────────────────────

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  // ── Avatar widget ─────────────────────────────────────────────────────────

  String _resolveImageUrl(String img) {
    return ProfileImageHelper.resolve(img);
  }

  Widget _buildAvatar(String avatar, double size) {
    final resolved = _resolveImageUrl(avatar.trim());
    final isNetwork =
        resolved.startsWith('http://') || resolved.startsWith('https://');
    final localPath = ProfileImageHelper.resolveLocalPath(resolved);
    final isLocal = !isNetwork && localPath.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultAvatar(size),
              )
            : isLocal
                ? Image.file(
                    File(localPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(size),
                  )
                : _defaultAvatar(size),
      ),
    );
  }

  Widget _defaultAvatar(double size) => Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: Icon(Icons.person, size: size * 0.55, color: Colors.grey),
      );

  // ── Comment bubble ────────────────────────────────────────────────────────

  Widget _buildCommentTile(Map<String, dynamic> comment,
      {bool isReply = false}) {
    final content = _asString(comment['content'] ?? comment['text']);
    final name = _extractName(comment);
    final avatar = _extractAvatar(comment);
    final isOwn = _isOwnComment(comment);
    final commentId = _extractCommentId(comment);
    final isBeingEdited = _editingCommentId == commentId;

    return GestureDetector(
      onLongPress: isOwn ? () => _showCommentActions(comment) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(
          left: isReply ? 44.0 : 0,
          bottom: isReply ? 8 : 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thread line for replies ────────────────────────────────────
            if (isReply)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Container(
                  width: 2,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

            _buildAvatar(avatar, isReply ? 28 : 36),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bubble ─────────────────────────────────────────────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isBeingEdited
                          ? const Color(0xFFFFF3EE)
                          : (isOwn
                              ? const Color(0xFFF5F5F9)
                              : const Color(0xFFF5F5F9)),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isReply ? 12 : 16),
                        topRight: const Radius.circular(16),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(4),
                      ),
                      border: isBeingEdited
                          ? Border.all(
                              color: const Color(0xFFFF641A)
                                  .withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name.isNotEmpty ? name : 'User',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            if (isOwn)
                              const Icon(Icons.more_horiz,
                                  size: 16, color: Color(0xFFAAAAAA)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF444444),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Action row ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Row(
                      children: [
                        // Reply button
                        GestureDetector(
                          onTap: () => _startReply(comment),
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF641A),
                            ),
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _startEdit(comment),
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _confirmDelete(commentId),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = _editingCommentId != null;
    final isReplying = _replyingToCommentId != null && !isEditing;
    final topComments = _topLevelComments;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82 + bottomInset,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle bar ─────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ── Comments list ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF641A),
                    ),
                  )
                : topComments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: topComments.length,
                        itemBuilder: (context, index) {
                          final comment = topComments[index];
                          final cId = _extractCommentId(comment);
                          final replies = _repliesFor(cId);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCommentTile(comment),
                              // ── Replies ────────────────────────────
                              ...replies.map(
                                (reply) =>
                                    _buildCommentTile(reply, isReply: true),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ── Replying-to / Editing indicator ────────────────────────────
          if (isReplying || isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF3EE),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_outlined : Icons.reply_rounded,
                    size: 16,
                    color: const Color(0xFFFF641A),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Editing your comment'
                          : 'Replying to $_replyingToName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFF641A),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFFFF641A),
                    ),
                  ),
                ],
              ),
            ),

          // ── Input field ─────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: bottomInset > 0
                  ? bottomInset + 12
                  : 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: isEditing
                            ? 'Edit your comment...'
                            : isReplying
                                ? 'Reply to $_replyingToName...'
                                : 'Add a comment...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isPosting ? null : _submitComment,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF641A),
                      shape: BoxShape.circle,
                    ),
                    child: _isPosting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEditing
                                ? Icons.check_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
