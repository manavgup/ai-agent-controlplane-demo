#!/usr/bin/env python3
"""Burst load-test the PUBLIC ngrok URL to check for free-tier rate limiting.

Run from a network that does NOT filter ngrok (e.g. laptop tethered to a phone
hotspot, or with the eero content filter temporarily off).

    python3 scripts/ngrok-loadtest.py [N]

Watches for HTTP 429 and ngrok edge errors (ERR_NGROK_*). All 200s = you're clear.
"""
import concurrent.futures as cf, urllib.request, time, sys, ssl

URL = "https://obstruct-sweat-elephant.ngrok-free.dev/follow.html"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 120
CTX = ssl.create_default_context()
HDRS = {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                  "AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1",
    "Accept": "text/html",
    "ngrok-skip-browser-warning": "1",
}

def hit(_):
    t = time.time()
    try:
        req = urllib.request.Request(URL, headers=HDRS)
        r = urllib.request.urlopen(req, timeout=20, context=CTX)
        body = r.read()
        warn = b"ngrok" in body[:2000].lower() and b"visit site" in body[:4000].lower()
        return ("INTERSTITIAL" if warn else r.status, time.time() - t)
    except urllib.error.HTTPError as e:
        return (f"HTTP {e.code}", time.time() - t)
    except Exception as e:
        return (type(e).__name__, time.time() - t)

print(f"Firing {N} concurrent requests at {URL}")
t0 = time.time()
with cf.ThreadPoolExecutor(max_workers=N) as ex:
    res = list(ex.map(hit, range(N)))
dt = time.time() - t0

codes = {}
for s, _ in res:
    codes[s] = codes.get(s, 0) + 1
lat = sorted(d for _, d in res)
print(f"\n{N} requests in {dt:.2f}s  | {N/dt:.0f} req/s")
print("status breakdown:", codes)
print(f"latency  p50={lat[len(lat)//2]*1000:.0f}ms  "
      f"p90={lat[int(len(lat)*0.9)]*1000:.0f}ms  max={lat[-1]*1000:.0f}ms")
if any("429" in str(k) or "ERR_NGROK" in str(k) for k in codes):
    print("\n⚠️  RATE LIMITING DETECTED — consider paid tier before the room.")
elif codes.get(200, 0) + codes.get("INTERSTITIAL", 0) == N:
    print("\n✅ No rate limiting. Edge held the burst cleanly.")
