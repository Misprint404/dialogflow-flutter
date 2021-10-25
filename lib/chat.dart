import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:dialogflow_grpc/dialogflow_grpc.dart';
import 'package:dialogflow_grpc/generated/google/cloud/dialogflow/v2beta1/session.pb.dart';
// TODO import Dialogflow

class Chat extends StatefulWidget {
  const Chat({Key? key}) : super(key: key);

  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;

  final RecorderStream _recorder = RecorderStream();
  late StreamSubscription _recorderStatus;
  late StreamSubscription<List<int>> _audioStreamSubscription;
  late BehaviorSubject<List<int>> _audioStream;

  // TODO DialogflowGrpc class instance
  late DialogflowGrpcV2Beta1 dialogflow;

  @override
  void initState() {
    super.initState();
    initPlugin();
  }

  @override
  void dispose() {
    _recorderStatus.cancel();
    _audioStreamSubscription.cancel();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlugin() async {
    _recorderStatus = _recorder.status.listen((status) {
      if (mounted) {
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
      }
    });

    try {
      await Future.wait([_recorder.initialize()]);
    } catch (e) {
      print("Error in initPlugin");
    }

    // TODO Get a Service account
    final serviceAccount = ServiceAccount.fromString(
        (await rootBundle.loadString('assets/credentials.json')));
    print(serviceAccount);
    // Create a DialogflowGrpc Instance
    dialogflow = DialogflowGrpcV2Beta1.viaServiceAccount(serviceAccount);
    print(dialogflow);
  }

  void stopStream() async {
    await _recorder.stop();
    await _audioStreamSubscription.cancel();
    await _audioStream.close();
  }

  void handleSubmitted2(String text) async {
    _messages.insert(0, ChatMessage(text: text, name: "Sabir", type: true));
    try {
      var data = await dialogflow.detectIntent(text, 'en-US');
      String fulfillmentText = data.queryResult.fulfillmentText;
      print(fulfillmentText);
    } catch (e) {
      print("Error at 81");
      print(e);
    }
    setState(() {
      _messages.insert(0, ChatMessage(text: text, name: "Bot", type: false));
      _textController.clear();
    });
  }

  void handleSubmitted(text) async {
    if (text.toString().isEmpty) return;
    print(text);
    _textController.clear();

    //TODO Dialogflow Code
    ChatMessage message = ChatMessage(
      text: text,
      name: "Sabir",
      type: true,
    );

    setState(() {
      _messages.insert(0, message);
    });
    try {
      DetectIntentResponse data = await dialogflow.detectIntent(text, 'en-US');
      String fulfillmentText = "";
      if (data.hasQueryResult()) {
        fulfillmentText = data.queryResult.fulfillmentText;
      } else {
        fulfillmentText = "Oops!!";
      }
      print("Line 115 $fulfillmentText");
      await dialogflow
          .detectIntent(text, "en-US")
          .then((value) => fulfillmentText = value.queryResult.fulfillmentText);
      if (fulfillmentText.isNotEmpty) {
        ChatMessage botMessage = ChatMessage(
          text: fulfillmentText,
          name: "Bot",
          type: false,
        );

        setState(() {
          _messages.insert(0, botMessage);
          Future.delayed(const Duration(seconds: 1));
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  void handleStream() async {
    _recorder.start();

    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((data) {
      print(" line 130");
      print(data);
      _audioStream.add(data);
    });

    // TODO Create SpeechContexts
    var biasList = SpeechContextV2Beta1(phrases: [
      'Dialogflow CX',
      'Dialogflow Essentials',
      'Action Builder',
      'HIPAA'
    ], boost: 20.0);

    // See: https://cloud.google.com/dialogflow/es/docs/reference/rpc/google.cloud.dialogflow.v2#google.cloud.dialogflow.v2.InputAudioConfig
    // Create an audio InputConfig
    var config = InputConfigV2beta1(
        encoding: 'AUDIO_ENCODING_LINEAR_16',
        languageCode: 'en-US',
        sampleRateHertz: 16000,
        singleUtterance: false,
        speechContexts: [biasList]);
    // TODO Make the streamingDetectIntent call, with the InputConfig and the audioStream
    final responseStream =
        dialogflow.streamingDetectIntent(config, _audioStream);
    // TODO Get the transcript and detectedIntent and show on screen
    responseStream.listen((data) {
      print('----');
      setState(() {
        print("Printing the data $data");
        // print(data);
        String transcript = data.recognitionResult.transcript;
        String queryText = data.queryResult.queryText;
        String fulfillmentText = data.queryResult.fulfillmentText;

        if (fulfillmentText.isNotEmpty) {
          ChatMessage message = ChatMessage(
            text: queryText,
            name: "Sabir",
            type: true,
          );

          ChatMessage botMessage = ChatMessage(
            text: fulfillmentText,
            name: "Bot",
            type: false,
          );

          _messages.insert(0, message);
          _textController.clear();
          _messages.insert(0, botMessage);
        }
        if (transcript.isNotEmpty) {
          _textController.text = transcript;
        }
      });
    }, onError: (e) {
      print("Error occured");
      print(e);
    }, onDone: () {
      print('done');
    });
  }

  // The chat interface-------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown,
      body: Column(
        children: <Widget>[
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemBuilder: (BuildContext context, int index) =>
                  _messages[index],
              itemCount: _messages.length,
            ),
          ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.all(
                Radius.circular(32),
              ),
            ),
            child: IconTheme(
              data:
                  IconThemeData(color: Theme.of(context).colorScheme.secondary),
              child: Container(
                padding: const EdgeInsets.only(left: 8.0),
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: TextField(
                        //minLines: 5,
                        //expands: true,
                        keyboardType: TextInputType.text,
                        controller: _textController,
                        onSubmitted: handleSubmitted,
                        decoration: const InputDecoration.collapsed(
                            hintText: "Send a message"),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => handleSubmitted(_textController.text),
                      ),
                    ),
                    IconButton(
                      iconSize: 30.0,
                      icon: Icon(_isRecording ? Icons.mic_off : Icons.mic),
                      onPressed: _isRecording ? stopStream : handleStream,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The chat message balloon
class ChatMessage extends StatelessWidget {
  ChatMessage({required this.text, required this.name, required this.type});

  final String text;
  final String name;
  final bool type;

  List<Widget> otherMessage(context) {
    return <Widget>[
      Container(
        margin: const EdgeInsets.only(right: 16.0),
        child: const CircleAvatar(child: Text('B')),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Container(
              width: 260.0,
              color: Colors.teal,
              margin: const EdgeInsets.only(top: 0.0),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 18.0,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> myMessage(context) {
    return <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(name, style: Theme.of(context).textTheme.subtitle1),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16.0)),
              child: Container(
                width: 260.0,
                color: Colors.white38,
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                margin: const EdgeInsets.only(top: 5.0),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(left: 8.0),
        child: CircleAvatar(
            child: Text(
          name[0],
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: type ? myMessage(context) : otherMessage(context),
      ),
    );
  }
}
