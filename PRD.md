# K12-Space-Automation Docker 部署封装 PRD

## 1. 背景

项目地址：https://github.com/BFanSYe/K12-Space-Automation

当前项目是一个带前端控制台和 Node.js 后端 API 的自动化工具。计划部署到自有 Debian 服务器，服务器已安装 1Panel 面板，后续通过 1Panel / Nginx 使用域名反向代理访问。

本 PRD 的目标是让开发者或 Codex 在现有项目基础上完成 Docker 化封装，使项目可以稳定运行在 Debian + Docker + 1Panel 环境中。

## 2. 部署目标

实现以下能力：

1. 使用 Docker 构建并运行项目。
2. 提供 `Dockerfile`、`.dockerignore`、`docker-compose.yml` 和部署说明文档。
3. 容器内默认监听项目原有服务端口，建议为 `8796`。
4. 支持通过 1Panel 创建反向代理，域名转发到容器服务。
5. 所有运行数据、配置文件、任务输出和日志必须持久化，容器重建或升级后不能丢失。
6. 不改变项目现有业务逻辑、接口路径、前端页面和数据结构。

## 3. 非目标

本次不做以下内容：

1. 不重构前端或后端业务代码。
2. 不修改 K12 自动化流程逻辑。
3. 不内置第三方账号、Cookie、Token、API Key。
4. 不把敏感配置写死到镜像里。
5. 不强依赖 1Panel 插件市场，只要求 Docker Compose 可部署。
6. 不做 Kubernetes、Swarm 或多节点部署。

## 4. 当前假设

开发前需要先检查仓库实际文件，以下是基于项目说明的初步假设：

1. 项目使用 Node.js，推荐运行时为 Node.js 22。
2. 前端为 Vue 3 / Vite，后端入口类似 `server/index.ts`。
3. 项目构建命令预计为：

```bash
npm ci
npm run build
```

4. 项目启动命令预计为：

```bash
npm run start
```

5. 服务默认端口预计为 `8796`。
6. 运行时可能涉及以下持久化路径或文件：

```text
data/
json/
config.json
codex_register/config.json
logs/
```

如果实际仓库存在差异，以仓库内 `package.json`、README 和服务端代码为准。

## 5. 目标服务器环境

目标环境：

```text
系统：Debian 12 或 Debian 11
面板：1Panel
运行方式：Docker / Docker Compose
反向代理：1Panel 自带 OpenResty / Nginx
域名：用户自行绑定
HTTPS：由 1Panel 申请或导入证书
```

容器不需要直接暴露到公网，只需要让 1Panel 的反向代理访问本机端口。

## 6. 交付物

需要在项目根目录新增或完善以下文件：

```text
Dockerfile
.dockerignore
docker-compose.yml
docs/docker-deploy.md
```

可选新增：

```text
.env.example
```

如果项目已有同名文件，应在保留原意的基础上修改，不要覆盖掉用户已有配置。

## 7. Dockerfile 要求

### 7.1 基础镜像

建议使用：

```dockerfile
node:22-bookworm-slim
```

如果构建依赖需要编译原生模块，可按需安装：

```bash
python3
make
g++
```

如果不需要，尽量保持镜像精简。

### 7.2 构建方式

优先使用多阶段构建：

1. `deps` 阶段安装依赖。
2. `builder` 阶段执行 `npm run build`。
3. `runner` 阶段只保留运行所需文件。

必须使用 `npm ci`，除非项目没有 `package-lock.json`。如果没有 lock 文件，再使用 `npm install`。

### 7.3 运行用户

容器内不要使用 root 用户运行应用。建议创建普通用户：

```text
app
```

运行目录：

```text
/app
```

### 7.4 端口

容器内暴露：

```text
8796
```

如果项目支持通过环境变量设置端口，应支持：

```text
PORT=8796
HOST=0.0.0.0
```

如果当前项目只监听 `127.0.0.1`，需要改为容器内可访问的 `0.0.0.0`，但不能改变接口行为。

