# code-rules.md

## 1. 文件定位

本文件定义企业级 Java 微服务 + DDD 项目的编码规范。

适用对象：

- Java 开发工程师
- 架构师
- 代码评审者
- AI 编程代理

本文件关注的是：

- 包结构怎么划分
- 类应该写在哪一层
- 命名怎么统一
- DTO / Entity / Domain Object 怎么分离
- 事务、仓储、异常、日志、测试怎么落地

目标不是“写得像教科书”，而是“团队能长期维护、系统能稳定演进”。

## 2. 基本原则

- 清晰优先于炫技
- 业务语义优先于技术技巧
- 兼容性优先于短期省事
- 小而清晰的类优先于巨型万能类
- 显式边界优先于隐式魔法
- 复用仓库既有模式优先于临时发明新风格

## 3. 标准项目结构模板

### 3.1 单服务推荐目录

```text
src/main/java/com/company/trade
  |- entry
  |  |- rest
  |  |  |- TradeOrderController.java
  |  |- rpc
  |  |  |- TradeOrderRpcService.java
  |  |- mq
  |  |  |- TradeOrderCreatedConsumer.java
  |  |- scheduler
  |  |  |- TradeOrderTimeoutScheduler.java
  |  |- assembler
  |     |- TradeOrderRequestAssembler.java
  |
  |- application
  |  |- service
  |  |  |- TradeOrderAppService.java
  |  |- command
  |  |  |- CreateTradeOrderCommand.java
  |  |- query
  |  |  |- TradeOrderPageQuery.java
  |  |- dto
  |  |  |- TradeOrderDTO.java
  |  |- assembler
  |     |- TradeOrderDTOAssembler.java
  |
  |- domain
  |  |- model
  |  |  |- TradeOrder.java
  |  |  |- TradeOrderLine.java
  |  |- service
  |  |  |- TradePricingDomainService.java
  |  |- event
  |  |  |- TradeOrderCreatedEvent.java
  |  |- repository
  |  |  |- TradeOrderRepository.java
  |  |- factory
  |  |  |- TradeOrderFactory.java
  |  |- valueobject
  |     |- TradeOrderId.java
  |     |- Money.java
  |
  |- infrastructure
     |- persistence
     |  |- repository
     |  |  |- TradeOrderRepositoryImpl.java
     |  |- mapper
     |  |  |- TradeOrderMapper.java
     |  |- dataobject
     |     |- TradeOrderDO.java
     |- rpc
     |- mq
     |- cache
     |- client
     |- config
```

### 3.2 多模块 Maven 推荐结构

```text
project-root
  |- pom.xml
  |- trade-api
  |- trade-domain
  |- trade-application
  |- trade-infrastructure
  |- trade-entry
  |- trade-bootstrap
```

如果当前仓库已经采用单模块分层结构，则不要强行拆成多模块。

## 4. DDD 分层编码规则

### 4.1 Entry 层

职责：

- 接收请求
- 做边界参数校验
- 组装 Command / Query
- 调用 Application Service
- 返回 Response DTO / VO

必须遵守：

- Controller 必须薄
- 不在 Controller 写业务规则
- 不在 Controller 拼 SQL
- 不直接返回 DO / PO / Entity
- 不把前端请求对象直接传入 Domain

推荐写法：

```java
@RestController
@RequestMapping("/api/trade/orders")
public class TradeOrderController {

    private final TradeOrderAppService tradeOrderAppService;

    @PostMapping
    public ApiResponse<Long> create(@Valid @RequestBody CreateTradeOrderRequest request) {
        CreateTradeOrderCommand command = TradeOrderRequestAssembler.toCommand(request);
        Long orderId = tradeOrderAppService.createOrder(command);
        return ApiResponse.success(orderId);
    }
}
```

### 4.2 Application 层

职责：

- 用例编排
- 事务控制
- 装载聚合
- 调用领域模型
- 保存聚合
- 发布事件

必须遵守：

- 一个 public 方法对应一个业务用例
- Application Service 不直接承载复杂业务规则
- 不直接写 SQL、Mapper 细节、HTTP 细节
- 事务边界优先放在应用层

推荐写法：

```java
@Service
public class TradeOrderAppService {

    private final TradeOrderRepository tradeOrderRepository;
    private final TradeOrderFactory tradeOrderFactory;

    @Transactional
    public Long createOrder(CreateTradeOrderCommand command) {
        TradeOrder tradeOrder = tradeOrderFactory.create(command);
        tradeOrder.submit();
        tradeOrderRepository.save(tradeOrder);
        return tradeOrder.getId().getValue();
    }
}
```

