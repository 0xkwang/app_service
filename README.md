# 🐳 Docker + GitHub Actions + Azure App Service CI/CD 파이프라인

**GitHub Actions를 통해 Docker 이미지를 자동으로 빌드하고 Azure App Service에 배포하는 완전한 CI/CD 파이프라인**

---

## 📋 프로젝트 구조

```
.
├── Dockerfile                    # Docker 이미지 정의 (멀티 스테이지 빌드)
├── app.js                        # Node.js 웹 애플리케이션
├── package.json                  # 프로젝트 메타데이터 및 스크립트
├── .dockerignore                 # Docker 빌드 컨텍스트 최적화
├── .gitignore                    # Git 추적 제외 파일
└── .github/
    └── workflows/
        └── azure-deploy.yml      # GitHub Actions 워크플로우 (핵심 CI/CD)
```

---

## 🚀 빠른 시작

### 1️⃣ **로컬 테스트**

```bash
# 의존성 설치
npm install

# 앱 실행
npm start

# 헬스체크
curl http://localhost:3000/health
```

### 2️⃣ **Docker 빌드 및 실행**

```bash
# 이미지 빌드
docker build -t docker-azure-app:latest .

# 컨테이너 실행
docker run -p 3000:3000 docker-azure-app:latest

# 접속
curl http://localhost:3000/
```

### 3️⃣ **GitHub에 푸시 (자동 배포)**

```bash
git add .
git commit -m "feat: Add Docker CI/CD pipeline"
git push origin main

# GitHub Actions 자동 실행
# → Docker 빌드 & ACR 푸시
# → Azure App Service 배포
```

---

## 🔧 Azure 리소스 설정

### **필수 설정 (한 번만)**

```bash
# 1. 리소스 그룹 생성
az group create --name my-resource-group --location eastus

# 2. Container Registry 생성
az acr create \
  --resource-group my-resource-group \
  --name myregistry \
  --sku Basic

# 3. App Service 플랜 생성
az appservice plan create \
  --name my-app-service-plan \
  --resource-group my-resource-group \
  --sku B1 \
  --is-linux

# 4. App Service 생성 (Docker 컨테이너용)
az webapp create \
  --resource-group my-resource-group \
  --plan my-app-service-plan \
  --name my-docker-app \
  --deployment-container-image-name myregistry.azurecr.io/docker-azure-app:latest

# 5. ACR 연결
az webapp config container set \
  --name my-docker-app \
  --resource-group my-resource-group \
  --docker-custom-image-name myregistry.azurecr.io/docker-azure-app:latest \
  --docker-registry-server-url https://myregistry.azurecr.io \
  --docker-registry-server-user myregistry \
  --docker-registry-server-password 'PASSWORD'
```

---

## 🔐 GitHub Secrets 설정

**Settings → Secrets and variables → Actions**에서 다음 4개 추가:

```
AZURE_REGISTRY_USERNAME = myregistry
AZURE_REGISTRY_PASSWORD = (ACR 비밀번호)
AZURE_CREDENTIALS = (Service Principal JSON)
AZURE_DEPLOYMENT_WEBHOOK_URL = (배포 웹훅 URL)
```

### 값 구하기

```bash
# ACR 자격증명
az acr credential show --resource-group my-resource-group --name myregistry

# Service Principal 생성
az ad sp create-for-rbac \
  --name "github-actions" \
  --role "Contributor" \
  --scopes /subscriptions/{subscription-id}/resourceGroups/my-resource-group

# Webhook URL
az webapp deployment container config \
  --resource-group my-resource-group \
  --name my-docker-app \
  --enable-cd true

az webapp deployment container show-cd-url \
  --resource-group my-resource-group \
  --name my-docker-app
```

---

## 📊 CI/CD 파이프라인 동작