### 7.5 启动命令

默认启动命令建议：

```dockerfile
CMD ["npm", "run", "start"]
```

如果项目实际生产启动命令不是这个，以 `package.json` 为准。

## 8. Docker Compose 要求

`docker-compose.yml` 需要满足以下要求：

1. 服务名建议为 `k12-space-automation`。
2. 容器名建议为 `k12-space-automation`。
3. 默认映射宿主机端口：

```text
127.0.0.1:8796:8796
```

注意：只绑定 `127.0.0.1`，不要默认暴露 `0.0.0.0:8796`，避免绕过 1Panel 反代直接公网访问。

4. 配置自动重启：

```yaml
restart: unless-stopped
```

5. 配置持久化卷：

```yaml
volumes:
  - ./data:/app/data
  - ./json:/app/json
  - ./config.json:/app/config.json
  - ./codex_register/config.json:/app/codex_register/config.json
  - ./logs:/app/logs
```

实际路径需要开发时确认。如果某些文件不存在，启动前应通过文档提示用户创建，或在 entrypoint 中安全初始化空文件。

6. 支持 `.env`：

```yaml
env_file:
  - .env
```

7. 建议增加 healthcheck：

```yaml
healthcheck:
  test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:8796/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

如果项目没有 `/api/health`，需要确认已有健康检查接口；没有则新增一个非常简单的健康检查接口，不影响业务逻辑。

## 9. .dockerignore 要求

至少排除：

```text
node_modules
dist
.git
.env
.env.*
npm-debug.log
Dockerfile
docker-compose.yml
README*.md
data
json
logs
*.zip
*.tar
*.tar.gz
```

注意：不要把本地敏感配置、运行数据、Cookie、Token、日志打入镜像。

## 10. 配置与敏感数据要求

必须遵守：

1. 镜像里不能包含真实 `config.json`、Cookie、Token、API Key、邮箱池数据。
2. `.env.example` 只能放示例值。
3. `.env` 必须加入 `.gitignore`。
4. Docker Compose 中默认只挂载本地目录或文件。
5. 文档中明确提醒用户备份以下内容：

```text
data/
json/
config.json
codex_register/config.json
logs/
.env
```

## 11. 1Panel 反向代理要求

文档中需要写清楚 1Panel 配置方式：

1. 在 1Panel 网站管理中创建反向代理网站。
2. 域名填写用户自己的域名，例如：

```text
k12.example.com
```

3. 代理目标：

```text
http://127.0.0.1:8796
```

4. 开启 HTTPS。
5. 建议开启 Basic Auth 或 IP 白名单。
6. 如果接口使用 WebSocket，需要确认 Nginx 已转发 Upgrade 头。

推荐 Nginx 代理头：

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

## 12. 安全要求

必须在部署文档中明确：

1. 不建议公网直接访问 `http://服务器IP:8796`。
2. Compose 默认只绑定 `127.0.0.1`。
3. 域名访问必须配置 HTTPS。
4. 后台控制台涉及账号、Token、Cookie、任务数据，必须加访问控制。
5. 建议至少使用一种保护方式：

```text
1Panel Basic Auth
IP 白名单
Cloudflare Access
Tailscale / ZeroTier 内网访问
```

6. 日志中如果可能出现敏感信息，后续应考虑脱敏，但本次不是强制目标。

## 13. 部署文档要求

`docs/docker-deploy.md` 需要包含以下步骤：

### 13.1 克隆项目

```bash
git clone https://github.com/BFanSYe/K12-Space-Automation.git
cd K12-Space-Automation
```

### 13.2 准备配置和目录

```bash
mkdir -p data json logs codex_register
touch config.json
touch codex_register/config.json
cp .env.example .env
```

如果空 JSON 会导致项目启动失败，应写入：

```json
{}
```

### 13.3 构建并启动

```bash
docker compose up -d --build
```

### 13.4 查看状态

```bash
docker compose ps
docker compose logs -f
```

### 13.5 本机验证

