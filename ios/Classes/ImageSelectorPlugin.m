#import "ImageSelectorPlugin.h"
#import "TZImagePickerController.h"
#import "UIView+Layout.h"
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "TZLocationManager.h"
#import "TZImagePreviewController.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/UIImage+GIF.h>
//#import <Foundation/Foundation.h>
//#import <UIKit/UIKit.h>
//#import <AVFoundation/AVFoundation.h>

@interface ImageSelectorPlugin () <TZImagePickerControllerDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property (strong, nonatomic) CLLocation *location;
@property (nonatomic, strong) UIImagePickerController *imagePickerVc;
@end

@implementation ImageSelectorPlugin{
    int _maxImage;
    bool _camera, _needCut;
    CGFloat _cutRatio;
    NSMutableArray *_selected;
    FlutterResult _result;
    UIImagePickerController *_imagePickerController;
    UIViewController *_viewController;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"image_selector"
                                     binaryMessenger:[registrar messenger]];
//    ImageSelectorPlugin* instance = [[ImageSelectorPlugin alloc] init];
      
//    UIViewController *viewController =
//        [UIApplication sharedApplication].delegate.window.rootViewController;
    ImageSelectorPlugin *instance =
        [[ImageSelectorPlugin alloc] initWithViewController:[UIApplication sharedApplication].delegate.window.rootViewController];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithViewController:(UIViewController *)viewController {
    self = [super init];
    if (self) {
      _viewController = viewController;
      _imagePickerController = [[UIImagePickerController alloc] init];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
      if ([@"selectImages" isEqualToString:call.method]) {
          _maxImage = [[call.arguments objectForKey:@"maxImage"] intValue];
          _camera = [[call.arguments objectForKey:@"camera"] boolValue];
          _needCut = [[call.arguments objectForKey:@"needCut"] boolValue];
          _cutRatio = [[call.arguments objectForKey:@"cutRatio"] floatValue];
          NSArray *selectedMap = [call.arguments objectForKey:@"selected"];
          _selected = [self toPHAssets:selectedMap];
          _result = result;
          
          if(_camera)
              [self takePhoto];
          else
              [self selectImage];
//          result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
      } else if([@"previewImages" isEqualToString:call.method]){
          int postion = [[call.arguments objectForKey:@"position"] intValue];
          NSArray *selectedMap = [call.arguments objectForKey:@"selected"];
          [self previewImages:[self toPHAssets:selectedMap] postion:postion];
      }else if([@"previewWebImages" isEqualToString:call.method]){
          int postion = [[call.arguments objectForKey:@"position"] intValue];
          NSArray *selectedMap = [call.arguments objectForKey:@"selected"];
          [self previewImages:[self toUrls:selectedMap] postion:postion];
      }else {
        result(FlutterMethodNotImplemented);
      }
}

- (NSMutableArray *)toPHAssets:(NSArray *)images{
    NSMutableArray *phAssets = [NSMutableArray new];
    if(!images) return phAssets;
    NSMutableArray *ids=[NSMutableArray new];
    for (NSDictionary *item in images) {
        [ids addObject:item[@"id"]];
    }
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:ids options:nil];
    for (int i = 0; i < fetchResult.count; i++) {
        [phAssets addObject:fetchResult[i]];
    }
    return phAssets;
}

- (NSMutableArray *)toUrls:(NSArray *)images{
    NSMutableArray *urls = [NSMutableArray new];
    if(!images) return urls;
    for (NSString *item in images) {
        [urls addObject:[NSURL URLWithString:item]];
    }
    return urls;
}

