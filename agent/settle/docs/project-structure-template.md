# Java DDD 微服务项目结构模板

## 1. 适用范围

本模板适用于：

- Spring Boot
- Maven
- Java 17+
- 微服务
- DDD

目标是提供一个团队可直接参考的项目目录基线。

## 2. 单模块分层模板

适合中小型服务或业务复杂度尚可控的场景。

```text
project-root
  |- pom.xml
  |- src
     |- main
     |  |- java
     |  |  |- com/company/trade
     |  |     |- interfaces
     |  |     |  |- rest
     |  |     |  |- rpc
     |  |     |  |- mq
     |  |     |  |- scheduler
     |  |     |  |- assembler
     |  |     |
     |  |     |- application
     |  |     |  |- service
     |  |     |  |- command
     |  |     |  |- query
     |  |     |  |- dto
     |  |     |  |- assembler
     |  |     |
     |  |     |- domain
     |  |     |  |- model
     |  |     |  |- service
     |  |     |  |- event
     |  |     |  |- repository
     |  |     |  |- factory
     |  |     |  |- valueobject
     |  |     |  |- specification
     |  |     |
     |  |     |- infrastructure
     |  |        |- persistence
     |  |        |  |- mapper
     |  |        |  |- repository
     |  |        |  |- dataobject
     |  |        |- rpc
     |  |        |- mq
     |  |        |- cache
     |  |        |- client
     |  |        |- config
     |  |
     |  |- resources
     |     |- application.yml
     |     |- mapper
     |     |- db
     |        |- migration
     |
     |- test
        |- java
        |  |- com/company/trade
        |     |- interfaces
        |     |- application
        |     |- domain
        |     |- infrastructure
        |
        |- resources
```

## 3. 多模块 Maven 模板

适合业务复杂、团队人数较多、边界需要更强约束的场景。

```text
project-root
  |- pom.xml
  |- trade-api
  |- trade-domain
  |- trade-application
  |- trade-infrastructure
  |- trade-entry
```

推荐职责：

- `trade-api`
  - 对外契约
  - RPC DTO
  - OpenAPI / protobuf / event schema

- `trade-domain`
  - 聚合
  - 实体
  - 值对象
  - 领域服务
  - Repository 接口

- `trade-application`
  - 用例编排
  - Command / Query
  - Application Service

- `trade-infrastructure`
  - Repository 实现
  - 数据库访问
  - MQ、RPC、缓存、外部 client

- `trade-entry`
  - REST Controller
  - RPC Provider
  - MQ Consumer
  - Scheduler
  - Spring Boot 启动
  - 装配
  - 配置

## 4. 推荐包命名

以 `com.company.trade` 为例：

```text
com.company.trade.interfaces.rest
com.company.trade.application.service
com.company.trade.domain.model
com.company.trade.infrastructure.persistence.repository
```

## 5. 示例类清单

```text
TradeOrderController
TradeOrderAppService
CreateTradeOrderCommand
TradeOrderPageQuery
TradeOrder
TradeOrderStatus
TradeOrderId
TradeOrderRepository
TradeOrderRepositoryImpl
TradeOrderMapper
TradeOrderDO
TradeOrderAssembler
TradeOrderCreatedEvent
```

## 6. resources 推荐结构

```text
src/main/resources
  |- application.yml
  |- application-dev.yml
  |- application-test.yml
  |- application-prod.yml
  |- mapper
  |- db/migration
  |- logback-spring.xml
```

## 7. test 推荐结构

建议测试目录与生产代码结构尽量镜像，便于定位：

```text
src/test/java/com/company/trade
  |- domain
  |- application
  |- interfaces
  |- infrastructure
```

## 8. Maven 模块依赖建议

推荐依赖方向：

```text
entry -> application -> domain
infrastructure -> domain
entry -> infrastructure
```

禁止反向依赖：

- `domain` 依赖 `entry`
- `domain` 依赖 `infrastructure`
- `application` 依赖 `entry`

## 9. 何时选单模块，何时选多模块

适合单模块：

- 团队规模较小
- 业务边界清晰但复杂度中等
- 当前目标是快速统一规范

适合多模块：

- 多人并行开发较多
- 模块边界需要强约束
- 领域复杂度高
- 需要更清晰的依赖治理

## 10. 落地建议

如果是存量项目：

1. 不要一次性重构全仓
2. 先从新增模块和新增功能开始遵守
3. 再逐步治理最混乱的模块

如果是新项目：

1. 直接选择单模块分层或多模块模板
2. 同步接入 `AGENTS.md`
3. 同步接入 `docs/code-rules.md`
4. 同步接入 `docs/engineering-rules.md`
5. 在 PR 模板中强制要求兼容性与风险说明
