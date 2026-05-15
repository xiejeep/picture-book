# 点读鸭 (DianDuYa) — 儿童英语绘本点读 App

一款基于 Flutter 开发的儿童英语绘本点读应用，通过 OCR 文字识别和 AI 文本增强，帮助孩子阅读英语绘本。

## 功能特性

- **绘本管理** — 添加、浏览、管理英语绘本，支持多页面浏览
- **OCR 文字识别** — 基于 Google ML Kit 自动识别绘本图片中的英文文字
- **AI 文本增强** — 接入 AI 模型优化识别结果，提升朗读准确性
- **点读朗读** — 点击文字区块即可播放 TTS 语音朗读
- **暗色模式** — 支持跟随系统自动切换亮色/暗色主题
- **儿童友好** — 温暖配色、圆润字体、大按钮触控区域

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x (Dart) |
| 状态管理 | Riverpod 2.x |
| 路由 | GoRouter |
| 本地存储 | Hive |
| OCR | Google ML Kit Text Recognition |
| TTS | flutter_tts |
| 字体 | Google Fonts (Fredoka + Nunito) |
| SDK 管理 | FVM |

## 项目结构

```
lib/
├── app.dart                        # MaterialApp.router 入口
├── main.dart                       # 初始化服务、ProviderScope
├── core/                           # 路由、主题、常量、工具类
├── data/                           # 服务（单例）、仓库、Hive 数据模型
└── presentation/
    ├── providers/                   # 全局 Riverpod providers
    ├── features/text_detection/     # OCR 文字检测功能模块
    ├── pages/                       # 全屏页面
    └── widgets/                     # 共享组件
```

## 快速开始

### 环境要求

- Flutter SDK (通过 FVM 管理)
- Xcode (iOS 构建)
- Android Studio (Android 构建)

### 安装与运行

```bash
# 安装 FVM (如未安装)
dart pub global activate fvm

# 安装 Flutter SDK
fvm install stable
fvm use stable

# 安装依赖
fvm flutter pub get

# 运行项目
fvm flutter run
```

### 常用命令

```bash
# 代码分析（lint + 类型检查）
flutter analyze

# 代码格式化
dart format lib/

# Hive 模型代码生成（修改模型后执行）
flutter pub run build_runner build --delete-conflicting-outputs
```

## 页面路由

| 路径 | 页面 |
|------|------|
| `/` | 首页 |
| `/book/:id` | 绘本详情 |
| `/book/:id/manage` | 绘本管理 |
| `/settings` | 设置 |
| `/settings/ai` | AI 设置 |
| `/settings/voice` | 语音设置 |
| `/settings/cache` | 缓存管理 |
| `/tutorial` | 使用教程 |

## 版本

当前版本：1.0.3+7（通过 `package_info_plus` 动态获取）

## License

[MIT License](LICENSE)
