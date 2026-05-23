# 🐳 Docker → Azure App Service 직접 배포

**GitHub Actions를 통해 Docker 이미지를 App Service에 직접 배포 (ACR 없음)**

---

## 📋 프로젝트 구조

```
.
├── app.js                        # Node.js 웹 애플리케이션
├── package.json                  # 프로젝트 설정
├── Dockerfile                    # Docker 이미지 정의
├── .gitignore                    # Git 추적 제외
├── .dockerignore                 # Docker 빌드 최적화
├── DEPLOYMENT_GUIDE.md           # 배포 가이드
└── .github/
    └── workflows/
        └── azure-deploy.yml      # GitHub Actions 워크플로우
```

---

## 🚀 배포 방식 (간단 버전)

```
GitHub (코드) 
  → Push to main
  → GitHub Actions (docker build)
  → App Service (컨테이너 시작)
  → https://my-docker-app.azurewebsites.net ✅
```

---

## 🔧 필수 설정

### 1. Azure 리소스 생성

```bash
# 리소스 그룹
az group create --name st707-githubactions-azureserver --location eastus

# App Service 플랜
az appservice plan create \
  --name my-app-service-plan \
  --resource-group st707-githubactions-azureserver \
  --sku B1 --is-linux

# Web App
az webapp create \
  --resource-group st707-githubactions-azureserver \
  --plan my-app-service-plan \
  --name my-docker-app \
  --deployment-container-image-name docker-azure-app:latest
```

### 2. GitHub Secrets 설정 (1개만!)

**Settings → Secrets and variables → Actions → New repository secret**

```
Name: AZURE_CREDENTIALS
Value: (Service Principal JSON - 아래 참고)
```

**Service Principal 생성:**
```bash
az ad sp create-for-rbac \
  --name "github-actions" \
  --role "Contributor" \
  --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/st707-githubactions-azureserver
```

---

## 📡 API 엔드포인트

배포 후:

```bash
GET https://my-docker-app.azurewebsites.net/
# → {"status": "healthy", "version": "1.0.0", ...}

GET https://my-docker-app.azurewebsites.net/health
# → {"status": "OK", ...}

GET https://my-docker-app.azurewebsites.net/api/system
# → {"node_version": "v18.x", "platform": "linux", ...}
```

---

## ⚡ 빠른 배포

```bash
# 1. 파일 준비 (이미 있음)
# 2. GitHub에 푸시
git add .
git commit -m "feat: Add Docker CI/CD"
git push origin main

# 3. GitHub Actions 자동 실행 (2-3분)
# 4. 접속
https://my-docker-app.azurewebsites.net
```

---

## 🎯 비교: ACR vs 직접 배포

| 항목 | ACR | 직접 배포 |
|------|-----|---------|
| 복잡도 | 중간 | 낮음 ✓ |
| 비용 | ACR 추가 | 0 ✓ |
| 빌드 시간 | 30초 (캐싱) | 2분 (매번) |
| 롤백 | 가능 | 불가능 |
| 버전 관리 | 가능 | 불가능 |

**언제 사용?**
- 학습 목적 ✓ (이 과제)
- 개발 환경 ✓
- 소규모 프로젝트 ✓
- 비용 최소화 ✓

**프로덕션은?**
- ACR 권장 (롤백, 버전 관리, 성능)

---

## 🛠️ 문제 해결

### 배포 실패
```bash
# 1. GitHub Actions 로그 확인
GitHub Repository → Actions 탭 → 최신 workflow

# 2. App Service 로그 확인
az webapp log tail --resource-group st707-githubactions-azureserver --name my-docker-app

# 3. 로컬 테스트
docker build -t test:latest .
docker run -p 3000:3000 test:latest
```

### Health Check 실패
```bash
# 헬스체크 재시도
curl -v https://my-docker-app.azurewebsites.net/health

# 포트 확인 (반드시 3000)
grep EXPOSE Dockerfile

# 환경 변수 확인
az webapp config appsettings list --resource-group st707-githubactions-azureserver --name my-docker-app
```

---

## 📖 상세 가이드

**DEPLOYMENT_GUIDE.md 참고** (Step-by-step 배포 방법)

---

**축하합니다! 🎉 간단한 CI/CD 파이프라인이 준비되었습니다.**
