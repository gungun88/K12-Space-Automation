# K12 Space Automation

[中文](README.md) | English

K12 Space Automation is a local K12 workspace automation console for mailbox pool management, email OTP flows, K12 workspace join/switch tasks, Sub2API imports, access-token checks/repairs, and account JSON export.

This repository contains source code, documentation, configuration templates, and lock files only. It does not include real runtime configuration, tokens, cookies, mailbox refresh tokens, account JSON files, or task data by default. Do not commit real credentials or local runtime data, even when the repository is private.

## Features

- Mailbox pool management: import, select, delete, status marking, and retry.
- OTP handling: mailbox URL, manual OTP, SMSBower Gmail, and Emailnator Gmail.
- K12 flow: login, join or switch K12 workspace, and read K12-context access tokens.
- Sub2API: OAuth import, noRT import, account liveness check, and access-token repair.
- JSON output: SUB2API and CPA account JSON formats.
- Data migration: import/export local configuration, mailbox pool, tasks, and token data packages.
- Task management: batch start, cancel, retry, clear failed tasks, pagination, status, and logs.

## Architecture

- `src/`: Vue 3 web console entry and UI logic.
- `server/index.ts`: local HTTP API server for task scheduling, configuration persistence, mailbox state, K12 flows, Sub2API calls, and JSON output.
- `codex_register/`: lower-level automation toolkit for registration, OAuth, mailboxes, SMS, Sentinel, Sub2API, CPA, and standalone web tools.
- `codex_register/config.example.json`: committable configuration template. Copy it to `codex_register/config.json` before filling real values.
- `public/`, `index.html`, `vite.config.ts`: Vite frontend assets and build configuration.
- `data/`, `json/`, `pool_tokens.txt`, `config.json`: runtime data and local configuration. These paths are ignored and are not part of the repository payload.

## Requirements

- Node.js 20+, Node.js 22+ recommended.
- npm 10+.
- Network access to the services you configure.
- Optional HTTP or SOCKS proxy.

## Install and Run

### 1. Prepare a Fresh Ubuntu/VPS Server

The steps below target a fresh Ubuntu server. For local development, skip to “Local Development Mode”.

Install basic tools:

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
```

Install Node.js 22 and npm with the NodeSource Node.js 22.x APT repository. If your server already has Node.js 20+, you may only run the version checks:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh
sudo -E bash /tmp/nodesource_setup.sh
sudo apt install -y nodejs

node -v
npm -v
```

Requirements:

- `node -v` should be `v20.x` or newer, `v22.x` recommended.
- `npm -v` should be `10.x` or newer.

NodeSource reference: <https://github.com/nodesource/distributions/blob/master/DEV_README.md>.

### 2. Clone the Repository

This is a private repository. The server must have GitHub access to `BFanSYe/K12-Space-Automation` through an HTTPS token, GitHub CLI login, or an SSH key.

HTTPS:

```bash
mkdir -p ~/apps
cd ~/apps
git clone https://github.com/BFanSYe/K12-Space-Automation.git
cd K12-Space-Automation
```

SSH:

```bash
mkdir -p ~/apps
cd ~/apps
git clone git@github.com:BFanSYe/K12-Space-Automation.git
cd K12-Space-Automation
```

If `git clone` fails with a permission error, fix the GitHub credentials on the server. Do not write GitHub tokens into repository files.

### 3. Install Dependencies and Build

```bash
npm install
npm run build
```

`npm run build` runs type checks and creates the `dist/` frontend bundle. Production mode requires this build; otherwise the web page may return 404.

### 4. Foreground Smoke Test

```bash
npm run start
```

A successful startup prints output similar to:

```text
K12 console API listening: http://0.0.0.0:8796/
```

Default URLs:

- On the server: `http://127.0.0.1:8796/`
- From another machine: `http://SERVER_IP:8796/`

In production mode, `npm run start` serves the built `dist/` frontend directly from the API server. Only port `8796` is needed by default. Port `5174` is for the Vite development server and usually should not be exposed in production.

If the page is not reachable:

```bash
curl http://127.0.0.1:8796/api/health
sudo ufw allow 8796/tcp
sudo ufw status
```

Also confirm that your cloud security group allows TCP `8796`.

### 5. Run in the Background with PM2

Install PM2:

```bash
sudo npm install -g pm2
```

Start the service from the project root:

```bash
cd ~/apps/K12-Space-Automation
pm2 start npm --name k12-space-automation -- run start
```

Common commands:

