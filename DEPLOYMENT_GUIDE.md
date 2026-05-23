# 🚀 Docker → Azure App Service 직접 배포 (ACR 없음)

**GitHub Actions에서 Docker 이미지를 빌드하고 App Service에 직접 배포**

---

## 🎯 **이 방식의 특징**

### ✅ **장점**
```
- Azure Container Registry 비용 0
- 구조 단순 (중간 단계 제거)
- 빠른 구현 (30분)
```

### ❌ **단점**
```
- 이미지 버전 관리 불가 (롤백 어려움)
- 배포 속도 느림 (매번 전체 빌드)
- 다중 환경 배포 비효율적
- 이미지 취약점 스캔 불가
```

**언제 사용할까?**
```
- 소규모 프로젝트
- 개발/테스트 환경
- 학습 목적 (과제)
- 비용 최소화 필요
```

---

## 📋 **필수 준비물**

### **Azure 리소스 (최소)**

```bash
# 1. 리소스 그룹
az group create --name st707-githubactions-azureserver --location eastus

# 2. App Service 플랜 (Linux)
az appservice plan create \
  --name my-app-service-plan \
  --resource-group st707-githubactions-azureserver \
  --sku B1 \
  --is-linux

# 3. Web App (Docker 컨테이너용)
az webapp create \
  --resource-group st707-githubactions-azureserver \
  --plan my-app-service-plan \
  --name my-docker-app \
  --deployment-container-image-name docker-azure-app:latest
```

---

## 🔐 **GitHub Secrets 설정 (최소)**

**이번엔 2개만 필요합니다!** (ACR 자격증명 불필요)

### Settings → Secrets and variables → Actions

```
AZURE_CREDENTIALS = (Service Principal JSON)
```

**Service Principal 생성:**

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az ad sp create-for-rbac \
  --name "github-actions" \
  --role "Contributor" \
  --scopes /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/st707-githubactions-azureserver
```

**출력 (전체 JSON을 복사):**
```json
{
  "appId": "xxxx1234-...",
  "displayName": "github-actions",
  "password": "xxx~xxx...",
  "tenant": "yyyy5678-..."
}
```

---

## 📁 **파일 구조**

```
your-project/
├── app.js                        (Node.js 앱)
├── package.json                  (의존성)
├── Dockerfile                    (Docker 정의)
├── .gitignore
├── .dockerignore
└── .github/
    └── workflows/
        └── azure-deploy.yml      (⭐ 간단해짐!)
```

---

## 🚀 **배포 프로세스 (내부 동작)**

### **Step 1: GitHub에 푸시**
```bash
git add .
git commit -m "feat: Direct Docker deployment to App Service"
git push origin main
```

### **Step 2: GitHub Actions 자동 실행**
```
Trigger: push to main
  ↓
Job: deploy (이제 단 하나!)
  ├─ Checkout
  ├─ Login to Azure
  ├─ docker build (로컬에서)
  ├─ azure/webapps-deploy@v2
  │  └─ App Service에 이미지 정보 전달
  ├─ Wait 30s
  └─ Health Check
```

### **Step 3: App Service에서 처리**
```
App Service 수신:
  ├─ 이미지 이름: docker-azure-app:sha256
  ├─ Docker daemon 실행 (App Service 내부)
  ├─ 컨테이너 시작
  └─ 포트 3000 → HTTP 80 매핑
```

---

## 📊 **ACR 방식과의 비교**

| 항목 | ACR 방식 | 직접 배포 |
|------|---------|---------|
| **빌드** | GitHub Actions | GitHub Actions |
| **저장소** | Azure ACR | App Service 내부 |
| **배포** | Webhook 자동 | azure/webapps-deploy |
| **빌드 시간** | 2분 (캐싱) | 2분 (매번) |
| **이미지 관리** | 버전 관리 가능 | 최신 1개만 |
| **롤백** | 30초 내 가능 | 불가능 |
| **비용** | ACR 비용 + | 비용 절감 |

---

## ⚠️ **주의사항**

### **문제 1: 매번 전체 빌드**
```
ACR 방식:
  ├─ 캐시 사용 (2분 → 30초)
  └─ 효율적

