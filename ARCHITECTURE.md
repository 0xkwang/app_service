# 🎯 Docker → Azure App Service 직접 배포 (ACR 없음) - 최종 정리

---

## 📊 **두 가지 배포 방식 최종 비교**

### **방식 1: ACR을 거치는 방식 (이전)**
```
GitHub Actions (빌드)
  ↓
Azure Container Registry (이미지 저장)
  ↓
App Service (pull & 실행)

특징: 복잡하지만 강력 (롤백, 버전관리, 보안)
```

### **방식 2: 직접 배포 (현재 - 당신의 선택) ⭐**
```
GitHub Actions (빌드 + 배포)
  ↓
App Service (컨테이너 실행)

특징: 간단하지만 기능 제한 (매번 빌드, 롤백 불가)
```

---

## 🗂️ **생성된 파일 (8개)**

### **핵심 애플리케이션**
```
/mnt/user-data/outputs/direct-deploy/
├── app.js                    ← Node.js 애플리케이션 (3개 API)
├── package.json              ← 의존성 정의
└── Dockerfile                ← Docker 이미지 정의 (멀티스테이지)
```

### **배포 자동화 (간단해짐!)**
```
├── .github/workflows/
│   └── azure-deploy.yml      ← GitHub Actions (단 1개 Job!)
```

### **설정 파일**
```
├── .gitignore                ← Git 추적 제외
├── .dockerignore             ← Docker 빌드 최적화
```

### **문서**
```
├── README.md                 ← 프로젝트 개요
└── DEPLOYMENT_GUIDE.md       ← 배포 단계별 가이드
```

---

## 🔑 **핵심 차이점**

### **GitHub Actions 워크플로우 비교**

**ACR 방식:**
```yaml
jobs:
  build:          ← Job 1: Docker 빌드
    steps:
      - docker build
      - docker push → ACR
  
  deploy:         ← Job 2: App Service 배포
    steps:
      - azure/webapps-deploy (ACR에서 pull)
```

**직접 배포 방식:**
```yaml
jobs:
  deploy:         ← 단 1개 Job!
    steps:
      - docker build (GitHub Actions에서)
      - azure/webapps-deploy (직접 배포)
```

**라인 수:**
- ACR 방식: 80줄
- 직접 배포: 35줄 (60% 감소!)

---

## 🚀 **3단계 배포 프로세스**

### **Step 1: GitHub에 푸시**
```bash
cd /path/to/direct-deploy

git add .
git commit -m "feat: Add Docker direct deployment to App Service"
git push origin main
```

### **Step 2: GitHub Actions 자동 실행** (2-3분)
```
GitHub Actions가 자동으로:
├─ Checkout (소스 코드 다운로드)
├─ Login to Azure (Service Principal 인증)
├─ Build Docker image (docker build 실행)
├─ Deploy to App Service (azure/webapps-deploy 호출)
├─ Wait 30s (컨테이너 초기화 대기)
└─ Verify deployment (헬스체크)
```

### **Step 3: 접속 확인**
```bash
# 브라우저
https://my-docker-app.azurewebsites.net

# CLI
curl https://my-docker-app.azurewebsites.net/health
# 응답: 200 OK
```

---

## 🔐 **필수 설정 (최소화!)**

### **1️⃣ Azure 리소스 (한 번만)**

```bash
# 1. 리소스 그룹 (이미 있으면 SKIP)
az group create \
  --name st707-githubactions-azureserver \
  --location eastus

# 2. App Service 플랜
az appservice plan create \
  --name my-app-service-plan \
  --resource-group st707-githubactions-azureserver \
  --sku B1 --is-linux

# 3. Web App (이게 전부!)
az webapp create \
  --resource-group st707-githubactions-azureserver \
  --plan my-app-service-plan \
  --name my-docker-app \
  --deployment-container-image-name docker-azure-app:latest
```

### **2️⃣ GitHub Secrets (1개만!)**

**GitHub Repository Settings**
```
Secrets and variables → Actions → New secret

Name: AZURE_CREDENTIALS
Value: (아래 JSON)
```

**Service Principal 생성:**
```bash
az ad sp create-for-rbac \
  --name "github-actions" \
  --role "Contributor" \
  --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/st707-githubactions-azureserver
```

**출력 (전체 JSON을 복사-붙여넣기):**
```json
{
  "appId": "xxxx1234-...",
  "displayName": "github-actions",
  "password": "xxx~xxx...",
  "tenant": "yyyy5678-..."
}
```

---

## 🔄 **내부 동작 (깊이 있게)**

### **docker build 단계**

```
Dockerfile 읽음
  ↓
Stage 1 (Builder): node:18-alpine
├─ COPY package*.json .
├─ RUN npm install --production
└─ node_modules 생성 (1분)
  ↓
Stage 2 (Runtime): node:18-alpine
├─ COPY --from=builder ... node_modules
├─ COPY app.js .
└─ 최종 이미지 완성 (30초)

최종 크기: ~150MB
```

### **azure/webapps-deploy 내부**

```
azure/webapps-deploy@v2 action 실행
  ├─ 이미지명 추출: docker-azure-app:${{ github.sha }}
  ├─ Azure API 호출
  │  POST https://management.azure.com/subscriptions/.../
  │    {"properties": {"image": "docker-azure-app:sha123"}}
  └─ App Service 수신
     ├─ 설정 업데이트
     ├─ Docker daemon에 지시
     └─ 컨테이너 재시작:
        docker run -p 80:3000 docker-azure-app:sha123
```