```bash
pm2 status
pm2 logs k12-space-automation
pm2 restart k12-space-automation
pm2 stop k12-space-automation
```

Enable startup on boot:

```bash
pm2 save
pm2 startup
```

`pm2 startup` prints a `sudo env ...` command. Copy and run that command once.

Recommended update flow:

```bash
cd ~/apps/K12-Space-Automation
git pull
npm install
npm run build
pm2 restart k12-space-automation
```

To change the port, set `PORT` when starting the process:

```bash
PORT=8899 pm2 start npm --name k12-space-automation -- run start
```

### 6. Optional: Nginx Reverse Proxy

Skip this section if `http://SERVER_IP:8796/` is enough. For domain-based access, proxy Nginx to local port `8796`.

Install Nginx:

```bash
sudo apt install -y nginx
```

Create a site configuration. Replace `example.com` with your domain:

```bash
sudo tee /etc/nginx/sites-available/k12-space-automation >/dev/null <<'NGINX'
server {
    listen 80;
    server_name example.com;

    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:8796;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/k12-space-automation /etc/nginx/sites-enabled/k12-space-automation
sudo nginx -t
sudo systemctl reload nginx
```

`http://example.com/` should now open the console. For HTTPS, add TLS with certbot or your existing certificates after the reverse proxy works.

### 7. Local Development Mode

Development mode starts both the API server and the Vite frontend server:

```bash
npm run dev
```

Default URLs:

- Web console: `http://127.0.0.1:5174/`
- API server: `http://127.0.0.1:8796/`

Vite proxies `/api` requests to `8796`. This mode is for development and debugging, not long-running VPS production deployments.

Common scripts:

```bash
npm run server    # Start the local API server only
npm run frontend  # Start the Vite web console only
npm run build     # Type-check and build the frontend
npm run preview   # Preview the built frontend
npm run start     # Start the local API server and serve dist/
```

### 8. First Configuration and Troubleshooting

After the first startup, open the web console and fill Settings for proxy, workspace, Sub2API, OTP, and JSON output. Saved runtime configuration is written to:

- `data/config.json`
- `config.json`

For standalone tools under `codex_register/`, copy the template when needed:

```bash
cp codex_register/config.example.json codex_register/config.json
```

Do not commit real configuration or runtime data, including tokens, cookies, mailbox refresh tokens, account JSON files, `config.json`, `data/`, `json/`, or `pool_tokens.txt`.

Common issues:

- `npm: command not found`: Node.js/npm is not installed or not on `PATH`; rerun the Node.js installation steps and check `node -v`, `npm -v`.
- `Cannot find module`: dependencies are incomplete; rerun `npm install` from the project root.
- 404 or blank page: run `npm run build` before `npm run start` or restart PM2 after rebuilding.
- Page unreachable: check `pm2 status`, `pm2 logs k12-space-automation`, `curl http://127.0.0.1:8796/api/health`, security groups, and firewall rules.
- Port already in use: set another `PORT` or stop the process using `8796`.
- PM2 cannot find local configuration: start PM2 from the project root, not another directory.

## Configuration

The main configuration is saved from the Settings page in the web console. Runtime writes:

- `data/config.json`: current console configuration.
- `config.json`: root-level compatibility configuration for legacy flows.

Standalone tools under `codex_register/` read `codex_register/config.json`. For first use:

```bash
cp codex_register/config.example.json codex_register/config.json
```

Common fields:

