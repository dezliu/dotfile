# Agent Progress Kanban

## 2026-04-23

- [done] `CLOUD_SERVICE_FEE_TUXI`（624/524/724）：对齐 `CABINET_OVERTIME_FEE_TUXI`——`OrderTypeEnum.CLOUD_SERVICE_FEE` + `CabinetOvertimeFeeOrderHandler`、`BillSettleCommandEnum`、`BillTypeAggEnum.EXPENSE_CLOUD_SERVICE_FEE_TUXI`、`BillDetailEnum`、`BillSettleCommand` 超期回执列表、`TradeBizTypeEnum` 代扣/结算、`StockSettleRecordCommand` resultType 624 税登文案、`OrderConsumer` 分账灰度订单类型、`OrderConfig.payOrderRePayList`、`WaitPayOrderRechargeJob`
- [note] 智能货架支付异步：`PayCommand#doTradeAsync` 用 `MqSendTopicConfig#useNewMessageType(billType.name(), recObject)`；Apollo `topic.mapping.generic-trade-type-map` 的 key 为 **BillTypeEnum 名**（如 `SMART_SHELF_ALLOWANCE`），与 `order.switch-new-creation` 是否新订单链路无关
- [done] 超期激励红包 `CABINET_OVERTIME_OPEN_ALLOWANCE`（703/382，账单 code/代扣 biz）：与 `SMART_SHELF_ALLOWANCE` 同设备补贴链路；`TradeBizTypeEnum` 侧业务码与代扣 382 对齐（未占用 `TradeBizTypeEnum` 的 703，因与广告分佣解冻码冲突）
- [done] 明确：`BillSettleCommand` 中广告分佣类 `sendCommissionFeeMessage` 回执不包含超期激励红包
- [done] `Bill.buildBillSettleTradeMessaage(BillConfig)`：GENERIC_TRADE 分支 billType 列表迁至 Apollo `bill.generic-settle-trade-bill-type-codes`，默认与原先硬编码一致（`BillConfig#resolveGenericSettleTradeBillTypeCodes`）

## 2026-04-21

- [done] 日账单创建链路日志：`BillSettleCommandEnum` + 三个 MQ 入口统一 `[日账单…]` 前缀与 billType/wallet/bizNo/command
- [done] `BillRule.billType` 改为 String 绑定 + `getBillType()` 惰性解析，兼容 Apollo 中较新枚举
- [done] `FailReDeductMessageHandlerImpl` 对无法解析的 rule 跳过，避免 NPE
- [done] `BillSettleCommandEnum`：Apollo 来源调整为 `bill.rules[*].billCreationCommandMap`（按 billType 命中规则，再按 walletType 取值）
- [done] `BillConfig`：`billCreationCommandMap` 注释增加 `OffLinePayExpenseBillCommand` 典型 Apollo 示例
- [done] 文档/日志：无 `BillSettleCommandEnum` 的新 `BillType` 须在 Apollo 配 `BillCreationCommand` 全类名；`newBillCreationCommand` 未命中时 `warn` 提示
- [todo] `settle/domain` 模块编译验证
- [done] 需求分析：`d:\doc\b0421\【需求文档】超期激励红包.md`（背景/范围/结算侧要点/待澄清项见对话）
- [done] 需求文档配图：已下载至 `D:\doc\workImage\`（`income-bill-app.png`、`balance-change-app.png`）；`docs.zto.com` 流程图链接 401 未取回，需内网登录后另存或换可匿名访问的地址
- [done] 超期激励红包端到端流程图：用户补充图已复制为 `D:\doc\workImage\chaoji-incentive-flowchart.png`，与结算域步骤对照见对话

## 2026-04-14

- [done] 识别需求：仅改造 `RechargeWaitPayOrderConsumer` 重试逻辑
- [done] 上下文确认：`PayOrderRedeductConsumer` 入参为 `PayOrderReDeductMq`
- [done] 代码改造：由直接发 `ORDER_PAY` 改为转发重扣消息到 `hst_pay_order_rededuct_kafka_topic`
- [done] 静态检查：已读取该文件 lint（仅存在原有 `getDepotCode()` 废弃告警）
- [todo] 编译验证：`settle/entry` 模块编译检查（待你触发或我继续执行）

## 2026-04-14（补充）

- [done] `PayOrderReDeductMq` 增加 `mqSource` 字段（与 `BillItemRechargePayMq` 一致，默认 `bigData`）
- [done] `RechargeWaitPayOrderConsumer` 转发重扣时设置 `mqSource=recharge`
- [done] `rechargeWaitPayRedeductPayStatusList` 抽到 `OrderConfig`（Apollo），默认仍为 PAY_FAIL/CREATE/PENDING_PAY
- [done] `CreateBillTest` 增加 `testRechargeWaitPayOrderConsumer` 集成调用单测