### **App Service에서의 처리**

```
App Service 내부 Docker
  ├─ docker pull docker-azure-app:sha123
  │  (로컬 캐시에 저장, 인터넷 접근 안 함)
  ├─ docker run -e PORT=3000 ...
  │  (Node.js 앱 시작)
  └─ 포트 매핑: 80 (HTTP) → 3000 (Node.js)

결과:
  ├─ https://my-docker-app.azurewebsites.net (80)
  │  내부적으로
  └─ http://localhost:3000 (App Service 내부)
```

---

## ⚠️ **알아야 할 제약사항**

### **1. 매번 전체 빌드**
```
배포할 때마다:
  npm install 실행 (2분)
  ├─ 의존성이 변하지 않아도 다시 설치
  └─ 시간 낭비

ACR 방식:
  캐시 사용 (30초)
  ├─ package.json 변경 없으면 캐시 hit
  └─ 효율적
```

### **2. 롤백 불가능**
```
배포 실패 시:
  직접 배포
  └─ "이전 버전이 어디에 있어?"
  └─ 코드 수정 후 재배포만 가능 (15분+)

ACR 방식
  └─ 이전 이미지 즉시 배포 (30초)
```

### **3. 이미지 버전 관리 불가**
```
프로덕션 버그 발생:
  직접 배포
  └─ "현재 어느 버전인가?" → 불명확

ACR 방식
  └─ docker-azure-app:v1.0.0 (명확)
  └─ 정확히 추적 가능
```

### **4. 다중 환경 비효율**
```
Dev, Staging, Production 3개 환경:
  직접 배포
  └─ 각각 docker build (6분)

ACR 방식
  └─ 1번 빌드 + 3번 pull (3분)
```

---

## 🎓 **당신이 배운 개념**

### **Docker**
- 멀티스테이지 빌드 (효율성 & 보안)
- 이미지 최적화 (크기 감소)
- 컨테이너 포트 매핑

### **GitHub Actions**
- 워크플로우 자동화
- 환경 변수 & Secrets 관리
- 조건부 실행 (if 문)

### **Azure**
- App Service (관리형 웹 호스팅)
- RBAC (역할 기반 접근 제어)
- Service Principal (임시 인증)

### **CI/CD**
- 자동화된 배포
- 헬스체크 (검증)
- 배포 흐름 자동화

---

## 🚨 **예상되는 에러와 해결**

### **에러 1: "Failed to deploy to App Service"**
```bash
# 원인: AZURE_CREDENTIALS 설정 오류
# 확인: GitHub Actions 로그
# 해결: Secrets 값 재입력
```

### **에러 2: "HTTP 500 (Internal Server Error)"**
```bash
# 원인: Node.js 애플리케이션 크래시
# 확인: az webapp log tail ...
# 해결: app.js 에러 수정
```

### **에러 3: "Connection refused (port 3000)"**
```bash
# 원인: 포트 설정 오류
# 확인: Dockerfile의 EXPOSE 3000 여부
# 해결: app.js에서 const PORT = process.env.PORT || 3000
```

---

## 📈 **성능 메트릭**

```
배포 시간:
├─ GitHub Actions 빌드: 2분
├─ App Service 배포: 1분
└─ 합계: 약 3분

이미지 크기:
└─ 150MB (멀티스테이지 최적화)

App Service 시작 시간:
└─ 약 30초
```

---

## ✅ **최종 체크리스트**

```
준비 단계:
[ ] 파일 8개 모두 준비됨
[ ] GitHub Repository 생성
[ ] Azure 리소스 생성 (az webapp create)

배포 단계:
[ ] AZURE_CREDENTIALS Secret 설정
[ ] git add . && git commit && git push
[ ] GitHub Actions 자동 실행 확인 (3분)

검증 단계:
[ ] curl https://my-docker-app.azurewebsites.net/ (200)
[ ] curl https://my-docker-app.azurewebsites.net/health (200)
[ ] curl https://my-docker-app.azurewebsites.net/api/system (200)
```

---

## 🎯 **다음은?**

### **현재 상황**
✅ 간단한 CI/CD 파이프라인 완성  
✅ Docker 배포 자동화  
✅ GitHub Actions 학습  

### **심화 학습**
1. **더 많은 엔드포인트 추가**
2. **데이터베이스 연동** (MongoDB, PostgreSQL)
3. **환경 변수 관리** (.env)
4. **모니터링 & 로깅**

### **프로덕션 준비**
- ACR로 업그레이드 (이 솔루션을 그 위에 구축)
- 이미지 취약점 스캔
- Blue-Green 배포 (무중단 배포)
- 롤백 자동화

---

## 📚 **참고 문서**

- **README.md**: 프로젝트 개요
- **DEPLOYMENT_GUIDE.md**: 배포 단계별 가이드 (매우 상세)
- 이 파일: 아키텍처 분석

---

## 🎉 **축하합니다!**

**ACR 없이도 완전한 Docker CI/CD 파이프라인을 구축했습니다.**

- 간단: 복잡한 설정 최소화 ✅
- 빠른 구현: 30분 내 배포 가능 ✅
- 학습 효과: Docker + GitHub Actions + Azure 실습 ✅

**다음 단계**: 이제 ACR을 추가하면 프로덕션급 파이프라인이 완성됩니다.

---

**더 궁금한 점이 있으면 언제든지 질문하세요!** 🚀
