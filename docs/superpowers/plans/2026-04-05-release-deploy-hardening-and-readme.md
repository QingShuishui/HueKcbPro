# Release Deployment Hardening And README Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the published backend image references with the live GitHub Actions workflow, harden the release compose defaults for public-server deployment, and replace the placeholder repository README with a concise project overview.

**Architecture:** Keep the existing release flow based on one reusable backend image and `docker-compose.release.yml`, but make the docs and examples match the actual GHCR image naming and tag behavior. Treat the release compose file as production-facing and expose only the API service by default.

**Tech Stack:** GitHub Actions, GHCR, Docker Compose, Markdown, Flutter, FastAPI

---

### Task 1: Record the release deployment plan

**Files:**
- Create: `docs/superpowers/plans/2026-04-05-release-deploy-hardening-and-readme.md`

- [x] **Step 1: Write the plan file**

Create this implementation plan so the release hardening and documentation changes have an explicit execution record.

- [x] **Step 2: Review scope**

Confirm the task only touches release deployment configuration and docs, so static verification is sufficient instead of adding a new automated test harness.

### Task 2: Harden release deployment defaults

**Files:**
- Modify: `backend_v2/docker-compose.release.yml`
- Modify: `backend_v2/.env.release.example`

- [x] **Step 1: Update the example GHCR image reference**

Set the example `APP_IMAGE` to the actual owner-derived GHCR path used by the workflow:

```env
APP_IMAGE=ghcr.io/qingshuishui/kcb-backend-v2
```

- [x] **Step 2: Update the example tag guidance**

Change the example `APP_TAG` to an explicit release tag:

```env
APP_TAG=backend-v0.1.1
```

- [x] **Step 3: Remove host port exposure for stateful services**

Delete the `ports` mappings from `postgres` and `redis` in the release compose file so they stay internal to the Docker network by default.

- [x] **Step 4: Preserve API exposure**

Keep the `api` service port mapping so the HTTP service remains reachable:

```yaml
ports:
  - "${API_PORT:-8000}:8000"
```

### Task 3: Sync deployment documentation

**Files:**
- Modify: `backend_v2/DEPLOY.md`
- Modify: `backend_v2/README.md`

- [x] **Step 1: Correct the published image name**

Replace old `ghcr.io/qsqs/...` references with:

```text
ghcr.io/qingshuishui/kcb-backend-v2
```

- [x] **Step 2: Clarify release tag usage**

Document that release deployments should pin `APP_TAG` to a release tag like `backend-v0.1.1`, while `latest` is only appropriate when intentionally tracking the default branch image.

- [x] **Step 3: Clarify network exposure**

Add a short note that the release compose file exposes only the API service by default and that database/cache access should be opened explicitly only when needed.

### Task 4: Replace the top-level README

**Files:**
- Modify: `README.md`

- [x] **Step 1: Remove the Flutter template README**

Replace the stock Flutter starter text with a concise repository overview.

- [x] **Step 2: Add a simple project structure section**

Document the main directories:

```text
lib/         Flutter client
backend_v2/  Dockerized FastAPI backend
backend/     Legacy backend code
```

- [x] **Step 3: Add a short deployment entry point**

Point readers to `backend_v2/DEPLOY.md` for production deployment and keep the wording minimal.

### Task 5: Verify and publish

**Files:**
- Verify: `backend_v2/docker-compose.release.yml`
- Verify: `backend_v2/.env.release.example`
- Verify: `backend_v2/DEPLOY.md`
- Verify: `README.md`

- [x] **Step 1: Render compose configuration**

Run:

```bash
docker compose --env-file backend_v2/.env.release.example -f backend_v2/docker-compose.release.yml config
```

Expected: exit code `0`, rendered services include `api`, `worker`, `beat`, `migrate`, `postgres`, and `redis`.

- [x] **Step 2: Review the diff**

Run:

```bash
git diff -- backend_v2/docker-compose.release.yml backend_v2/.env.release.example backend_v2/DEPLOY.md backend_v2/README.md README.md docs/superpowers/plans/2026-04-05-release-deploy-hardening-and-readme.md
```

Expected: only the intended release-config and documentation changes are present.

- [ ] **Step 3: Commit**

Run:

```bash
git add README.md backend_v2/README.md backend_v2/DEPLOY.md backend_v2/.env.release.example backend_v2/docker-compose.release.yml docs/superpowers/plans/2026-04-05-release-deploy-hardening-and-readme.md
git commit -m "docs: harden release deploy setup"
```

- [ ] **Step 4: Push**

Run:

```bash
git push origin main
```
