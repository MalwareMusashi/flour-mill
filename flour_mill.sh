#!/bin/bash

# flour mill
# automated recon - scans, checks vulns, runs tools
# usage: ./flour_mill.sh [target] or TARGET=ip ./flour_mill.sh

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
BLU='\033[0;34m'
NC='\033[0m'

AVAIL=()
MISSING=()
TARGET=""
OUTDIR=""
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
start_time=$(date +%s)
SCAN_TYPE=""
os=""
VERSION="2.0"

# check for update flag
if [[ "$1" == "--update" || "$1" == "-u" ]]; then
    echo -e "${YEL}[*] checking for updates...${NC}"
    
    script_dir=$(dirname $(readlink -f "$0"))
    
    if [[ -d "$script_dir/.git" ]]; then
        cd "$script_dir"
        git fetch origin >/dev/null 2>&1
        
        local_hash=$(git rev-parse HEAD)
        remote_hash=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
        
        if [[ "$local_hash" == "$remote_hash" ]]; then
            echo -e "${GRN}[+] already up to date${NC}"
        else
            echo -e "${YEL}[*] updating...${NC}"
            git pull
            echo -e "${GRN}[+] updated${NC}"
        fi
    else
        echo -e "${RED}not a git repo, can't update${NC}"
        echo -e "${YEL}reinstall from github or use git clone${NC}"
    fi
    exit 0
fi

# check for version flag
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "flour_mill v${VERSION}"
    exit 0
fi

# grab target from args if provided
if [[ -n "$1" && "$1" != -* ]]; then
    TARGET="$1"
fi

