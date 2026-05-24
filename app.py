from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    # Azure Kudu L7 로드밸런서의 Health Check에 응답할 JSON 페이로드
    return {"status": "healthy", "message": "Docker Container is running seamlessly on Azure!"}

if __name__ == '__main__':
    # 시스템 환경변수를 최우선으로 수용하며, 누락 시 3000번 포트로 Fallback
    port = int(os.environ.get('WEBSITES_PORT', 3000))
    
    # [핵심] 커널의 INADDR_ANY(0.0.0.0) 상수에 소켓을 바인딩하여 모든 네트워크 인터페이스의 패킷 수신
    app.run(host='0.0.0.0', port=port)