import 'dart:developer';

import 'package:blqapp/src/config/config.dart';
import 'package:blqapp/src/data/channel.crate.dart';
import 'package:flutter/material.dart';
import 'package:sendbird_sdk/core/channel/open/open_channel.dart';

import 'package:sendbird_sdk/sendbird_sdk.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChannelManager messagingClass = ChannelManager();
  final textEditingController = TextEditingController();

  OpenChannel? openChannel;
  late PreviousMessageListQuery query;

  bool isLoading = false;

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
  }

  Future<void> _initializeChat() async {
    OpenChannel.getChannel(ConfigFile.channelUrl).then((openChannel) {
      this.openChannel = openChannel;
      openChannel.enter().then((_) => _initialize());
    }).catchError((error) {
      setState(() {
        errorMessage = "Error connecting to channel: $error";
      });
    });
  }

  void _initialize() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      log("step 1");
      openChannel = await OpenChannel.getChannel(ConfigFile.channelUrl);
      query = PreviousMessageListQuery(
        channelType: ChannelType.open,
        channelUrl: ConfigFile.channelUrl,
      );
      log("step 2");

      while (query.hasNext) {
        final nextMessages = await query.loadNext();
        log("step 3");
        setState(() {
          messageList.addAll(nextMessages);
          isLoading = false;
        });

        log("step 4");
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
          title: const Text('Chat'),
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
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : messageList.isNotEmpty
                    ? _list()
                    : Container(
                        child: Text(openChannel?.name ?? "No messages"),
                      ),
        bottomNavigationBar: Row(
          children: [
            _buildAddIconButton(),
            _buildExpandedTextField(),
          ],
        ));
  }

  Widget _buildAddIconButton() {
    return IconButton(
      icon: const Icon(Icons.add),
      onPressed: () {},
    );
  }

  Widget _buildExpandedTextField() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: textEditingController,
          decoration: _buildInputDecoration(),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      hintText: 'Type a message',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(48),
        borderSide: const BorderSide(
          color: Color(0xFF323232),
        ),
      ),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      suffixIcon: _buildSuffixIconButton(),
    );
  }

  Widget _buildSuffixIconButton() {
    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10),
      width: 0,
      height: 0,
      padding: const EdgeInsets.all(1.0),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xffFF006A),
      ),
      child: IconButton(
        padding: const EdgeInsets.all(0),
        icon: const Icon(Icons.arrow_upward),
        color: Colors.black,
        onPressed: () {
          if (textEditingController.value.text.isEmpty) {
            return;
          }

          messagingClass.sendMessageToChannel(textEditingController.value.text);

          textEditingController.clear();
        },
      ),
    );
  }

  Widget _list() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: messageList.length,
      itemBuilder: (BuildContext context, int index) {
        if (index >= messageList.length) return Container();

        BaseMessage message = messageList[index];

        return GestureDetector(
          onDoubleTap: () async {
            final openChannel =
                await OpenChannel.getChannel(ConfigFile.channelUrl);
            Navigator.of(context)
                .pushNamed(
              '/message/update/${openChannel.channelType.toString()}/${openChannel.channelUrl}/${message.messageId}',
            )
                .then((message) async {
              if (message != null) {
                for (int index = 0; index < messageList.length; index++) {
                  if (messageList[index].messageId == message) {
                    // setState(() => messageList[index] = message.messageId);
                    break;
                  }
                }
              }
            });
          },
          onLongPress: () async {
            final openChannel =
                await OpenChannel.getChannel(ConfigFile.channelUrl);
            await openChannel.deleteMessage(message.messageId);
            setState(() {
              messageList.remove(message);
              title = '${openChannel.name} (${messageList.length})';
            });
          },
          child: Column(
            children: [
              ListTile(
                title: Text(
                  message.message,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    //todo
                    //  message.sender?.profileUrl
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          message.sender?.userId ?? '',
                          style: const TextStyle(fontSize: 12.0),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 16),
                      alignment: Alignment.centerRight,
                      child: Text(
                        DateTime.fromMillisecondsSinceEpoch(message.createdAt)
                            .toString(),
                        style: const TextStyle(fontSize: 12.0),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        );
      },
    );
  }
}

// #1A1A1A