```
┌─────────────────────────────────────────────────┐
│ git push origin main                             │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ GitHub Actions 트리거 (azure-deploy.yml)        │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ Job: Build                                       │
│ ├─ Checkout repository                          │
│ ├─ Setup Docker Buildx                          │
│ ├─ Login to ACR                                 │
│ └─ Build & Push image                           │
│    └─ myregistry.azurecr.io/docker-azure-app   │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ Job: Deploy (main 브랜치만)                     │
│ ├─ Login to Azure                               │
│ ├─ Deploy to App Service                        │
│ ├─ Wait 30s                                     │
│ ├─ Health Check (/health)                       │
│ └─ Success Log                                  │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│ 배포 완료 ✅                                     │
│ https://my-docker-app.azurewebsites.net         │
└──────────────────────────────────────────────────┘
```

---

## 📡 API 엔드포인트

배포 후 다음 URL로 접근 가능:

| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| `/` | GET | 기본 상태 정보 |
| `/health` | GET | 헬스체크 (메모리, 가동 시간) |
| `/api/system` | GET | 시스템 정보 (CPU, 메모리 등) |

**예시:**
```bash
curl https://my-docker-app.azurewebsites.net/
# {
#   "status": "healthy",
#   "service": "Docker CI/CD Pipeline",
#   "version": "1.0.0",
#   "hostname": "container-id",
#   "uptime": 125.432
# }

curl https://my-docker-app.azurewebsites.net/health
# {
#   "status": "OK",
#   "checks": {
#     "memory": {...},
#     "uptime": 125.432
#   }
# }
```

---

## 🔍 내부 동작 분석

### **멀티 스테이지 Docker 빌드**

```dockerfile
Stage 1 (Builder)
  ├─ node:18-alpine (빌드 도구 포함)
  ├─ npm install --production
  └─ node_modules 생성

Stage 2 (Runtime)
  ├─ node:18-alpine (최소 이미지)
  ├─ builder에서 node_modules 복사
  ├─ app.js 복사
  └─ 최종 크기: ~150MB (vs 700MB 단계별)
```

**보안 이점:**
- 최종 이미지에 빌드 도구 미포함
- 소스 코드 개발 의존성 미노출
- 컨테이너 탈출 시 공격 면적 ↓

### **GitHub Actions 권한 격리**

```yaml
secrets.AZURE_REGISTRY_PASSWORD
  ├─ 로그에 자동 마스킹
  ├─ 워크플로우 내에서만 접근 가능
  └─ 노출 시 즉시 교체 필요

secrets.AZURE_CREDENTIALS
  ├─ Service Principal (임시 토큰처럼 작동)
  ├─ 최소 권한 원칙 (특정 리소스 그룹만)
  └─ 시간 제한 설정 가능
```

---

## 🛠️ 문제 해결

### **배포 실패: "Failed to push image"**

```bash
# ACR 로그인 확인
az acr login --name myregistry

# 이미지 테스트
docker push myregistry.azurecr.io/docker-azure-app:latest
```

### **App Service 시작 안 됨**

```bash
# 로그 확인
az webapp log tail --resource-group my-resource-group --name my-docker-app

# 포트 확인 (PORT 환경변수)
az webapp config appsettings list \
  --resource-group my-resource-group \
  --name my-docker-app
```

### **GitHub Actions 실패**

```
Actions 탭 → 실패한 워크플로우 → 로그 확인
```

---

## 🎓 학습 포인트

1. **CI/CD 파이프라인**: 자동화된 빌드 & 배포
2. **Docker 멀티 스테이지 빌드**: 이미지 최적화 & 보안
3. **GitHub Actions**: 워크플로우 기반 자동화
4. **Azure 리소스**: Container Registry, App Service
5. **권한 관리**: RBAC, Service Principal, Secrets

---

## 📖 추가 자료

- [Docker 멀티 스테이지 빌드](https://docs.docker.com/build/building/multi-stage/)
- [GitHub Actions 문법](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Azure App Service 배포](https://learn.microsoft.com/en-us/azure/app-service/)

---

## 📝 라이선스

MIT License
