#!/bin/bash

# quick recon script - automates the boring stuff
# runs nmap then suggests tools based on what's open

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

banner() {
    echo -e "${BLU}================================${NC}"
    echo -e "${BLU}  Auto Recon Tool Suggester${NC}"
    echo -e "${BLU}================================${NC}\n"
}

# check what tools we got
check_tools() {
    echo -e "${YEL}[*] checking for tools...${NC}\n"
    
    tools=(
        "nmap"
        "kerbrute"
        "impacket-GetNPUsers"
        "impacket-GetUserSPNs"
        "enum4linux"
        "smbclient"
        "crackmapexec"
        "hydra"
        "medusa"
        "nikto"
        "gobuster"
        "dirb"
        "sqlmap"
        "ssh-audit"
        "msfconsole"
        "responder"
        "ldapsearch"
        "dig"
        "dnsenum"
    )
    
    for t in "${tools[@]}"; do
        if command -v "$t" &>/dev/null; then
            AVAIL+=("$t")
            echo -e "${GRN}[+]${NC} $t"
        else
            MISSING+=("$t")
            echo -e "${RED}[-]${NC} $t"
        fi
    done
    
    echo -e "\n${GRN}found: ${#AVAIL[@]}${NC} | ${RED}missing: ${#MISSING[@]}${NC}\n"
    
    if ! command -v nmap &>/dev/null; then
        echo -e "${RED}[!] need nmap installed, exiting${NC}"
        exit 1
    fi
}

has_tool() {
    for t in "${AVAIL[@]}"; do
        [[ "$t" == "$1" ]] && return 0
    done
    return 1
}

get_target() {
    if [[ -z "$TARGET" ]]; then
        read -p "target ip/hostname: " TARGET
    fi
    
    [[ -z "$TARGET" ]] && { echo -e "${RED}[!] need a target${NC}"; exit 1; }
    echo -e "${GRN}[+] target: $TARGET${NC}\n"
}

setup_scan() {
    echo -e "${YEL}scan type:${NC}"
    echo "1) quick (top 1k)"
    echo "2) standard (all ports + versions)"
    echo "3) full aggressive"
    echo "4) stealth"
    echo "5) custom"
    read -p "> " choice
    
    case $choice in
        1) flags="-sS -F" ;;
        2) flags="-sS -sV -sC -p-" ;;
        3) flags="-A -p- -T4" ;;
        4) flags="-sS -f -T2" ;;
        5) read -p "nmap flags: " flags ;;
        *) flags="-sS -sV -sC -p-" ;;
    esac
    
    echo -e "\n${YEL}verbosity:${NC}"
    echo "1) normal"
    echo "2) -v"
    echo "3) -vv"
    read -p "> " v
    
    verb=""
    [[ $v == 2 ]] && verb="-v"
    [[ $v == 3 ]] && verb="-vv"
    
    read -p "output dir (default: ./scans): " custom
    
    if [[ -z "$custom" ]]; then
        OUTDIR="./scans/${TARGET}_${TIMESTAMP}"
    else
        OUTDIR="${custom}/${TARGET}_${TIMESTAMP}"
    fi
    
    mkdir -p "$OUTDIR/logs"
    
    echo -e "\n${GRN}[+] configured${NC}"
    echo -e "    flags: $flags $verb"
    echo -e "    output: $OUTDIR\n"
}

run_scan() {
    echo -e "${YEL}[*] running nmap...${NC}\n"
    
    nmapout="$OUTDIR/nmap.txt"
    nmapxml="$OUTDIR/nmap.xml"
    nmapgrep="$OUTDIR/nmap.gnmap"
    
    cmd="sudo nmap $flags $verb -oN $nmapout -oX $nmapxml -oG $nmapgrep $TARGET"
    
    echo -e "${BLU}$cmd${NC}\n"
    
    if eval "$cmd"; then
        echo -e "\n${GRN}[+] scan done${NC}\n"
    else
        echo -e "\n${RED}[!] scan failed${NC}"
        exit 1
    fi
}

