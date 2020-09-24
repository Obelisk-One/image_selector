import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_selector/image_selector.dart';

void main() {
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List _items = [];
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    print('${[
      'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2563028145.webp',
      'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2265204834.webp',
      'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2573232376.webp',
      'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p1655227895.webp',
      'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2002731234.webp',
    ]}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
        backgroundColor: Colors.white,
        brightness: Brightness.light,
      ),
      body: Center(
        child: Column(
          children: [
            RaisedButton(
              child: Text('打开相册'),
              onPressed: () async {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => CupertinoActionSheet(
                    actions: <Widget>[
                      CupertinoActionSheetAction(
                        child: Text('相机'),
                        isDefaultAction: true,
                        onPressed: () async {
                          ImageSelector.selectImages(
                            maxImage: 1,
                            camera: true,
                            selected: _items,
                          ).then((value) async {
                            if (!mounted) return;
                            setState(() {
                              _items.addAll(value);
                            });
                            print(_items);
                          });
                          Navigator.of(context).pop('delete');
                        },
                      ),
                      CupertinoActionSheetAction(
                        child: Text('去相册选择'),
                        isDefaultAction: true,
                        onPressed: () {
                          ImageSelector.selectImages(
                            maxImage: 1,
                            camera: false,
                            selected: _items,
                          ).then((value) async {
                            if (!mounted) return;
                            setState(() {
                              _items = value;
                            });
                            print(_items);
                          });
                          Navigator.of(context).pop('delete');
                        },
                      ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      child: Text('取消'),
                      onPressed: () => Navigator.of(context).pop('delete'),
                    ),
                  ),
                );
              },
            ),
            SizedBox(
              height: 10,
            ),
            RaisedButton(
              child: Text('选择头像'),
              onPressed: () async {
                ImageSelector.selectAvatar(cutRatio: 60 / 44).then((value) {
                  if (!mounted) return;
                  setState(() {
                    _avatarPath = value;
                  });
                });
              },
            ),
            SizedBox(
              height: 10,
            ),
            RaisedButton(
              child: Text('预览网图'),
              onPressed: () async {
                ImageSelector.previewWebImages(
                  0,
                  [
                    'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2563028145.webp',
                    'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2265204834.webp',
                    'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2573232376.webp',
                    'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p1655227895.webp',
                    'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2002731234.webp',
                  ],
                );
              },
            ),
            SizedBox(
              height: 10,
            ),
            _avatarPath != ''
                ? Image.file(
                    File(_avatarPath),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Container(),
            SizedBox(
              height: 10,
            ),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: _items
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        print(_items.indexOf(e));
                        print(_items);
                        ImageSelector.previewImages(_items.indexOf(e), _items);
                      },
                      child: Image.file(
                        File(e['path']),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                  .toList(),
            )
          ],
        ),
      ),
    );
  }
}