- (void)previewImages:(NSArray *)images postion:(int)postion {
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:1 columnNumber:4 delegate:self pushPhotoPickerVc:YES];
    imagePickerVc.maxImagesCount = 1;
    imagePickerVc.showSelectBtn = NO;
    [imagePickerVc setPhotoPreviewPageDidLayoutSubviewsBlock:^(UICollectionView *collectionView, UIView *naviBar, UIButton *backButton, UIButton *selectButton, UILabel *indexLabel, UIView *toolBar, UIButton *originalPhotoButton, UILabel *originalPhotoLabel, UIButton *doneButton, UIImageView *numberImageView, UILabel *numberLabel) {
//        if (naviBar) {
//            [naviBar removeFromSuperview];
//            naviBar = nil;
//        }
        if (toolBar) {
            [toolBar removeFromSuperview];
            toolBar = nil;
        }
        if (numberLabel) {
            [numberLabel removeFromSuperview];
            numberLabel = nil;
        }
        if (numberImageView) {
            [numberImageView removeFromSuperview];
            numberImageView = nil;
        }
        if (doneButton) {
            [doneButton removeFromSuperview];
            doneButton = nil;
        }
        if (originalPhotoButton) {
            [originalPhotoButton removeFromSuperview];
            originalPhotoButton = nil;
        }
        if (originalPhotoLabel) {
            [originalPhotoLabel removeFromSuperview];
            originalPhotoLabel = nil;
        }
    }];
    TZImagePreviewController *previewVc = [[TZImagePreviewController alloc] initWithPhotos:images currentIndex:postion tzImagePickerVc:imagePickerVc];
    [previewVc setSetImageWithURLBlock:^(NSURL *URL, UIImageView *imageView, void (^completion)(void)) {
        [self configImageView:imageView URL:URL completion:completion];
    }];
    [_viewController presentViewController:previewVc animated:YES completion:nil];
}

- (void)configImageView:(UIImageView *)imageView URL:(NSURL *)URL completion:(void (^)(void))completion{
    if ([URL.absoluteString.lowercaseString hasSuffix:@"gif"]) {
        // 先显示静态图占位
        [[SDWebImageManager sharedManager] loadImageWithURL:URL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            if (!imageView.image) {
                imageView.image = image;
            }
        }];
        // 动图加载完再覆盖掉
//        [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:URL options:0 progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
//            imageView.image = [UIImage sd_animatedGIFWithData:data];
//            if (completion) {
//                completion();
//            }
//        }];
    } else {
        [imageView sd_setImageWithURL:URL placeholderImage:nil options:SDWebImageRetryFailed completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            if (completion) {
                completion();
            }
        }];
    }
}

- (void)finishWithSuccess:(NSArray *)assets images:(NSArray *)images {
    if(assets && assets.count > 0){
        NSMutableArray *resultList = [NSMutableArray new];
        for (PHAsset *asset in assets) {
            //获取原图
//            [[TZImageManager manager] getOriginalPhotoWithAsset:asset completion:^(UIImage *photo, NSDictionary *info) {
//                NSString *path = [self saveImageToTemp:photo];
//                NSLog(@"%@", path);
//            }];
            NSString *path = [self saveImageToTemp:images[resultList.count]];
//            NSLog(@"%@", path);
            
            [resultList addObject:@{
                @"id" : asset.localIdentifier,
                @"width" : @(asset.pixelWidth),
                @"height" : @(asset.pixelHeight),
                @"path" : path,
                @"realPath" : path,
                @"fileName" : [asset valueForKey:@"filename"],
                @"parentFolderName" : @"",
                @"duration" : @0,
                @"chooseModel" : @0,
                @"mimeType" : @"",
                @"size" : @0}
             ];
            
//            NSLog(@"%@",asset.localIdentifier);
//            NSLog(@"%lu",(unsigned long)asset.pixelWidth);
//            NSLog(@"%lu",(unsigned long)asset.pixelHeight);
//            NSLog(@"%@",[asset valueForKey:@"filename"]);
        }
        if (_result)
            _result(resultList);
        _result = nil;
    }
}

- (void)finishWithError:(NSString *)errorCode errorMessage:(NSString *)errorMessage {
    if (_result)
    _result([FlutterError errorWithCode:errorCode
                                message:errorMessage
                                details:nil]);
    _result = nil;
}

// The way we save images to the tmp dir currently throws away all EXIF data
// (including the orientation of the image). That means, pics taken in portrait
// will not be orientated correctly as is. To avoid that, we rotate the actual
// image data.
// TODO(goderbauer): investigate how to preserve EXIF data.
- (UIImage *)normalizedImage:(UIImage *)image {
  if (image.imageOrientation == UIImageOrientationUp) return image;

  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  [image drawInRect:(CGRect){0, 0, image.size}];
  UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return normalizedImage;
}

