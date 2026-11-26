# NCR0X :: Ncrox para Termux

> Versão do [Satanachia ncrox](https://github.com/N3CR0-X/ncrox) para o Termux, com réplica dos comandos originais, arsenal ofensivo, repositório de ferramentas e identidade banner próprio.
> Arquivo único. Sem root. Sem distro. Tudo no aparelho.

---

## Sumário

1. [O que é](#1-o-que-é)
2. [O que não é](#2-o-que-não-é)
3. [Requisitos](#3-requisitos)
4. [Instalação](#4-instalação)
5. [Estrutura de arquivos](#5-estrutura-de-arquivos)
6. [Camada de identidade](#6-camada-de-identidade)
7. [Modos de execução](#7-modos-de-execução)
8. [Comandos de auditoria](#8-comandos-de-auditoria)
9. [Rede e web](#9-rede-e-web)
10. [Arsenal ofensivo](#10-arsenal-ofensivo)
11. [Reverse shell](#11-reverse-shell)
12. [nhack](#12-nhack)
13. [Wordlists](#13-wordlists)
14. [Utilitários](#14-utilitários)
15. [Como interpretar as saídas](#15-como-interpretar-as-saídas)
16. [Manutenção](#16-manutenção)
17. [Limitações](#17-limitações)
18. [Solução de problemas](#18-solução-de-problemas)
19. [Aviso de uso](#19-aviso-de-uso)

---

## 1. O que é

O NCR0X é um ambiente de hacking em **um único arquivo**, executado dentro do Termux, sem root, com arsenal ofensivo para hacking.

| **Arsenal ofensivo** | Recon, brute force, stress, shell reverso, captura e cracking |

A réplica existe porque o ncrox original foi desenhado para rodar no sandbox do APK Android, onde `pkg`, `apt` e o prefixo do Termux são inacessíveis. Dentro do Termux, os comandos que dependem da API Android do app degradam; a réplica cobre esse buraco com equivalentes nativos do sistema.

---

## 2. O que não é
- Não dá root. Sem SYN scan, ARP spoof, deauth ou pick crua de pacotes.

- Não substitui nmap, hashcat, sqlmap, ffuf ou Burp — é o que cabe num celular sem root.

- Não é discreto. Praticamente tudo aqui gera log no alvo.

- Não é multi-alvo. Quase todas as ferramentas trabalham com **um** host por execução.

---

## 3. Requisitos

- Termux **oficial** (F-Droid ou repositório oficial no GitHub). 

- Android 7 ou superior.

- Rede para instalação, `search`, `web`, `github`, `whois`, `nhack` e wordlists.

- ~400 MB livres para o conjunto completo (wordlists grandes + rockyou).

- `termux-api` opcional, para `say`, `volume` e `flash`.

---

## 4. Instalação

```bash
git clone https://github.com/MIATSUNO/ncrox
bash ncrox.sh
exec bash -l
```

O instalador, em ordem:

1. Atualiza índices e instala dependências (`python`, `git`, `curl`, `openssl-tool`, `dnsutils`, `whois`, `jq`, `findutils`, `ncurses-utils`, `termux-tools`, `ncat`, `netcat-openbsd`, `rlwrap`, `gzip`, `tar`, `unzip`, `zip`).

2. Clona `github.com/N3CR0-X/ncrox` em `~/.ncrox/src`.

3. Grava a biblioteca de réplica e os auxiliares Python.
4. Cria os launchers em `$PREFIX/bin`.
5. Reescreve prompt, tela de entrada, paleta e teclas extras, guardando os originais em backup.
6. Baixa as wordlists base.

Se o clone falhar, a instalação segue e a réplica assume integralmente.

---

## 5. Estrutura de arquivos

```
~/.ncrox/
├── src/                  clone do ncrox (REPL python)
├── lib/ncrox_lib.sh      biblioteca de comandos e ferramentas
├── tools/                auxiliares python (crack.py, phish.py)
├── wordlists/            listas gzip
├── hack/
│   ├── dl/               zips baixados via nhack
│   ├── env/              .env/.conf extraídos
│   └── <tool>/           ferramentas nhack instaladas
├── backup/               originais de .bashrc, motd, cores e teclas
└── phish/                página clonada + capturas.log
```

Launchers em `$PREFIX/bin`: `ncrox`, `ncrox-update`, `ncrox-restore`, `nhack` e todos os `ncx-*`.

---

## 6. Camada de identidade

Abrir o Termux mostra o banner e o prompt:

```
┌─[satanachia]─[~]
└─λ
```

| Banner | `$PREFIX/etc/motd` | Arte ASCII laranja + subtítulo azul em toda sessão nova |
| Prompt | bloco marcado no `~/.bashrc` | Caminho em azul, colchetes em laranja, `λ` |
| Título da janela | `PROMPT_COMMAND` | `satanachia :: <pasta>` |
| Paleta | `~/.termux/colors.properties` | Fundo quase preto, azul `#1E90FF`, laranja `#FF7A00` |
| Teclas extras | `~/.termux/termux.properties` | Linha com ESC, `/`, `-`, TAB, CTRL, ALT e setas |

O bloco no `.bashrc` fica entre `# >>> ncrox prompt >>>` e `# <<< ncrox prompt <<<`, removível sem afetar o restante.

---

## 7. Modos de execução

### 7.1 REPL nativo

```bash
ncrox
```

Abre o `satanachia.py` original, com prompt, comandos e `help` do próprio ncrox. `exit` encerra.

### 7.2 Réplica

```bash
ncrox help
ncrox vigia 10.0.0.1
```

O primeiro argumento vai para o despachante da réplica. Comando desconhecido é procurado no `$PATH`.

### 7.3 Diferenças

| Comandos Android do APK | falham ou degradam = não no Termux |
| Depende de rede | só nos comandos de rede | não |
| Depende do clone = não |
| Arsenal ofensivo = sim |

---

## 8. Comandos de auditoria

### `vigia <host> [portas]`

Varredura TCP connect em um host, até 32 portas, 1 s por tentativa.

```bash
vigia 10.0.0.1 22,80,443
```

Saída apenas com portas abertas e contagem final:

```
 22/tcp aberta
 443/tcp aberta
abertas: 2
```

Porta fechada e porta filtrada ficam invisíveis. A ausência não prova nada além de "não houve handshake".

### `oraculo <dominio>`

Resolve A/AAAA pelo resolvedor do sistema. Vazio ou `sem resolução` indica NXDOMAIN, falha de rede ou bloqueio do resolvedor.

### `bastiao <host> [porta]`

Handshake TLS com validação de cadeia, nome e expiração.

| `verify return code` | Significado |
|-------‐-------‐-‐-------|

| `0 (ok)` | Cadeia válida |
| `10` | Certificado expirado |
| `18` | Autoassinado |
| `20` | CA desconhecida |
| `62` | Nome não corresponde ao host |

`0` não significa ausência de vulnerabilidades — só que o certificado fecha.

### `selo <arquivo> [sha256]`

Calcula SHA-256 e, com o hash esperado, imprime `CONFERE` ou `DIVERGE`. Hash só autentica se o valor esperado vier de fonte confiável.

---

## 9. Rede e web


| `dns <dom>` | Resolução direta |
| `whois <dom>` | RDAP em JSON cru, 2500 bytes |
| `net` / `ip a` | Interfaces e endereços locais |
| `search <termo>` | 12 linhas de título/link do Bing RSS |
| `web get <url>` | 4000 primeiros bytes do corpo |
| `web title <url>` | Tag `<title>` |
| `web links <url>` | Até 20 links absolutos únicos |
| `web status <url>` | Somente o código HTTP |
| `web headers <url>` | Cabeçalhos via HEAD |
| `github repo\|user\|releases\|issues\|search` | JSON filtrado da API |
| `ondeuto -ip` | Cidade, região, país e ASN do seu IP público |

`web` aceita apenas HTTP/HTTPS. Sites que dependem de JavaScript devolvem o esqueleto deles como vazio.

---

## 10. Arsenal ofensivo

### 10.1 `ncx-port` — varredura de portas

```bash
ncx-port 10.0.0.1 top -t 200 -b
ncx-port 10.0.0.1 all -t 400
ncx-port 10.0.0.1 22,80,443,8080
```


| `top` (padrão) | ~55 portas de maior interesse |
| `all` | 1 a 65535 |
| `p1,p2,...` | Lista explícita |
| `-t N` | Probes simultâneos (padrão 150) |
| `-w N` | Timeout por porta, em segundos |
| `-b` | Banner grab |

Saída: `[+] 3306/tcp open :: <banner>`.

**Leitura:** o banner identifica o serviço (`SSH-2.0-OpenSSH_8.4`, `220 (vsFTPd 3.0.3)`). Banner vazio com porta aberta indica serviço que espera o cliente falar primeiro.

**Ajuste:** muitas portas estranhas abertas = roteador respondendo por tudo?; reduza `-t`. Em `all`, acima de 400 processos o Android começa a matar workers.

### 10.2 `ncx-dir` — descoberta de caminhos

```bash
ncx-dir https://alvo.com -t 40
ncx-dir https://alvo.com -w raft-dirs -x php -t 60
```

Contam como achado: `200 204 301 302 307 401 403` (ajustável em `-c`).

Saída: `[200] admin  (4213 bytes)`.

**Leitura:** `200` com corpo grande é página real. `301/302` redireciona, vale seguir. `401/403` existe mas barra. `200` com tamanho idêntico em tudo indica wildcard 404 disfarçado.

### 10.3 `ncx-brute` — força bruta de login

```bash
ncx-brute https://alvo.com/login usuario senha -s "logout" -t 20
ncx-brute https://alvo.com/login email pass -p 10k -c 302
```

| Flag | Efeito |
|---|---|
| `-u` | Lista de usuários (padrão: `users`) |
| `-p` | Lista de senhas (padrão: `10k`) |
| `-s` | Texto presente só no sucesso |
| `-f` | Texto presente só no fracasso — tem prioridade sobre `-s` |
| `-c` | Código HTTP de sucesso |
| `-t` | Concorrência |

Saída: `[OK] admin : senha123  (code 302, 512 bytes)` ou `[--] admin : 123456  (code 200, 4891 bytes)`.

**Leitura:** só `[OK]` importa. Se todos vierem `[OK]`, a detecção está frouxa — use `-f` com a mensagem de erro real da aplicação. Se todos vierem `[--]`, o campo ou o endpoint estão errados.

### 10.4 `ncx-flood` — stress HTTP

```bash
ncx-flood https://alvo.com -c 100 -n 1000
ncx-flood https://alvo.com -c 50 -n 500 -m POST
```

Dispara `n` requisições com `c` simultâneas e mede a vazão.

Saída: `4821.3 req/s em 0.21s`.

**Leitura:** req/s alto com alvo lento indica que você só encheu a fila do seu próprio socket. Compare o tempo total com a queda de resposta do alvo em outro terminal.

### 10.5 `ncx-sub` — enumeração de subdomínios

```bash
ncx-sub alvo.com -w dns5000 -t 40
```

Saída: `[+] dev.alvo.com -> 10.0.0.7`. Só imprime o que resolve.

**Leitura:** subdomínio que resolve para IP privado costuma ser ambiente interno exposto por engano. Sem checagem de wildcard, um `*.alvo.com` genérico gera falso positivo em massa.

### 10.6 `ncx-takeover` — subdomain takeover

```bash
ncx-takeover alvo.com -w dns5000 -t 20
```

Resolve o CNAME, compara com 24 fingerprints de serviços (GitHub Pages, Heroku, S3, Netlify, Azure, Shopify, Zendesk, Fastly e outros) e busca a assinatura de "app inexistente" no corpo.

| Marca | Significado |
|---|---|
| `[VULN]` | CNAME aponta para serviço + assinatura de recurso removido confirmada |
| `[SUSP]` | CNAME aponta para serviço, mas a assinatura não apareceu |

`[VULN]` é forte candidato, não prova: você ainda precisa tentar registrar o recurso no provedor.

### 10.7 `ncx-crack` — quebra de hash

```bash
ncx-crack 5f4dcc3b5aa765d61d8327deb882cf99 -w 10k
ncx-crack '$2b$12$...' -w rockyou -r cdsl -t 4
```

Algoritmo detectado pelo tamanho e prefixo: `32` md5, `40` sha1, `64` sha256, `96` sha384, `128` sha512, `$2a$/$2b$/$2y$` bcrypt.

Regras (`-r`): `c` variação de caixa, `d` dígitos e anos 1990-2026, `l` leetspeak, `s` sufixos comuns.

Saída: `[+] QUEBRADO: senha123`.

**Leitura:** o contador `[i] N testados` vai para stderr e mostra o ritmo. bcrypt roda com 1 processo e é ordens de magnitude mais lento — normal.

---

## 11. Reverse shell

### `ncx-rev <lhost> <lport> [flags]`

```bash
ncx-rev - 4444 -l
ncx-rev 10.0.0.5 4444 -t python3 -u
ncx-rev 10.0.0.5 4444 -t powershell-b64
```

| `-` no lugar do IP | Detecta o IP local automaticamente |
| `-t tipo` | Um payload específico |
| `-a` | Todos os tipos |
| `-u` | URL-encode |
| `-b` | Base64 |
| `-l` | Abre o listener em seguida |

Tipos: `bash sh bash196 nc nc-mkfifo ncat socat python3 python2 perl php ruby node awk telnet xterm lua java powershell powershell-b64 golang`.

`ncat` e `socat` exigem listener correspondente; o rodapé imprime o comando certo.

### `ncx-listen <porta>`

Abre o receptor com `ncat`, caindo para `nc -lvnp`, depois `busybox nc -l -p`, embrulhado em `rlwrap` quando disponível.

**Leitura:** shell sem prompt = normal em `nc` puro. Sem `rlwrap`, setas e histórico não funcionam. Se conectar e cair na hora, o payload e o listener estão incompatíveis.

---

## 12. nhack

### `ncrox for hack` / `nhack list`

Lista os `.zip` publicados em `github.com/N3CR0-X/ncroxhack` com nome e tamanho.

### `nhack search <termo>`

Filtra o catálogo pelo termo.

### `nhack pick <tool.zip>`

Baixa de `raw.githubusercontent.com` com fallback para `/raw/`, valida o zip com `unzip -t`, mostra o SHA-256 e grava em `~/.ncrox/hack/dl/`.

### `nhack -st <tool.zip> [--no-run]`

Extrai e instala:

- Rejeita zip com caminho absoluto ou `../`.
- Achata diretório-raiz único.
- Arquivos com shebang ou bit de execução viram symlink em `$PREFIX/bin` (colisão recebe prefixo `tool-`).
- `.env`, `.conf`, `.cfg` vão para `~/.ncrox/hack/env/`.
- `requirements.txt` gera venv isolada em `~/.venvs/nhack-<tool>`.
- `install.sh`/`setup.sh` executam automaticamente, salvo `--no-run`.

### `nhack get <tool.zip>`

`pick` + `-st` em um passo.

### `nhack installed` / `nhack rm <tool>`

Lista e remove ferramentas, apagando também os symlinks e a venv.

**Leitura:** `linked: 0` significa zip sem executável — só arquivos de dados. Se `install.sh` falhar, a ferramenta fica instalada mas provavelmente inoperante.

---

## 13. Wordlists

```bash
ncx-wordlists list
ncx-wordlists catalog
ncx-wordlists update
ncx-wordlists get raft-dirs
ncx-wordlists rockyou
ncx-wordlists clean
```

Tudo é gravado comprimido em `~/.ncrox/wordlists` e lido em streaming com `gzip -dc`, sem carregar na memória.

O parâmetro `-w` de qualquer ferramenta aceita três formas: nome do catálogo, caminho de arquivo local ou `.gz`.

| Nome | Conteúdo |
|---|---|
| `common` | Caminhos web genéricos |
| `raft-dirs` | Diretórios raft |
| `dir23` | directory-list 2.3 small |
| `dns5000` | 5 mil subdomínios |
| `namelist` | Nomes DNS |
| `10k` | 10 mil senhas |
| `pass-short` | Senhas curtas populares |
| `users` | Usuários comuns |
| `top1m` | 1 milhão de senhas |
| `rockyou` | 14 milhões de senhas |

---

## 14. Utilitários

`hash`, `base64 enc|dec`, `urlinfo`, `jsoncheck`, `comparar`, `fileinfo`, `uuid`, `netcheck`, `sysinfo`, `disk`, `which`, `where`, `findtext`, `rede`, `tree`, `readmd`, `device`, `battery`, `storage`, `screen`, `uptime`, `locale`, `timezone`, `volume`, `ringer`, `say`, `open`, `pack`, `docs`, `applist`, `tasklist`, `settings`.

`rede 10.0.0.0/24` calcula rede, máscara, broadcast e hosts sem tocar na rede. `netcheck host porta` faz uma conexão TCP de até 3 s.

---

## 15. Como interpretar as saídas

### 15.1 Cores

| Cor | Uso |
|---|---|
| Laranja | Cabeçalho de ferramenta, porta aberta, achado |
| Azul | Contexto, subtítulo, status |
| Verde | Positivo: aberto, achado, quebrado, instalado |
| Vermelho | Vulnerável, erro, falha |
| Amarelo | Suspeita, aviso brando |
| Cinza | Neutro, ignorado, tentativa sem resultado |

### 15.2 Marcadores

| Marcador | Significado |
|---|---|
| `[+]` | Sucesso |
| `[-]` | Falha esperada, sem resultado |
| `[!]` | Aviso ou erro de execução |
| `[OK]` / `[--]` | Credencial válida / inválida |
| `[VULN]` / `[SUSP]` | Takeover confirmado / suspeito |
| `[200]`, `[403]` | Código HTTP do caminho |

### 15.3 Estrutura padrão

```
┌─ ferramenta :: parâmetros        ← laranja, cabeçalho
└─                                ← fecho do cabeçalho
  resultados                      ← corpo
────────────────────────────────  ← rodapé cinza
```

O cabeçalho repete exatamente o que foi executado. Se os parâmetros estiverem errados, é ali que você percebe.

---

## 16. Manutenção

| Comando | Efeito |
|---|---|
| `ncrox-update` | `git pull` no clone |
| `ncrox-restore` | Devolve `.bashrc`, cores, teclas e motd originais e remove launchers |
| `ncx-wordlists clean` | Apaga todas as listas |
| `nhack rm <tool>` | Remove ferramenta e symlinks |
| `ncrox -r` | Abre a ajuda da réplica sem tocar no REPL |

O `ncrox-restore` **não** apaga `~/.ncrox` — fontes, wordlists e ferramentas permanecem.

---

## 17. Limitações

### 17.1 Plataforma

- **Sem root:** nenhuma ferramenta abre socket cru. Sem SYN scan, sem UDP scan, sem ARP spoof, sem deauth, sem tcpdump.
- **Sem PTY no REPL:** o `satanachia.py` roda dentro do shell do Termux, mas programas interativos chamados por ele (vim, top) continuam problemáticos.
- **Processos morrem em segundo plano:** o Android encerra sessões ociosas; varreduras longas exigem a tela ligada ou wake lock.
- **Comandos Android do APK degradam:** `flash`, `aviso`, `applist -sudozi`, `lock`, `avrcp`, `settings` do REPL original dependem do sandbox do app e falham ou retornam vazio. A réplica cobre com `getprop`, `dumpsys`, `pm`, `wm` e `termux-*`, mas sem os mesmos dados.
- **`say`, `volume` e `flash`** exigem `termux-api` e o app Termux:API instalado.
- **Um host por execução.** Nada de CIDR, faixa ou lista de alvos em `ncx-port`, `ncx-dir`, `ncx-brute` ou `ncx-flood`.

### 17.2 Rede

- **IPv4 apenas** nas varreduras: só o primeiro endereço resolvido é usado.
- **TCP connect puro:** cada porta aberta deixa registro no alvo; é o modo mais barulhento possível.
- **Sem UDP.** DNS, SNMP e afins não são cobertos.
- **Sem proxy, sem cookies persistentes, sem cabeçalhos customizados** nas ferramentas HTTP.
- **Sem detecção de wildcard DNS** em `ncx-sub` — domínio com `*.alvo.com` gera falso positivo em massa.
- **Sem detecção de wildcard 404** em `ncx-dir` — calibrar manualmente comparando tamanhos.

### 17.3 Ferramentas

| Ferramenta | Limite |
|---|---|
| `ncx-port` | Um processo bash por porta; `all` com `-t` alto estoura o limite de processos |
| `ncx-dir` | Sem recursão, sem autenticação, sem 404 calibrado |
| `ncx-brute` | Só `application/x-www-form-urlencoded`; sem token CSRF, sem JSON, sem cookie jar, sem lidar com rate limit ou bloqueio de conta; detecção de sucesso é heurística |
| `ncx-flood` | Um `curl` por requisição, sem keep-alive; não é DDoS, é stress de um IP só |
| `ncx-takeover` | Fingerprint heurístico, confirmação só por HTTP; não prova que você consegue reivindicar o recurso |
| `ncx-crack` | Só CPU, sem GPU, sem máscara, sem regras estilo hashcat; bcrypt é lento; hashes com salt por usuário não são tratados |
| `ncx-phish` | HTTP puro, sem TLS, sem túnel (só LAN ou com port forward), sem relay de 2FA, sem repasse de cookie de sessão; reescrita de `action` é ingênua e quebra em SPA |
| `ncx-rev` | Só gera payload; sem staging, sem TLS por padrão; vários dependem de binários que o alvo pode não ter |

### 17.4 nhack

- API do GitHub sem token: **60 requisições por hora**, depois disso a listagem retorna vazio.
- O repositório precisa ser público e os zips precisam estar na raiz.
- `install.sh` roda código arbitrário — o zip é confiável só se a origem for.
- Sem assinatura, sem pin de dependência, sem rollback automático em caso de falha.

### 17.5 Wordlists

- Os caminhos apontam para a branch `master` do SecLists: renomeações na origem quebram o `update`.
- `rockyou` são ~130 MB comprimidos e ~300 MB livres no processo.
- `top1m` em `ncx-brute` gera milhões de combinações e pode levar horas.

### 17.6 Identidade

- A paleta e as teclas sobrescrevem o que existia; os originais só voltam com `ncrox-restore`.
- `extra-keys` não é aplicado se você já tiver uma linha própria.
- O banner aparece em toda sessão nova, inclusive em scripts com `bash -l`.

---

## 18. Solução de problemas

| Sintoma | Causa provável | Correção |
|---|---|---|
| `comando não encontrado` | Launcher fora do `$PATH` | `exec bash -l` ou reinstale |
| `sem resolução` | DNS do sistema | Troque o resolvedor, teste com `oraculo` |
| Listagem do `nhack` vazia | Repo vazio, 404 ou limite de API | Confira o repositório; aguarde 1 h |
| `zip corrompido` | Download truncado | `nhack pick` novamente |
| `zip com caminho absoluto ou ..` | Zip mal empacotado | Reempacote com `zip -r` a partir da pasta |
| Todos `[--]` no brute | Campo ou endpoint errados | Confira os nomes dos inputs no HTML |
| Todos `[OK]` no brute | Detecção frouxa | Use `-f` com a mensagem de erro real |
| Varredura travando | `-t` acima do limite | Reduza para 100–200 |
| `nenhum nc/ncat instalado` | Dependência faltando | `pkg install netcat-openbsd ncat` |
| Prompt antigo | Sessão não recarregada | `exec bash -l` |
| Cores não aplicadas | Termux não recarregou | `termux-reload-settings` |

---

## 19. Aviso de uso

Use apenas em alvos próprios ou com autorização explícita.

Todas as ferramentas geram conexões e consultas reais, registradas no alvo. `ncx-flood` e `ncx-brute` podem derrubar serviço frágil e disparar bloqueio de conta. `ncx-phish` coleta credenciais em texto puro. `nhack` executa scripts do ncroxhack packs no seu aparelho.