직접 배포:
  ├─ 캐시 없음 (매번 2분)
  └─ 자주 배포하면 비효율
```

### **문제 2: 롤백 불가능**
```
배포 실패 시:
  ├─ ACR: 이전 버전 즉시 복구 가능
  ├─ 직접: 코드 수정 후 재배포만 가능
  └─ 시간 낭비 (15분+)
```

### **문제 3: 이미지 버전 관리 불가**
```
프로덕션에서 문제 발생:
  ├─ ACR: 정확히 어느 버전인지 추적 가능
  ├─ 직접: "최신 버전"이 뭔지 모호
  └─ 디버깅 어려움
```

---

## ✅ **배포 단계별 검증**

### **Step 1: 로컬 테스트 (배포 전)**
```bash
# Docker 빌드
docker build -t docker-azure-app:latest .

# 실행
docker run -p 3000:3000 docker-azure-app:latest

# 테스트
curl http://localhost:3000/health
```

### **Step 2: GitHub Actions 확인**
```
GitHub Repository
  → Actions 탭
  → 최신 workflow 클릭
  → 로그 확인 (2-3분)
```

**성공 신호:**
```
✅ Checkout repository
✅ Login to Azure
✅ Build Docker image
✅ Deploy to App Service using Docker image
✅ Wait for deployment
✅ Verify deployment
```

### **Step 3: App Service 접속**
```bash
# 브라우저
https://my-docker-app.azurewebsites.net

# CLI
curl https://my-docker-app.azurewebsites.net/health
# 응답: 200 OK
```

---

## 🔍 **azure/webapps-deploy 내부 동작**

```
azure/webapps-deploy@v2가 실행하는 것:

1. Azure 인증 (이미 로그인됨)

2. 이미지 정보를 App Service에 전달
   curl https://management.azure.com/subscriptions/.../
     -X PUT \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"docker":{"image":"docker-azure-app:sha123"}}'

3. App Service가 수신
   ├─ 이미지명 저장
   ├─ Docker daemon에 지시
   └─ 컨테이너 재시작

4. App Service 내부의 Docker
   ├─ docker pull docker-azure-app:sha123
   │  (로컬 저장, 인터넷 불필요)
   ├─ docker run -p 80:3000 ...
   └─ 컨테이너 시작
```

**핵심:**
```
이미지를 "어디에" 저장하나?

ACR 방식:
  └─ GitHub Actions (빌드)
  └─ Azure ACR (저장소)
  └─ App Service (pull해서 실행)

직접 배포:
  └─ GitHub Actions (빌드)
  └─ App Service (직접 전달)
```

---

## 🛠️ **문제 해결**

### **문제: "Failed to deploy to App Service"**

```bash
# 원인 1: AZURE_CREDENTIALS 설정 오류
# 해결:
echo ${{ secrets.AZURE_CREDENTIALS }} | jq .
# (GitHub Actions에서 로그 확인)

# 원인 2: App Service 이름 오류
az webapp list --resource-group st707-githubactions-azureserver --query "[].name"

# 원인 3: App Service가 없음
az webapp create \
  --resource-group st707-githubactions-azureserver \
  --plan my-app-service-plan \
  --name my-docker-app
```

### **문제: 컨테이너가 시작되지 않음**

```bash
# 로그 확인
az webapp log tail \
  --resource-group st707-githubactions-azureserver \
  --name my-docker-app

# 환경 변수 확인
az webapp config appsettings list \
  --resource-group st707-githubactions-azureserver \
  --name my-docker-app

# 포트 문제 (반드시 3000이어야 함)
cat Dockerfile | grep EXPOSE
```

### **문제: 헬스체크 실패 (HTTP != 200)**

```bash
# 직접 확인
curl -v https://my-docker-app.azurewebsites.net/health

