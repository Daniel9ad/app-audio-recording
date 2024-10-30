import 'dart:async';
import 'dart:io';

import 'package:app_audio_recording/audio_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio recording',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final _record = Record();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final TextEditingController _controller = TextEditingController();

  Timer? _timer;
  int _time = 0;
  bool _isRecording = true;
  String? _audioPath;

  @override
  void initState() {
    requestPermission();
    super.initState();
  }

  requestPermission () async {
    if (!kIsWeb){
      bool permissionStatus = await _audioQuery.permissionsRequest();
      if (!permissionStatus){
        await _audioQuery.permissionsRequest();
      }
      setState(() {});
    }
  }

  void _startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      setState(() {
        _time++;
      });
    });
  }

  Future<void> _start () async {
    try {
      if (await _record.hasPermission()) {
        Directory? dir;
        if (Platform.isIOS){
          dir = await getApplicationDocumentsDirectory();
        } else {
          dir = Directory('/storage/emulated/0/Download/');
          if (!await dir.exists()) dir = (await getExternalStorageDirectory());
        }
        await _record.start(path: '${dir?.path}${_controller.text}.aac');
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _stop () async {
    final path = await _record.stop();
    _audioPath = path;
    if (_audioPath?.isNotEmpty ?? false){
      print(path ?? '');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _record.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 520,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton(
                    // icon: Image.asset(
                    //   'assets/microphone.png',
                    // ),
                    icon: const Icon(Icons.record_voice_over),
                    onPressed: () {
                      if (_isRecording){
                        showDialog(
                          context: context, 
                          builder: (context) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  height: 150,
                                  width: 350,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15)
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.all(20),
                                        height: 50,
                                        child: Material(
                                          child: TextField(
                                            controller: _controller,
                                            textAlignVertical: TextAlignVertical.center,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.all(12)
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 20, right: 20),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.pop(context);
                                                if (_controller.text.isNotEmpty){
                                                  _startTimer();
                                                  _start();
                                                  setState(() {
                                                    _isRecording = false;
                                                  });
                                                }
                                              },
                                              child: Container(
                                                height: 40,
                                                width: 80,
                                                color: Colors.blue,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Save',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                    decoration: TextDecoration.none
                                                  )
                                                ),
                                              ),
                                            ),
                                          ]
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ],
                            );
                          }
                        );
                      } else {
                        _stop();
                        _timer?.cancel();
                        setState(() {
                          _isRecording = true;
                          _time = 0;
                        });
                      }
                    },
                  ),
                ),
                Text(
                  formattedTime(timeInSecond: _time),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 55,
                    color: Colors.blue
                  )
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height - 550,
            child: FutureBuilder<List<SongModel>>(
              future: _audioQuery.querySongs(
                sortType: null,
                orderType: OrderType.ASC_OR_SMALLER,
                uriType: UriType.EXTERNAL,
                ignoreCase: true,
              ),
              builder: (context, item){
                if (item.data == null) return const CircularProgressIndicator();
                if (item.data!.isEmpty) return const Text('Nothing found:');
                final data = item.data?.where((item) => item.fileExtension == "aac").toList() ?? [];
                return Stack(
                  alignment: AlignmentDirectional.bottomEnd,
                  children: [
                    ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return AudioItem(
                          item: data[index],
                        );
                      }
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

String formattedTime({required int timeInSecond}){
  int sec = timeInSecond % 60;
  int min = (timeInSecond / 60).floor();
  String minute = min.toString().length <= 1 ? '0$min' : '$min';
  String seconds= sec.toString().length <= 1 ? '0$sec' : '$sec';
  return '$minute:$seconds';
}
