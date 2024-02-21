import 'dart:developer';

import 'package:blqapp/src/config/config.dart';
import 'package:sendbird_sdk/core/channel/base/base_channel.dart';
import 'package:sendbird_sdk/core/channel/open/open_channel.dart';

import 'package:sendbird_sdk/params/user_message_params.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart';

class ChannelManager {
  Future<void> sendMessageToChannel(String messageText) async {
    if (messageText.isEmpty) {
      return;
    }
    try {
      final channel = await OpenChannel.getChannel(ConfigFile.channelUrl);
      await channel.enter();

      final params = UserMessageParams(message: messageText);

      channel.sendUserMessage(params);
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<User> initializeSendbird() async {
    final sendbird = SendbirdSdk(appId: ConfigFile.appId);

    try {
      final user = await sendbird.connect(ConfigFile.userId,
          accessToken: ConfigFile.accessToken);

      return user;
    } catch (e) {
      log("not connected");
      return User.fromJson({});
    }
  }
}
