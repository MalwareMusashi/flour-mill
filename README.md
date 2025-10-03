# Flour Mill

automated pentesting recon tool - scans ports, detects os, checks vulns, suggests tools, installs missing stuff

## what it does

1. checks what tools you got installed
2. auto-installs missing tools (asks first)
3. pings target and detects OS from TTL
4. runs nmap (tcp or udp, your choice)
5. parses open ports/services
6. checks CVEs, github, exploit-db for each service
7. suggests tools for each port
8. runs them interactively
9. logs everything with timestamps
10. shows summary with timing and vulns found

## requirements

**must have:**
- nmap
- sudo
- curl (for vuln checks)
- git (for updates)
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

**basic:**
```bash
git clone https://github.com/MalwareMusashi/flour-mill
cd flour_mill
chmod +x flour_mill.sh
./flour_mill.sh
```

**install globally (run from anywhere):**
```bash
# from the repo directory
chmod +x flour_mill.sh

# copy to bin
sudo cp flour_mill.sh /usr/local/bin/flour_mill

# now just run
flour_mill
```

**or symlink (recommended - easier to update):**
```bash
sudo ln -s $(pwd)/flour_mill.sh /usr/local/bin/flour_mill
```

**uninstall:**
```bash
sudo rm /usr/local/bin/flour_mill
```

## updating

**if installed via git:**
```bash
flour_mill --update
```

or

```bash
flour_mill -u
```

**manual update (if not using git):**
```bash
cd ~/flour_mill
git pull

# if symlinked, you're done
# if copied to /usr/local/bin:
sudo cp flour_mill.sh /usr/local/bin/flour_mill
```

**check version:**
```bash
flour_mill --version
```

## usage

**three ways to set target:**

```bash
# 1. command line argument
flour_mill 192.168.1.100

# 2. exported variable
export TARGET=192.168.1.100
flour_mill

# 3. interactive prompt
flour_mill
target: _
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
[*] checking tools...
[+] nmap
[-] netexec
[-] kerbrute
...

got: 8 | missing: 5

missing 5 tools
install? (y/n): y

[*] installing...
[*] getting pipx...
[*] netexec...
[+] installed
[*] kerbrute...
[+] installed
...

done: 13 available
```

handles:
- python tools via pipx (netexec, impacket)
- github releases (kerbrute)
- apt packages (everything else)

### os detection

script pings target and detects os from TTL:

```
[*] checking...
[+] up
[+] probably windows (ttl=128)
```

ttl ranges:
- 250-256: bsd/cisco/oracle
- 120-130: windows
- 60-70: linux

### vuln checking

for each service with version:

```
port 445 - smb
version: Samba 3.0.20

check vulns? (y/n): y

[*] vuln check...
[*] nvd...
[!] cves:
    → CVE-2007-2447

[*] github...
[!] found:
    → github.com/amriunix/CVE-2007-2447

[*] exploit-db...
[!] found:
Samba 3.0.20 < 3.0.25rc3 - Command Execution
```

checks:
- NVD (NIST vulnerability database)
- github repos (sorted by stars)
- exploit-db (via searchsploit)

all vulns saved to `vulns.txt` in output dir

### example run

```
$ flour_mill 192.168.1.100

[flour mill ascii art]

[*] checking tools...
[+] nmap
[-] netexec
...

missing 3 tools
install? (y/n): y

[*] installing...
[+] netexec installed
...

[+] using exported target: 192.168.1.100
[*] checking...
[+] up
[+] probably windows (ttl=128)

scan type:
1) quick
2) standard
3) full
4) stealth
5) udp
6) udp full
7) custom
> 2

verbosity:
1) normal
2) -v
3) -vv
> 1

save to:
1) ~/Documents/scans
2) ./scans
3) custom
> 1

[+] setup done
    -sS -sV -sC -p-
    /home/user/Documents/scans/192.168.1.100_20241002_153022

[*] scanning...

[*] starting scan...
    sudo nmap -sS -sV -sC -p- 192.168.1.100
    might take a bit...

[+] scan done

[*] parsing...

open:
139/tcp  open  netbios-ssn  Samba 3.0.20
445/tcp  open  smb          Samba 3.0.20

========================================
port 445 - smb
version: Samba 3.0.20
========================================

check vulns? (y/n): y

[*] vuln check...
[!] cves:
    → CVE-2007-2447

[!] found:
    → github.com/amriunix/CVE-2007-2447

tool: netexec
desc: smb test
cmd: netexec smb 192.168.1.100 -u '' -p ''
[+] available
run? (y/n): y
...

===== SUMMARY =====

target: 192.168.1.100
os: windows
type: standard
time: 5m 23s

files:
  /home/user/Documents/scans/192.168.1.100_20241002_153022/nmap.txt
  /home/user/Documents/scans/192.168.1.100_20241002_153022/nmap.xml
  /home/user/Documents/scans/192.168.1.100_20241002_153022/ports.txt
  logs: 3 files

ports: 2 open

vulns found:
[smb:Samba 3.0.20] CVE-2007-2447
[smb:Samba 3.0.20] github.com/amriunix/CVE-2007-2447

done
```

## output structure

```
~/Documents/scans/192.168.1.100_20241002_153022/
├── nmap.txt
├── nmap.xml
├── nmap.gnmap
├── ports.txt
├── vulns.txt           # all found vulns
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
- symlink install = easier updates

## common issues

**"need nmap"**
```bash
sudo apt install nmap
```

**"scan failed"**
- verify sudo access
- ping target manually first
- try stealth scan if filtered

**"no net" during vuln checks**
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

**"not a git repo, can't update"**
- reinstall via git clone
- or manually pull changes

**can't find output**
- check path in summary
- default: `~/Documents/scans/`
- use `find ~ -name "nmap.txt"` to locate

## flags

```bash
flour_mill --update        # update from git
flour_mill -u              # same

flour_mill --version       # show version
flour_mill -v              # same

flour_mill 192.168.1.100   # run with target
```

## features

- **auto tool installation** - installs missing tools automatically
- **os detection** - detects target os from ping ttl
- **vuln checking** - searches nvd, github, exploit-db
- **tcp/udp scanning** - supports both protocols
- **timing stats** - shows how long everything took
- **organized output** - timestamped dirs and files
- **vuln aggregation** - all findings in one summary file
- **self-update** - update script with one command
- **multiple target methods** - cli arg, export, or prompt

## changelog

**v1.0**
- initial release
- auto-install for all tools
- os detection from ttl values
- vuln checking (nvd, github, exploit-db)
- vuln summary file
- timing in summary output
- port counting
- udp scanning support
- netexec replaces crackmapexec
- self-update functionality
- command-line target argument
- improved target handling (export/arg/prompt)
- version flag

---

built for ctfs and quick pentests. automates the boring enum stuff so you can focus on exploitation.

**update regularly:**
```bash
flour_mill --update
```