# 로그 확인
az webapp log tail \
  --resource-group st707-githubactions-azureserver \
  --name my-docker-app

# 일반적 원인:
# 1. app.js 에러
# 2. PORT 환경변수 안 읽음
# 3. 포트 바인딩 실패
```

---

## 📈 **성능 최적화 팁**

### **더 빠른 배포를 위해:**

```
현재: 매번 2분 (npm install)

최적화:
└─ .dockerignore에 불필요한 파일 제외
└─ package.json 변경 최소화
└─ 명시적 캐싱 전략 (레이어 순서)
```

**Dockerfile 최적화 예시:**
```dockerfile
# ❌ 나쁜 예: 변경 많은 것 먼저
COPY . .
RUN npm install

# ✅ 좋은 예: 변경 적은 것 먼저
COPY package*.json .
RUN npm install
COPY . .
```

---

## 🔄 **배포 후 업데이트 (재배포)**

### **코드 수정 → 자동 배포**

```bash
# 1. 코드 수정
nano app.js

# 2. Push (자동 배포 트리거)
git add app.js
git commit -m "fix: Update endpoint"
git push origin main

# 3. 2-3분 후 자동 배포 완료
```

**매 배포마다:**
```
1. GitHub Actions에서 docker build (2분)
2. App Service에 이미지 정보 전달 (1초)
3. App Service가 컨테이너 재시작 (30초)
4. 헬스체크 (10초)
```

**총 소요 시간: 약 3분**

---

## 📊 **실행 흐름 (시각화)**

```
┌─────────────────────────┐
│ git push origin main     │
└────────────┬────────────┘
             │
┌────────────▼────────────────────────────┐
│ GitHub Actions 트리거                    │
│ (azure-deploy.yml)                      │
└────────────┬─────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│ Step 1: Checkout                          │
│ (소스 코드 다운로드)                      │
└────────────┬───────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│ Step 2: Login to Azure                    │
│ (Service Principal 인증)                  │
└────────────┬───────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│ Step 3: docker build                      │
│ (Dockerfile 읽음)                         │
│ ├─ Stage 1: npm install (1분)             │
│ └─ Stage 2: 최종 이미지 (30초)             │
└────────────┬───────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│ Step 4: azure/webapps-deploy              │
│ (이미지 정보를 App Service에 전달)       │
└────────────┬───────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│ Azure App Service (App Service 자체처리)  │
│ ├─ 기존 컨테이너 중지                     │
│ ├─ 새 이미지 시작                         │
│ └─ 헬스체크                               │
└────────────┬───────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│ ✅ 배포 완료                              │
│ https://my-docker-app.azurewebsites.net   │
└──────────────────────────────────────────┘
```

---

## ✨ **이 방식의 보안**

```
GitHub Actions 보안:
  ├─ AZURE_CREDENTIALS (암호화)
  ├─ 로그에서 자동 마스킹
  └─ 조건: main 브랜치만

App Service 보안:
  ├─ Docker 컨테이너 (격리)
  ├─ USER node (루트 제거)
  └─ HEALTHCHECK (비정상 감지)
```

---

## ✅ **최종 체크리스트**

```
[ ] Dockerfile 준비
[ ] app.js 준비
[ ] package.json 준비
[ ] GitHub Secrets (AZURE_CREDENTIALS) 설정
[ ] App Service 생성
[ ] .github/workflows/azure-deploy.yml 준비
[ ] git push origin main
[ ] GitHub Actions 워크플로우 성공
[ ] curl https://my-docker-app.azurewebsites.net/health (200)
```

---

**이제 준비 완료! 🎉 바로 배포할 수 있습니다.**

ACR 없어서 더 간단하지만, 프로덕션 환경에서는 **ACR 방식을 권장**합니다. (롤백, 버전 관리, 성능)
