# 项目协作规则

## legado 复刻前置规则（强制）

- 所有功能开发在动手前，必须先确认 legado 中对应功能的实现与行为。
- 所有功能开发在确认 legado 对应实现时，必须将相关 legado 文件完整读取后再下结论。
- 复刻时必须以 legado 的交互语义、状态流转和边界处理为基准，避免主观改写。
- 若暂时无法确认 legado 对应实现，需先暂停开发并与需求方确认后再继续。

## UI 实现规范（强制）

- UI 实现统一使用 `Shadcn + Cupertino` 组合。
- 组件与交互实现优先参考文档：`https://mariuti.com/flutter-shadcn-ui/llms.txt`。
