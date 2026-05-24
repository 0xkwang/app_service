# 1. Base Image: 공격 표면(Attack Surface)이 최소화된 경량 데비안 커널 사용
FROM python:3.11-slim

# 2. 작업 디렉토리 네임스페이스 격리
WORKDIR /app

# 3. [캐시 최적화 레이어] 소스코드 복사 전 의존성 파일만 선행 복사
COPY requirements.txt .

# 4. 패키지 설치 및 불필요한 캐시 즉각 소각 (이미지 경량화)
RUN pip install --no-cache-dir -r requirements.txt

# 5. [변동 레이어] 실제 비즈니스 로직 복사
COPY . .

# 6. 도커 데몬 및 Azure 프록시에 수신 대기 포트 선언
EXPOSE 3000

# 7. 엔트리포인트: 해당 프로세스를 컨테이너의 PID 1로 격리하여 실행
CMD ["python", "app.py"]