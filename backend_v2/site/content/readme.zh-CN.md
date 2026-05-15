# HueKcbPro

HueKcbPro 是一个面向湖北第二师范学院课表场景的课表系统，包含原生 Flutter 客户端和面向部署的 FastAPI 后端。这个项目重点解决的是课表访问速度、缓存兜底可用性，以及 Android 发布与后端部署的工程化落地。

## 下载

Android 安装包已经构建并发布到 GitHub Releases，可以直接下载使用。

- [下载最新版本](https://github.com/QingShuishui/HueKcbPro/releases/latest)
- [查看全部 Releases](https://github.com/QingShuishui/HueKcbPro/releases)

## 项目优势

- 使用原生 Flutter 课表界面，而不是简单的 WebView 壳应用
- 支持实时刷新获取最新课程表，减少课程调课带来的信息滞后
- 在网络异常或后端缓存过期时提供缓存课表兜底与提醒机制
- 支持会话恢复，在离线刷新失败时仍可尽量保留本地访问能力
- 后端采用 Docker 化部署，包含 API、数据库、缓存、任务队列和调度组件
- 具备面向实际交付的 Android 发布与后端镜像发布流程

## 技术栈

### 移动端

- Flutter
- Dart
- Riverpod 状态管理
- Dio 网络请求
- Flutter Secure Storage 凭证与令牌存储
- Path Provider / Package Info Plus 本地持久化与应用元数据

### 后端

- FastAPI
- PostgreSQL
- Redis
- Celery Worker 与 Beat 调度
- Docker / Docker Compose

### 交付与发布

- GitHub Actions
- GitHub Releases
- GitHub Container Registry
- Android Release 工作流

## 架构说明

当前仓库主要包含一个原生移动端和一个 Docker 化后端服务：

- `lib/`：Flutter 应用源码
- `test/`：Flutter 单元测试与组件测试
- `backend_v2/`：当前使用的 FastAPI 后端、Docker 配置与部署文档
- `backend/`：保留在仓库中的早期后端实现
- `.github/workflows/`：Android 发布与后端镜像发布工作流

运行时，Flutter 客户端通过后端 API 完成登录认证、课表拉取、刷新请求和更新元数据获取。当前后端栈使用 PostgreSQL 存储核心数据，Redis 提供缓存和队列基础设施，Celery 负责后台任务处理。

## 快速开始

### Flutter 客户端

```bash
flutter pub get
flutter run
```

### 后端

```bash
cd backend_v2
docker compose up --build
```

## 部署

当前后端的生产部署说明见 [`backend_v2/DEPLOY.md`](./backend_v2/DEPLOY.md)。

后端发布镜像通过 GitHub Actions 发布到：

```text
ghcr.io/qingshuishui/kcb-backend-v2
```

## 开源协议

本项目采用 GNU General Public License v3.0（GPL-3.0）开源。

如果你分发本项目的修改版本，通常也需要按照 GPL-3.0 提供对应源码。

完整协议见 [LICENSE](./LICENSE)。
