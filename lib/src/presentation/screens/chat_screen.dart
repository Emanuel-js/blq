import 'dart:developer';

import 'package:blqapp/src/config/config.dart';
import 'package:blqapp/src/data/channel.crate.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sendbird_sdk/core/channel/open/open_channel.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:sendbird_sdk/sendbird_sdk.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChannelManager messagingClass = ChannelManager();
  final textEditingController = TextEditingController();
  final itemScrollController = ItemScrollController();
  OpenChannel? openChannel;
  late PreviousMessageListQuery query;

  bool isLoading = false;
  bool isEmptyFild = true;

  String? errorMessage;

  String title = '';
  bool hasPrevious = false;
  List<BaseMessage> messageList = [];
  int? participantCount;

  @override
  void initState() {
    super.initState();

    messagingClass.initializeSendbird().then((user) {
      if (user.connectionStatus.name.isNotEmpty) {
        _initializeChat();
      } else {
        print("Sendbird initialization failed.");
      }
    }).catchError((error) {
      print("Error during Sendbird initialization: $error");
    });
    setState(() {
      textEditingController.addListener(() {
        setState(() {
          isEmptyFild = textEditingController.text.isEmpty;
        });
      });
    });
  }

  Future<void> _initializeChat() async {
    OpenChannel.getChannel(ConfigFile.channelUrl).then((openChannel) {
      this.openChannel = openChannel;
      openChannel.enter().then((_) => initialize());
    }).catchError((error) {
      setState(() {
        errorMessage = "Error connecting to channel: $error";
      });
    });
  }

  void initialize() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      openChannel = await OpenChannel.getChannel(ConfigFile.channelUrl);
      query = PreviousMessageListQuery(
        channelType: ChannelType.open,
        channelUrl: ConfigFile.channelUrl,
      );

      while (query.hasNext) {
        final nextMessages = await query.loadNext();
        if (messageList.length < 100) {
          setState(() {
            messageList.addAll(nextMessages);
            isLoading = false;
          });
        } else {
          itemScrollController.jumpTo(index: messageList.length - 1);
          break;
        }
      }

      title = '${openChannel!.name} (${messageList.length})';
      hasPrevious = query.hasNext;
      participantCount = openChannel!.participantCount;
    } catch (error) {
      setState(() {
        errorMessage = "Error loading messages: $error";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    openChannel?.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF0E0D0D),
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () {
              // Navigator.of(context).pop();
            },
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {},
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: Row(
          children: [
            buildAddIconButton(),
            buildExpandedTextField(),
          ],
        ));
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    } else if (messageList.isNotEmpty) {
      return _buildMessageList();
    } else {
      return Center(child: Text(openChannel?.name ?? "No messages"));
    }
  }

  Widget _buildMessageList() {
    messageList.sort((b, a) => b.createdAt.compareTo(a.createdAt));
    return ScrollablePositionedList.builder(
      physics: const ClampingScrollPhysics(),
      initialScrollIndex: messageList.isEmpty ? 0 : messageList.length - 1,
      itemScrollController: itemScrollController,
      itemCount: messageList.length,
      itemBuilder: (BuildContext context, int index) {
        if (index >= messageList.length) return Container();
        return _buildMessageRow(messageList[index]);
      },
    );
  }

  Widget _buildMessageRow(BaseMessage message) {
    bool isCurrentUser = message.sender?.userId == ConfigFile.userId;
    bool isOperatorMessage = message.sender!.isActive!;

    return Row(
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isCurrentUser) buildAvatar(message.sender!),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width *
                0.7, // Adjust the percentage as needed
          ),
          decoration: BoxDecoration(
            gradient: isCurrentUser
                ? const LinearGradient(
                    colors: [
                      Color(0xffFF006B),
                      Color(0xffFF4593),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isCurrentUser ? null : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isCurrentUser ? 18 : 4),
              topRight: Radius.circular(isCurrentUser ? 4 : 18),
              bottomRight: const Radius.circular(18),
              bottomLeft: const Radius.circular(16),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser) buildSenderInfo(message, isOperatorMessage),
                Text(
                  message is UserMessage
                      ? message.message
                      : 'Unsupported message type',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isCurrentUser) buildTime(message),
      ],
    );
  }

  Widget buildAddIconButton() {
    return IconButton(
      icon: const Icon(Icons.add),
      onPressed: () {},
    );
  }

  Widget buildExpandedTextField() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: textEditingController,
          decoration: buildInputDecoration(),
          onChanged: (value) {
            isEmptyFild = value.isEmpty ? true : false;
          },
        ),
      ),
    );
  }

  InputDecoration buildInputDecoration() {
    return InputDecoration(
      hintText: '메세지 보내기',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(48),
        borderSide: const BorderSide(
          color: Color(0xFF323232),
        ),
      ),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      suffixIcon: buildSuffixIconButton(),
    );
  }

  Widget buildSuffixIconButton() {
    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10),
      width: 0,
      height: 0,
      padding: const EdgeInsets.all(1.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isEmptyFild ? const Color(0xff3A3A3A) : const Color(0xffFF006A),
      ),
      child: IconButton(
        padding: const EdgeInsets.all(0),
        icon: const Icon(Icons.arrow_upward),
        color: Colors.black,
        onPressed: () async {
          if (textEditingController.value.text.isEmpty) {
            return;
          }

          final params =
              UserMessageParams(message: textEditingController.value.text);
          try {
            final preMessage = openChannel!.sendUserMessage(params,
                onCompleted: (message, error) {
              if (error != null) {
              } else {}
            });

            textEditingController.clear();
            _addMessage(preMessage);
          } catch (e) {
            log('Error sending message: $e');
          }
        },
      ),
    );
  }

  Widget buildAvatar(Sender user) {
    // make the url different for each user
    return CircleAvatar(
      radius: 20,
      backgroundImage: NetworkImage('${ConfigFile.avatorUrl}=${user.userId}'),
    );
  }

  Widget buildSenderInfo(BaseMessage message, bool isOperatorMessage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message is UserMessage
              ? message.sender?.nickname ?? 'Unknown'
              : 'Unsupported message type',
          style: const TextStyle(
            color: Color(0xFFADADAD),
            fontSize: 14,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 8),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: !isOperatorMessage
                ? const LinearGradient(
                    colors: [Color(0xff101010), Color(0xff2F2F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [
                      Color(0xff46F9F5),
                      Color(0xff46F9F5),
                    ],
                  ),
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ],
    );
  }

  Widget buildTime(BaseMessage message) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 8,
      ),
      child: Text(
        timeago.format(
          DateTime.fromMillisecondsSinceEpoch(message.createdAt),
          locale: 'en_short',
        ),
      ),
    );
  }

  void _addMessage(BaseMessage message) {
    OpenChannel.getChannel(ConfigFile.channelUrl).then((openChannel) {
      setState(() {
        messageList.add(message);
      });

      Future.delayed(
        const Duration(milliseconds: 100),
        () => itemScrollController.jumpTo(index: messageList.length - 1),
      );
    });
  }
}