banner() {
    echo -e "${BLU}"
    cat << "EOF"
    || __   ||
    ||=\_`\=||
    || (__/ ||
    ||  | | :-"""-.
    ||==| \/-=-.   \
    ||  |(_|o o/   |_
    ||   \/ "  \   ,_)
    ||====\ ^  /__/
    ||     ;--'  `-.
    ||    /      .  \
    ||===;        \  \
    ||   |         | |
    || .-\ '     _/_/
    |:'  _;.    (_  \
    /  .'  `;\   \\_/
   |_ /     |||  |\\
  /  _)=====|||  | ||
 /  /|      ||/  / //
 \_/||      ( `-/ ||
    ||======/  /  \\ .-.
    ||      \_/    \'-'/
    ||      ||      `"`
    ||======||
    ||      ||

                        ╔═══════════════════════════════╗
                        ║     Flour Mill v2.0           ║
                        ║   scan → parse → exploit      ║
                        ╚═══════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# check deps
check_deps() {
    echo -e "${YEL}[*] checking tools...${NC}\n"
    
    tools=(
        "nmap:network scanning"
        "kerbrute:kerberos enum"
        "impacket-GetNPUsers:asreproast"
        "impacket-GetUserSPNs:kerberoast"
        "enum4linux:smb enum"
        "smbclient:smb client"
        "netexec:protocol testing"
        "hydra:bruteforce"
        "medusa:bruteforce"
        "nikto:web scanner"
        "gobuster:dir bruteforce"
        "dirb:web enum"
        "ffuf:web fuzzer"
        "dirsearch:web scanner"
        "nuclei:vuln scanner"
        "sqlmap:sqli"
        "ssh-audit:ssh check"
        "msfconsole:metasploit"
        "responder:poisoner"
        "ldapsearch:ldap"
        "dig:dns"
        "dnsenum:dns enum"
    )
    
    for t in "${tools[@]}"; do
        tool=$(echo "$t" | cut -d: -f1)
        desc=$(echo "$t" | cut -d: -f2)
        
        if command -v "$tool" &>/dev/null; then
            AVAIL+=("$tool")
            echo -e "${GRN}[+]${NC} $tool"
        else
            MISSING+=("$tool")
            echo -e "${RED}[-]${NC} $tool"
        fi
    done
    
    echo -e "\n${GRN}got: ${#AVAIL[@]}${NC} | ${RED}missing: ${#MISSING[@]}${NC}\n"
    
    [[ ! $(command -v nmap) ]] && { echo -e "${RED}need nmap${NC}"; exit 1; }
    
    # check wordlists
    check_wordlists
    
    # install wordlists
install_wordlists() {
    echo -e "${YEL}[*] installing wordlists...${NC}\n"
    
    # dirb
    if [ ! -f "/usr/share/wordlists/dirb/common.txt" ]; then
        echo -e "${BLU}[*] dirb wordlists...${NC}"
        sudo apt install -y dirb 2>/dev/null
        [ -f "/usr/share/wordlists/dirb/common.txt" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
    fi
    
    # dirbuster
    if [ ! -f "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt" ]; then
        echo -e "${BLU}[*] dirbuster wordlists...${NC}"
        sudo apt install -y dirbuster 2>/dev/null
        [ -f "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
    fi
    
    # rockyou
    if [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
        echo -e "${BLU}[*] rockyou...${NC}"
        if [ -f "/usr/share/wordlists/rockyou.txt.gz" ]; then
            sudo gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null
            [ -f "/usr/share/wordlists/rockyou.txt" ] && echo -e "${GRN}[+] extracted${NC}" || echo -e "${RED}[-] failed${NC}"
        else
            sudo apt install -y wordlists 2>/dev/null
            [ -f "/usr/share/wordlists/rockyou.txt.gz" ] && sudo gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null
            [ -f "/usr/share/wordlists/rockyou.txt" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
        fi
    fi
    
    # seclists
    if [ ! -d "/usr/share/seclists" ]; then
        echo -e "${BLU}[*] seclists...${NC}"
        sudo apt install -y seclists 2>/dev/null || {
            # fallback to github
            sudo git clone https://github.com/danielmiessler/SecLists.git /usr/share/seclists 2>/dev/null
        }
        [ -d "/usr/share/seclists" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
    fi
    
    echo -e "\n${GRN}wordlists setup done${NC}\n"
}

# install missing stuff
    if [ ${#MISSING[@]} -gt 0 ]; then
        echo -e "${YEL}missing ${#MISSING[@]} tools${NC}"
        read -p "install? (y/n): " inst
        
        [[ "$inst" =~ ^[Yy]$ ]] && install_missing
        echo ""
    fi
}

# check for wordlists
check_wordlists() {
    echo -e "${YEL}[*] checking wordlists...${NC}\n"
    
    wordlists=(
        "/usr/share/wordlists/dirb/common.txt:dirb common"
        "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt:dirbuster medium"
        "/usr/share/wordlists/rockyou.txt:rockyou"
        "/usr/share/seclists:seclists"
    )
    
    missing_wl=()
    
    for wl in "${wordlists[@]}"; do
        path=$(echo "$wl" | cut -d: -f1)
        name=$(echo "$wl" | cut -d: -f2)
        
        if [ -e "$path" ]; then
            echo -e "${GRN}[+]${NC} $name"
        else
            echo -e "${RED}[-]${NC} $name"
            missing_wl+=("$name")
        fi
    done
    
    echo ""
    
    if [ ${#missing_wl[@]} -gt 0 ]; then
        echo -e "${YEL}missing ${#missing_wl[@]} wordlists${NC}"
        read -p "install wordlists? (y/n): " inst_wl
        
        if [[ "$inst_wl" =~ ^[Yy]$ ]]; then
            install_wordlists
        fi
        echo ""
    fi
}

# install wordlists
install_wordlists() {
    echo -e "${YEL}[*] installing wordlists...${NC}\n"
    
    # dirb
    if [ ! -f "/usr/share/wordlists/dirb/common.txt" ]; then
        echo -e "${BLU}[*] dirb wordlists...${NC}"
        sudo apt install -y dirb 2>/dev/null
        [ -f "/usr/share/wordlists/dirb/common.txt" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
    fi
    
    # dirbuster
    if [ ! -f "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt" ]; then
        echo -e "${BLU}[*] dirbuster wordlists...${NC}"
        sudo apt install -y dirbuster 2>/dev/null
        [ -f "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
    fi
    
    # rockyou
    if [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
        echo -e "${BLU}[*] rockyou...${NC}"
        if [ -f "/usr/share/wordlists/rockyou.txt.gz" ]; then
            sudo gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null
            [ -f "/usr/share/wordlists/rockyou.txt" ] && echo -e "${GRN}[+] extracted${NC}" || echo -e "${RED}[-] failed${NC}"
        else
            sudo apt install -y wordlists 2>/dev/null
            [ -f "/usr/share/wordlists/rockyou.txt.gz" ] && sudo gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null
            [ -f "/usr/share/wordlists/rockyou.txt" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
        fi
    fi
    
    # seclists
    if [ ! -d "/usr/share/seclists" ]; then
        echo -e "${BLU}[*] seclists...${NC}"
        sudo apt install -y seclists 2>/dev/null || {
            # fallback to github
            sudo git clone https://github.com/danielmiessler/SecLists.git /usr/share/seclists 2>/dev/null
        }
        [ -d "/usr/share/seclists" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
    fi
    
    echo -e "\n${GRN}wordlists setup done${NC}\n"
}

# install missing
install_missing() {
    echo -e "${YEL}[*] installing...${NC}\n"
    
    # need pipx for some stuff
    need_pipx=false
    for t in "${MISSING[@]}"; do
        case $t in
            netexec|impacket-*|kerbrute) need_pipx=true ;;
        esac
    done
    
    if $need_pipx && ! command -v pipx &>/dev/null; then
        echo -e "${YEL}[*] getting pipx...${NC}"
        sudo apt update && sudo apt install -y pipx
        pipx ensurepath
    fi
    
    # check if go needed
    need_go=false
    for t in "${MISSING[@]}"; do
        [[ "$t" == "ffuf" || "$t" == "nuclei" ]] && need_go=true
    done
    
    if $need_go && ! command -v go &>/dev/null; then
        echo -e "${YEL}go not found, needed for ffuf${NC}"
        read -p "install go? (y/n): " inst_go
        if [[ "$inst_go" =~ ^[Yy]$ ]]; then
            echo -e "${YEL}[*] installing go...${NC}"
            sudo apt update && sudo apt install -y golang-go
        fi
    fi
    
    for t in "${MISSING[@]}"; do
        echo -e "${BLU}[*] $t...${NC}"
        
        case $t in
            netexec)
                pipx install git+https://github.com/Pennyw0rth/NetExec 2>/dev/null
                ;;
            impacket-GetNPUsers|impacket-GetUserSPNs)
                pipx install impacket 2>/dev/null
                ;;
            kerbrute)
                wget -q https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64 -O /tmp/kerbrute
                chmod +x /tmp/kerbrute
                sudo mv /tmp/kerbrute /usr/local/bin/kerbrute 2>/dev/null
                ;;
            ffuf)
                # check if go is installed
                if command -v go &>/dev/null; then
                    go install github.com/ffuf/ffuf@latest 2>/dev/null
                    # move from ~/go/bin to /usr/local/bin if exists
                    [[ -f ~/go/bin/ffuf ]] && sudo cp ~/go/bin/ffuf /usr/local/bin/ 2>/dev/null
                else
                    # try apt first
                    sudo apt install -y ffuf 2>/dev/null
                fi
                ;;
            nuclei)
                # install via go
                if command -v go &>/dev/null; then
                    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest 2>/dev/null
                    [[ -f ~/go/bin/nuclei ]] && sudo cp ~/go/bin/nuclei /usr/local/bin/ 2>/dev/null
                else
                    # try apt
                    sudo apt install -y nuclei 2>/dev/null
                fi
                ;;
            dirsearch)
                sudo apt install -y dirsearch 2>/dev/null || {
                    # fallback to github
                    git clone https://github.com/maurosoria/dirsearch.git /tmp/dirsearch 2>/dev/null
                    sudo cp /tmp/dirsearch/dirsearch.py /usr/local/bin/dirsearch 2>/dev/null
                    sudo chmod +x /usr/local/bin/dirsearch 2>/dev/null
                    rm -rf /tmp/dirsearch
                }
                ;;
            *)
                sudo apt install -y $t 2>/dev/null
                ;;
        esac
        
        if command -v "$t" &>/dev/null; then
            echo -e "${GRN}[+] installed${NC}"
            AVAIL+=("$t")
        else
            echo -e "${RED}[-] failed${NC}"
        fi
    done
    
    # rebuild missing list
    MISSING=()
    for t in "${tools[@]}"; do
        tool=$(echo "$t" | cut -d: -f1)
        command -v "$tool" &>/dev/null || MISSING+=("$tool")
    done
    
    echo -e "\n${GRN}done: ${#AVAIL[@]} available${NC}"
    [ ${#MISSING[@]} -gt 0 ] && echo -e "${RED}still missing: ${#MISSING[@]}${NC}\n"
}

has_tool() {
    for t in "${AVAIL[@]}"; do
        [[ "$t" == "$1" ]] && return 0
    done
    return 1
}

# get target and detect os
get_target() {
    # check if TARGET is already set
    if [[ -n "$TARGET" ]]; then
        echo -e "${GRN}[+] using exported target: $TARGET${NC}"
    else
        read -p "target: " TARGET
        [[ -z "$TARGET" ]] && { echo -e "${RED}need target${NC}"; exit 1; }
    fi
    
    echo -e "${YEL}[*] checking...${NC}"
    
    kernel=$(uname -s)
    [ $kernel = "Linux" ] && tw="W" || tw="t"
    
    ping_out=$(ping -c 1 -${tw} 1 "$TARGET" 2>/dev/null | grep ttl)
    
    if [[ -n "$ping_out" ]]; then
        echo -e "${GRN}[+] up${NC}"
        
        ttl=$(echo "$ping_out" | grep -oP 'ttl=\K[0-9]+')
        
        # detect os
        if [[ $ttl -ge 250 && $ttl -le 256 ]]; then
            os="bsd/cisco"
        elif [[ $ttl -ge 120 && $ttl -le 130 ]]; then
            os="windows"
        elif [[ $ttl -ge 60 && $ttl -le 70 ]]; then
            os="linux"
        else
            os="unknown"
        fi
        
        echo -e "${GRN}[+] probably $os (ttl=$ttl)${NC}"
    else
        echo -e "${YEL}no ping (filtered?)${NC}"
    fi
    
    echo ""
}

# setup scan
setup_scan() {
    echo -e "${YEL}scan type:${NC}"
    echo "1) quick"
    echo "2) standard"
    echo "3) full"
    echo "4) stealth"
    echo "5) quick stealth"
    echo "6) quick aggressive"
    echo "7) udp"
    echo "8) udp full"
    echo "9) custom"
    read -p "> " c
    
    case $c in
        1) flags="-sS -F"; SCAN_TYPE="quick" ;;
        2) flags="-sS -sV -sC -p-"; SCAN_TYPE="standard" ;;
        3) flags="-A -p- -T4"; SCAN_TYPE="full" ;;
        4) flags="-sS -f -T2"; SCAN_TYPE="stealth" ;;
        5) flags="-sS -sV -F -T2 -Pn"; SCAN_TYPE="quick-stealth" ;;
        6) flags="-sS -sV -sC -F -T4 --min-rate=1000"; SCAN_TYPE="quick-aggressive" ;;
        7) flags="-sU -F"; SCAN_TYPE="udp" ;;
        8) flags="-sU -p-"; SCAN_TYPE="udp-full" ;;
        9) read -p "flags: " flags; SCAN_TYPE="custom" ;;
        *) flags="-sS -sV -sC -p-"; SCAN_TYPE="standard" ;;
    esac
    
    echo -e "\n${YEL}verbosity:${NC}"
    echo "1) normal"
    echo "2) -v"
    echo "3) -vv"
    read -p "> " v
    
    verb=""
    [[ $v == 2 ]] && verb="-v"
    [[ $v == 3 ]] && verb="-vv"
    
    # where to save
    echo -e "\n${YEL}save to:${NC}"
    echo "1) ~/Documents/scans"
    echo "2) ./scans"
    echo "3) custom"
    read -p "> " d
    
    case $d in
        1) base="$HOME/Documents/scans" ;;
        2) base="./scans" ;;
        3) 
            read -p "path: " base
            [[ -z "$base" ]] && base="./scans"
            ;;
        *) base="$HOME/Documents/scans" ;;
    esac
    
    # ask for scan name
    echo -e "\n${YEL}scan name (optional):${NC}"
    read -p "name (or enter for default): " scan_name
    
    if [[ -n "$scan_name" ]]; then
        OUTDIR="${base}/${scan_name}_${TARGET}_${TIMESTAMP}"
    else
        OUTDIR="${base}/${TARGET}_${TIMESTAMP}"
    fi
    
    mkdir -p "$OUTDIR/logs"
    
    echo -e "\n${GRN}[+] setup done${NC}"
    echo -e "    $flags $verb"
    echo -e "    $OUTDIR\n"
}