- (NSString *)saveImageToTemp:(UIImage *)image {
    image = [self normalizedImage:image];
    
    //如果图片过大,缩放图片
//    NSNumber *maxWidth = [self->_arguments objectForKey:@"maxWidth"];
//    NSNumber *maxHeight = [self->_arguments objectForKey:@"maxHeight"];
//
//    if (maxWidth != (id)[NSNull null] || maxHeight != (id)[NSNull null]) {
//        image = [self scaledImage:image maxWidth:maxWidth maxHeight:maxHeight];
//    }
    
    NSData *data = UIImageJPEGRepresentation(image, 1.0);
    NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *tmpFile = [NSString stringWithFormat:@"image_selector_%@.jpg", guid];
    NSString *tmpDirectory = NSTemporaryDirectory();
    NSString *tmpPath = [tmpDirectory stringByAppendingPathComponent:tmpFile];
    
    if ([[NSFileManager defaultManager] createFileAtPath:tmpPath contents:data attributes:nil]) {
        return tmpPath;
    } else {
        [self finishWithError:@"create_error" errorMessage:@"Temporary file could not be created"];
        return @"";
    }
}

- (void)selectImage{
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:_maxImage columnNumber:4 delegate:self pushPhotoPickerVc:YES];

    // imagePickerVc.barItemTextColor = [UIColor blackColor];
    // [imagePickerVc.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor blackColor]}];
    // imagePickerVc.navigationBar.tintColor = [UIColor blackColor];
    // imagePickerVc.naviBgColor = [UIColor whiteColor];
    // imagePickerVc.navigationBar.translucent = NO;
        
    #pragma mark - 五类个性化设置，这些参数都可以不传，此时会走默认设置
    imagePickerVc.isSelectOriginalPhoto = NO;

    if (_maxImage > 1) {
        // 1.设置目前已经选中的图片数组
        imagePickerVc.selectedAssets = _selected; // 目前已经选中的图片数组
    }
    imagePickerVc.allowTakePicture = NO; // 在内部显示拍照按钮
    imagePickerVc.allowTakeVideo = NO;   // 在内部显示拍视频按
//    imagePickerVc.videoMaximumDuration = 10; // 视频最大拍摄时间
    [imagePickerVc setUiImagePickerControllerSettingBlock:^(UIImagePickerController *imagePickerController) {
        imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
    }];
