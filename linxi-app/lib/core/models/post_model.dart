import 'user_model.dart';

class Post {
  final String id;
  final String content;
  final List<String> images;
  final User author;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final String? address;
  final bool isLiked;

  Post({
    required this.id,
    required this.content,
    required this.images,
    required this.author,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.address,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      author: User.fromJson(json['author'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      address: json['address'],
      isLiked: json['isLiked'] ?? false,
    );
  }

  Post copyWith({
    int? likeCount,
    bool? isLiked,
  }) {
    return Post(
      id: id,
      content: content,
      images: images,
      author: author,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      viewCount: viewCount,
      address: address,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
