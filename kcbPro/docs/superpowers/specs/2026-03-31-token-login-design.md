# Token Login Design

**Date:** 2026-03-31

## Goal

为课表系统增加“用户登录 + 短链接访问”能力。每个用户使用自己的教务系统账号登录一次后，系统生成一个 8 位 token 链接。后续用户通过该链接访问时，服务端从本地 SQLite 数据库读取该用户的学号与加密密码，解密后重新登录教务系统并拉取对应课表。

## Scope

本次设计只覆盖以下能力：

- 首页显示登录表单
- 提交学号与密码后生成 8 位 token
- 服务端使用 SQLite 保存 token 与加密后的账号密码
- 用户后续通过 `/t/<token>` 访问自己的课表
- 页面明确提示用户保存该短链接

本次不包含以下能力：

- 多设备同步或多机部署
- 第三方登录
- 权限分级
- token 过期回收策略
- 课表缓存优化

## Current Project Context

当前项目是一个 Flask 应用，主要结构如下：

- `/app.py`：提供首页与 `/api/schedule` 接口
- `/utils/crawler.py`：使用写死在 `config.py` 中的账号密码登录教务系统并抓取课表
- `/templates/index.html`：当前直接展示课表页面
- `/static/js/script.js`：前端调用 `/api/schedule` 拉取课表

当前问题是：

- 账号密码写死在配置文件中，只支持一个固定用户
- 没有登录表单
- 没有用户级持久化身份
- 没有短链接访问能力

## Recommended Approach

采用以下方案：

- 使用 SQLite 本地数据库保存 `token -> username + encrypted_password`
- 使用 `cryptography.fernet.Fernet` 加密密码
- 加密密钥通过服务器环境变量提供
- 每次访问 token 链接时，后端解密密码并实时登录教务系统获取课表

推荐这个方案的原因：

- 适合单台长期运行的自控服务器
- 不依赖额外数据库服务
- 相比直接存明文密码更安全
- 改动范围清晰，适合当前 Flask 项目体量

## User Flow

### First Visit

1. 用户访问 `/`
2. 页面展示登录表单，输入学号和密码
3. 浏览器提交到 `POST /login`
4. 后端尝试用该账号密码登录教务系统
5. 如果登录成功，生成 8 位 token，保存加密后的账号密码
6. 后端跳转到 `/t/<token>`
7. 页面展示课表，并提示用户保存该链接

### Later Visits

1. 用户直接访问 `/t/<token>`
2. 前端向 `/api/schedule/<token>` 请求数据
3. 后端根据 token 取出用户记录
4. 解密密码并登录教务系统
5. 获取并返回该用户课表
6. 页面正常展示课表

### Failure Cases

- token 不存在：页面提示链接无效，请重新登录
- 教务系统登录失败：提示登录失效，请重新登录生成新链接
- 网络超时：提示暂时无法获取课表
- 数据解密失败：提示服务器配置异常

## Architecture

### Route Layer

新增或调整以下路由：

- `GET /`
  - 渲染登录页面
- `POST /login`
  - 接收学号与密码
  - 调用教务登录验证
  - 生成 token
  - 加密密码并写入数据库
  - 跳转到 `/t/<token>`
- `GET /t/<token>`
  - 渲染课表页面外壳
  - 模板中注入 token
- `GET /api/schedule/<token>`
  - 根据 token 查找用户
  - 解密密码
  - 调用教务系统抓取课表
  - 返回 JSON
- `POST /logout/<token>`（可选）
  - 删除 token 记录

### Service Layer

建议新增独立模块，拆分责任：

- `utils/credential_store.py`
  - 初始化 SQLite 数据库
  - 插入、查询、删除 token 记录
  - 更新最后访问时间
- `utils/crypto.py`
  - 加载环境变量密钥
  - 提供密码加密与解密函数
- `utils/token_generator.py`
  - 生成唯一的 8 位 token
- `utils/crawler.py`
  - 改为接收 `username` 和 `password` 参数，而不是依赖 `config.py` 中的固定账号

### Template Layer

页面拆成两个视图更清晰：

- 登录页模板：显示登录表单与错误提示
- 课表页模板：显示课表、周选择器和“请保存此链接”的提示区域

如果不想拆成两个模板，也可以复用现有模板并通过变量切换模式，但从可维护性看，拆分更好。

## Data Model

SQLite 建议新增一张表 `saved_logins`：

- `token TEXT PRIMARY KEY`
- `username TEXT NOT NULL`
- `encrypted_password TEXT NOT NULL`
- `created_at TEXT NOT NULL`
- `last_accessed_at TEXT NOT NULL`

