# ===== 초경량 RUNTIME STAGE =====
FROM node:18-alpine

WORKDIR /app

# 1. 보안: 루트 사용자 권한 박탈 및 제한된 사용자(node)로 전환
USER node

# 2. 애플리케이션 소스 및 패키지 메타데이터 복사
COPY --chown=node:node package*.json ./
COPY --chown=node:node app.js .

# (주의: 향후 외부 라이브러리(express 등)를 추가할 경우 여기에 RUN npm install을 추가해야 합니다.)

# 3. 헬스체크 (시스템 모니터링 데몬용 IPC 통신)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# 4. 컨테이너 포트 노출
EXPOSE 3000

# 5. 메인 프로세스(PID 1) 실행
CMD ["node", "app.js"]