#
# Be sure to run `pod lib lint NFTPlayer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NFTPlayer'
  s.version          = '1.0.0'
  s.summary          = 'iOS视频播放器'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  NFTPlayer 基于系统AVPlayer渲染的视频播放器，通过接管resourceLoader来管理整个视频播放的网络层和缓存层
                       DESC

  s.homepage         = 'https://github.com/pdcodeunder'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'pengdong' => 'pd767180024@163.com' }
  s.source           = { :git => 'https://github.com/pdcodeunder/NFTPlayer', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  
  s.swift_version = '5.0'
  s.platform = :ios
  s.ios.deployment_target = '13.0'

  s.source_files = 'NFTPlayer/Classes/**/*'
  
  s.resources = 'NFTPlayer/Assets/*'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
