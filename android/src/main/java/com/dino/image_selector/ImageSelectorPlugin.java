package com.dino.image_selector;

import android.app.Activity;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.provider.MediaStore;
import android.util.Log;

import androidx.annotation.NonNull;

import com.luck.picture.lib.entity.LocalMedia;

import java.io.File;
import java.io.FileDescriptor;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * ImageSelectorPlugin
 */
public class ImageSelectorPlugin implements FlutterPlugin,
        MethodCallHandler,
        ActivityAware,
        PluginRegistry.ActivityResultListener {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;
    private Activity activity;
    private Context context;
    private BinaryMessenger messenger;
    private Result pendingResult;
    private MethodCall methodCall;

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        ImageSelectorPlugin instance = new ImageSelectorPlugin();
        instance.onAttachedToEngine(registrar.context(), registrar.messenger(), registrar.activity());
        registrar.addActivityResultListener(instance);
    }

    private void onAttachedToEngine(Context applicationContext, BinaryMessenger binaryMessenger, Activity activity) {
        context = applicationContext;
        messenger = binaryMessenger;
        if (activity != null) {
            this.activity = activity;
        }
        channel = new MethodChannel(binaryMessenger, "image_selector");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
//        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "image_selector");
//        channel.setMethodCallHandler(this);
        onAttachedToEngine(flutterPluginBinding.getApplicationContext(), flutterPluginBinding.getBinaryMessenger(), null);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        context = null;
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        messenger = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding activityPluginBinding) {
        activityPluginBinding.addActivityResultListener(this);
        activity = activityPluginBinding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding activityPluginBinding) {
        activityPluginBinding.addActivityResultListener(this);
        activity = activityPluginBinding.getActivity();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (!setPendingMethodCallAndResult(call, result)) {
            finishWithAlreadyActiveError(result);
            return;
        }
        if (call.method.equals("selectImages")) {
            final int maxImage = call.argument("maxImage");
            final boolean camera = call.argument("camera");
            final boolean needCut = call.argument("needCut");
            final double cutRatio = call.argument("cutRatio");
            final ArrayList<Map<String, Object>> list = call.argument("selected");
            ArrayList<LocalMedia> selected = toLocalMedia(list);

            ImageSelector selector = new ImageSelector(maxImage, camera, needCut, cutRatio, selected, activity, new ImageSelector.SelectorCallback() {
                @Override
                public void onSuccess(ArrayList<Map<String, Object>> result) {
                    finishWithSuccess(result);
                }

                @Override
                public void onError(String code, String msg) {
                    finishWithError(code, msg);
                }
            });
            selector.selectImage();
        } else if (call.method.equals("previewImages")) {
            final int position = call.argument("position");
            final ArrayList<Map<String, Object>> list = call.argument("selected");
            ArrayList<LocalMedia> selected = toLocalMedia(list);
            ImageSelector selector = new ImageSelector(activity);
            selector.previewImages(position, selected, false);
            finishWithSuccess(null);
        } else if (call.method.equals("previewWebImages")) {
            final int position = call.argument("position");
            final List<String> list = call.argument("selected");
            ArrayList<LocalMedia> selected = new ArrayList<>();
            if (list != null && list.size() > 0) {
                for (String item : list) {
                    LocalMedia localMedia = new LocalMedia();
                    localMedia.setPath(item);
                    selected.add(localMedia);
                }
            }
            ImageSelector selector = new ImageSelector(activity);
            selector.previewImages(position, selected, true);
            finishWithSuccess(null);
        } else {
            result.notImplemented();
        }
    }

    @Override
    public boolean onActivityResult(int i, int i1, Intent intent) {
        return false;
    }

    private boolean setPendingMethodCallAndResult(
            MethodCall methodCall, MethodChannel.Result result) {
        if (pendingResult != null) {
            return false;
//            clearMethodCallAndResult();
        }

        this.methodCall = methodCall;
        pendingResult = result;
        return true;
    }

    private void finishWithAlreadyActiveError(MethodChannel.Result result) {
        if (result != null)
            result.error("already_active", "Image selector is already active", null);
        clearMethodCallAndResult();
    }

    private void finishWithSuccess(List<Map<String, Object>> imagePathList) {
        if (pendingResult != null)
            pendingResult.success(imagePathList);
        clearMethodCallAndResult();
    }

    private void finishWithError(String errorCode, String errorMessage) {
        if (pendingResult != null)
            pendingResult.error(errorCode, errorMessage, null);
        clearMethodCallAndResult();
    }

    private void clearMethodCallAndResult() {
        methodCall = null;
        pendingResult = null;
    }

    private ArrayList<LocalMedia> toLocalMedia(ArrayList<Map<String, Object>> list) {
        ArrayList<LocalMedia> selected = new ArrayList<>();
        if (list != null && list.size() > 0) {
            for (Map<String, Object> item : list) {
                selected.add(new LocalMedia(
                        Long.parseLong(item.get("id").toString()),
                        item.get("realPath").toString(),
                        item.get("fileName").toString(),
                        item.get("parentFolderName").toString(),
                        0,
                        Integer.parseInt(item.get("chooseModel").toString()),
                        item.get("mimeType").toString(),
                        Integer.parseInt(item.get("width").toString()),
                        Integer.parseInt(item.get("height").toString()),
                        Long.parseLong(item.get("size").toString())
                ));
            }
        }
        return selected;
    }
}