parse_scan() {
    echo -e "${YEL}[*] parsing results...${NC}\n"
    
    [[ ! -f "$nmapout" ]] && { echo -e "${RED}[!] no scan output${NC}"; exit 1; }
    
    grep -E "^[0-9]+/(tcp|udp).*open" "$nmapout" > "$OUTDIR/ports.txt" || true
    
    if [[ ! -s "$OUTDIR/ports.txt" ]]; then
        echo -e "${RED}[!] no open ports${NC}"
        exit 0
    fi
    
    echo -e "${GRN}open ports:${NC}\n"
    cat "$OUTDIR/ports.txt"
    echo ""
}

# figure out what to run based on port/service
get_suggestions() {
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
                echo "smbclient|list shares|smbclient -L //$TARGET -N"
                echo "crackmapexec|smb attacks|crackmapexec smb $TARGET -u '' -p ''"
            }
            ;;
        3389)
            [[ "$svc" =~ ms-wbt-server|rdp ]] && {
                echo "hydra|rdp bruteforce|hydra -L users.txt -P pass.txt rdp://$TARGET"
            }
            ;;
        22)
            [[ "$svc" =~ ssh ]] && {
                echo "ssh-audit|check config|ssh-audit $TARGET"
                echo "hydra|ssh bruteforce|hydra -L users.txt -P pass.txt ssh://$TARGET"
            }
            ;;
        21)
            [[ "$svc" =~ ftp ]] && {
                echo "hydra|ftp bruteforce|hydra -L users.txt -P pass.txt ftp://$TARGET"
            }
            ;;
        80|443|8080|8443)
            [[ "$svc" =~ http|https|ssl ]] && {
                echo "nikto|web scan|nikto -h $TARGET:$p"
                echo "gobuster|dir bruteforce|gobuster dir -u http://$TARGET:$p -w /usr/share/wordlists/dirb/common.txt"
                echo "sqlmap|sqli test|sqlmap -u http://$TARGET:$p --batch --crawl=1"
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
            echo "msfconsole|search exploits|msfconsole -q -x 'search $svc; exit'"
            ;;
    esac
}

run_tools() {
    while read line; do
        p=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
        svc=$(echo "$line" | awk '{print $3}')
        
        echo -e "${BLU}============================================${NC}"
        echo -e "${YEL}port $p - $svc${NC}"
        echo -e "${BLU}============================================${NC}"
        
        sugg=$(get_suggestions "$p" "$svc")
        
        [[ -z "$sugg" ]] && { echo -e "${YEL}no suggestions for this${NC}\n"; continue; }
        
        while IFS='|' read -r tool desc example; do
            [[ -z "$tool" ]] && continue
            
            echo -e "\n${GRN}tool:${NC} $tool"
            echo -e "${GRN}desc:${NC} $desc"
            echo -e "${GRN}example:${NC} $example"
            
            if ! has_tool "$tool"; then
                echo -e "${RED}[-] not installed${NC}"
                continue
            fi
            
            echo -e "${GRN}[+] available${NC}"
            read -p "run? (y/n): " ans
            
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                read -p "command (enter for example): " usercmd
                
                [[ -z "$usercmd" ]] && usercmd="$example"
                
                echo -e "\n${BLU}running: $usercmd${NC}\n"
                
                log="$OUTDIR/logs/${tool}_p${p}_${TIMESTAMP}.txt"
                
                eval "$usercmd" 2>&1 | tee "$log"
                
                echo -e "\n${GRN}[+] saved to $log${NC}"
            else
                echo -e "${YEL}skipped${NC}"
            fi
        done <<< "$sugg"
        
        echo ""
        
    done < "$OUTDIR/ports.txt"
}

summary() {
    echo -e "\n${BLU}========== SUMMARY ==========${NC}\n"
    echo -e "target: $TARGET"
    echo -e "timestamp: $TIMESTAMP"
    echo -e "output: $OUTDIR\n"
    
    echo -e "${GRN}files:${NC}"
    echo -e "  nmap: $nmapout"
    echo -e "  xml: $nmapxml"
    echo -e "  ports: $OUTDIR/ports.txt"
    
    logs=$(ls -1 "$OUTDIR/logs" 2>/dev/null | wc -l)
    echo -e "  tool logs: $logs in $OUTDIR/logs/\n"
    
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo -e "${YEL}missing tools:${NC}"
        printf '  %s\n' "${MISSING[@]}"
        echo ""
    fi
    
    echo -e "${GRN}done${NC}\n"
}

main() {
    banner
    check_tools
    get_target
    setup_scan
    run_scan
    parse_scan
    run_tools
    summary
}

main