# run scan
run_scan() {
    echo -e "${YEL}[*] scanning...${NC}\n"
    
    nmapout="$OUTDIR/nmap.txt"
    nmapxml="$OUTDIR/nmap.xml"
    nmapgrep="$OUTDIR/nmap.gnmap"
    
    cmd="sudo nmap $flags $verb -oN $nmapout -oX $nmapxml -oG $nmapgrep $TARGET"
    
    echo -e "${BLU}[*] starting scan...${NC}"
    echo -e "${BLU}    $cmd${NC}"
    echo -e "${BLU}    might take a bit...${NC}\n"
    
    if eval "$cmd"; then
        echo -e "\n${GRN}[+] scan done${NC}\n"
    else
        echo -e "\n${RED}[!] failed${NC}"
        exit 1
    fi
}

# parse results
parse_results() {
    echo -e "${YEL}[*] parsing...${NC}\n"
    
    [[ ! -f "$nmapout" ]] && { echo -e "${RED}no output${NC}"; exit 1; }
    
    grep -E "^[0-9]+/(tcp|udp).*open" "$nmapout" > "$OUTDIR/ports.txt" || true
    
    if [[ ! -s "$OUTDIR/ports.txt" ]]; then
        echo -e "${RED}no open ports${NC}"
        exit 0
    fi
    
    echo -e "${GRN}open:${NC}\n"
    cat "$OUTDIR/ports.txt"
    echo ""
}

