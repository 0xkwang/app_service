# 1. Base Image: Python 3.9 환경의 경량화(slim) OS 바이너리를 메모리에 로드
FROM python:3.9-slim

# 2. Workdir: 컨테이너 내부의 격리된 파일 시스템 경로 지정
WORKDIR /app

# 3. Copy: 호스트의 종속성 명세서를 컨테이너 내부로 복사
COPY requirements.txt .

# 4. Run: 패키지 설치 (레이어 캐싱을 최적화하기 위해 소스코드 복사 전에 실행)
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy: 실제 애플리케이션 소스코드를 컨테이너로 복사
COPY . .

# 6. Expose: 컨테이너의 80번 포트가 외부망과 통신할 것임을 커널망(Network Namespace)에 선언
EXPOSE 80

# 7. Cmd: 컨테이너가 PID 1번으로 실행할 최종 프로세스 정의
CMD ["python", "app.py"]