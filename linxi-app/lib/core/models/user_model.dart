class User {
  final String id;
  final String nickname;
  final String? avatar;
  final String verifyStatus; // 'unverified', 'pending', 'verified'
  final double coinBalance;

  User({
    required this.id,
    required this.nickname,
    this.avatar,
    this.verifyStatus = 'unverified',
    this.coinBalance = 0.0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname'] ?? 'User_${json['id']?.toString().substring(0, 4) ?? "0000"}',
      avatar: json['avatar'],
      verifyStatus: json['verifyStatus'] ?? 'unverified',
      coinBalance: (json['coinBalance'] is int) 
          ? (json['coinBalance'] as int).toDouble() 
          : (json['coinBalance'] as double? ?? 0.0),
    );
  }
}