# check vulns
check_vulns() {
    local svc=$1
    local ver=$2
    
    echo -e "\n${BLU}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║${NC}${YEL}              VULNERABILITY CHECK                       ${NC}${BLU}║${NC}"
    echo -e "${BLU}╚════════════════════════════════════════════════════════╝${NC}"
    
    search=$(echo "$svc $ver" | sed 's/[^a-zA-Z0-9. ]//g')
    
    ping -c 1 8.8.8.8 &>/dev/null || { echo -e "${RED}no net${NC}"; return; }
    command -v curl &>/dev/null || { echo -e "${RED}need curl${NC}"; return; }
    
    found_vulns=false
    
    # nvd
    echo -e "\n${YEL}[*] searching NVD for: $search${NC}"
    cves=$(curl -s "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=${search// /%20}" 2>/dev/null)
    
    if echo "$cves" | grep -q "CVE-"; then
        found_vulns=true
        echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║        CVEs FOUND - POTENTIAL VULNERABILITIES          ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"
        echo "$cves" | grep -oP 'CVE-[0-9]{4}-[0-9]+' | head -5 | while read c; do
            echo -e "${RED}  ▶ $c${NC}"
            echo -e "    https://nvd.nist.gov/vuln/detail/$c"
            echo "[$svc:$ver] $c" >> "$OUTDIR/vulns.txt"
        done
    else
        echo -e "${GRN}  ✓ no known CVEs${NC}"
    fi
    
    # github
    echo -e "\n${YEL}[*] searching GitHub for exploits...${NC}"
    gh="${search// /+}+exploit"
    repos=$(curl -s "https://api.github.com/search/repositories?q=${gh}&sort=stars&order=desc" 2>/dev/null)
    
    if echo "$repos" | grep -q '"full_name"'; then
        found_vulns=true
        echo -e "\n${YEL}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YEL}║            EXPLOITS AVAILABLE ON GITHUB                ║${NC}"
        echo -e "${YEL}╚════════════════════════════════════════════════════════╝${NC}\n"
        echo "$repos" | grep -oP '"full_name":\s*"\K[^"]+' | head -3 | while read r; do
            echo -e "${YEL}  ▶ https://github.com/$r${NC}"
            echo "[$svc:$ver] github.com/$r" >> "$OUTDIR/vulns.txt"
        done
    else
        echo -e "${GRN}  ✓ no public exploits found${NC}"
    fi
    
    # searchsploit
    if command -v searchsploit &>/dev/null; then
        echo -e "\n${YEL}[*] searching Exploit-DB...${NC}"
        ex=$(searchsploit "$search" 2>/dev/null | grep -v "Exploits: No Results")
        
        if [[ -n "$ex" ]]; then
            found_vulns=true
            echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║             EXPLOITS IN EXPLOIT-DB                     ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"
            echo "$ex" | head -5
            echo "$ex" | head -5 >> "$OUTDIR/vulns.txt"
        else
            echo -e "${GRN}  ✓ no exploits in database${NC}"
        fi
    fi
    
    # summary box if vulns found
    if $found_vulns; then
        echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                        ║${NC}"
        echo -e "${RED}║                    ACTION REQUIRED                     ║${NC}"
        echo -e "${RED}║          Vulnerabilities detected for $svc $ver        ║${NC}"
        echo -e "${RED}║              Check vulns.txt for full details          ║${NC}"
        echo -e "${RED}║               Review suggested exploits above          ║${NC}"
        echo -e "${RED}║                                                        ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "\n${GRN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GRN}║           No obvious vulnerabilities found             ║${NC}"
        echo -e "${GRN}╚════════════════════════════════════════════════════════╝${NC}"
    fi
    
    echo ""
}

