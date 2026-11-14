# MT Manager for iOS

非官方 iOS 文件管理器项目，参考 MT 管理器的双窗口文件管理体验。与 MT 管理器原作者无隶属关系。

## 两个独立版本

- **TrollStore**：独立构建 IPA，适用于 TrollStore 支持的系统版本。
- **Jailbreak**：独立构建越狱应用及 rootful / rootless Debian 包。

共享 UIKit 核心代码，最低部署目标暂定 iOS 12.0。注意：应用部署目标不代表 TrollStore 本身支持 iOS 12；TrollStore 的固件支持范围由 TrollStore 决定。

## 当前阶段

- UIKit 双窗口文件浏览器
- 文件 App 导入
- IPA ZIP 包结构及 Info.plist 基础信息读取
- 文本 / plist 文件预览
- TrollStore 与 Jailbreak 两套构建 Scheme
- GitHub Actions 手动构建

## 后续计划

1. 还原 MT 管理器主界面布局、图标与操作菜单（左上卡片的 Android 图标替换为 Apple 图标）
2. 完善文件复制、移动、删除、重命名及压缩功能
3. IPA Payload 浏览、资源提取、Mach-O 分析
4. TrollStore 与越狱环境的额外文件访问适配

## 权限说明

TrollStore 安装本身不等于自动获得任意文件系统访问权限。越狱版的 rootful / rootless 文件访问也需要按具体 bootstrap、注入和签名环境分别适配。当前代码只访问应用沙盒及用户通过系统文件选择器授权的文件。

IPA 分析包括包结构、plist、资源和二进制元数据分析，不会把 Swift / Objective-C 二进制还原成完整原始源码。

## 构建

在 macOS 安装 Xcode 与 XcodeGen：

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project MTManager-iOS.xcodeproj -scheme MTManagerTrollStore -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

进入 GitHub Actions，选择 **Build MT Manager iOS**，点击 **Run workflow**。
