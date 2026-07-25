import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../core/helpers/profile_image_helper.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../data/user_app/datasources/business_posts_remote_data_source.dart';
import '../../../data/user_app/datasources/comments_remote_data_source.dart';
import '../../../injection_container.dart';
import '../../../app_router.dart';
import '../home/comments_bottom_sheet.dart';

class PostDetailsPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic>? initialPostData;

  const PostDetailsPage({
    super.key,
    required this.postId,
    this.initialPostData,
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  Map<String, dynamic>? _postData;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isLiked = false;
  int _likesCount = 0;
  bool _isLikeLoading = false;
  int _commentsCount = 0;

  List<Map<String, dynamic>> _inlineComments = [];
  bool _isLoadingComments = false;
  final TextEditingController _commentInputController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isPostingComment = false;

  String? _editingCommentId;
  String? _replyingToCommentId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    if (widget.initialPostData != null && widget.initialPostData!.isNotEmpty) {
      _postData = widget.initialPostData;
      _isLoading = false;
      _extractData();
    } else {
      _fetchPost();
    }
  }

  @override
  void dispose() {
    _commentInputController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPost() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dataSource = sl<BusinessPostsRemoteDataSource>();
      final result = await dataSource.getPostById(widget.postId);

      if (!mounted) return;

      if (result.isNotEmpty) {
        setState(() {
          _postData = result;
          _isLoading = false;
        });
        _extractData();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Post not found or has been removed.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load post. Please try again.';
      });
    }
  }

  void _extractData() {
    if (_postData == null) return;
    final map = _postData!;
    final likes = _firstInt(map, const ['likes', 'likesCount', 'likeCount', 'totalLikes']) ?? 0;
    final comments = _firstInt(map, const ['comments', 'commentsCount', 'commentCount', 'totalComments']) ?? 0;
    final rawLiked = BusinessPostsRemoteDataSource.extractIsLikedFromMap(map);
    final isLocallyLiked = widget.postId.isNotEmpty
        ? sl<UserSessionManager>().isPostLikedLocally(widget.postId)
        : false;

    setState(() {
      _likesCount = likes;
      _commentsCount = comments;
      _isLiked = rawLiked ?? isLocallyLiked;
    });

    if (widget.postId.isNotEmpty) {
      sl<BusinessPostsRemoteDataSource>().getPostLikesDetails(widget.postId).then((freshResult) {
        if (mounted && freshResult.count >= 0) {
          setState(() {
            _likesCount = freshResult.count;
            if (freshResult.isLiked != null) {
              _isLiked = freshResult.isLiked!;
              if (freshResult.isLiked!) {
                sl<UserSessionManager>().saveLikedPostId(widget.postId);
              } else {
                sl<UserSessionManager>().removeLikedPostId(widget.postId);
              }
            }
          });
        }
      }).catchError((_) {});

      _fetchInlineComments();
    }
  }

  Future<void> _fetchInlineComments() async {
    if (widget.postId.isEmpty) return;
    setState(() {
      _isLoadingComments = true;
    });

    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      final comments = await dataSource.getComments(widget.postId, pageNumber: 1, pageSize: 50);
      if (mounted) {
        setState(() {
          _inlineComments = comments;
          _commentsCount = comments.length > _commentsCount ? comments.length : _commentsCount;
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  String? _extractParentId(Map<String, dynamic> comment) {
    final parent = comment['parentCommentId'] ?? comment['parentId'] ?? comment['replyToId'];
    if (parent != null && parent.toString().trim().isNotEmpty && parent.toString().trim() != 'null') {
      return parent.toString().trim();
    }
    return null;
  }

  String _extractCommentId(Map<String, dynamic> comment) {
    final id = comment['id'] ?? comment['commentId'] ?? comment['_id'];
    return (id ?? '').toString().trim();
  }

  List<Map<String, dynamic>> get _topLevelComments =>
      _inlineComments.where((c) => _extractParentId(c) == null).toList();

  List<Map<String, dynamic>> _repliesFor(String parentId) =>
      _inlineComments.where((c) => _extractParentId(c) == parentId).toList();

  void _startReply(Map<String, dynamic> comment) {
    final commentId = _extractCommentId(comment);
    final name = _extractCommentAuthor(comment);
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToName = name;
      _editingCommentId = null;
    });
    _commentFocusNode.requestFocus();
  }

  void _startEdit(Map<String, dynamic> comment) {
    final content = _firstString(comment, const ['content', 'text', 'message']);
    final commentId = _extractCommentId(comment);
    setState(() {
      _editingCommentId = commentId;
      _replyingToCommentId = null;
      _replyingToName = null;
    });
    _commentInputController.text = content;
    _commentInputController.selection = TextSelection.fromPosition(
      TextPosition(offset: content.length),
    );
    _commentFocusNode.requestFocus();
  }

  void _cancelReplyOrEdit() {
    setState(() {
      _editingCommentId = null;
      _replyingToCommentId = null;
      _replyingToName = null;
    });
    _commentInputController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _submitInlineComment() async {
    final text = _commentInputController.text.trim();
    if (text.isEmpty || widget.postId.isEmpty || _isPostingComment) return;

    if (_editingCommentId != null) {
      await _submitEdit(text);
      return;
    }

    setState(() {
      _isPostingComment = true;
    });

    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      final newComment = await dataSource.addComment(
        postId: widget.postId,
        content: text,
        parentCommentId: _replyingToCommentId,
      );

      if (!mounted) return;

      _commentInputController.clear();
      FocusScope.of(context).unfocus();

      final currentUser = sl<UserSessionManager>().getUser();
      final realName = currentUser?.name.trim() ?? '';
      final realImage = ProfileImageHelper.resolve(currentUser?.profileImagePath);
      final realId = currentUser?.id.trim() ?? '';

      final commentUser = newComment['user'];
      final hasUserObj = commentUser is Map && commentUser.isNotEmpty;

      final localComment = {
        if (newComment.isNotEmpty) ...newComment,
        if (newComment['id'] == null) 'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': text,
        if (newComment['createdAt'] == null) 'createdAt': DateTime.now().toIso8601String(),
        if (_replyingToCommentId != null) 'parentCommentId': _replyingToCommentId,
        'user': {
          if (hasUserObj) ...Map<String, dynamic>.from(commentUser),
          'id': realId,
          if (realName.isNotEmpty) 'name': realName,
          if (realImage.isNotEmpty) 'avatar': realImage,
        },
      };

      setState(() {
        _inlineComments.add(localComment);
        _commentsCount += 1;
        _isPostingComment = false;
        _replyingToCommentId = null;
        _replyingToName = null;
      });

      _fetchInlineComments();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPostingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post comment. Please try again.')),
      );
    }
  }

  Future<void> _submitEdit(String newText) async {
    if (_editingCommentId == null) return;
    setState(() => _isPostingComment = true);

    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      await dataSource.updateComment(
        commentId: _editingCommentId!,
        content: newText,
      );

      if (!mounted) return;

      setState(() {
        final idx = _inlineComments.indexWhere((c) => _extractCommentId(c) == _editingCommentId);
        if (idx != -1) {
          _inlineComments[idx] = {
            ..._inlineComments[idx],
            'content': newText,
            'text': newText,
          };
        }
        _editingCommentId = null;
        _isPostingComment = false;
      });

      _commentInputController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _editingCommentId = null;
        _isPostingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update comment: $e')),
      );
    }
  }

  void _confirmDeleteComment(String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Comment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteComment(commentId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final dataSource = sl<CommentsRemoteDataSource>();
      await dataSource.deleteComment(commentId);

      if (!mounted) return;

      setState(() {
        _inlineComments.removeWhere(
          (c) => _extractCommentId(c) == commentId || _extractParentId(c) == commentId,
        );
        _commentsCount = _inlineComments.length;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  void _showCommentActions(Map<String, dynamic> comment) {
    final commentId = _extractCommentId(comment);
    final isOwn = _isOwnComment(comment);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFFFF641A)),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(comment);
              },
            ),
            if (isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Comment'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Comment', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteComment(commentId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_isLikeLoading || widget.postId.isEmpty) return;

    final previousLiked = _isLiked;
    final previousCount = _likesCount;

    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    if (_isLiked) {
      sl<UserSessionManager>().saveLikedPostId(widget.postId);
    } else {
      sl<UserSessionManager>().removeLikedPostId(widget.postId);
    }

    try {
      final postTitle = _firstString(_postData ?? {}, const ['title', 'name', 'content']);
      final result = await sl<BusinessPostsRemoteDataSource>().toggleLike(widget.postId, title: postTitle);
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
          if (result.count >= 0) {
            _likesCount = result.count;
          }
          if (result.isLiked != null) {
            _isLiked = result.isLiked!;
            if (result.isLiked!) {
              sl<UserSessionManager>().saveLikedPostId(widget.postId);
            } else {
              sl<UserSessionManager>().removeLikedPostId(widget.postId);
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = previousLiked;
          _likesCount = previousCount;
          _isLikeLoading = false;
        });
        if (_isLiked) {
          sl<UserSessionManager>().saveLikedPostId(widget.postId);
        } else {
          sl<UserSessionManager>().removeLikedPostId(widget.postId);
        }
      }
    }
  }

  Future<void> _sharePost() async {
    final title = _firstString(_postData ?? {}, const ['title', 'name', 'placeName', 'authorName']);
    final text = _firstString(_postData ?? {}, const ['text', 'content', 'message', 'description', 'body']);
    final deepLink = 'hayy://post/${widget.postId}';

    final shareText = [
      if (title.isNotEmpty) title,
      if (text.isNotEmpty) text,
      deepLink,
    ].join('\n\n');

    await Share.share(shareText, subject: title.isNotEmpty ? title : 'HAYY Post');
  }

  void _openCommentsSheet() {
    CommentsBottomSheet.show(
      context,
      widget.postId,
      onCommentAdded: () {
        _fetchInlineComments();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final popResult = {
      'postId': widget.postId,
      'isLiked': _isLiked,
      'likesCount': _likesCount,
      'commentsCount': _commentsCount,
    };

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F8),
        body: Column(
          children: [
            ThemedTopHeader(
              title: 'Post Details',
              showBackButton: true,
              onBackPressed: () => Navigator.pop(context, popResult),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF641A),
        ),
      );
    }

    if (_errorMessage != null || _postData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              CustomButton(
                onPressed: _fetchPost,
                text: 'Retry',
                width: 140,
              ),
            ],
          ),
        ),
      );
    }

    final post = _postData!;

    final placeId = _firstString(post, const ['placeId', 'place_id', 'businessId', 'ownerId']);
    final authorName = _firstString(post, const ['name', 'authorName', 'placeName', 'title', 'businessName'], fallback: 'Place');
    final avatarUrl = _extractAvatarUrl(post);
    final timeText = _formatRelativeTime(
        _firstString(post, const ['time', 'createdAt', 'date', 'createdDate'], fallback: ''));
    final contentText = _firstString(post, const ['text', 'content', 'message', 'description', 'body']);
    final postImageUrl = ImageUrlFormatter.extractFromMap(post);
    final currentUserAvatar = sl<UserSessionManager>().getUser()?.profileImagePath ?? '';
    final topComments = _topLevelComments;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Post Card ───────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Author / Place Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToPlace(placeId),
                        child: ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  width: 46,
                                  height: 46,
                                  cacheWidth: 120,
                                  cacheHeight: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                                )
                              : _buildAvatarFallback(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToPlace(placeId),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorName,
                                style: const TextStyle(
                                  color: Color(0xFF1E1E1E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timeText,
                                style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (placeId.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _navigateToPlace(placeId),
                          icon: const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFFFF641A)),
                          label: const Text(
                            'View Place',
                            style: TextStyle(
                              color: Color(0xFFFF641A),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF2EC),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

                // Post Content Text
                if (contentText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      contentText,
                      style: const TextStyle(
                        color: Color(0xFF2C2C2C),
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                // Post Image (Auto aspect ratio)
                if (postImageUrl.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        postImageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF641A),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

                // Post Actions (Like, Comment, Share)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Like Button
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _toggleLike,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isLiked ? const Color(0xFFE53935) : const Color(0xFF757575),
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_likesCount',
                                style: TextStyle(
                                  color: _isLiked ? const Color(0xFFE53935) : const Color(0xFF757575),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Comments Button
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _openCommentsSheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.mode_comment_outlined,
                                color: Color(0xFF757575),
                                size: 21,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_commentsCount',
                                style: const TextStyle(
                                  color: Color(0xFF757575),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Share Button
                      IconButton(
                        onPressed: _sharePost,
                        icon: const Icon(Icons.share_outlined, color: Color(0xFF757575), size: 22),
                        tooltip: 'Share',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Comments Section Header ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 20, color: Color(0xFFFF641A)),
                  const SizedBox(width: 8),
                  Text(
                    'Comments ($_commentsCount)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _openCommentsSheet,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF641A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Comments List / Input Container ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Replying / Editing banner indicator
                if (_editingCommentId != null || _replyingToCommentId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD4C0)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _editingCommentId != null ? Icons.edit : Icons.reply,
                          size: 16,
                          color: const Color(0xFFFF641A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _editingCommentId != null
                                ? 'Editing your comment'
                                : 'Replying to ${_replyingToName ?? "user"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF641A),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelReplyOrEdit,
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                // Quick comment input box with user avatar
                Row(
                  children: [
                    _buildUserAvatarWidget(currentUserAvatar, 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _commentInputController,
                          focusNode: _commentFocusNode,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: _editingCommentId != null
                                ? 'Edit comment...'
                                : _replyingToCommentId != null
                                    ? 'Write a reply...'
                                    : 'Add a comment...',
                            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _submitInlineComment(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isPostingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF641A)),
                          )
                        : IconButton(
                            onPressed: _submitInlineComment,
                            icon: Icon(
                              _editingCommentId != null ? Icons.check_circle_rounded : Icons.send_rounded,
                              color: const Color(0xFFFF641A),
                              size: 20,
                            ),
                            tooltip: _editingCommentId != null ? 'Save' : 'Send',
                          ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
                const SizedBox(height: 12),

                // Inline Comments list preview
                if (_isLoadingComments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF641A)),
                      ),
                    ),
                  )
                else if (topComments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No comments yet. Be the first to comment!',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topComments.length > 5 ? 5 : topComments.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFF5F5F5)),
                    ),
                    itemBuilder: (context, index) {
                      return _buildCommentTile(topComments[index]);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment, {bool isReply = false}) {
    final commentId = _extractCommentId(comment);
    final name = _extractCommentAuthor(comment);
    final content = _firstString(comment, const ['content', 'text', 'message']);
    final avatar = _extractCommentAvatar(comment);
    final isOwn = _isOwnComment(comment);
    final replies = _repliesFor(commentId);

    return InkWell(
      onLongPress: () => _showCommentActions(comment),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.only(left: isReply ? 24 : 0, top: 4, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserAvatarWidget(avatar, isReply ? 26 : 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: isReply ? 12 : 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          if (isOwn)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _startEdit(comment),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.edit_outlined, size: 15, color: Colors.grey),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _confirmDeleteComment(commentId),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF444444),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _startReply(comment),
                        child: const Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF641A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (replies.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...replies.map((reply) => _buildCommentTile(reply, isReply: true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      width: 46,
      height: 46,
      color: const Color(0xFFFFEADF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_rounded,
        color: Color(0xFFFF641A),
        size: 24,
      ),
    );
  }

  Widget _buildUserAvatarWidget(String avatar, double size) {
    final resolved = ProfileImageHelper.resolve(avatar.trim());
    final isNetwork = resolved.startsWith('http://') || resolved.startsWith('https://');
    final localPath = ProfileImageHelper.resolveLocalPath(resolved);
    final isLocal = !isNetwork && localPath.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image.network(
                resolved,
                cacheWidth: 120,
                cacheHeight: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildUserAvatarFallback(size),
              )
            : isLocal
                ? Image.file(
                    File(localPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildUserAvatarFallback(size),
                  )
                : _buildUserAvatarFallback(size),
      ),
    );
  }

  Widget _buildUserAvatarFallback(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        color: Colors.grey,
        size: size * 0.55,
      ),
    );
  }

  void _navigateToPlace(String placeId) {
    if (placeId.isEmpty) return;
    Navigator.pushNamed(
      context,
      AppRoutes.placeDetails,
      arguments: placeId,
    );
  }

  String _extractCommentAuthor(Map<String, dynamic> comment) {
    final user = comment['user'] ?? comment['author'];
    if (user is Map) {
      final name = user['name'] ?? user['userName'] ?? user['fullName'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString().trim();
      }
    }
    return _firstString(comment, const ['userName', 'authorName', 'name'], fallback: 'User');
  }

  String _extractCommentAvatar(Map<String, dynamic> comment) {
    final user = comment['user'] ?? comment['author'];
    String avatar = '';
    if (user is Map) {
      avatar = (user['avatar'] ??
              user['profileImage'] ??
              user['imageUrl'] ??
              user['profileImageUrl'] ??
              user['profilePicture'] ??
              user['picture'] ??
              user['photo'] ??
              user['image'] ??
              '')
          .toString()
          .trim();
    }
    if (avatar.isEmpty) {
      avatar = _firstString(comment, const [
        'userAvatar',
        'authorAvatar',
        'userProfileImage',
        'userImage',
        'profileImage',
        'avatar'
      ]);
    }

    final resolved = ProfileImageHelper.resolve(avatar);
    if (resolved.isNotEmpty) {
      return resolved;
    }

    if (_isOwnComment(comment)) {
      final currentUserImage = sl<UserSessionManager>().getUser()?.profileImagePath;
      final resolvedSessionImage = ProfileImageHelper.resolve(currentUserImage);
      if (resolvedSessionImage.isNotEmpty) {
        return resolvedSessionImage;
      }
    }

    return avatar;
  }

  bool _isOwnComment(Map<String, dynamic> comment) {
    final currentUserId = sl<UserSessionManager>().getUser()?.id.trim() ?? '';
    if (currentUserId.isEmpty) return false;

    final user = comment['user'] ?? comment['author'];
    String uId = '';
    if (user is Map) {
      uId = (user['id'] ?? user['userId'] ?? '').toString().trim();
    }
    if (uId.isEmpty) {
      uId = (comment['userId'] ?? comment['authorId'] ?? '').toString().trim();
    }
    return uId.isNotEmpty && uId.toLowerCase() == currentUserId.toLowerCase();
  }

  String _firstString(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty && value.toString().trim() != 'null') {
        return value.toString().trim();
      }
    }
    for (final nestedKey in ['place', 'business', 'author', 'user', 'data']) {
      final nested = map[nestedKey];
      if (nested is Map) {
        final nMap = Map<String, dynamic>.from(nested);
        for (final key in keys) {
          final value = nMap[key];
          if (value != null && value.toString().trim().isNotEmpty && value.toString().trim() != 'null') {
            return value.toString().trim();
          }
        }
      }
    }
    return fallback;
  }

  int? _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        final p = int.tryParse(val.trim());
        if (p != null) return p;
      }
    }
    return null;
  }

  String _extractAvatarUrl(Map<String, dynamic> map) {
    for (final nestedKey in ['place', 'business', 'author', 'user', 'publisher']) {
      final nested = map[nestedKey];
      if (nested is Map) {
        final nMap = Map<String, dynamic>.from(nested);

        // Ensure the avatar exactly matches the cover/main image extracted in PlaceDetailsPage!
        final placeImg = ImageUrlFormatter.extractFromMap(nMap);
        if (placeImg.isNotEmpty) return placeImg;

        for (final key in [
          'CoverImage', 'coverImage', 'cover_image', 'Cover', 'cover', 'coverPath', 'coverUrl',
          'avatar', 'logo', 'photo', 'image', 'imageUrl'
        ]) {
          final val = nMap[key];
          if (val != null && val.toString().trim().isNotEmpty && val.toString().trim() != 'null') {
            return ImageUrlFormatter.format(val);
          }
        }
      }
    }
    for (final key in [
      'CoverImage', 'coverImage', 'cover_image', 'Cover', 'cover', 'coverPath', 'coverUrl',
      'placeCover', 'businessCover', 'publisherCover',
      'avatar', 'authorAvatar', 'placeAvatar', 'logo', 'profilePicture', 'photo'
    ]) {
      final val = map[key];
      if (val != null && val.toString().trim().isNotEmpty && val.toString().trim() != 'null') {
        return ImageUrlFormatter.format(val);
      }
    }
    return '';
  }
  // ── Relative-time helpers ─────────────────────────────────────────────────

  DateTime? _parseDateTimeUtc(String text) {
    if (text.isEmpty) return null;
    final hasTimezone =
        text.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
    if (hasTimezone) return DateTime.tryParse(text);
    String normalized = text.trim();
    if (normalized.contains(' ')) normalized = normalized.replaceAll(' ', 'T');
    if (normalized.contains(':')) normalized = '${normalized}Z';
    return DateTime.tryParse(normalized) ?? DateTime.tryParse(text);
  }

  String _formatRelativeTime(String raw) {
    if (raw.isEmpty) return 'Recently';
    final parsed = _parseDateTimeUtc(raw);
    if (parsed == null) return raw;
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? "min" : "mins"} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? "hour" : "hours"} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d ${d == 1 ? "day" : "days"} ago';
    }
    if (diff.inDays < 30) {
      final w = (diff.inDays / 7).floor();
      return '$w ${w == 1 ? "week" : "weeks"} ago';
    }
    if (diff.inDays < 365) {
      final mo = (diff.inDays / 30).floor();
      return '$mo ${mo == 1 ? "month" : "months"} ago';
    }
    final yr = (diff.inDays / 365).floor();
    return '$yr ${yr == 1 ? "year" : "years"} ago';
  }
}
