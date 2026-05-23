# 🚀 배포 검증 및 테스트 가이드

당신의 Docker + GitHub Actions + Azure App Service CI/CD 파이프라인을 완성하는 단계별 가이드

---

## ✅ **Step 1: 로컬 검증 (배포 전)**

### 1-1. 파일 구조 확인

```bash
# 프로젝트 디렉토리로 이동
cd your-project

# 파일 목록 확인
ls -la

# 출력되어야 할 파일:
# -rw-r--r-- app.js
# -rw-r--r-- package.json
# -rw-r--r-- Dockerfile
# -rw-r--r-- .gitignore
# -rw-r--r-- .dockerignore
# -rw-r--r-- README.md
# drwxr-xr-x .github/
```

### 1-2. 로컬에서 앱 실행

```bash
# Node.js 설치 확인
node --version  # v18.0.0 이상

# 의존성 설치
npm install

# 앱 시작
npm start

# 다른 터미널에서 테스트
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/api/system
```

**예상 출력:**
```json
{
  "status": "healthy",
  "service": "Docker CI/CD Pipeline",
  "version": "1.0.0",
  "environment": "production",
  "hostname": "your-machine-name",
  "uptime": 12.345
}
```

### 1-3. Docker 로컬 테스트

```bash
# Docker 설치 확인
docker --version

# 이미지 빌드
docker build -t docker-azure-app:local .

# 빌드 결과 확인
docker images | grep docker-azure-app

# 컨테이너 실행
docker run -p 3000:3000 docker-azure-app:local

# 다른 터미널에서 테스트
curl http://localhost:3000/
curl http://localhost:3000/api/system

# 컨테이너 로그 확인
docker logs <container-id>
```

---

## 🔧 **Step 2: Azure 리소스 설정**

### 2-1. Azure CLI 설치 및 로그인

```bash
# Azure CLI 설치 여부 확인
az --version

# Azure 로그인
az login

# 구독 확인
az account show
```

### 2-2. 리소스 생성 (한 번만)

**⚠️ 주의: 이미 생성했다면 SKIP**

```bash
# 변수 설정 (자신의 값으로 변경)
RESOURCE_GROUP="st707-githubactions-azureserver"
ACR_NAME="myregistry"
APP_PLAN="my-app-service-plan"
APP_NAME="my-docker-app"
LOCATION="eastus"

# 1. 리소스 그룹 생성
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# 2. Container Registry 생성
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

# 3. App Service 플랜 생성
az appservice plan create \
  --name $APP_PLAN \
  --resource-group $RESOURCE_GROUP \
  --sku B1 \
  --is-linux

# 4. Web App 생성
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_PLAN \
  --name $APP_NAME \
  --deployment-container-image-name "${ACR_NAME}.azurecr.io/docker-azure-app:latest"

# 5. ACR 연결 설정
az webapp config container set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-custom-image-name "${ACR_NAME}.azurecr.io/docker-azure-app:latest" \
  --docker-registry-server-url "https://${ACR_NAME}.azurecr.io" \
  --docker-registry-server-user $ACR_NAME \
  --docker-registry-server-password $(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query 'passwords[0].value' -o tsv)
```

### 2-3. Secrets 수집

```bash
# ACR 자격증명
echo "=== ACR 자격증명 ==="
az acr credential show \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME

# Service Principal 생성
echo "=== Service Principal 생성 ==="
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az ad sp create-for-rbac \
  --name "github-actions" \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

# Webhook URL
echo "=== Webhook URL ==="
az webapp deployment container show-cd-url \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME
```

---

## 🔐 **Step 3: GitHub Secrets 설정**

### 3-1. GitHub Repository Settings 접속

```
https://github.com/your-username/your-repo/settings/secrets/actions
```

### 3-2. 4개 Secret 추가

**Secret 1: AZURE_REGISTRY_USERNAME**
```
Value: myregistry  (ACR 이름)
```

**Secret 2: AZURE_REGISTRY_PASSWORD**
```
Value: (az acr credential show에서 password[0].value)
```

**Secret 3: AZURE_CREDENTIALS**
```
Value: (Service Principal JSON 전체)
{
  "appId": "...",
  "displayName": "github-actions",
  "password": "...",
  "tenant": "..."
}
```

**Secret 4: AZURE_DEPLOYMENT_WEBHOOK_URL** (선택사항)
```
Value: (az webapp deployment container show-cd-url에서)
```

---

## 📤 **Step 4: Git Push 및 GitHub Actions 실행**

### 4-1. GitHub에 코드 푸시

```bash
# Git 초기화 (처음일 경우)
git init
git remote add origin https://github.com/your-username/your-repo.git

# 파일 추가
git add .

# 커밋
git commit -m "feat: Add Docker + GitHub Actions + Azure CI/CD pipeline"

# 푸시
git push -u origin main

# 또는 기존 저장소인 경우
git add .
git commit -m "feat: Update CI/CD pipeline"
git push origin main
```

### 4-2. GitHub Actions 모니터링

```
GitHub Repository
  → Actions 탭
  → 최신 워크플로우 클릭
  → Build job 진행 상황 확인
  → Deploy job 진행 상황 확인
```