约束与规则：

- `token` 必须唯一，长度固定 8
- `username` 允许重复
- 创建记录时同时写入 `created_at` 与 `last_accessed_at`
- 每次成功访问 token 链接后更新 `last_accessed_at`

## Security Design

### Password Storage

- 数据库中不保存明文密码
- 使用 Fernet 进行对称加密后保存
- 环境变量名建议为 `CREDENTIAL_ENCRYPTION_KEY`

### Key Management

- 密钥只保存在服务器环境变量中
- 不写入仓库
- 不写入 SQLite
- 启动时若密钥缺失，服务直接报错并拒绝启动

### Token Characteristics

- token 长度固定 8 位
- 使用大小写字母与数字组合
- 只要拿到链接即可访问对应课表，这是已确认的产品要求

这意味着 token 本身就是访问凭证。因此 8 位 token 需要足够随机，避免简单枚举。

## API Behavior

### `POST /login`

请求字段：

- `username`
- `password`

成功行为：

- 验证账号密码有效
- 创建 token 并落库
- 302 跳转到 `/t/<token>`

失败行为：

- 留在登录页
- 显示“学号或密码错误”或“当前无法访问教务系统”

### `GET /api/schedule/<token>`

成功返回：

- 现有课表 JSON 结构
- 保留 `current_week`、`selected_week`、`grid` 等字段，减少前端改动

失败返回：

- `{ "error": "链接无效，请重新登录" }`
- `{ "error": "登录失效，请重新登录" }`
- `{ "error": "暂时无法获取课表" }`

## Frontend Behavior

### Login Page

登录页应包含：

- 学号输入框
- 密码输入框
- 登录按钮
- 错误提示区域

### Timetable Page

课表页在现有页面基础上增加：

- 页面顶部或显著位置显示当前访问链接
- 提示文案：
  - “登录成功。请保存此链接，下次可直接访问。”
- 可选复制按钮

前端请求地址需要从固定 `/api/schedule` 改为根据当前页面 token 访问 `/api/schedule/<token>`。

## Error Handling

### Invalid Token

- 用户访问不存在的 token 时，不返回空白页
- 应显示清晰错误信息，并提供返回登录页入口

### Crawler Login Failure

- 如果数据库中记录存在，但教务系统登录失败，向前端返回明确错误
- 前端显示重新登录提示，不继续渲染旧数据

### Encryption Failure

- 若解密异常，视为服务器配置问题
- 日志记录错误细节
- 前端只收到通用错误信息

## Testing Strategy

本次实现应至少覆盖以下测试点：

### Unit Tests

- token 生成为 8 位且字符集合法
- 加密后可正确解密
- 数据库存取流程正确
- 不存在的 token 查询返回空

### Integration Tests

- `POST /login` 成功后重定向到 `/t/<token>`
- 无效 token 访问 `/api/schedule/<token>` 返回错误 JSON
- 有效 token 时，接口能读取记录并调用课表抓取逻辑

### Manual Verification

- 首次访问显示登录页
- 输入正确账号密码后进入专属链接页
- 刷新专属链接仍可显示课表
- 页面中能看到“请保存链接”的提示

## Implementation Notes

- 现有 `config.py` 中的固定 `USERNAME` 与 `PASSWORD` 应从主流程中移除
- `utils.crawler.login_and_get_schedule()` 应改为参数化函数，例如：
  - `login_and_get_schedule(username, password)`
- `app.py` 需要把“首页直接展示课表”的逻辑改成“首页展示登录表单”
- 前端脚本需要支持从模板注入 token，并据此请求专属 API

## Risks And Tradeoffs

### Accepted Tradeoffs

- 使用 SQLite，未来多机部署需要迁移
- token 持有者可直接访问，这是已确认的需求
- 每次访问都重新登录教务系统，请求速度取决于教务系统响应

### Main Risks

- 如果服务器环境变量泄露，加密保护会失效
- 8 位 token 仍存在理论上的枚举风险，需要保证随机性足够高
- 教务系统验证码或登录流程变化会影响整条链路

## Final Design Summary

本方案将当前单用户、写死凭据的课表系统改为多用户短链接访问模式。核心实现是：

- 首页登录
- 登录成功后生成 8 位 token
- 本地 SQLite 保存 `token + username + encrypted_password`
- 访问 `/t/<token>` 时按 token 取回用户凭据，解密后实时登录教务系统并展示该用户课表

这样可以满足：

- 不同用户使用自己的账号
- 下次通过短链接直接访问
- 页面明确提示用户保存链接
