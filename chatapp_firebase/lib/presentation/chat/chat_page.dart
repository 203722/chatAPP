import 'dart:io';
import 'package:chatapp_firebase/presentation/chat/group_info.dart';
import 'package:chatapp_firebase/service/database_service.dart';
import 'package:chatapp_firebase/widgets/message_tile.dart';
import 'package:chatapp_firebase/widgets/video_widget.dart';
import 'package:chatapp_firebase/widgets/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String userName;

  const ChatPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.userName,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Stream<QuerySnapshot>? chats;
  TextEditingController messageController = TextEditingController();
  String admin = "";

  @override
  void initState() {
    getChatandAdmin();
    super.initState();
  }

  getChatandAdmin() {
    DatabaseService().getChats(widget.groupId).then((val) {
      setState(() {
        chats = val;
      });
    });
    DatabaseService().getGroupAdmin(widget.groupId).then((val) {
      setState(() {
        admin = val;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Text(widget.groupName),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            onPressed: () {
              nextScreen(
                context,
                GroupInfo(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                  adminName: admin,
                ),
              );
            },
            icon: const Icon(Icons.info),
          )
        ],
      ),
      body: Stack(
        children: <Widget>[
          // Chat messages here
          chatMessages(),
          Container(
            alignment: Alignment.bottomCenter,
            width: MediaQuery.of(context).size.width,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              width: MediaQuery.of(context).size.width,
              color: Colors.grey[700],
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Send a message...",
                        hintStyle: TextStyle(color: Colors.white, fontSize: 16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      pickAndSendMessage();
                    },
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.attach_file,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      sendMessage();
                    },
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget chatMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: chats,
      builder: (context, snapshot) {
        return snapshot.hasData
            ? ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return buildMessageTile(doc);
                },
              )
            : const Center(
                child: CircularProgressIndicator(),
              );
      },
    );
  }

  Widget buildMessageTile(DocumentSnapshot doc) {
    final isSentByMe = widget.userName == doc["sender"];
    String archivo = doc["message"];

    if (doc["message"].startsWith("https://firebasestorage.googleapis.com")) {
      if (doc["type"] == "video") {
        // Message is a video
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: VideoPlayerWidget(videoUrl: doc["message"]),
          ),
        );
      } else if (doc["type"] == "image") {
        // Message is an image
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: Image.network(doc["message"]),
          ),
        );
      } else if (doc["type"] == "audio") {
        // Message is an audio
        return MessageTile(
          message: doc["message"],
          sender: doc["sender"],
          sentByMe: isSentByMe,
        );
      }
    }

    // Message is text
    return MessageTile(
      message: doc["message"],
      sender: doc["sender"],
      sentByMe: isSentByMe,
    );
  }

  Future playAudioFromUrl(String audioUrl) async {
      AudioPlayer audioPlayer = AudioPlayer();
      audioPlayer.setUrl(audioUrl);
  }

  sendMessage() async {
    if (messageController.text.isNotEmpty) {
      Map<String, dynamic> messageMap = {
        "message": messageController.text,
        "sender": widget.userName,
        "time": DateTime.now().millisecondsSinceEpoch,
      };

      await DatabaseService().sendMessage(widget.groupId, messageMap);
      messageController.text = "";
    }
  }

  String getFileType(File file) {
  String extension = file.path.split('.').last.toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
      return 'image';
    case 'mp4':
    case 'mov':
    case 'avi':
      return 'video';
    case 'mp3':
      return 'audio';
    default:
      return 'unknown';
    }
  }

  pickAndSendMessage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'avi', 'mp3'],
    );

    if (result != null && result.files.isNotEmpty) {
      PlatformFile file = result.files.first;
      File mediaFile = File(file.path!);

      if (mediaFile.existsSync()) {
        String fileType = getFileType(mediaFile);
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference reference = FirebaseStorage.instance.ref().child('media/$fileName');

        UploadTask uploadTask = reference.putFile(mediaFile);
        TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);

        String mediaUrl = await taskSnapshot.ref.getDownloadURL();

        Map<String, dynamic> messageMap = {
          "type": fileType,
          "message": mediaUrl,
          "sender": widget.userName,
          "time": DateTime.now().millisecondsSinceEpoch,
        };

        await DatabaseService().sendMessage(widget.groupId, messageMap);
      }
    }
  }
}
