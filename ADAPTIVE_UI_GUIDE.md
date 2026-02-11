# Flutter 自适应 UI 适配建议文档 (平板与横屏优化)

本文档基于 `flutter-adaptive-ui` 最佳实践，针对 `wordcard_coach` 应用在平板及竖屏/横屏切换场景下的适配方案进行分析与建议。

## 1. 核心布局策略 (Breakpoints)

建议采用 Material Design 标准断点：
- **Compact (手机)**: 宽度 < 600px
- **Medium (平板/大屏)**: 600px <= 宽度 < 840px
- **Expanded (桌面)**: 宽度 >= 840px

## 2. 关键页面适配建议

### 2.1 全局导航 (MainNavigationScreen)
**现状**: 仅使用了 `BottomNavigationBar`，在宽屏上图标会被拉得很稀疏，且占用底部宝贵的垂直空间。

**建议**:
- **断点切换**: 当宽度 >= 600px 时，将 `BottomNavigationBar` 替换为 `NavigationRail` (侧边导航栏)。
- **实现示例**:
```dart
Widget build(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final isWide = width >= 600;

  return Scaffold(
    body: Row(
      children: [
        if (isWide) NavigationRail(...), // 宽屏显示侧边栏
        Expanded(child: IndexedStack(...)),
      ],
    ),
    bottomNavigationBar: isWide ? null : BottomNavigationBar(...), // 窄屏显示底部栏
  );
}
```

### 2.2 首页仪表盘 (HomeDashboardScreen)
**现状**: 所有组件垂直堆叠，在横屏或平板上会导致内容过长且两侧留白过多。

**建议**:
- **每日任务 (Daily Quest)**: 在宽屏上，将原本堆叠的 `BubblyButton` 改为水平排列的 `GridView` 或 `Row`。
- **每日金句卡片 (Daily Sentence)**: 限制最大宽度（如 800px），并居中显示，避免因宽度过大导致视觉比例失调。
- **栅格化布局**: 
```dart
LayoutBuilder(
  builder: (context, constraints) {
    int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      // ... 任务按钮
    );
  }
)
```

### 2.3 练习界面 (Speaking/Spelling/Selection Practice)
**现状**: 典型的手机垂直流布局。在宽屏或横屏下，内容居中垂直分布，会导致：
1. **拼写练习 (Spelling)**: 键盘区域在宽屏上会散得很开，或者在横屏上需要滚动才能看到。
2. **选择练习 (Selection)**: 选项卡片被拉得很长，视觉焦点分散。

**建议**:
- **分栏布局 (Split-view)**: 在横屏下，左侧显示单词/题目图片区，右侧显示交互区（虚拟键盘、选项按钮）。
- **键盘区域优化**: 拼写练习的字母按钮在平板上应限制最大宽度或采用固定栅格，避免按钮间距过大。
- **布局切换逻辑示例**:
```dart
bool isWide = MediaQuery.sizeOf(context).width > 600;
Widget content = isWide 
  ? Row(children: [Expanded(child: leftPanel), Expanded(child: rightPanel)]) 
  : Column(children: [topPanel, bottomPanel]);
```

## 3. 实现技术要点

1. **优先使用 `MediaQuery.sizeOf(context)`**: 性能优于 `MediaQuery.of(context)`，仅在尺寸变化时触发重绘。
2. **避免锁定方向**: 确保 `main.dart` 或 `Info.plist`/`AndroidManifest.xml` 中没有硬编码锁定手机方向。
3. **内容最大宽度约束**: 
   针对大屏，合理使用 `Center` 和 `ConstrainedBox` 限制内容区域最大宽度，防止文本行过长影响阅读：
   ```dart
   Center(
     child: ConstrainedBox(
       constraints: BoxConstraints(maxWidth: 900),
       child: child,
     ),
   )
   ```

## 4. 后续步骤建议

1. **抽象导航项**: 创建统一的 `NavigationDestination` 数据结构。
2. **引入自适应布局组件**: 创建 `AdaptiveScaffold` 或类似的通用组件。
3. **多设备预览**: 使用 Flutter SDK 自带的 `DevicePreview` 插件进行快速验证。

---
*文档由 Antigravity 依据 flutter-adaptive-ui skills 自动分析生成。*
