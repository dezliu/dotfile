# 直投分期：退换单与 `saveDeliveryInstallmentOrder` 处理逻辑

本文档说明应用层入口 `BizOrderAppServiceImpl#saveDeliveryInstallmentOrder` 如何编排直投分期订单，并重点区分 **支付单 / 退货单（含明细）/ 全量取消（无明细）/ 变更支付** 的差异。

## 1. 统一编排（应用层）

```text
validateParam → idptCheck → prepareData → calcAmount
→ queryHistoryOrder（事务外）
→ [事务] saveOrder → saveOrderDetail → dealHistoryOrder
→ sendOrderAfter（事务提交后）
```

对应实现：`settle/application/.../BizOrderAppServiceImpl.java`。

| 步骤 | 职责 |
|------|------|
| `validateParam` | 各 `Command` 上的参数与业务前置校验 |
| `idptCheck` | 按 `bizCode` 幂等：已存在分期主单则拒绝 |
| `prepareData` | 补全门店/老板名、合作商一级组织等；**退货子类**会加载原单并做强校验 |
| `calcAmount` | 计算订单金额与明细金额；**退货全量取消**固定为 0 |
| `queryHistoryOrder` | 查询同主单号下未完结历史分期及其待处理支付单（受 `closeFailedPeriods` 等影响） |
| `saveOrder` | 组装并持久化新 `InstallmentOrder` |
| `saveOrderDetail` | 批量写入明细；无明细时跳过 |
| `dealHistoryOrder` | 将历史待支付单置为不支付、关闭历史分期单、发汇总刷新消息 |
| `sendOrderAfter` | 默认发「结算收单」MQ；**全量取消**改为发「退款后置」消息 |

## 2. 消息入口与 Command 路由

Topic：`tuxi_hst_delivery_installment_order_topic`  
消费类：`DeliveryInstallmentOrderConsumer#getOrderCommand`。

| `operationType` | 条件 | 使用的 Command |
|-----------------|------|----------------|
| `REFUND(2)` | `orderDetailList` **为空** | `DeliveryInstallmentCancelOrderCommand`（全量取消） |
| `REFUND(2)` | `orderDetailList` **非空** | `DeliveryInstallmentRefundOrderCommand`（退货重算） |
| `CHANGE_PAY(3)` | — | `DeliveryInstallmentChangePayCommand` |
| `PAY(1)` | — | `DeliveryInstallmentOrderCommand` |
| 其他 | — | `null`（当前实现未防护，存在 NPE 风险） |

分布式锁：按 `orderCode` 加锁后再调用 `saveDeliveryInstallmentOrder`。

## 3. 退货单（有明细）：`DeliveryInstallmentRefundOrderCommand`

继承 `DeliveryInstallmentOrderCommand`，与支付单共用「历史单查询 + 事务内关单」能力。

### 3.1 `prepareData`（相对基类增量）

- 按 `orderCode` + 当前 `bizCode` 查**未完结**原分期，取 `id` 最大的一条作为 `sourceInstallmentOrder`。
- 校验与业务规则（不满足则抛错）：
  - 分期方式、年限、直投类型（若原单与消息均有值）须一致；
  - **按天**直投：不支持退货单；
  - **已提前还款**（`periodChangeType == 1`）：不支持；
  - **按周期计费**（`CYCLE_BILL`）：不支持退货单。
- `originalTotalPeriod`：兼容历史数据，优先原单 `originalTotalPeriod`，为 0 时用 `totalPeriod`。

### 3.2 `calcAmount`

- 用 `buildUnFinishPayOrderQuery`：仅统计 **`PENDING_PAY`**，且带 `lastPlanDate = new Date()`，即与「失败/支付中」期数无关（与变更支付里 `carryFailedPeriods` 分支不同）。
- `remainPeriod` = 待支付计划数量；再算剩余天数（月结用配置月天数 × 期数，日结用期数）。
- 按剩余天数 × 格口单价重算明细金额并汇总 `orderAmount`。

### 3.3 下游消息

- 重写 `buildOrderMessage` / `populateBill`，`splitRule` 中带 `remainPeriod`、`nextPlanDate` 等。
- `sendOrderAfter` 使用基类：向 `TUXI_HST_SETTLEMENT_RECEIVE_ORDER_TOPIC` 发送收单消息。