### 4.3 Domain 层

职责：

- 承载业务规则
- 表达业务状态与行为
- 保证不变量
- 定义聚合边界

必须遵守：

- 有规则的对象不能只是 getter/setter 数据壳
- 不变量必须在领域层保护
- 领域模型不依赖入口层 DTO 和持久化 DO
- 领域方法使用业务语言表达行为

推荐写法：

```java
public class TradeOrder {

    private TradeOrderId id;
    private TradeOrderStatus status;

    public void submit() {
        if (this.status != TradeOrderStatus.DRAFT) {
            throw new DomainException("只有草稿订单才能提交");
        }
        this.status = TradeOrderStatus.SUBMITTED;
    }

    public void cancel() {
        if (!this.status.canCancel()) {
            throw new DomainException("当前状态不允许取消");
        }
        this.status = TradeOrderStatus.CANCELLED;
    }
}
```

### 4.4 Infrastructure 层

职责：

- 持久化实现
- 外部系统集成
- 缓存/MQ/RPC 技术接入
- 配置与框架装配

必须遵守：

- Repository 接口在 domain，实现在 infrastructure
- DO / PO 仅表达存储结构
- 外部调用异常要转换并保留诊断信息
- 技术细节不反向污染领域模型

## 5. 命名规范模板

### 5.1 类命名

- Controller：`TradeOrderController`
- RPC 服务：`TradeOrderRpcService`
- MQ 消费者：`TradeOrderCreatedConsumer`
- Application Service：`TradeOrderAppService`
- Domain Service：`TradePricingDomainService`
- Repository 接口：`TradeOrderRepository`
- Repository 实现：`TradeOrderRepositoryImpl`
- Command：`CreateTradeOrderCommand`
- Query：`TradeOrderPageQuery`
- DTO：`TradeOrderDTO`
- Request：`CreateTradeOrderRequest`
- Response：`TradeOrderDetailResponse`
- DO：`TradeOrderDO`
- Event：`TradeOrderCreatedEvent`
- Factory：`TradeOrderFactory`
- Assembler：`TradeOrderAssembler`

### 5.2 方法命名

- 创建：`createOrder`
- 提交：`submit`
- 审核：`approve`
- 取消：`cancel`
- 获取详情：`getDetail`
- 分页查询：`pageOrders`
- 判断状态：`canCancel`
- 存在性判断：`existsByOrderNo`

### 5.3 禁止命名

禁止使用：

- `CommonUtil`
- `BaseManager`
- `DataProcessor`
- `HandleService`
- `doAction`
- `process`
- `updateInfo`

原因：

- 业务语义不清晰
- 评审困难
- 后续维护难以定位责任

## 6. DTO / Command / Domain / DO 分离规范

### 6.1 角色分工

- Request：接口入参
- Response：接口出参
- Command：应用层写请求对象
- Query：应用层读请求对象
- DTO：应用层返回或跨层传输对象
- Domain Object：领域模型
- DO / PO：数据库映射对象

### 6.2 强制要求

- 不能把 Request 直接当 Domain Model 用
- 不能把 DO 直接返回给前端
- 不能让 Domain 依赖 DO
- 复杂转换必须有 Assembler

### 6.3 推荐转换流

```text
Request -> Command -> Domain -> DO
DO -> Domain -> DTO -> Response
```

## 7. Repository 规范

Repository 必须表达“聚合持久化语义”，而不是“表操作大全”。

推荐接口：

```java
public interface TradeOrderRepository {

    void save(TradeOrder tradeOrder);

    Optional<TradeOrder> findById(TradeOrderId orderId);

    boolean existsByOrderNo(String orderNo);
}
```

不推荐接口：

```java
int updateStatusById(Long id, Integer status);
List<Map<String, Object>> selectByMap(Map<String, Object> params);
void saveOrUpdateAll(Object obj);
```

如果项目存在 CQRS 或专门查询模型，可以将复杂查询放入 query repository，但必须明确职责，不得混淆聚合仓储。

## 8. 事务规范

强制要求：

- 事务边界优先放在 Application Service
- 事务应围绕聚合一致性边界
- 跨服务流程不要依赖分布式大事务
- 远程调用、发消息、数据库写入顺序要经过设计

