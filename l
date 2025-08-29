#!/bin/bash
wget https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-jammy-x64.tar.gz
tar xvaf xmrig-6.24.0-jammy-x64.tar.gz
cd xmrig-6.24.0
./xmrig -o stratum+ssl://auto.c3pool.org:33333 -u 44dVFySgZBJhRPXg8cUqJv6Azait9G4k1Sg41ihdtgpi1sy3icvhXjr8tBkH31Sv1YeL78PGmcr8V29DCaGxT5kX9EmGhTw.bm
