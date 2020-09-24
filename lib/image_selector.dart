import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageSelector {
  static const MethodChannel _channel = const MethodChannel('image_selector');

  ///
  /// 选择图片
  /// camera:打开相机/打开相册
  /// needCut:是否需要裁剪
  /// maxImage:最多可选图片
  /// selected:已选图片对象数组
  ///
  static Future<List> selectImages({
    @required int maxImage,
    bool camera = false,
    bool needCut = false,
    double cutRatio = 1,
    List selected,
  }) async {
    if (maxImage <= 0)
      throw new ArgumentError.value(maxImage, 'maxImage must over zero');

    if (selected == null) selected = [];
    try {
      final List<dynamic> images = await _channel.invokeMethod(
        'selectImages',
        <String, dynamic>{
          'maxImage': maxImage,
          'camera': camera,
          'needCut': needCut,
          'cutRatio': cutRatio,
          'selected': selected,
        },
      );
      return images;
    } on PlatformException catch (e) {
      throw e;
    }
  }

  ///
  /// 选择头像
  /// camera:打开相机/打开相册
  /// needCut:是否需要裁剪
  ///
  static Future<String> selectAvatar({
    bool camera = false,
    bool needCut = true,
    double cutRatio = 1,
  }) async {
    try {
      final List<dynamic> images = await _channel.invokeMethod(
        'selectImages',
        <String, dynamic>{
          'maxImage': 1,
          'camera': camera,
          'needCut': needCut,
          'cutRatio': cutRatio,
          'selected': [],
        },
      );
      if (images != null && images.length > 0) return images[0]['path'];
      throw new PlatformException(
        code: 'EmptyList',
        message: 'No item in the result',
      );
    } on PlatformException catch (e) {
      throw e;
    }
  }

  static void previewImages(
    int position,
    List selected,
  ) {
    try {
      _channel.invokeMethod(
        'previewImages',
        <String, dynamic>{
          'position': position,
          'selected': selected,
        },
      );
    } on PlatformException catch (e) {
      throw e;
    }
  }

  static void previewWebImages(
    int position,
    List<String> urls,
  ) {
    try {
      if (urls == null || urls.length < 0)
        throw PlatformException(
          code: 'EmptyList',
          message: '请传入图片URL',
        );

      _channel.invokeMethod(
        'previewWebImages',
        <String, dynamic>{
          'position': position,
          'selected': urls,
        },
      );
    } on PlatformException catch (e) {
      throw e;
    }
  }
}
