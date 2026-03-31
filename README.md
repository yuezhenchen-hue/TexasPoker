# 🃏 德扑策略师 (Poker Strategy Master)

一款使用 **Swift + SwiftUI** 构建的 iOS 德州扑克游戏 App。

## 功能特性

- **完整德州扑克规则**: 翻牌前 → 翻牌 → 转牌 → 河牌 → 摊牌
- **4 个 AI 对手**: 保守型 (Tight)、激进型 (Aggressive)、松散型 (Loose) 三种策略风格
- **精美 SwiftUI 界面**: 仿真牌桌、程序化绘制扑克牌、玩家面板
- **手牌评估**: 支持全部 10 种牌型（皇家同花顺 → 高牌）
- **完整操作**: 弃牌、过牌、跟注、加注（滑块选择）、全下
- **中文界面**: 完全中文本地化

## 环境要求

- macOS + Xcode 15+
- iOS 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (用于生成 .xcodeproj)

## 安装与运行

```bash
# 克隆仓库
git clone https://github.com/yuezhenchen-hue/TexasPoker.git
cd TexasPoker

# 生成 Xcode 项目
xcodegen generate

# 用 Xcode 打开
open TexasPoker.xcodeproj
```

在 Xcode 中选择模拟器，点击 Run (⌘R) 即可运行。

## 项目结构

```
TexasPoker/
├── project.yml                      # XcodeGen 配置
├── TexasPoker/
│   ├── TexasPokerApp.swift          # App 入口
│   ├── Models/
│   │   ├── Card.swift               # 扑克牌 & 牌组
│   │   ├── HandEvaluator.swift      # 手牌评估器
│   │   ├── Player.swift             # 玩家 & AI 策略
│   │   └── GameEngine.swift         # 游戏引擎
│   ├── ViewModels/
│   │   └── GameViewModel.swift      # 游戏状态管理
│   ├── Views/
│   │   ├── ContentView.swift        # 欢迎页
│   │   ├── GameView.swift           # 游戏主界面
│   │   ├── CardView.swift           # 扑克牌组件
│   │   ├── PlayerView.swift         # 玩家面板组件
│   │   └── ActionBar.swift          # 操作按钮栏
│   └── Assets.xcassets/             # 图片资源 & App 图标
└── README.md
```

## 德州扑克规则

1. 每位玩家发 2 张底牌（仅自己可见）
2. 共 4 轮下注：翻牌前 → 翻牌（3 张公共牌）→ 转牌（第 4 张）→ 河牌（第 5 张）
3. 从 7 张牌中选出最优 5 张组合比大小
4. **牌型大小**: 皇家同花顺 > 同花顺 > 四条 > 葫芦 > 同花 > 顺子 > 三条 > 两对 > 一对 > 高牌

## 技术栈

| 技术 | 用途 |
|------|------|
| Swift 5.9 | 编程语言 |
| SwiftUI | UI 框架 |
| Combine | 响应式状态管理 |
| XcodeGen | 项目文件生成 |

## License

MIT License
