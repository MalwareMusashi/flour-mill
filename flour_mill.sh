#!/bin/bash

# flour mill - automated recon tool
# scans ports, checks vulns, suggests tools

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
    echo -e "${BLU}"
    # detailed flour mill with unicode
    cat << "EOF"
                                    ╔═════╗
                                   ║ MILL ║
                                   ║ ┌─┐  ║
                                  ╔╩═╡ ├══╩╗
                                 ║  └─┘   ║
                                 ║ ┌───┐  ║
                             ╔═══╩═╡   ├══╩═══╗
                            ║   ┌─┴───┴─┐    ║
                            ║  │ FLOUR  │    ║
                            ║  │  MILL  │    ║
                        ╔═══╩══╧════════╧════╩═══╗
                       ║ ▓▓  ▓▓  ░░░░░░░  ▓▓  ▓▓ ║
                       ║ ▓▓  ▓▓  GRINDING ▓▓  ▓▓ ║
                       ║ ▓▓  ▓▓  ░░░░░░░  ▓▓  ▓▓ ║
      ╔════════════╗   ║═══════════════════════════║   ╔════════════╗
     ║            ║   ║                           ║   ║            ║
    ║   ╔═══╗     ║  ║  ╔══════════════════════╗  ║  ║     ╔═══╗   ║
    ║  ║ ╱│╲ ║    ║  ║  ║                      ║  ║  ║    ║ ╱│╲ ║  ║
    ║  ║ ─┼─ ║    ║  ║  ║   ┌──────────────┐   ║  ║  ║    ║ ─┼─ ║  ║
    ║  ║ ╲│╱ ║    ║  ║  ║   │ GRAIN STONES │   ║  ║  ║    ║ ╲│╱ ║  ║
    ║  ║  O  ║    ║  ║  ║   │   ↓↓↓↓↓↓↓    │   ║  ║  ║    ║  O  ║  ║
    ║   ╚═══╝     ║  ║  ║   │    FLOUR     │   ║  ║  ║     ╚═══╝   ║
 ╔══╩════════════╩══║  ║  ║   └──────────────┘   ║  ║  ║══╩════════════╩══╗
 ║                  ║  ║  ╚══════════════════════╝  ║  ║                  ║
 ║ ░░░░░░░░░░░░░░░░ ║  ║                            ║  ║ ░░░░░░░░░░░░░░░░ ║
 ║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║  ║░░░░░░░░░░░░░░░░░░░░░░░░░░░║  ║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║
 ║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║  ║▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓║  ║ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║
 ║ ░░░░░░░░░░░░░░░░ ║  ║░░░░░░░░░░░░░░░░░░░░░░░░░░░║  ║ ░░░░░░░░░░░░░░░░ ║
 ║≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈╚══╩════════════════════════════╩══╝≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈║
 ║≈≈≈ ≈≈≈  ≈≈≈  ≈≈≈  WATER WHEEL & CHANNEL  ≈≈≈  ≈≈≈  ≈≈≈  ≈≈≈  ≈≈≈ ≈≈≈║
 ╚═══════════════════════════════════════════════════════════════════════╝
 
                    ╔════════════════════════════════════════╗
                    ║         Flour Mill v1.0                ║
                    ║    scan → parse → exploit              ║
                    ╚════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
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
    echo "5) udp scan (top 1k udp ports)"
    echo "6) udp full (all udp ports - slow)"
    echo "7) custom"
    read -p "> " choice
    
    case $choice in
        1) 
            flags="-sS -F"
            SCAN_TYPE="quick"
            ;;
        2) 
            flags="-sS -sV -sC -p-"
            SCAN_TYPE="standard"
            ;;
        3) 
            flags="-A -p- -T4"
            SCAN_TYPE="full"
            ;;
        4) 
            flags="-sS -f -T2"
            SCAN_TYPE="stealth"
            ;;
        5) 
            flags="-sU -F"
            SCAN_TYPE="udp"
            ;;
        6) 
            flags="-sU -p-"
            SCAN_TYPE="udp-full"
            ;;
        7) 
            read -p "nmap flags: " flags
            SCAN_TYPE="custom"
            ;;
        *) 
            flags="-sS -sV -sC -p-"
            SCAN_TYPE="standard"
            ;;
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
    
    echo -e "${BLU}[*] scan starting...${NC}"
    echo -e "${BLU}    cmd: $cmd${NC}"
    echo -e "${BLU}    this might take a while...${NC}\n"
    
    if eval "$cmd"; then
        echo -e "\n${GRN}[+] scan completed${NC}\n"
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

