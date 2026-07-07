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

这一节你可以理解为：先把项目下载下来，再准备几个必须存在的文件夹和空文件，最后启动容器。

### 3.1 拉取项目

先登录到你的 Debian 服务器终端。

建议把项目放在 `/opt` 目录，这样后面找项目、维护项目都会更清楚。

先执行：

```bash
cd /opt
git clone https://github.com/gungun88/K12-Space-Automation.git
cd /opt/K12-Space-Automation
```

如果你的系统提示没有权限进入 `/opt`，先执行：

```bash
sudo mkdir -p /opt
cd /opt
```

然后再执行上面的 `git clone` 命令。

为什么要先 `cd /opt`：

- `git clone` 会把项目下载到你“当前所在的目录”
- 先进入 `/opt`，项目就会被放到 `/opt/K12-Space-Automation`
- 这样后面你查找项目、更新项目、备份项目都会更方便

执行完以后，你当前应该已经进入项目目录。可以检查一下：

```bash
pwd
```

如果看到最后一段路径是 `K12-Space-Automation`，说明这一步没问题。

### 3.2 准备运行目录和文件

这一段最容易让新手看懵。你不用先理解每个文件的作用，先照着做就行。

下面这几条命令的作用只有两个：

- 创建程序运行时需要的文件夹
- 创建程序运行时需要的空文件

直接整段复制执行：

```bash
mkdir -p data json auth .web-data codex_register
test -f config.json || printf '{}\n' > config.json
test -f codex_register/config.json || printf '{}\n' > codex_register/config.json
test -f pool_tokens.txt || touch pool_tokens.txt
test -f 2925-account.json || printf '{}\n' > 2925-account.json
cp .env.example .env
chown -R 1000:1000 data json auth .web-data
chown 1000:1000 config.json codex_register/config.json pool_tokens.txt 2925-account.json
```

如果你想知道上面每一步在做什么，可以按下面理解：

- `mkdir -p data json auth .web-data codex_register`
  这条命令会创建 5 个文件夹。没有就创建，已经有了也不会报错。
- `config.json`
  这是主程序配置文件。先创建一个空的 `{}`，后面程序会往里写配置。
- `codex_register/config.json`
  这是 `codex_register` 模块自己的配置文件，也先创建一个空的 `{}`。
- `pool_tokens.txt`
  这是文本文件，用来保存 token。先建一个空文件即可。
- `2925-account.json`
  这是某条邮箱链路可能会用到的文件。即使你暂时不用，也建议先创建，避免 Docker 挂载时报错。
- `cp .env.example .env`
  这一步是把示例环境变量文件复制成正式的 `.env` 文件。后面如果要改端口、时区、浏览器路径，改这个文件就行。
- `chown -R 1000:1000 data json auth .web-data`
  这一步非常重要。它是把运行目录的属主改成容器里的应用用户，否则容器虽然能启动，但会因为没有写入权限不断重启。
- `chown 1000:1000 config.json codex_register/config.json pool_tokens.txt 2925-account.json`
  这一步是把几个会被程序写入的文件也交给容器用户。

执行完以后，建议你用下面命令检查一下文件是否已经准备好：

```bash
ls -la
ls -la codex_register
```

如果你能看到下面这些内容，说明 `3.2` 已完成：

- `data`
- `json`
- `auth`
- `.web-data`
- `config.json`
- `.env`
- `pool_tokens.txt`
- `2925-account.json`
- `codex_register/config.json`

如果你只想无脑照着部署，到这里就够了。下面这一段是补充说明，不看也可以继续。

如果你漏掉了上面的 `chown`，很可能会在 `docker compose ps` 里看到容器一直 `Restarting`，日志里出现 `EACCES: permission denied`。这不是程序坏了，而是目录权限不对。

这些路径是当前项目真实会写入的运行态数据，之所以要提前准备，是因为 Docker 会把它们挂载到容器里，保证你以后重启、升级容器时数据不会丢：

- `data/`
- `json/`
- `auth/`
- `.web-data/`
- `config.json`
- `codex_register/config.json`
- `pool_tokens.txt`
- `2925-account.json`

说明：

- `data/config.json` 会在服务首次启动后自动生成。
- 根目录 `config.json` 是兼容 `codex_register` 模块所必需的配置文件，不能删除。
- 如果你不使用 `2925` 邮箱链路，`2925-account.json` 仍建议保留为空文件，避免后续容器挂载报错。

### 3.3 构建并启动

文件准备好后，执行下面命令启动：

```bash
docker compose up -d --build
```

这条命令的意思是：

- `build`：先构建镜像
- `up -d`：然后在后台启动容器

第一次启动通常会比较慢，等几分钟都正常。

查看状态：

```bash
docker compose ps
docker compose logs -f --tail=200
```

你可以这样理解这两条命令：

- `docker compose ps`
  看容器有没有启动成功
- `docker compose logs -f --tail=200`
  实时看最近 200 行日志，方便判断有没有报错

如果看到类似下面的信息，一般说明服务已经启动成功：

```text
K12 console API listening: http://0.0.0.0:8796/
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

如果你看不懂返回内容，记住一个最简单的判断方法：

- 只要 `curl http://127.0.0.1:8796/api/health` 没报错，并且返回里带有 `ok`，就说明程序基本已经跑起来了。

## 5. 1Panel 反向代理配置

### 5.1 创建站点

在 1Panel 的网站管理中新增反向代理站点：

- 域名：例如 `k12space.doingfb.com`
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