//    imagePickerVc.autoSelectCurrentWhenDone = NO;

    // imagePickerVc.photoWidth = 1600;
    // imagePickerVc.photoPreviewMaxWidth = 1600;
    UIColor *mainColor=[UIColor colorWithRed:45/255.0 green:109/255.0 blue:247/255.0 alpha:1.0];

    // 2. Set the appearance
    // 2. 在这里设置imagePickerVc的外观
    //     imagePickerVc.navigationBar.barTintColor = [UIColor colorWithRed:45/255.0 green:109/255.0 blue:247/255.0 alpha:1.0];
    imagePickerVc.oKButtonTitleColorDisabled = [UIColor lightGrayColor];
    imagePickerVc.oKButtonTitleColorNormal = mainColor;
    imagePickerVc.navigationBar.translucent = YES;
    imagePickerVc.iconThemeColor = mainColor;
    imagePickerVc.showPhotoCannotSelectLayer = YES;
    imagePickerVc.cannotSelectLayerColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];

    [imagePickerVc setPhotoPickerPageUIConfigBlock:^(UICollectionView *collectionView, UIView *bottomToolBar, UIButton *previewButton, UIButton *originalPhotoButton, UILabel *originalPhotoLabel, UIButton *doneButton, UIImageView *numberImageView, UILabel *numberLabel, UIView *divideLine) {
    //        [doneButton setTitleColor:mainColor forState:UIControlStateNormal];
        [previewButton setTitleColor:mainColor forState:UIControlStateNormal];
            [originalPhotoButton setTitleColor:mainColor forState:UIControlStateSelected];
    //        [numberLabel setBackgroundColor:mainColor];
    }];

    /*
    [imagePickerVc setAssetCellDidSetModelBlock:^(TZAssetCell *cell, UIImageView *imageView, UIImageView *selectImageView, UILabel *indexLabel, UIView *bottomView, UILabel *timeLength, UIImageView *videoImgView) {
        cell.contentView.clipsToBounds = YES;
        cell.contentView.layer.cornerRadius = cell.contentView.tz_width * 0.5;
    }];
     */

    // 3. Set allow picking video & photo & originalPhoto or not
    // 3. 设置是否可以选择视频/图片/原图
    imagePickerVc.allowPickingVideo = NO;
    imagePickerVc.allowPickingImage = YES;
    imagePickerVc.allowPickingOriginalPhoto = NO;
    imagePickerVc.allowPickingGif = NO;
    imagePickerVc.allowPickingMultipleVideo = NO; // 是否可以多选视频

    // 4. 照片排列按修改时间升序
    imagePickerVc.sortAscendingByModificationDate = YES;

    // imagePickerVc.minImagesCount = 3;
    // imagePickerVc.alwaysEnableDoneBtn = YES;

    // imagePickerVc.minPhotoWidthSelectable = 3000;
    // imagePickerVc.minPhotoHeightSelectable = 2000;

    /// 5. Single selection mode, valid when maxImagesCount = 1
    /// 5. 单选模式,maxImagesCount为1时才生效
    imagePickerVc.showSelectBtn = NO;
    imagePickerVc.allowCrop = _needCut;
    imagePickerVc.needCircleCrop = NO;
    // 设置竖屏下的裁剪尺寸
    NSInteger left = 0;
    CGFloat width = _viewController.view.tz_width - 2 * left;
    CGFloat height = width / _cutRatio;
    NSInteger top = (_viewController.view.tz_height - height) / 2;
    imagePickerVc.cropRect = CGRectMake(left, top, width, height);
    imagePickerVc.scaleAspectFillCrop = YES;
    // 设置横屏下的裁剪尺寸
    // imagePickerVc.cropRectLandscape = CGRectMake((self.view.tz_height - widthHeight) / 2, left, widthHeight, widthHeight);
    /*
     [imagePickerVc setCropViewSettingBlock:^(UIView *cropView) {
     cropView.layer.borderColor = [UIColor redColor].CGColor;
     cropView.layer.borderWidth = 2.0;
     }];*/

    //     imagePickerVc.allowPreview = NO;
    // 自定义导航栏上的返回按钮
    /*
    [imagePickerVc setNavLeftBarButtonSettingBlock:^(UIButton *leftButton){
        [leftButton setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
        [leftButton setImageEdgeInsets:UIEdgeInsetsMake(0, -10, 0, 20)];
    }];
    imagePickerVc.delegate = self;
    */

    // Deprecated, Use statusBarStyle
    // imagePickerVc.isStatusBarDefault = NO;
    imagePickerVc.statusBarStyle = UIStatusBarStyleLightContent;

    // 设置是否显示图片序号
    imagePickerVc.showSelectedIndex = NO;

    // 设置拍照时是否需要定位，仅对选择器内部拍照有效，外部拍照的，请拷贝demo时手动把pushImagePickerController里定位方法的调用删掉
    // imagePickerVc.allowCameraLocation = NO;

    // 自定义gif播放方案
//    [[TZImagePickerConfig sharedInstance] setGifImagePlayBlock:^(TZPhotoPreviewView *view, UIImageView *imageView, NSData *gifData, NSDictionary *info) {
//        FLAnimatedImage *animatedImage = [FLAnimatedImage animatedImageWithGIFData:gifData];
//        FLAnimatedImageView *animatedImageView;
//        for (UIView *subview in imageView.subviews) {
//            if ([subview isKindOfClass:[FLAnimatedImageView class]]) {
//                animatedImageView = (FLAnimatedImageView *)subview;
//                animatedImageView.frame = imageView.bounds;
//                animatedImageView.animatedImage = nil;
//            }
//        }
//        if (!animatedImageView) {
//            animatedImageView = [[FLAnimatedImageView alloc] initWithFrame:imageView.bounds];
//            animatedImageView.runLoopMode = NSDefaultRunLoopMode;
//            [imageView addSubview:animatedImageView];
//        }
//        animatedImageView.animatedImage = animatedImage;
//    }];

    // 设置首选语言 / Set preferred language
    // imagePickerVc.preferredLanguage = @"zh-Hans";
        
    #pragma mark - 到这里为止
        
    // You can get the photos by block, the same as by delegate.
    // 你可以通过block或者代理，来得到用户选择的照片.
