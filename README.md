# Flour Mill

automated pentesting recon tool - scans ports, detects os, checks vulns, suggests tools, installs missing stuff

## what it does

1. checks what tools you got installed
2. **auto-installs missing tools** (asks first)
3. pings target and **detects OS from TTL**
4. runs nmap (tcp or udp, your choice)
5. parses open ports/services
6. **checks CVEs, github, exploit-db** for each service
7. suggests tools for each port
8. runs them interactively
9. logs everything with timestamps
10. **shows summary with timing and vulns found**

## requirements

**must have:**
- nmap
- sudo
- curl (for vuln checks)
- internet (for auto-install and vuln lookups)

**optional (script offers to install these):**
- netexec (replaces crackmapexec)
- kerbrute
- impacket tools (GetNPUsers, GetUserSPNs)
- enum4linux, smbclient
- hydra, medusa
- nikto, gobuster, dirb, sqlmap
- ssh-audit, msfconsole, responder
- ldapsearch, dig, dnsenum
- searchsploit

script will ask to install any missing tools automatically

## setup

**basic:**
```bash
chmod +x flour_mill.sh
./flour_mill.sh
```

**install globally (run from anywhere):**
```bash
# clone
git clone https://github.com/MalwareMusashi/flour-mill
cd flour_mill

chmod +x flour_mill.sh

# copy to bin
sudo cp flour_mill.sh /usr/local/bin/flour_mill

# now just run
flour_mill
```

**or symlink:**
```bash
sudo ln -s $(pwd)/flour_mill.sh /usr/local/bin/flour_mill
```

**uninstall:**
```bash
sudo rm /usr/local/bin/flour_mill
```

## usage

```bash
./flour_mill.sh
```

or with target preset:

```bash
TARGET=192.168.1.100 ./flour_mill.sh
```

### scan types

1. quick - top 1k ports
2. standard - all ports + versions (recommended)
3. full - aggressive, OS detection
4. stealth - SYN scan, slow timing
5. udp - top 1k udp ports
6. udp full - all udp ports (very slow)
7. custom - enter your own nmap flags

### output locations

1. Documents folder - `~/Documents/scans/` (default)
2. current directory - `./scans/`
3. custom path - specify your own

### auto-install feature

when script runs, if tools are missing:

```
[*] checking for tools...
[+] nmap
[-] netexec
[-] kerbrute
...

found: 8 | missing: 5

[!] found 5 missing tools
install missing tools? (y/n): y

[*] installing tools...
[*] installing pipx first...
[*] installing netexec...
[+] netexec installed
[*] installing kerbrute...
[+] kerbrute installed
...

installed successfully
available: 13 | still missing: 0
```

handles:
- python tools via pipx (netexec, impacket)
- github releases (kerbrute)
- apt packages (everything else)

### os detection

script pings target and detects os from TTL:

```
[*] checking target...
[+] target is up
[+] likely running: Windows (ttl=128)
```

ttl ranges:
- 250-256: OpenBSD/Cisco/Oracle
- 120-130: Windows
- 60-70: Linux

### vuln checking

for each service with version:

```
port 445 - smb
version: Samba 3.0.20

check vulns? (y/n): y

[*] checking vulns...
[*] nvd: Samba 3.0.20
[!] found cves:
    → CVE-2007-2447 - https://nvd.nist.gov/vuln/detail/CVE-2007-2447

[*] github...
[!] repos:
    → github.com/amriunix/CVE-2007-2447

[*] exploit-db...
[!] found:
Samba 3.0.20 < 3.0.25rc3 - 'Username' map script' Command Execution
```

checks:
- NVD (NIST vulnerability database)
- github repos (sorted by stars)
- exploit-db (via searchsploit)

all vulns saved to `vulns_summary.txt` in output dir

### example run

