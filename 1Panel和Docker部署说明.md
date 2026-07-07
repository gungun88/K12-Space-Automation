# K12-Space-Automation 1Panel 和 Docker 部署说明

本文档对应当前仓库的实际运行方式，目标环境为 Debian 11/12 + Docker + Docker Compose + 1Panel。

## 1. 部署产物

根目录已新增以下文件：

- `Dockerfile`
- `.dockerignore`
- `docker-compose.yml`
- `.env.example`

## 2. 运行前提

服务器需要已安装：

- Docker
- Docker Compose
- 1Panel

建议服务器至少 2C4G。项目内含浏览器自动化流程，内存过低时容易触发 Chromium 异常。

## 3. 首次部署

### 3.1 拉取项目

```bash
git clone https://github.com/BFanSYe/K12-Space-Automation.git
cd K12-Space-Automation
```

### 3.2 准备运行目录和文件

以下路径是当前项目真实会写入的运行态数据，必须放在宿主机持久化：

- `data/`
- `json/`
- `auth/`
- `.web-data/`
- `config.json`
- `codex_register/config.json`
- `pool_tokens.txt`
- `2925-account.json`

初始化命令：

```bash
mkdir -p data json auth .web-data codex_register
test -f config.json || printf '{}\n' > config.json
test -f codex_register/config.json || printf '{}\n' > codex_register/config.json
test -f pool_tokens.txt || : > pool_tokens.txt
test -f 2925-account.json || printf '{}\n' > 2925-account.json
cp .env.example .env
```

说明：

- `data/config.json` 会在服务首次启动后自动生成。
- 根目录 `config.json` 是兼容 `codex_register` 模块所必需的配置文件，不能删除。
- 如果你不使用 `2925` 邮箱链路，`2925-account.json` 仍建议保留为空文件，避免后续容器挂载报错。

### 3.3 构建并启动

```bash
docker compose up -d --build
```

查看状态：

```bash
docker compose ps
docker compose logs -f --tail=200
```

## 4. 本机验证

容器默认只监听宿主机回环地址，不直接暴露公网端口。

```bash
curl http://127.0.0.1:8796/
curl http://127.0.0.1:8796/api/health
```

预期：

- `/` 返回前端页面
- `/api/health` 返回 `200`

## 5. 1Panel 反向代理配置

### 5.1 创建站点

在 1Panel 的网站管理中新增反向代理站点：

- 域名：例如 `k12.example.com`
- 代理地址：`http://127.0.0.1:8796`

### 5.2 推荐反代头

如果使用自定义 Nginx/OpenResty 配置，至少保留：

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

### 5.3 HTTPS 和访问控制

必须做：

- 在 1Panel 中为域名开启 HTTPS
- 不要直接开放 `8796` 到公网

建议至少启用一种额外保护：

- 1Panel Basic Auth
- IP 白名单
- Cloudflare Access
- Tailscale / ZeroTier 内网访问

## 6. 目录和持久化说明

当前 compose 已挂载以下路径：

- `./data:/app/data`
- `./json:/app/json`
- `./auth:/app/auth`
- `./.web-data:/app/.web-data`
- `./config.json:/app/config.json`
- `./codex_register/config.json:/app/codex_register/config.json`
- `./pool_tokens.txt:/app/pool_tokens.txt`
- `./2925-account.json:/app/2925-account.json`

这些路径中可能包含配置、Token、Cookie、任务记录和账号输出，不应提交到 Git，也不应打进镜像。

## 7. 容器实现说明

本次封装做了两项和部署直接相关的兼容处理：

- 服务继续使用 `npm run start`，容器内监听 `0.0.0.0:8796`
- 为 Debian 容器补齐了 Chromium 浏览器路径和启动参数，避免自动化任务在 Linux 容器中找不到浏览器

默认浏览器参数来自 `.env`：

```dotenv
SENTINEL_BROWSER_PATH=/usr/bin/chromium
SENTINEL_BROWSER_ARGS=--no-sandbox,--disable-dev-shm-usage
```

如果你的宿主机或基础镜像后续改成别的浏览器路径，改 `.env` 即可。

## 8. 更新方式

```bash
git pull
docker compose up -d --build
docker image prune -f
```

## 9. 备份方式

建议至少备份以下内容：

- `data/`
- `json/`
- `auth/`
- `.web-data/`
- `config.json`
- `codex_register/config.json`
- `pool_tokens.txt`
- `2925-account.json`
- `.env`

示例命令：

```bash
tar -czf k12-space-automation-backup-$(date +%F).tar.gz \
  data json auth .web-data config.json codex_register/config.json \
  pool_tokens.txt 2925-account.json .env
```

## 10. 常见问题

### 10.1 `/api/health` 正常，但自动化任务失败

这通常不是 Web 服务故障，而是运行环境问题。优先检查：

- 代理是否可用
- `config.json` / `codex_register/config.json` 是否填入真实配置
- 服务器内存是否足够
- `docker compose logs -f` 中是否出现 Chromium、Sentinel、proxy 相关报错

### 10.2 浏览器相关报错

当前镜像已安装 `chromium`，并默认使用：

```text
/usr/bin/chromium
```

如果你自定义了镜像或宿主环境，浏览器路径不一致时修改 `.env` 中的 `SENTINEL_BROWSER_PATH`。

### 10.3 端口冲突

如果宿主机 `8796` 被占用，修改 `.env`：

```dotenv
APP_PORT=8896
```

然后重新启动：

```bash
docker compose up -d
```
