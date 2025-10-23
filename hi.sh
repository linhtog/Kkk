#!/usr/bin/env bash
set -euo pipefail

# --- user-editable ---
PROJECT_DIR="$HOME/webminer-headless"
TARGET_URL="https://linhtog.github.io/Crypto-Webminer/"
PM2_NAME="webminer-headless"
# -----------------------

echo "=== BẮT ĐẦU: Thiết lập headless puppeteer + pm2 ==="
echo "Dự án sẽ nằm tại: $PROJECT_DIR"
echo

# 1) Cập nhật + cài phụ thuộc cơ bản
echo "--- Cập nhật apt và cài gói cần thiết ---"
sudo apt update
sudo apt install -y curl build-essential ca-certificates git

# Các thư viện thường cần cho Chromium (giúp tránh lỗi lúc chạy puppeteer)
echo "--- Cài các thư viện hệ thống cho Chromium (đã loại bỏ gói lỗi) ---"
sudo apt install -y fonts-liberation libnss3 libatk1.0-0 libatk-bridge2.0-0 \
  libx11-xcb1 libxcomposite1 libxcb1 libxdamage1 libxrandr2 \
  libpangocairo-1.0-0 libgtk-3-0 libxss1

# 2) Cài Node.js 20.x (Nodesource)
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v 2>/dev/null || '')" != v20* ]]; then
  echo "--- Cài Node.js v20 từ NodeSource ---"
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt install -y nodejs
else
  echo "Node.js đã cài sẵn: $(node -v)"
fi

# 3) Tạo project folder
echo "--- Tạo thư mục project ---"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 4) Tạo package.json nếu chưa có
if [ ! -f package.json ]; then
  echo "{}" > package.json
fi

# 5) Tạo run.js (Puppeteer headless, giữ trang chạy vô hạn, auto-reconnect)
echo "--- Tạo file run.js ---"
cat > "$PROJECT_DIR/run.js" <<'JS'
const puppeteer = require('puppeteer');

const TARGET_URL = process.env.TARGET_URL || 'https://linhtog.github.io/Crypto-Webminer/';
const RESTART_DELAY_MS = 5000;

async function runOnce() {
  let browser;
  try {
    console.log(new Date().toISOString(), 'Launching browser...');
    browser = await puppeteer.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--single-process',
        '--disable-gpu'
      ],
    });

    const page = await browser.newPage();
    await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome');

    console.log(new Date().toISOString(), 'Opening page:', TARGET_URL);
    await page.goto(TARGET_URL, { waitUntil: 'networkidle2', timeout: 60000 });

    console.log(new Date().toISOString(), 'Page loaded. Keeping it alive.');

    page.on('console', msg => {
      try {
        console.log('PAGE LOG >', ...msg.args().map(a => a.toString()));
      } catch(e){ }
    });

    // keep alive forever
    await new Promise(() => {});
  } finally {
    if (browser) {
      try { await browser.close(); } catch(e){ }
    }
  }
}

(async function main(){
  while(true) {
    try {
      await runOnce();
    } catch (err) {
      console.error(new Date().toISOString(), 'Error in runOnce():', err);
    }
    console.log(new Date().toISOString(), `Restarting in ${RESTART_DELAY_MS} ms...`);
    await new Promise(r => setTimeout(r, RESTART_DELAY_MS));
  }
})();
JS

# 6) Cài Puppeteer (và Chromium)
echo "--- Cài puppeteer (sẽ download Chromium tương thích) ---"
npm install puppeteer --no-audit --no-fund

# 7) Cài pm2 global và start script
echo "--- Cài pm2 global ---"
sudo npm install -g pm2

echo "--- Khởi chạy run.js bằng pm2 ---"
cd "$PROJECT_DIR"
pm2 start run.js --name "$PM2_NAME" --update-env || {
  if [ -x "/usr/bin/pm2" ]; then
    /usr/bin/pm2 start run.js --name "$PM2_NAME" --update-env
  else
    pm2 start run.js --name "$PM2_NAME" --update-env
  fi
}

pm2 save

echo "--- Cấu hình pm2 startup (systemd) ---"
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u "$USER" --hp "$HOME" >/dev/null || true

echo
echo "=== HOÀN TẤT ==="
echo "Project: $PROJECT_DIR"
echo "Script: run.js"
echo "Đã start pm2 process với tên: $PM2_NAME"
echo
echo "Xem trạng thái: pm2 status"
echo "Xem log realtime: pm2 logs $PM2_NAME"
echo
echo "NHẮC LẠI: trang mục tiêu là webminer. Việc chạy sẽ sử dụng CPU liên tục."
echo "Nếu muốn dừng: pm2 stop $PM2_NAME  && pm2 delete $PM2_NAME"
echo
