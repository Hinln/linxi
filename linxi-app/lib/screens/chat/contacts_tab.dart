import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/chat_provider.dart';
import '../../core/models/chat_model.dart';
import 'chat_screen.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  @override
  void initState() {
    super.initState();
    // Connect socket and fetch conversations
    final chatProvider = context.read<ChatProvider>();
    chatProvider.initSocket();
    chatProvider.fetchConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: false,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingConversations && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.conversations.isEmpty) {
            return const Center(
              child: Text(
                'No conversations yet',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchConversations();
            },
            child: ListView.separated(
              itemCount: provider.conversations.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                return _buildConversationItem(context, provider.conversations[index], provider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationItem(BuildContext context, Conversation conversation, ChatProvider provider) {
    final otherUser = conversation.otherUser;
    final timeStr = conversation.lastMessageTime != null
        ? DateFormat('HH:mm').format(conversation.lastMessageTime!)
        : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              otherUser: otherUser,
            ),
          ),
        ).then((_) {
            // Refresh when back
            provider.fetchConversations();
        });
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: otherUser.avatar != null
                ? CachedNetworkImageProvider(otherUser.avatar!)
                : const NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Felix') as ImageProvider,
            backgroundColor: Colors.grey[800],
          ),
          if (conversation.unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        otherUser.nickname,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          conversation.lastMessageContent ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: conversation.unreadCount > 0 ? Colors.white : Colors.grey,
            fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      trailing: Text(
        timeStr,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }
}
