const http = require('http');
const os = require('os');

// 환경 변수에서 포트 읽기 (Azure App Service는 PORT 환경변수 사용)
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0'; // 컨테이너 내부 모든 인터페이스에서 수신

// 애플리케이션 정보
const APP_VERSION = '1.0.0';
const ENVIRONMENT = process.env.NODE_ENV || 'production';
const DEPLOYMENT_TIME = new Date().toISOString();

// HTTP 서버 생성
const server = http.createServer((req, res) => {
  // 요청 로깅
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);

  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json');

  // 라우팅
  if (req.url === '/' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'healthy',
      service: 'Docker CI/CD Pipeline',
      version: APP_VERSION,
      environment: ENVIRONMENT,
      timestamp: new Date().toISOString(),
      deployment_time: DEPLOYMENT_TIME,
      hostname: os.hostname(),
      uptime: process.uptime()
    }, null, 2));
  } 
  else if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'OK',
      checks: {
        memory: process.memoryUsage(),
        uptime: process.uptime()
      }
    }, null, 2));
  }
  else if (req.url === '/api/system' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      node_version: process.version,
      platform: process.platform,
      arch: process.arch,
      cpus: os.cpus().length,
      memory: {
        total: os.totalmem(),
        free: os.freemem()
      },
      container: {
        pid: process.pid,
        ppid: process.ppid
      }
    }, null, 2));
  }
  else {
    res.writeHead(404);
    res.end(JSON.stringify({
      error: 'Not Found',
      message: `${req.method} ${req.url} - 이 엔드포인트는 존재하지 않습니다.`,
      available_endpoints: [
        'GET /',
        'GET /health',
        'GET /api/system'
      ]
    }, null, 2));
  }
});

// 서버 시작
server.listen(PORT, HOST, () => {
  console.log(`=================================================`);
  console.log(`🚀 Node.js 웹 서버 시작`);
  console.log(`📍 주소: http://${HOST}:${PORT}`);
  console.log(`🔧 환경: ${ENVIRONMENT}`);
  console.log(`📦 버전: ${APP_VERSION}`);
  console.log(`🐳 컨테이너 호스트명: ${os.hostname()}`);
  console.log(`📅 배포 시간: ${DEPLOYMENT_TIME}`);
  console.log(`=================================================`);
});

// 우아한 종료 처리
process.on('SIGTERM', () => {
  console.log('📛 SIGTERM 신호 수신 - 서버 종료 중...');
  server.close(() => {
    console.log('✅ 서버 종료 완료');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('📛 SIGINT 신호 수신 - 서버 종료 중...');
  server.close(() => {
    console.log('✅ 서버 종료 완료');
    process.exit(0);
  });
});

// 예외 처리
process.on('uncaughtException', (err) => {
  console.error('💥 처리되지 않은 예외:', err);
  process.exit(1);
});