//    [imagePickerVc setDidFinishPickingPhotosHandle:^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto) {
//        NSLog(@"%@",photos);
//    }];

    if (@available(iOS 13.0, *)) {
        imagePickerVc.modalPresentationStyle = UIModalPresentationAutomatic;
        [imagePickerVc setModalInPresentation:YES];
    } else {
        imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    [_viewController presentViewController:imagePickerVc animated:YES completion:nil];
}

#pragma mark - UIImagePickerController

- (void)takePhoto {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
        // 无相机权限 做一个友好的提示
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
        [_viewController presentViewController:alertController animated:YES completion:nil];
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self takePhoto];
                });
            }
        }];
        // 拍照之前还需要检查相册权限
    } else if ([PHPhotoLibrary authorizationStatus] == 2) { // 已被拒绝，没有相册权限，将无法保存拍的照片
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
        [_viewController presentViewController:alertController animated:YES completion:nil];
    } else if ([PHPhotoLibrary authorizationStatus] == 0) { // 未请求过相册权限
        [[TZImageManager manager] requestAuthorizationWithCompletion:^{
            [self takePhoto];
        }];
    } else {
        [self pushImagePickerController];
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (UIImagePickerController *)imagePickerVc {
    if (_imagePickerVc == nil) {
        _imagePickerVc = [[UIImagePickerController alloc] init];
        _imagePickerVc.delegate = self;
        // set appearance / 改变相册选择页的导航栏外观
        _imagePickerVc.navigationBar.barTintColor = _viewController.navigationController.navigationBar.barTintColor;
        _imagePickerVc.navigationBar.tintColor = _viewController.navigationController.navigationBar.tintColor;
        UIBarButtonItem *tzBarItem, *BarItem;
        if (@available(iOS 9, *)) {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[TZImagePickerController class]]];
            BarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UIImagePickerController class]]];
        } else {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedIn:[TZImagePickerController class], nil];
            BarItem = [UIBarButtonItem appearanceWhenContainedIn:[UIImagePickerController class], nil];
        }
        NSDictionary *titleTextAttributes = [tzBarItem titleTextAttributesForState:UIControlStateNormal];
        [BarItem setTitleTextAttributes:titleTextAttributes forState:UIControlStateNormal];
 
    }
    return _imagePickerVc;
}

// 调用相机
- (void)pushImagePickerController {
    // 提前定位
    __weak typeof(self) weakSelf = self;
    [[TZLocationManager manager] startLocationWithSuccessBlock:^(NSArray<CLLocation *> *locations) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.location = [locations firstObject];
    } failureBlock:^(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.location = nil;
    }];
    
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        self.imagePickerVc.sourceType = sourceType;
        NSMutableArray *mediaTypes = [NSMutableArray array];
