# ===== BUILD STAGE =====
FROM node:18-alpine AS builder

WORKDIR /app

# 패키지 의존성 파일 복사
COPY package*.json ./

# 의존성 설치 (production 모드)
RUN npm install --production

# ===== RUNTIME STAGE =====
FROM node:18-alpine

WORKDIR /app

# 보안: 루트 사용자 대신 node 사용자로 실행
USER node

# 빌더 스테이지에서 node_modules 복사
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

# 애플리케이션 소스 복사
COPY --chown=node:node app.js .
COPY --chown=node:node package.json .

# 헬스체크 추가 (Azure App Service 모니터링)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# 포트 노출
EXPOSE 3000

# 애플리케이션 시작
CMD ["node", "app.js"]