# get tool suggestions
get_tools() {
    p=$1
    svc=$2
    
    case $p in
        88|464)
            [[ "$svc" =~ kerberos ]] && {
                echo "kerbrute|enum users|kerbrute userenum -d DOMAIN --dc $TARGET users.txt"
                echo "impacket-GetNPUsers|asreproast|GetNPUsers.py DOMAIN/ -dc-ip $TARGET -usersfile users.txt"
                echo "impacket-GetUserSPNs|kerberoast|GetUserSPNs.py DOMAIN/user:pass -dc-ip $TARGET"
            }
            ;;
        139|445)
            [[ "$svc" =~ netbios|microsoft-ds|smb ]] && {
                echo "enum4linux|smb enum|enum4linux -a $TARGET"
                echo "smbclient|shares|smbclient -L //$TARGET -N"
                echo "netexec|smb test|netexec smb $TARGET -u '' -p ''"
            }
            ;;
        3389)
            [[ "$svc" =~ ms-wbt-server|rdp ]] && {
                echo "hydra|rdp brute|hydra -L users.txt -P pass.txt rdp://$TARGET"
            }
            ;;
        22)
            [[ "$svc" =~ ssh ]] && {
                echo "ssh-audit|check config|ssh-audit $TARGET"
                echo "hydra|ssh brute|hydra -L users.txt -P pass.txt ssh://$TARGET"
            }
            ;;
        21)
            [[ "$svc" =~ ftp ]] && {
                echo "hydra|ftp brute|hydra -L users.txt -P pass.txt ftp://$TARGET"
            }
            ;;
        80|443|8080|8443)
            [[ "$svc" =~ http|https|ssl ]] && {
                echo "nikto|web scan|nikto -h $TARGET:$p"
                echo "gobuster|dirs|gobuster dir -u http://$TARGET:$p -w /usr/share/wordlists/dirb/common.txt"
                echo "ffuf|fuzzing|ffuf -w /usr/share/wordlists/dirb/common.txt -u http://$TARGET:$p/FUZZ"
                echo "dirsearch|web scan|dirsearch -u http://$TARGET:$p"
                echo "nuclei|vuln scan|nuclei -u http://$TARGET:$p -t ~/nuclei-templates/"
                echo "sqlmap|sqli|sqlmap -u http://$TARGET:$p --batch --crawl=1"
            }
            ;;
        389|636|3268|3269)
            [[ "$svc" =~ ldap ]] && {
                echo "ldapsearch|ldap enum|ldapsearch -x -h $TARGET -b 'dc=domain,dc=com'"
            }
            ;;
        53)
            [[ "$svc" =~ domain|dns ]] && {
                echo "dig|dns query|dig @$TARGET ANY domain.com"
                echo "dnsenum|dns enum|dnsenum --dnsserver $TARGET domain.com"
            }
            ;;
        *)
            echo "msfconsole|search|msfconsole -q -x 'search $svc; exit'"
            ;;
    esac
}