# look for vulns
check_vulns() {
    local svc=$1
    local ver=$2
    
    echo -e "\n${YEL}[*] checking vulns...${NC}"
    
    # clean it up
    search=$(echo "$svc $ver" | sed 's/[^a-zA-Z0-9. ]//g')
    
    # need internet
    ping -c 1 8.8.8.8 &>/dev/null || { echo -e "${RED}[-] no internet${NC}"; return; }
    
    command -v curl &>/dev/null || { echo -e "${RED}[-] need curl${NC}"; return; }
    
    vuln_found=false
    
    # nvd check
    echo -e "${BLU}[*] nvd: $search${NC}"
    cves=$(curl -s "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=${search// /%20}" 2>/dev/null)
    
    if echo "$cves" | grep -q "CVE-"; then
        echo -e "${RED}[!] found cves:${NC}"
        echo "$cves" | grep -oP 'CVE-[0-9]{4}-[0-9]+' | head -5 | while read c; do
            echo -e "    ${RED}→${NC} $c - https://nvd.nist.gov/vuln/detail/$c"
            echo "[$svc:$ver] $c" >> "$OUTDIR/vulns_summary.txt"
        done
        vuln_found=true
    else
        echo -e "${GRN}[+] nothing in nvd${NC}"
    fi
    
    # github
    echo -e "\n${BLU}[*] github...${NC}"
    gh="${search// /+}+exploit"
    repos=$(curl -s "https://api.github.com/search/repositories?q=${gh}&sort=stars&order=desc" 2>/dev/null)
    
    if echo "$repos" | grep -q '"full_name"'; then
        echo -e "${YEL}[!] repos:${NC}"
        echo "$repos" | grep -oP '"full_name":\s*"\K[^"]+' | head -3 | while read r; do
            echo -e "    ${YEL}→${NC} github.com/$r"
            echo "[$svc:$ver] github.com/$r" >> "$OUTDIR/vulns_summary.txt"
        done
        vuln_found=true
    else
        echo -e "${GRN}[+] nothing on github${NC}"
    fi
    
    # searchsploit
    if command -v searchsploit &>/dev/null; then
        echo -e "\n${BLU}[*] exploit-db...${NC}"
        ex=$(searchsploit "$search" 2>/dev/null | grep -v "Exploits: No Results")
        
        if [[ -n "$ex" ]]; then
            echo -e "${RED}[!] found:${NC}"
            echo "$ex" | head -5
            echo "$ex" | head -5 >> "$OUTDIR/vulns_summary.txt"
            vuln_found=true
        else
            echo -e "${GRN}[+] nothing in edb${NC}"
        fi
    fi
    
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
                echo "netexec|smb attacks|netexec smb $TARGET -u '' -p ''"
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
        ver=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}' | xargs)
        
        echo -e "${BLU}============================================${NC}"
        echo -e "${YEL}port $p - $svc${NC}"
        if [[ -n "$ver" ]]; then
            echo -e "${YEL}version: $ver${NC}"
        fi
        echo -e "${BLU}============================================${NC}"
        
        # check vulns if got version
        if [[ -n "$ver" ]]; then
            read -p "check vulns? (y/n): " chk
            [[ "$chk" =~ ^[Yy]$ ]] && check_vulns "$svc" "$ver"
        fi
        
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
                
                echo -e "\n${BLU}[*] starting $tool...${NC}"
                echo -e "${BLU}    running: $usercmd${NC}\n"
                
                log="$OUTDIR/logs/${tool}_p${p}_${TIMESTAMP}.txt"
                
                eval "$usercmd" 2>&1 | tee "$log"
                
                echo -e "\n${GRN}[+] $tool completed${NC}"
                echo -e "${GRN}[+] saved to $log${NC}"
            else
                echo -e "${YEL}skipped${NC}"
            fi
        done <<< "$sugg"
        
        echo ""
        
    done < "$OUTDIR/ports.txt"
}

summary() {
    echo -e "\n${BLU}========== SUMMARY ==========${NC}\n"
    
    # calculate time
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    if [ $elapsed -gt 3600 ]; then
        hours=$((elapsed / 3600))
        mins=$(((elapsed % 3600) / 60))
        secs=$(((elapsed % 3600) % 60))
        time_str="${hours}h ${mins}m ${secs}s"
    elif [ $elapsed -gt 60 ]; then
        mins=$((elapsed / 60))
        secs=$((elapsed % 60))
        time_str="${mins}m ${secs}s"
    else
        time_str="${elapsed}s"
    fi
    
    echo -e "${YEL}target:${NC} $TARGET"
    echo -e "${YEL}os detected:${NC} ${os:-unknown}"
    echo -e "${YEL}scan type:${NC} $SCAN_TYPE"
    echo -e "${YEL}time:${NC} $time_str"
    echo -e "${YEL}timestamp:${NC} $TIMESTAMP\n"
    
    echo -e "${GRN}files:${NC}"
    echo -e "  nmap: $nmapout"
    echo -e "  xml: $nmapxml"
    echo -e "  ports: $OUTDIR/ports.txt"
    
    # count logs
    logs=$(ls -1 "$OUTDIR/logs" 2>/dev/null | wc -l)
    echo -e "  tool logs: $logs in $OUTDIR/logs/\n"
    
    # count open ports
    if [ -f "$OUTDIR/ports.txt" ]; then
        port_count=$(wc -l < "$OUTDIR/ports.txt")
        echo -e "${GRN}found ${port_count} open ports${NC}\n"
    fi
    
    # show vulns found if checked
    if [ -f "$OUTDIR/vulns_summary.txt" ]; then
        echo -e "${RED}vulnerabilities found:${NC}"
        cat "$OUTDIR/vulns_summary.txt"
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
    check_tools
    get_target
    setup_scan
    run_scan
    parse_scan
    run_tools
    summary
}

main