**각 단계별 예상 시간:**
- Checkout: 5초
- Setup Buildx: 10초
- Login to ACR: 5초
- Build & Push: 1-2분
- Deploy: 30초
- Health Check: 10초

**전체 소요 시간: 약 3-4분**

---

## ✨ **Step 5: 배포 검증**

### 5-1. GitHub Actions 성공 확인

```
✅ azure-deploy workflow
  ├─ ✅ build job
  │  ├─ ✅ Checkout repository
  │  ├─ ✅ Setup Docker Buildx
  │  ├─ ✅ Login to Azure Container Registry
  │  ├─ ✅ Extract metadata for Docker image
  │  └─ ✅ Build and push Docker image
  └─ ✅ deploy job
     ├─ ✅ Login to Azure
     ├─ ✅ Deploy to Azure App Service
     ├─ ✅ Wait for deployment
     ├─ ✅ Verify deployment
     └─ ✅ Log deployment summary
```

### 5-2. App Service 헬스 체크

```bash
# 배포된 앱 접속 (브라우저 또는 curl)
RESOURCE_GROUP="st707-githubactions-azureserver"
APP_NAME="my-docker-app"

# URL 확인
echo "https://${APP_NAME}.azurewebsites.net"

# 헬스체크
curl https://${APP_NAME}.azurewebsites.net/health

# 전체 정보
curl https://${APP_NAME}.azurewebsites.net/

# 시스템 정보
curl https://${APP_NAME}.azurewebsites.net/api/system
```

**예상 응답:**
```json
{
  "status": "healthy",
  "service": "Docker CI/CD Pipeline",
  "version": "1.0.0",
  "environment": "production",
  "deployment_time": "2026-05-23T10:30:00.000Z",
  "hostname": "container-xyz123",
  "uptime": 45.678
}
```

### 5-3. Azure Portal 확인

```
Azure Portal
  → App Services
  → my-docker-app
  → Overview
    ├─ Status: Running ✅
    ├─ URL: https://my-docker-app.azurewebsites.net
    └─ Container Settings
       └─ Image: myregistry.azurecr.io/docker-azure-app:latest
```

---

## 🔄 **Step 6: 배포 후 업데이트**

### 6-1. 코드 수정 후 재배포

```bash
# app.js 수정
nano app.js

# 변경 예시: APP_VERSION을 1.0.1로 변경
```

### 6-2. Git 푸시 (자동 재배포)

```bash
git add app.js
git commit -m "feat: Update app version to 1.0.1"
git push origin main

# → GitHub Actions 자동 실행
# → 약 3-4분 후 배포 완료
```

### 6-3. 업데이트 확인

```bash
# 새 버전 확인
curl https://my-docker-app.azurewebsites.net/ | grep version

# 출력: "version": "1.0.1"
```

---

## 🛠️ **문제 해결**

### **문제 1: GitHub Actions Build 실패**

```bash
# 원인: Dockerfile 문법 오류

# 해결:
docker build -t test:latest .
# (로컬에서 먼저 테스트)

# 결과가 성공하면 GitHub Actions도 성공할 것
```

### **문제 2: Deploy 실패 (ACR 로그인 오류)**

```bash
# 원인: Secrets 설정 오류

# 확인:
az acr login --name myregistry

# 다시 설정:
# 1. GitHub Secrets 재확인
# 2. ACR 자격증명 갱신
# 3. 워크플로우 재실행 (GitHub Actions 탭)
```

### **문제 3: App Service 시작 안 됨**

```bash
# 원인: PORT 환경변수 미설정 또는 콘테이너 크래시

# 확인:
az webapp log tail \
  --resource-group st707-githubactions-azureserver \
  --name my-docker-app

# 로그에서 에러 메시지 확인
# 보통: "Cannot find module" 또는 "listen EADDRINUSE"

# 해결:
# 1. Dockerfile의 EXPOSE 3000 확인
# 2. app.js의 PORT 환경변수 처리 확인
```

---

## 📊 **배포 검증 체크리스트**

```
[ ] 로컬 npm start 성공
[ ] 로컬 docker build 성공
[ ] 로컬 docker run 성공
[ ] GitHub Secrets 4개 모두 설정
[ ] GitHub Actions 워크플로우 성공
[ ] App Service 상태: Running
[ ] curl https://app-name.azurewebsites.net/ 성공 (200)
[ ] /health 엔드포인트 응답 (200)
[ ] /api/system 엔드포인트 응답 (200)
```

---

## 🎯 **최종 확인**

모든 단계를 완료했다면:

1. **GitHub Actions**: 매 push마다 자동 배포 ✅
2. **Docker**: 멀티 스테이지 빌드로 최적화 ✅
3. **Azure**: App Service에서 컨테이너 실행 중 ✅
4. **CI/CD**: 완전 자동화 ✅

---

## 📚 **추가 학습**

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions Advanced](https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions)
- [Azure Container Instances](https://learn.microsoft.com/en-us/azure/container-instances/)

---

**축하합니다! 🎉 완전한 CI/CD 파이프라인을 구축했습니다!**