# run tools
run_tools() {
    while read line; do
        p=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
        svc=$(echo "$line" | awk '{print $3}')
        ver=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}' | xargs)
        
        echo -e "${BLU}========================================${NC}"
        echo -e "${YEL}port $p - $svc${NC}"
        [[ -n "$ver" ]] && echo -e "${YEL}version: $ver${NC}"
        echo -e "${BLU}========================================${NC}"
        
        # vuln check
        if [[ -n "$ver" ]]; then
            read -p "check vulns? (y/n): " vc
            [[ "$vc" =~ ^[Yy]$ ]] && check_vulns "$svc" "$ver"
        fi
        
        sugg=$(get_tools "$p" "$svc")
        
        [[ -z "$sugg" ]] && { echo -e "${YEL}nothing for this${NC}\n"; continue; }
        
        while IFS='|' read -r tool desc ex; do
            [[ -z "$tool" ]] && continue
            
            echo -e "\n${GRN}tool:${NC} $tool"
            echo -e "${GRN}desc:${NC} $desc"
            echo -e "${GRN}cmd:${NC} $ex"
            
            if ! has_tool "$tool"; then
                echo -e "${RED}[-] not installed${NC}"
                continue
            fi
            
            echo -e "${GRN}[+] available${NC}"
            read -p "run? (y/n): " r
            
            if [[ "$r" =~ ^[Yy]$ ]]; then
                read -p "custom cmd (or enter): " uc
                [[ -z "$uc" ]] && uc="$ex"
                
                echo -e "\n${BLU}[*] running $tool...${NC}"
                echo -e "${BLU}    $uc${NC}\n"
                
                log="$OUTDIR/logs/${tool}_p${p}_${TIMESTAMP}.txt"
                
                eval "$uc" 2>&1 | tee "$log"
                
                echo -e "\n${GRN}[+] $tool done${NC}"
                echo -e "${GRN}    saved: $log${NC}"
            else
                echo -e "${YEL}skip${NC}"
            fi
        done <<< "$sugg"
        
        echo ""
        
    done < "$OUTDIR/ports.txt"
}