//        if (self.showTakeVideoBtnSwitch.isOn) {
//            [mediaTypes addObject:(NSString *)kUTTypeMovie];
//        }
//        if (self.showTakePhotoBtnSwitch.isOn) {
//            [mediaTypes addObject:(NSString *)kUTTypeImage];
//        }
        [mediaTypes addObject:(NSString *)kUTTypeImage];
        if (mediaTypes.count) {
            _imagePickerVc.mediaTypes = mediaTypes;
        }
        [_viewController presentViewController:_imagePickerVc animated:YES completion:nil];
    } else {
        NSLog(@"模拟器中无法打开照相机,请在真机中使用");
    }
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    
    TZImagePickerController *tzImagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:1 delegate:self];
    tzImagePickerVc.sortAscendingByModificationDate = YES;
    [tzImagePickerVc showProgressHUD];
    if ([type isEqualToString:@"public.image"]) {
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        NSDictionary *meta = [info objectForKey:UIImagePickerControllerMediaMetadata];
        // save photo and get asset / 保存图片，获取到asset
        [[TZImageManager manager] savePhotoWithImage:image meta:meta location:self.location completion:^(PHAsset *asset, NSError *error){
            [tzImagePickerVc hideProgressHUD];
            if (error) {
                NSLog(@"图片保存失败 %@",error);
            } else {
                TZAssetModel *assetModel = [[TZImageManager manager] createModelWithAsset:asset];
                if (self->_needCut) { // 允许裁剪,去裁剪
                    TZImagePickerController *imagePicker = [[TZImagePickerController alloc] initCropTypeWithAsset:assetModel.asset photo:image completion:^(UIImage *cropImage, id asset) {
                        [self finishWithSuccess:@[asset] images:@[cropImage]];
                    }];
                    imagePicker.allowPickingImage = YES;
                    imagePicker.needCircleCrop = NO;
                    imagePicker.circleCropRadius = 100;
                    [self->_viewController presentViewController:imagePicker animated:YES completion:nil];
                } else {
                    [self finishWithSuccess:@[assetModel.asset] images:@[image]];
                }
            }
        }];
    } else if ([type isEqualToString:@"public.movie"]) {
        NSURL *videoUrl = [info objectForKey:UIImagePickerControllerMediaURL];
        if (videoUrl) {
            [[TZImageManager manager] saveVideoWithUrl:videoUrl location:self.location completion:^(PHAsset *asset, NSError *error) {
                [tzImagePickerVc hideProgressHUD];
                if (!error) {
                    TZAssetModel *assetModel = [[TZImageManager manager] createModelWithAsset:asset];
                    [[TZImageManager manager] getPhotoWithAsset:assetModel.asset completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
                        if (!isDegraded && photo) {
                            [self finishWithSuccess:@[assetModel.asset] images:@[photo]];
                        }
                    }];
                }
            }];
        }
    }
}

//- (void)refreshCollectionViewWithAddedAsset:(PHAsset *)asset image:(UIImage *)image {
//    [_selectedAssets addObject:asset];
//    [_selectedPhotos addObject:image];
//    [_collectionView reloadData];
//}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    if ([picker isKindOfClass:[UIImagePickerController class]]) {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - TZImagePickerControllerDelegate

/// User click cancel button
/// 用户点击了取消
- (void)tz_imagePickerControllerDidCancel:(TZImagePickerController *)picker {
    [self finishWithError:@"Canceled" errorMessage:@"User did cancel selector"];
}

// The picker should dismiss itself; when it dismissed these handle will be called.
// You can also set autoDismiss to NO, then the picker don't dismiss itself.
// If isOriginalPhoto is YES, user picked the original photo.
// You can get original photo with asset, by the method [[TZImageManager manager] getOriginalPhotoWithAsset:completion:].
// The UIImage Object in photos default width is 828px, you can set it by photoWidth property.
// 这个照片选择器会自己dismiss，当选择器dismiss的时候，会执行下面的代理方法
// 你也可以设置autoDismiss属性为NO，选择器就不会自己dismis了
// 如果isSelectOriginalPhoto为YES，表明用户选择了原图
// 你可以通过一个asset获得原图，通过这个方法：[[TZImageManager manager] getOriginalPhotoWithAsset:completion:]
// photos数组里的UIImage对象，默认是828像素宽，你可以通过设置photoWidth属性的值来改变它
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto infos:(NSArray<NSDictionary *> *)infos {
//    _selectedPhotos = [NSMutableArray arrayWithArray:photos];
//    _selectedAssets = [NSMutableArray arrayWithArray:assets];
//    _isSelectOriginalPhoto = isSelectOriginalPhoto;
//    [_collectionView reloadData];
    // _collectionView.contentSize = CGSizeMake(0, ((_selectedPhotos.count + 2) / 3 ) * (_margin + _itemWH));
    
    // 1.打印图片名字
//    [self printAssetsName:assets];
    // 2.图片位置信息
//    for (PHAsset *phAsset in assets) {
//        NSLog(@"location:%@",phAsset.location);
//    }
    
    // 3. 获取原图的示例，用队列限制最大并发为1，避免内存暴增
//    self.operationQueue = [[NSOperationQueue alloc] init];
//    self.operationQueue.maxConcurrentOperationCount = 1;
//    for (NSInteger i = 0; i < assets.count; i++) {
//        PHAsset *asset = assets[i];
//        // 图片上传operation，上传代码请写到operation内的start方法里，内有注释
//        TZImageUploadOperation *operation = [[TZImageUploadOperation alloc] initWithAsset:asset completion:^(UIImage * photo, NSDictionary *info, BOOL isDegraded) {
//            if (isDegraded) return;
//            NSLog(@"图片获取&上传完成");
//        } progressHandler:^(double progress, NSError * _Nonnull error, BOOL * _Nonnull stop, NSDictionary * _Nonnull info) {
//            NSLog(@"获取原图进度 %f", progress);
//        }];
//        [self.operationQueue addOperation:operation];
//    }
    [self finishWithSuccess:assets images:photos];
}