推荐原则：

- 单聚合内部强一致
- 跨服务通过事件最终一致
- 风险链路考虑补偿、重试、幂等

## 9. 异常规范

### 9.1 异常分类

建议统一分类：

- `ValidationException`
- `DomainException`
- `NotFoundException`
- `PermissionDeniedException`
- `IntegrationException`
- `InfrastructureException`

### 9.2 使用要求

- 不允许吞异常
- 不允许动不动直接抛 `RuntimeException`
- 包装异常必须保留原始 cause
- 对外错误信息要稳定、克制，不暴露内部实现

推荐写法：

```java
try {
    remoteClient.create(request);
} catch (Exception ex) {
    throw new IntegrationException("调用库存服务失败", ex);
}
```

## 10. 参数校验规范

校验责任划分：

- 入口层：参数格式、必填、长度、枚举值、基础合法性
- 应用层：用例完整性检查
- 领域层：业务不变量校验

禁止：

- 只依赖前端校验
- 只在 Controller 校验业务规则
- 在多个层重复写同一套复杂规则且没有统一来源

## 11. API 设计规范

### 11.1 基本要求

- 字段名清晰稳定
- 错误码有统一语义
- 支持可演进性
- 写接口优先考虑幂等
- 分页接口统一分页结构

### 11.2 写接口关注点

- 是否支持幂等
- 是否有重复提交保护
- 是否要记录审计日志
- 是否有状态流转约束

### 11.3 读接口关注点

- 返回对象是否与前端展示需求匹配
- 是否泄露内部技术字段
- 是否存在 N+1 查询或过度聚合

## 12. 并发与幂等规范

所有写操作默认都要考虑重试与重复调用。

至少明确：

- 幂等键是什么
- 是否允许重复请求
- 并发冲突怎么处理
- 锁粒度是什么
- 锁失败怎么处理

推荐顺序：

1. 先考虑乐观锁
2. 再考虑唯一约束
3. 再考虑幂等表/幂等键
4. 最后才是分布式锁

## 13. 日志规范

### 13.1 强制要求

- 日志必须可定位问题
- 日志不得输出敏感信息
- 使用参数化日志，不做字符串拼接
- 热路径不要刷屏 info

### 13.2 错误日志最少应包含

- 操作名
- 业务标识
- 失败原因
- 是否可重试

推荐写法：

```java
log.error("create trade order failed, orderNo={}, retryable={}", orderNo, false, ex);
```

## 14. 配置规范

- 环境差异必须通过配置体现，不通过代码分支体现
- 不能硬编码外部域名、topic、账号、秘钥
- 业务常量和环境配置要区分
- 默认值必须安全

## 15. 工具类规范

工具类必须少而精。

禁止：

- `CommonUtils`
- `BusinessUtils`
- `StringUtilsEx`
- `TradeHelper` 里塞满 unrelated 方法

如果逻辑有明确业务意义，应优先放入：

- Domain Service
- Factory
- Assembler
- Specification

## 16. 测试代码规范

### 16.1 测试命名

测试名应表达业务行为，而不是实现细节。

推荐：

- `should_submit_order_when_status_is_draft`
- `should_throw_exception_when_order_is_already_cancelled`

### 16.2 测试分层

- Domain：单元测试
- Application：服务测试
- Infrastructure：集成测试
- Entry：接口测试/契约测试

### 16.3 测试数据要求

- 数据要可读
- 尽量贴近业务场景
- 不要制造难懂的魔法常量

## 17. 注释规范

- 优先让代码自解释
- 仅在业务规则、外部约束、非直观设计点加注释
- 不写“把值赋给变量”这种废话注释

适合写注释的地方：

- 状态机约束
- 兼容性处理
- 双写/双读过渡逻辑
- 第三方系统特殊约束

## 18. 推荐技术栈默认值

若仓库未明确指定，可默认按以下思路理解：

- Spring Boot：服务启动框架
- Spring MVC：HTTP 接口
- MyBatis 或 JPA：持久化
- JUnit 5：测试
- AssertJ：断言
- Mockito：Mock

但一旦仓库已有既定技术选型，必须遵循仓库现状。

## 19. 企业级“好代码”定义

本仓库中的好代码，至少满足：

- 能被其他工程师快速读懂
- 分层职责明确
- 业务规则位置正确
- 对外契约稳定
- 可测试
- 可演进
- 可观测
- 不存在明显重复与隐式耦合
