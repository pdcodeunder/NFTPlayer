## 介绍

NFTPlayer 基于系统AVPlayer渲染的视频播放器，通过接管resourceLoader来管理整个视频播放的网络层和缓存层。根据业务需要可以很方便的实现交互层、渲染层、播放层、网络层、缓存层等播放行为的监控。

注：
此库还是一个雏形，功能上还不够完善，实现的功能都是暂时能想到的，如果需要更多的功能欢迎留言，有时间会逐一实现。也欢迎你加入一起维护完善。

缓存层使用的是一个视频对应一个文件，空白内容补0方案实现，如果你是播放超长视频为主的项目，可以换成多文件视频数据切片的方式来实现

有问题欢迎指出，有更好的实现方案欢迎提出，共同学习进步

## 引入

```ruby
pod 'NFTPlayer'
```

运行 `pod install` 

## 功能

- [x] 边下边播
- [x] 自定义缓存层
- [x] 自定义网络层，根据业务需要可以方便的加入限流策略
- [x] 换源：视频播放失败时自动切换到下一个视频源进行播放，降低失败率
- [x] 预加载

## 代码结构

- Interface：对外开放接口
  - MediaConvertible：媒体播放源所要实现的协议，获取同一个视频不同数据源URL列表
  - PlayerInterfaceView：视频播放期间对视频控制的UI，需要遵守PlayerInterfaceViewProtocol协议，提供了一个默认默认UI：PlayerInterfaceDefaultView
  - PlayerManager：视频播放统一管理类
  - PlayerPreDownloader：预加载
- Player
  - VideoPlayer：视频播放器
  - VideoRenderView：视频渲染图层
- ResourceLoader:
  - AssetResourceLoader：接管视频AVURLAsset ResourceLoader
- DataSource
  - DataSourceCenter：数据存储获取管理中心
  - DataSourceUrlOperation：URL操作控制，一个视频URL对应一个DataSourceUrlOperation，管理多个DataSourceInformationRequestOperation和DataSourceDataRequestOperation类
  - DataSourceInformationRequestOperation：视频信息请求操作，一个AVAssetResourceLoader contentInformationRequest对应一个DataSourceInformationRequestOperation服务类
  - DataSourceDataRequestOperation：视频数据请求操作，一个AVAssetResourceLoader dataRequest对应一个DataSourceDataRequestOperation服务类
  - DataSourceRequestTask：网络请求task，一个网络请求对应一个task
- DataSourceCache：视频缓存，一个URL对应一个DataSourceCache

## Author

pd767180024@163.com

如果对你有点帮助，还请给个🌟 🌟 

## 效果

![运行效果](https://file.ippzone.com/img/png/id/2285310941)

## License

NFTPlayer is available under the MIT license. See the LICENSE file for more info.