## 4. 全量取消（无明细）：`DeliveryInstallmentCancelOrderCommand`

继承 `DeliveryInstallmentRefundOrderCommand`，用于 **退货且不带明细**（消费者侧约定为整单取消场景）。

### 4.1 `calcAmount`

- `orderAmount = 0`。

### 4.2 `populateBill`

- 新分期单账单状态置为 **已结清**（`InstallmentBillStatusEnum.SETTLED`），与有明细退货的账单语义区分。

### 4.3 `sendOrderAfter`（重写）

- **仅当** `orderDetailList` 为空：不发收单 Topic，改为发送 `SettleMessageTypeEnum.INSTALLMENT_REFUND_AFTER`（`InstallmentRefundAfterEvent`，`bizCode` 为当前消息业务单号），走 `GENERIC_SETTLE_TOPIC`。
- 有明细时不会走到此类（路由到 `DeliveryInstallmentRefundOrderCommand`），此处 `else` 分支在现路由下基本不可达。

### 4.4 异步后置：`InstallmentRefundEventHandlerImpl`

- 根据当前 `bizCode` 查分期单，判断 `operationType` 是否为 **退货或变更支付**（`getCancelOriginalFlag`）。
- `prepareData`：再查同主单号下「进行中」的其它分期（排除逻辑以仓储为准）。
- `updateCancelPay`：对每条未完成分期调用 `InstallmentOrder#cancelPay`（待支付置 `NO_PAY`、分期单关单、发 `INSTALLMENT_REFRESH_SUMMARY`）。

说明：主流程里 `dealHistoryOrder` 已对历史分期与支付单做过一轮处理；后置 Handler 面向「退款/变更支付」场景的补充关单与汇总刷新，具体是否与主流程重复依赖数据状态与调用时序，排查问题时需两边对照。

## 5. MQ 体 `DeliveryInstallmentOrderMq.validateParam` 与退货

- `CHANGE_PAY` 在校验里**提前 return**，不要求 `installmentMethod`、`yearPeriod`、`boxLeasePrice` 等。
- **退货（REFUND）走「其他」分支**：仍要求 `installmentMethod`、`yearPeriod`、`boxLeasePrice` 等；与 `DeliveryInstallmentOrderCommand#validateParam` 组合：退货不要求必须带明细（支付单才强制明细非空）。

## 6. 与其它操作类型的关系（便于对照）

| 类型 | 典型 Command | 历史单处理 | 金额特点 |
|------|----------------|------------|----------|
| 支付 | `DeliveryInstallmentOrderCommand` | `closeFailedPeriods` 控制是否纳入失败期等 | 按年/天/周期规则 |
| 变更支付 | `DeliveryInstallmentChangePayCommand` | 依赖原单与 `carryFailedPeriods` | 剩余期数/天数重算（详见 [delivery-installment-change-pay-flow.md](./delivery-installment-change-pay-flow.md)） |
| 退货有明细 | `DeliveryInstallmentRefundOrderCommand` | 同基类 | 仅 `PENDING_PAY` 驱动剩余天数 |
| 全量取消 | `DeliveryInstallmentCancelOrderCommand` | 同基类 + 后置异步 | 金额为 0，新单 SETTLED |

## 7. 相关源码索引

| 说明 | 路径 |
|------|------|
| 应用层编排 | `settle/application/.../BizOrderAppServiceImpl.java` |
| 消费路由 | `settle/entry/.../DeliveryInstallmentOrderConsumer.java` |
| 基类流程与历史单 | `settle/domain/.../DeliveryInstallmentOrderCommand.java` |
| 退货有明细 | `settle/domain/.../DeliveryInstallmentRefundOrderCommand.java` |
| 全量取消 | `settle/domain/.../DeliveryInstallmentCancelOrderCommand.java` |
| 退款后置消费 | `settle/domain/.../msgHandler/InstallmentRefundEventHandlerImpl.java` |
| 分期关支付 | `settle/domain/.../InstallmentOrder.java`（`cancelPay`） |

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-04-15 | 初版：基于当前代码整理退换单与 `saveDeliveryInstallmentOrder` 编排说明。 |
| 2026-05-20 | 增加变更结算专项文档交叉引用。 |

*文档版本：与仓库代码同步整理，变更请以代码为准。*