| Field | Description |
| --- | --- |
| `port` | API server port, default `8796`. |
| `defaultProxyUrl` | Proxy for OpenAI/Auth requests. Supports `direct`, HTTP, and SOCKS. |
| `openaiProxyUrls` | Rotating proxy list for OpenAI/Auth requests. |
| `mailApiBaseUrl` | Base URL for four-part mailbox OTP APIs. |
| `workspaceIds` | K12 workspace ID list. |
| `route` | K12 workspace route, `request` or `accept`. |
| `taskConcurrency` | Task concurrency. |
| `runWorkspaceJoin` | Whether to run the K12 join/switch flow. |
| `runSub2Api` | Whether to import accounts into Sub2API. |
| `sub2apiNoRtMode` | Whether to use noRT import mode. |
| `sub2apiUrl` | Sub2API service URL. |
| `sub2apiEmail` | Sub2API admin email. |
| `sub2apiPassword` | Sub2API admin password. |
| `sub2apiGroupName` | Target Sub2API group. |
| `sub2apiProxyName` | Sub2API proxy name. |
| `sub2apiAccountPriority` | Sub2API account priority. |
| `sub2apiConcurrency` | Sub2API import concurrency. |
| `sub2apiAutoRefillEnabled` | Enable automatic Sub2API refill. |
| `sub2apiRefillGroupName` | Group checked by automatic refill. |
| `sub2apiRefillThreshold` | Automatic refill threshold. |
| `sub2apiRefillEmailCount` | Mailbox count used for automatic refill. |
| `sub2apiRefillIntervalMs` | Automatic refill interval. |
| `sub2apiRefillDeepCheckEnabled` | Enable deep liveness checks for automatic refill. |
| `gmailMailProvider` | Dynamic Gmail provider, `smsbower` or `emailnator`. |
| `smsBowerMailEnabled` | Enable SMSBower Gmail OTP. |
| `smsBowerApiKey` | SMSBower API key. |
| `smsBowerMailBaseUrl` | SMSBower mail API URL. |
| `smsBowerMailService` | SMSBower mail service name. |
| `smsBowerMailDomain` | SMSBower mail domain. |
| `smsBowerMailMaxPrice` | Maximum SMSBower mail price. |
| `smsBowerGmailFissionEnabled` | Enable SMSBower Gmail fission child-mailbox tasks. |
| `smsBowerGmailFissionCount` | Fission count per Gmail mailbox. |
| `emailnatorBaseUrl` | Emailnator service URL. |
| `emailnatorEmailType` | Emailnator mailbox type. |
| `requireChatgptAccountId` | Require ChatGPT account ID in access tokens. |
| `tokenOut` | Access-token output file, default `pool_tokens.txt`. |
| `jsonOutDir` | Account JSON output directory, default `json/`. |
| `jsonOutFormat` | JSON output format, `sub2api` or `cpa`. |

## Task Flow

1. Open the web console.
2. Fill Settings and confirm proxy, workspace, Sub2API, and OTP settings.
3. Import a mailbox pool or enable dynamic Gmail OTP.
4. Configure task count, concurrency, K12 workspace flow, Sub2API/noRT, and JSON output.
5. Start tasks and inspect status, logs, access-token summaries, and output paths.
6. Retry failed tasks after reading logs, or lower concurrency before rerunning.
7. Use data import/export for local state migration. Do not use Git for runtime data.

## Sensitive File Boundary

The following files or directories may contain passwords, API keys, mailbox refresh tokens, access tokens, cookies, OAuth data, mailbox pools, account JSON files, or task logs. They should not be committed, even to a private repository:

```text
config.json
codex_register/config.json
data/
json/
pool_tokens.txt
auth/
k12-basic-auth*
.env
.env.*
*.pem
*.key
*.crt
*.log
```

Before committing, check:

```bash
git status --short --ignored
git ls-files | rg '(^|/)(data|json|auth|pool_tokens|config\.json|k12-basic-auth|\.env|.*\.pem|.*\.key)'
```

The second command should produce no output. `codex_register/config.example.json` is a template and may be committed.

## FAQ

### `EmailOtpValidate wrong_email_otp_code`

OpenAI rejected the submitted email OTP. Common causes are stale mailbox messages, ad emails containing six-digit numbers, or expired OTPs. Use another mailbox, clean old messages, or verify with manual OTP mode.

### Redirected to `accounts.google.com`

The mailbox was routed to Google OAuth instead of the normal email OTP flow. This tool does not automate Google account login. Use a mailbox that can proceed through email OTP.

### `CreateAccount HTTP 500 Request timeout`

This is usually caused by upstream instability, a slow proxy, request timeout, or high concurrency. Retry, change proxy, or lower concurrency.

### Cancel does not stop instantly

Tasks stop at the next cancellable boundary. If a network request is in progress, status updates may wait until that request returns or times out.

### Sub2API import fails

Verify `sub2apiUrl`, `sub2apiEmail`, `sub2apiPassword`, `sub2apiGroupName`, and proxy settings first. Then inspect the HTTP status and response summary in task logs.

### JSON output is missing

Verify `jsonOutDir`, `jsonOutFormat`, access-token availability, and write permission for the target directory.

## Build Verification

Run before committing:

```bash
npm run build
npx tsc --noEmit -p codex_register/tsconfig.json
git status --short --ignored
git ls-files | rg '(^|/)(data|json|auth|pool_tokens|config\.json|k12-basic-auth|\.env|.*\.pem|.*\.key)'
```

`npm run build` and `npx tsc` should pass. The sensitive-file check should produce no output.

## License

This project is licensed under the MIT License. See `LICENSE`.