```
$ ./flour_mill.sh

[flour mill ascii art]

[*] checking for tools...
[+] nmap
[-] netexec
...

[!] found 3 missing tools
install missing tools? (y/n): y

[*] installing tools...
[+] netexec installed
...

[*] checking target...
[+] target is up
[+] likely running: Windows (ttl=128)

target ip/hostname: 10.10.10.3

scan type:
1) quick (top 1k)
2) standard (all ports + versions)
3) full aggressive
4) stealth
5) udp scan (top 1k udp ports)
6) udp full (all udp ports - slow)
7) custom
> 2

verbosity:
1) normal
2) -v
3) -vv
> 1

save scans to:
1) Documents folder
2) current directory
3) custom path
> 1

[+] configured
    flags: -sS -sV -sC -p-
    output: /home/user/Documents/scans/10.10.10.3_20241002_153022

[*] running nmap...
...

open ports:
139/tcp  open  netbios-ssn  Samba 3.0.20
445/tcp  open  smb          Samba 3.0.20

============================================
port 445 - smb
version: Samba 3.0.20
============================================

check vulns? (y/n): y

[*] checking vulns...
[!] found cves:
    → CVE-2007-2447

[!] repos:
    → github.com/amriunix/CVE-2007-2447

tool: netexec
desc: smb attacks
example: netexec smb 10.10.10.3 -u '' -p ''
[+] available
run? (y/n): y
...

========== SUMMARY ==========

target: 10.10.10.3
os detected: Windows
scan type: standard
time: 5m 23s
timestamp: 20241002_153022

files:
  nmap: /home/user/Documents/scans/10.10.10.3_20241002_153022/nmap.txt
  xml: /home/user/Documents/scans/10.10.10.3_20241002_153022/nmap.xml
  ports: /home/user/Documents/scans/10.10.10.3_20241002_153022/ports.txt
  tool logs: 3 in /home/user/Documents/scans/10.10.10.3_20241002_153022/logs/

found 2 open ports

vulnerabilities found:
[smb:Samba 3.0.20] CVE-2007-2447
[smb:Samba 3.0.20] github.com/amriunix/CVE-2007-2447

done
```

## output structure

```
~/Documents/scans/10.10.10.3_20241002_153022/
├── nmap.txt
├── nmap.xml
├── nmap.gnmap
├── ports.txt
├── vulns_summary.txt      # all found vulns
└── logs/
    ├── netexec_p445_20241002_153022.txt
    ├── enum4linux_p445_20241002_153022.txt
    └── gobuster_p80_20241002_153022.txt
```

## port → tool mappings

| port | service | tools |
|------|---------|-------|
| 88, 464 | kerberos | kerbrute, GetNPUsers, GetUserSPNs |
| 139, 445 | smb | enum4linux, smbclient, netexec |
| 3389 | rdp | hydra |
| 22 | ssh | ssh-audit, hydra |
| 21 | ftp | hydra |
| 80, 443, 8080, 8443 | http/https | nikto, gobuster, sqlmap |
| 389, 636 | ldap | ldapsearch |
| 53 | dns | dig, dnsenum |

## tips

- run as sudo (needed for syn/udp scans)
- have wordlists in `/usr/share/wordlists/`
- vuln checks need internet
- script auto-installs tools but you can skip
- all output timestamped and organized
- vulns saved to summary file

## common issues

**"need nmap installed"**
```bash
sudo apt install nmap
```

**"scan failed"**
- verify sudo access
- ping target manually first
- try stealth scan if filtered

**"no internet" during vuln checks**
- need curl: `sudo apt install curl`
- check network connection
- vuln checks will be skipped

**tool install fails**
```bash
# manual installs
sudo apt install pipx
pipx install git+https://github.com/Pennyw0rth/NetExec
pipx install impacket

# kerbrute
wget https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64
chmod +x kerbrute_linux_amd64
sudo mv kerbrute_linux_amd64 /usr/local/bin/kerbrute
```

**can't find output**
- check path in summary
- default: `~/Documents/scans/`
- use `find ~ -name "nmap.txt"` to locate

## features

- **auto tool installation** - installs missing tools automatically
- **os detection** - detects target os from ping ttl
- **vuln checking** - searches nvd, github, exploit-db
- **tcp/udp scanning** - supports both protocols
- **timing stats** - shows how long everything took
- **organized output** - timestamped dirs and files
- **vuln aggregation** - all findings in one summary file

## changelog

- added auto-install for all tools (not just netexec)
- added os detection from ttl values
- added vuln summary file
- added timing to summary output
- added port counting in summary
- improved install process (handles pipx, apt, github)
- supports udp scanning
- netexec replaces crackmapexec

---

built for ctfs and quick pentests. automates the boring enum stuff so you can focus on exploitation.