// If user picking a video and allowPickingMultipleVideo is NO, this callback will be called.
// If allowPickingMultipleVideo is YES, will call imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:
// 如果用户选择了一个视频且allowPickingMultipleVideo是NO，下面的代理方法会被执行
// 如果allowPickingMultipleVideo是YES，将会调用imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingVideo:(UIImage *)coverImage sourceAssets:(PHAsset *)asset {
//    _selectedPhotos = [NSMutableArray arrayWithArray:@[coverImage]];
//    _selectedAssets = [NSMutableArray arrayWithArray:@[asset]];
//    // open this code to send video / 打开这段代码发送视频
//    [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPresetLowQuality success:^(NSString *outputPath) {
//        // NSData *data = [NSData dataWithContentsOfFile:outputPath];
//        NSLog(@"视频导出到本地完成,沙盒路径为:%@",outputPath);
//        // Export completed, send video here, send by outputPath or NSData
//        // 导出完成，在这里写上传代码，通过路径或者通过NSData上传
//    } failure:^(NSString *errorMessage, NSError *error) {
//        NSLog(@"视频导出失败:%@,error:%@",errorMessage, error);
//    }];
////    [_collectionView reloadData];
//    // _collectionView.contentSize = CGSizeMake(0, ((_selectedPhotos.count + 2) / 3 ) * (_margin + _itemWH));
}

// If user picking a gif image and allowPickingMultipleVideo is NO, this callback will be called.
// If allowPickingMultipleVideo is YES, will call imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:
// 如果用户选择了一个gif图片且allowPickingMultipleVideo是NO，下面的代理方法会被执行
// 如果allowPickingMultipleVideo是YES，将会调用imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingGifImage:(UIImage *)animatedImage sourceAssets:(PHAsset *)asset {
//    _selectedPhotos = [NSMutableArray arrayWithArray:@[animatedImage]];
//    _selectedAssets = [NSMutableArray arrayWithArray:@[asset]];
//    [_collectionView reloadData];
}

// Decide album show or not't
// 决定相册显示与否
- (BOOL)isAlbumCanSelect:(NSString *)albumName result:(PHFetchResult *)result {
    /*
    if ([albumName isEqualToString:@"个人收藏"]) {
        return NO;
    }
    if ([albumName isEqualToString:@"视频"]) {
        return NO;
    }*/
    return YES;
}

// Decide asset show or not't
// 决定asset显示与否
- (BOOL)isAssetCanSelect:(PHAsset *)asset {
    /*
    switch (asset.mediaType) {
        case PHAssetMediaTypeVideo: {
            // 视频时长
            // NSTimeInterval duration = phAsset.duration;
            return NO;
        } break;
        case PHAssetMediaTypeImage: {
            // 图片尺寸
            if (phAsset.pixelWidth > 3000 || phAsset.pixelHeight > 3000) {
                // return NO;
            }
            return YES;
        } break;
        case PHAssetMediaTypeAudio:
            return NO;
            break;
        case PHAssetMediaTypeUnknown:
            return NO;
            break;
        default: break;
    }
     */
    return YES;
}

@end
