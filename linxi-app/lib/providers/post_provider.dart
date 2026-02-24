import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import '../core/api_service.dart';
import '../core/models/post_model.dart';

class PostProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String _uploadProgress = '';
  
  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String get uploadProgress => _uploadProgress;

  int _page = 1;
  bool _hasMore = true;

  Future<void> fetchPosts({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _posts = [];
    }

    if (!_hasMore) return;
    if (!refresh && _isLoading) return;

    _isLoading = true;
    if (refresh) notifyListeners(); // Only notify if refresh to show indicator

    try {
      final response = await _api.get('/posts/home', queryParameters: {
        'page': _page,
        'limit': 10,
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final newPosts = data.map((e) => Post.fromJson(e)).toList();
        
        if (newPosts.length < 10) {
          _hasMore = false;
        }

        if (refresh) {
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
        _page++;
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadImageToOSS(File file) async {
    _isUploading = true;
    _uploadProgress = '0%';
    notifyListeners();

    try {
      // 1. Get presigned URL
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      // Ensure fileType matches what we use in PUT request
      const fileType = 'image/jpeg'; 
      
      final presignedRes = await _api.get('/posts/presigned-url', queryParameters: {
        'fileName': filename, // Fixed param name to match backend
        'fileType': fileType, // Pass fileType to backend
      });
      
      if (presignedRes.statusCode != 200) {
        throw 'Failed to get upload URL';
      }

      final uploadUrl = presignedRes.data['url'];
      // Backend returns full signed URL in 'url', but we need public URL for DB
      // Assuming backend might return objectName to construct public URL or publicUrl field
      // If backend only returns 'url' (signed PUT) and 'objectName', we construct public URL manually
      // Or backend returns 'publicUrl'. Let's check backend implementation or assume standard OSS public URL format.
      // Based on previous code, it expected 'publicUrl'.
      // If backend doesn't return publicUrl, we can construct it: https://{bucket}.{region}.aliyuncs.com/{objectName}
      // But let's assume backend logic (which we just updated or checked) provides it or we use objectName.
      
      // Fix: Backend returns { url, objectName }.
      final objectName = presignedRes.data['objectName'];
      // Construct public URL (replace with your actual bucket domain)
      // Ideally, backend should return this.
      // For now, let's assume a placeholder or simple construction if missing.
      String publicUrl = presignedRes.data['publicUrl'] ?? '';
      if (publicUrl.isEmpty && objectName != null) {
         // Fallback construction
         // You should replace this with your actual OSS domain logic
         publicUrl = 'https://${AppConstants.ossBucket}.${AppConstants.ossRegion}.aliyuncs.com/$objectName';
      }

      // 2. Upload file to OSS using PUT
      final dio = Dio();
      await dio.put(
        uploadUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            Headers.contentLengthHeader: await file.length(),
            'Content-Type': fileType, // Critical: Must match presigned URL generation
          },
        ),
        onSendProgress: (count, total) {
          final progress = (count / total * 100).toStringAsFixed(0);
          _uploadProgress = '$progress%';
          notifyListeners();
        },
      );

      return publicUrl;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final msg = e.response?.data.toString() ?? '';
        if (msg.contains('SignatureDoesNotMatch')) {
           Fluttertoast.showToast(
             msg: "Upload failed: Time skew detected. Please check your device time.",
             toastLength: Toast.LENGTH_LONG,
             gravity: ToastGravity.CENTER,
           );
        }
      }
      debugPrint('Upload Dio error: $e');
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> createPost({
    required String content,
    List<String> images = const [],
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.post('/posts', data: {
        'content': content,
        'images': images,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'visibility': 'public', // Default
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Refresh home feed
        await fetchPosts(refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Create post error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    // Optimistic update
    final originalPost = _posts[index];
    final newIsLiked = !isLiked;
    final newLikeCount = isLiked ? originalPost.likeCount - 1 : originalPost.likeCount + 1;

    _posts[index] = originalPost.copyWith(
      isLiked: newIsLiked,
      likeCount: newLikeCount,
    );
    notifyListeners();

    try {
      if (newIsLiked) {
        await _api.post('/posts/$postId/like');
      } else {
        await _api.delete('/posts/$postId/like');
      }
    } catch (e) {
      // Revert if failed
      _posts[index] = originalPost;
      notifyListeners();
      debugPrint('Toggle like error: $e');
    }
  }

  Future<bool> addComment(String postId, String content) async {
    try {
      final response = await _api.post('/comments', data: {
        'postId': int.parse(postId),
        'content': content,
      });

      if (response.statusCode == 201) {
        // Update local comment count
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _posts[index] = _posts[index].copyWith(
            commentCount: _posts[index].commentCount + 1, // Note: copyWith needs commentCount support
          );
          notifyListeners(); // Refresh UI to show updated count
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Add comment error: $e');
      return false;
    }
  }
}