```bash
curl http://127.0.0.1:8796/
curl http://127.0.0.1:8796/api/health
```

### 13.6 反向代理

说明 1Panel 中将域名代理到：

```text
http://127.0.0.1:8796
```

### 13.7 更新项目

```bash
git pull
docker compose up -d --build
docker image prune -f
```

### 13.8 备份

```bash
tar -czf k12-backup-$(date +%F).tar.gz data json logs config.json codex_register/config.json .env
```

## 14. 代码改动边界

允许的改动：

1. 增加 Docker 相关文件。
2. 增加部署文档。
3. 如果服务端只监听 `127.0.0.1`，允许改成支持 `HOST=0.0.0.0`。
4. 如果没有健康检查接口，允许新增只返回状态的 `/api/health`。
5. 如果启动时持久化目录不存在，允许增加安全的目录初始化逻辑。

不允许的改动：

1. 不改自动化业务流程。
2. 不改现有 API 返回结构。
3. 不改前端交互逻辑。
4. 不删除现有配置文件或示例文件。
5. 不提交真实敏感数据。

## 15. 验收标准

完成后必须满足：

1. 在全新 Debian 服务器上，只安装 Docker 和 Docker Compose 即可部署。
2. 执行以下命令成功：

```bash
docker compose up -d --build
```

3. 容器状态为 healthy 或 running。
4. 本机访问成功：

```bash
curl http://127.0.0.1:8796/
```

5. 如果实现了健康检查：

```bash
curl http://127.0.0.1:8796/api/health
```

应返回 200。

6. 通过 1Panel 域名反代可以打开前端控制台。
7. 重启容器后配置和数据仍存在。
8. 执行 `docker compose down` 再 `docker compose up -d` 后数据仍存在。
9. 镜像中不包含 `.env`、真实 `config.json`、Cookie、Token、运行日志和任务输出。
10. README 或 `docs/docker-deploy.md` 中有明确部署、更新、备份和安全说明。

## 16. 推荐测试流程

开发完成后按以下顺序测试：

1. 本地检查：

```bash
npm ci
npm run build
```

2. Docker 构建：

```bash
docker compose build --no-cache
```

3. Docker 启动：

```bash
docker compose up -d
```

4. 查看日志：

```bash
docker compose logs --tail=200
```

5. 访问服务：

```bash
curl -I http://127.0.0.1:8796/
```

6. 验证持久化：

```bash
docker compose restart
docker compose down
docker compose up -d
```

7. 检查镜像是否误包含敏感文件：

```bash
docker run --rm k12-space-automation sh -lc "find /app -maxdepth 3 -type f | sort"
```

## 17. 建议的最终文件结构

```text
K12-Space-Automation/
  Dockerfile
  docker-compose.yml
  .dockerignore
  .env.example
  docs/
    docker-deploy.md
  data/
  json/
  logs/
  config.json
  codex_register/
    config.json
```

其中 `data/`、`json/`、`logs/`、`config.json`、`codex_register/config.json` 是运行时数据或配置，不能打进镜像，应该由宿主机挂载。

## 18. 给开发 Codex 的执行提示词

可以把下面这段直接发给另一个 Codex：

```text
请阅读当前仓库，按照 PRD.md 为 K12-Space-Automation 增加 Docker 部署支持。

重点要求：
1. 新增或完善 Dockerfile、.dockerignore、docker-compose.yml、docs/docker-deploy.md、可选 .env.example。
2. 不修改业务逻辑，只做容器化、健康检查、端口监听和部署文档相关的最小改动。
3. Compose 默认只绑定 127.0.0.1:8796:8796，方便 1Panel / Nginx 反向代理，不要默认公网暴露端口。
4. data、json、logs、config.json、codex_register/config.json 等运行数据必须持久化。
5. 镜像中不能包含真实敏感配置、Cookie、Token、API Key、日志和任务输出。
6. 完成后运行 npm 构建和 docker compose 构建测试，并说明验证结果。
```