# summary
summary() {
    echo -e "\n${BLU}===== SUMMARY =====${NC}\n"
    
    end=$(date +%s)
    elapsed=$((end - start_time))
    
    if [ $elapsed -gt 3600 ]; then
        h=$((elapsed / 3600))
        m=$(((elapsed % 3600) / 60))
        s=$(((elapsed % 3600) % 60))
        time="${h}h ${m}m ${s}s"
    elif [ $elapsed -gt 60 ]; then
        m=$((elapsed / 60))
        s=$((elapsed % 60))
        time="${m}m ${s}s"
    else
        time="${elapsed}s"
    fi
    
    echo -e "${YEL}target:${NC} $TARGET"
    echo -e "${YEL}os:${NC} ${os:-unknown}"
    echo -e "${YEL}type:${NC} $SCAN_TYPE"
    echo -e "${YEL}time:${NC} $time\n"
    
    echo -e "${GRN}files:${NC}"
    echo -e "  $nmapout"
    echo -e "  $nmapxml"
    echo -e "  $OUTDIR/ports.txt"
    
    logs=$(ls -1 "$OUTDIR/logs" 2>/dev/null | wc -l)
    echo -e "  logs: $logs files\n"
    
    if [ -f "$OUTDIR/ports.txt" ]; then
        pc=$(wc -l < "$OUTDIR/ports.txt")
        echo -e "${GRN}ports: $pc open${NC}\n"
    fi
    
    if [ -f "$OUTDIR/vulns.txt" ]; then
        echo -e "${RED}vulns found:${NC}"
        cat "$OUTDIR/vulns.txt"
        echo ""
    fi
    
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo -e "${YEL}missing:${NC}"
        printf '  %s\n' "${MISSING[@]}"
        echo ""
    fi
    
    echo -e "${GRN}done${NC}\n"
}

main() {
    banner
    check_deps
    get_target
    setup_scan
    run_scan
    parse_results
    run_tools
    summary
}

main
