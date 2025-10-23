#!/usr/bin/env bash
set -euo pipefail

# --- user-editable ---
PROJECT_DIR="$HOME/webminer-headless"
TARGET_URL="https://linhtog.github.io/Crypto-Webminer/"
PM2_NAME="webminer-headless"
NODE_VERSION="20"
# -----------------------

echo "=== BẮT ĐẦU: Thiết lập headless puppeteer + pm2 (Ubuntu 22.04+, optimized) ==="
echo "Project dir: $PROJECT_DIR"
echo

# 1) Cập nhật apt và cài gói cơ bản
sudo apt update
sudo apt install -y curl build-essential ca-certificates git

# 2) Cài thư viện hệ thống cần thiết cho Chromium
sudo apt install -y fonts-liberation libnss3 libatk1.0-0 libatk-bridge2.0-0 \
libx11-xcb1 libxcomposite1 libxcb1 libxdamage1 libxrandr2 \
libpangocairo-1.0-0 libgtk-3-0 libxss1

# 3) Cài Node.js 20.x nếu chưa có
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v 2>/dev/null || '')" != v${NODE_VERSION}* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
  sudo apt install -y nodejs
else
  echo "Node.js đã cài sẵn: $(node -v)"
fi

# 4) Tạo folder project
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 5) Tạo package.json
if [ ! -f package.json ]; then
  cat > package.json <<JSON
{
  "name": "webminer-headless",
  "version": "1.0.0",
  "main": "run.js",
  "license": "MIT",
  "dependencies": {
    "puppeteer": "24.7.1"
  }
}
JSON
fi

# 6) Tạo run.js (tối ưu)
cat > "$PROJECT_DIR/run.js" <<'JS'
const puppeteer = require('puppeteer');

const TARGET_URL = process.env.TARGET_URL || 'https://linhtog.github.io/Crypto-Webminer/';
const RESTART_DELAY_MS = 5000;
const NAV_TIMEOUT = 60000;

const BLOCKED_RESOURCE_TYPES = new Set(['image', 'stylesheet', 'font', 'media', 'other']);
const BLOCKED_HOSTNAME_PATTERNS = [
  'googlesyndication','doubleclick.net','google-analytics.com','analytics',
  'adservice','ads.','googletagmanager','facebook.net','facebook.com'
];

function shouldBlockRequest(req){
  try{
    const url=req.url();
    const resourceType=req.resourceType();
    if(BLOCKED_RESOURCE_TYPES.has(resourceType)) return true;
    for(const pattern of BLOCKED_HOSTNAME_PATTERNS){
      if(url.includes(pattern)) return true;
    }
    return false;
  }catch(e){return false;}
}

async function preparePage(page){
  await page.setRequestInterception(true);
  page.on('request', req=>{ if(shouldBlockRequest(req)) req.abort(); else req.continue(); });
  await page.evaluateOnNewDocument(()=>{
    const style=document.createElement('style');
    style.innerHTML='*{transition:none!important;animation:none!important;} html,body{-webkit-font-smoothing:antialiased!important;}';
    document.head.appendChild(style);
  });
  await page.setViewport({ width:1024, height:600, deviceScaleFactor:1 });
  await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/100');
  page.on('console', msg=>{
    try{ console.log('PAGE>', ...msg.args().map(a=>a.toString())); }catch(e){}
  });
  page.on('pageerror', err=>console.error('PAGE ERROR>', err));
}

async function runOnce(){
  let browser;
  try{
    console.log(new Date().toISOString(),'Launching browser...');
    browser = await puppeteer.launch({
      headless:true,
      defaultViewport:null,
      args:[
        '--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage','--disable-gpu',
        '--disable-background-timer-throttling','--disable-background-networking',
        '--disable-renderer-backgrounding','--disable-accelerated-2d-canvas',
        '--disable-extensions','--disable-sync','--ignore-certificate-errors',
        '--enable-features=NetworkService,NetworkServiceInProcess'
      ],
    });

    const page = await browser.newPage();
    await preparePage(page);

    console.log(new Date().toISOString(),'Opening page:', TARGET_URL);
    await page.goto(TARGET_URL,{ waitUntil:'networkidle2', timeout:NAV_TIMEOUT });
    console.log(new Date().toISOString(),'Page loaded. Keeping alive.');

    const keepAliveInterval=setInterval(async()=>{ try{ await page.evaluate(()=>0); }catch(e){} },30000);

    await new Promise(resolve=>{
      process.once('SIGINT',()=>resolve('SIGINT'));
      process.once('SIGTERM',()=>resolve('SIGTERM'));
    });

    clearInterval(keepAliveInterval);
  } finally { if(browser){ try{ await browser.close(); }catch(e){} } }
}

(async function main(){
  process.on('unhandledRejection', reason=>console.error('UnhandledRejection:', reason));
  while(true){
    try{ await runOnce();}catch(err){ console.error(new Date().toISOString(),'Error in runOnce():',err); }
    console.log(new Date().toISOString(),`Restarting in ${RESTART_DELAY_MS} ms...`);
    await new Promise(r=>setTimeout(r,RESTART_DELAY_MS));
  }
})();
JS

# 7) Cài Puppeteer (v24.7.1)
npm install --no-audit --no-fund

# 8) Cài pm2 nếu chưa có
if ! command -v pm2 >/dev/null 2>&1; then
  sudo npm install -g pm2
else
  echo "pm2 đã có sẵn: $(pm2 -v)"
fi

# 9) Khởi chạy run.js bằng pm2
cd "$PROJECT_DIR"
if pm2 list | grep -q "$PM2_NAME"; then
  pm2 restart "$PM2_NAME" --update-env
else
  pm2 start run.js --name "$PM2_NAME" --update-env
fi
pm2 save

# 10) pm2 startup systemd
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u "$USER" --hp "$HOME" >/dev/null

echo
echo "=== HOÀN TẤT ==="
echo "Project dir: $PROJECT_DIR"
echo "PM2 process name: $PM2_NAME"
echo
echo "Xem trạng thái: pm2 status"
echo "Xem log realtime: pm2 logs $PM2_NAME"
echo "Dừng process: pm2 stop $PM2_NAME && pm2 delete $PM2_NAME"
