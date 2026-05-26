from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello, Azure Web App with Docker and GitHub Actions!"

if __name__ == '__main__':
    # 0.0.0.0으로 바인딩하여 Docker 컨테이너 외부(Azure 호스트)에서 접근 가능하게 설정
    app.run(host='0.0.0.0', port=80)