Понял — делаю **максимально развёрнутый, детальный, практичный и готовый к использованию Markdown-документ** по pfSense для WorldSkills: **всё** что может понадобиться — интерфейсы, VLAN, NAT (авто/гибрид/ручной), Port-Forward, firewall rules (конкретные поля для UI), PBR, Multi-WAN, DHCP, DNS, Suricata/Snort (IDS/IPS) — установка, правила, inline/alert, обновление, логирование, тестирование, отладка, hardware offloading, switch-trunk примеры, готовые CLI-команды, ответы на ошибки и готовые блоки для отчёта.
Это один большой файл в Markdown — копируй в `.md` и учи / используй как шпаргалку и чек-лист.

Я выкладываю **всё** — длинно, полно, но без воды. Поехали.

---

```markdown
# pfSense — Полный практический гид (WorldSkills / полевой)
**Формат:** Markdown  
**Назначение:** полный практический reference для настройки pfSense в соревнованиях / лаборатории / CTF.  
**Содержание:** интерфейсы, VLAN, NAT (auto/manual/hybrid), Port Forward, Firewall rules (готовые записи), Multi-WAN, PBR, DHCP/DNS, IDS/IPS (Suricata / Snort), логирование, диагностика, типичные ошибки и их исправления, готовые проверки, журнал действий и шаблоны отчётов.

---

## Оглавление
1. Принципы (кратко)  
2. Начальная подготовка (UI + Console)  
3. Вариант A — классика (WAN DHCP, LAN, DMZ) — пошагово  
4. Вариант B — VLAN на одном физическом интерфейсе — пошагово  
5. Вариант C — Hard Mode (Static WAN, Manual NAT, PBR, Multi-WAN) — пошагово  
6. NAT (Outbound modes + Port Forward) — детально  
7. Firewall Rules — принцип, порядок, готовые примеры (копи/вставь)  
8. Multi-WAN и Policy Based Routing (PBR)  
9. DHCP / DNS / DNS Resolver vs Forwarder  
10. IDS/IPS — Suricata и Snort на pfSense — установка, конфиг, правила, inline vs alert, логи  
11. Hardware Offloading / Performance на pfSense  
12. Диагностика: консольные команды и разбор логов  
13. Тестирование: конечные проверки и тест-кейсы  
14. Частые ошибки и пошаговые исправления  
15. Журнал действий — шаблон готового отчёта (WSK)  
16. Быстрые сниппеты конфигураций и готовые команды (copy/paste)  
17. Полезные советы, примечания и чек-лист

---

## 1. Принципы (кратко, но важно)
- Правила pfSense применяются к **входящему трафику** на интерфейсе (traffic entering that interface).  
- Первое совпавшее правило сверху вниз — применяется. Порядок правил критичен.  
- NAT и Firewall — разные подсистемы: Port-forward создаёт NAT правило + associated firewall rule (если галка стоит).  
- Outbound NAT (маскарадинг) нужен, чтобы внутренние сети имели выход в интернет при одном внешнем IP.  
- Suricata/Snort — анализирует трафик по сигнатурам; сначала в alert/IDS режиме, затем в IPS/block mode.  
- Всегда делай backup конфигурации (`Diagnostics → Backup & Restore`) перед изменениями.

---

## 2. Начальная подготовка (UI + Console)

### UI:
- Открой web UI: `https://<pfsense-ip>/`  
- Login: admin / (пароль)  
- Всегда скачивай бэкап: `Diagnostics → Backup & Restore → Download config.xml`

### Console (serial/SSH):
- Подключение по SSH: `ssh admin@<pfsense-ip>` (если включено)  
- Доступ к консоли через локальную консоль (VM console) — полезно при поломке web UI.

### Быстрая безопасная процедура перед началом:
1. Скачать config.xml.  
2. Убедиться в доступности консоли (serial/VM console).  
3. Проверить версию pfSense (`Status → Dashboard`), если пакет Suricata/Benches поддерживаются.  
4. Включить time sync (NTP): `System → General Setup → NTP servers`.

---

## 3. Вариант A — классическая топология (пошагово)

**Топология:**
- WAN — внешний (DHCP/Static)
- LAN — 192.168.10.0/24 (DHCP range .50–.200)
- DMZ — 192.168.20.0/24 (static ip on server 192.168.20.10)

### 3.1 Назначение интерфейсов
UI: `Interfaces → Assignments`
- назначить NIC’ы: WAN (igb0), LAN (igb1), OPT1 -> переименовать в DMZ (igb2)

### 3.2 Настройка WAN
UI: `Interfaces → WAN`
- Если DHCP: IPv4 Configuration Type: **DHCP**  
- Рекомендуется: **Block private networks** и **Block bogon networks** (для WAN).

Если Static:
- IPv4 Configuration Type: **Static IPv4**  
- Address: `<public>/mask`  
- Gateway: указать шлюз (провайдера)

Save → Apply.

### 3.3 Настройка LAN
UI: `Interfaces → LAN`  
- IPv4 Static: `192.168.10.1/24`  
- Enable DHCP: `Services → DHCP Server → LAN`, Range: `192.168.10.50–192.168.10.200`

### 3.4 Настройка DMZ
UI: `Interfaces → OPT1` → Rename: DMZ  
- IPv4 Static: `192.168.20.1/24`  
- DHCP обычно **OFF** для DMZ servers (лучше static).

### 3.5 Проверка базовой связности
- Diagnostics → Ping: с pfSense на DMZ и LAN адреса.  
- Попробуй `ping 192.168.20.10` (сервер DMZ) из LAN или консоли.

### 3.6 Outbound NAT (обычно Automatic)
UI: `Firewall → NAT → Outbound`  
- Mode: **Automatic Outbound NAT** (по умолчанию)

### 3.7 Port Forward (HTTP -> DMZ)
UI: `Firewall → NAT → Port Forward → Add`
- Interface: **WAN**
- Protocol: **TCP**
- Destination: **WAN address**
- Destination Port Range: **80**
- Redirect target IP: `192.168.20.10`
- Redirect target port: **80**
- **Check**: Add associated filter rule — ✔
Save → Apply.

### 3.8 Firewall rules (конкретные записи)
**LAN** — Secure minimal:
1. Allow DNS to pfSense / External (UDP 53)  
2. Allow HTTP/HTTPS to any (TCP 80,443)  
3. Allow AdminHost (e.g. 192.168.10.10) → DMZ 22 (SSH)  
4. Block LAN net → DMZ net (explicit)  
5. Default deny (implicit)

**DMZ**:
1. Allow WAN → DMZ:80/443 (auto rule from NAT)  
2. Allow LAN Admin → DMZ:22  
3. Block other

**WAN**:
- Auto rules from NAT handle forwarded ports. Recommend to manually add block rules for bogons/private if provider doesn't.

### 3.9 Тесты
- С внешней машины: `curl http://<WAN_IP>/` -> должен получить страницу DMZ.  
- С LAN: `ssh admin@192.168.20.10` (если разрешено).  
- Проверить logs: `Status → System Logs → Firewall` и через консоль `clog /var/log/filter.log | tail -n 200`.

---

## 4. Вариант B — VLAN на одном физическом интерфейсе

**Топология (trunk on switch):**
- VLAN10 Admin -> 192.168.10.0/24
- VLAN20 Users -> 192.168.20.0/24
- VLAN30 DMZ -> 192.168.30.0/24

### 4.1 На switch: сделать trunk для порта, куда подключен pfSense
**Cisco (пример):**
```

interface Gi0/1
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 10,20,30

```
Access ports на клиентских портах: `switchport mode access; switchport access vlan 20`

### 4.2 Создание VLAN в pfSense
UI: `Interfaces → Assignments → VLANs → Add`
- Parent Interface: `igb1`
- VLAN Tag: `10`
- Description: `VLAN10-Admin`
Повтори для 20 и 30.

### 4.3 Назначение интерфейсов и IP
UI: `Interfaces → Assignments → Add` — добавь `VLAN10`, `VLAN20`, `VLAN30`.  
Настрой IP:
- VLAN10: `192.168.10.1/24`, DHCP ON (range .50–.100)  
- VLAN20: `192.168.20.1/24`, DHCP ON  
- VLAN30: `192.168.30.1/24`, DHCP OFF (DMZ)

### 4.4 Firewall (изоляция)
**VLAN20 (Users)**:
- Rule1: Allow TCP 80,443 → any (to internet)  
- Rule2: Block → VLAN10 net  
- Rule3: Block → VLAN30 net

**VLAN10 (Admin)**:
- Allow → any (or limited management)

**VLAN30 (DMZ)**:
- Allow → WAN (forwarded ports)
- Allow VLAN10 → VLAN30:22
- Block VLAN20 → VLAN30

### 4.5 Проверки
- С client vlan20: `curl http://192.168.30.10` — должно быть **запрещено**.  
- С client vlan10: `ssh admin@192.168.30.10` — разрешено.

---

## 5. Вариант C — Hard Mode (Static WAN + Manual NAT + PBR + Multi-WAN)

### 5.1 Static WAN
UI: `Interfaces → WAN` → IPv4 Type: **Static**  
- Address: `203.0.113.10/24`  
- Gateway: `203.0.113.1`

### 5.2 Manual Outbound NAT
UI: `Firewall → NAT → Outbound → Manual Outbound NAT`  
Пример правила:
- Source: `192.168.10.0/24` → Translation: `Interface address (WAN)`

Добавить правило для DMZ и VLAN, если есть.

### 5.3 Multi-WAN and Gateways
UI: `System → Routing → Gateways → Add`  
- Добавить второй gateway (GW2): `203.0.113.2` (если есть второй провайдер)  
- Проверить `Status → Gateways` → Online.

### 5.4 Policy Based Routing (PBR)
UI: `Firewall → Rules → <interface>` (например VLAN20) → Add правило  
- В секции **Advanced Features** → **Gateway**: выбрать `GW2`.  
Трафик по данному правилу пойдёт через GW2.

### 5.5 DMZ через VPN
- Настроить VPN client (OpenVPN или IPsec) в pfSense → создать gateway для VPN.  
- В Firewall rule для DMZ → Advanced → Gateway: `VPN_GW`.

### 5.6 Проверки
- `traceroute` с клиентов VLAN20/DMZ → увидеть выбранный gateway.  
- `Status → System Logs → Gateways` → verify.

---

## 6. NAT — подробности и режимы

### Режимы Outbound NAT:
- **Automatic** — pfSense генерирует правила, подходит в большинстве случаев.  
- **Hybrid** — автоматические + пользовательские правила.  
- **Manual** — пользовательские правила полностью.

**Когда Manual?**
- Когда нужно точечно контролировать исходящий NAT для разных внутренних подсетей (Multi-WAN, 1:1 NAT, частый case в C).

### 6.1 Port Forward (полный алгоритм)
1. `Firewall → NAT → Port Forward → Add`  
2. Interface: WAN  
3. Protocol: TCP/UDP  
4. Destination: WAN address (или single host)  
5. Destination Port: External port (например 8080)  
6. Redirect target IP: Internal IP (192.168.20.10)  
7. Redirect target port: Internal port (80)  
8. Check **Add associated filter rule** (если нет — создать правило вручную).  
9. Save → Apply.

### 6.2 1:1 NAT (static NAT)
UI: `Firewall → NAT → 1:1`  
- Interface: WAN  
- External IP: public IP (203.0.113.20)  
- Internal IP: 192.168.20.10  
- Mask bits: 32  
- Description → Save → Apply

---

## 7. Firewall Rules — принцип + готовые примеры (копируй-вставляй)

### Принцип:
- Пиши правила от специфичного к общему (specific → general).  
- Порядок важен.  
- Не забывай Allow established/related (pf handles stateful answers automatically).

### Поле-по-полю (UI):
- Action: Pass / Block / Reject  
- Interface: LAN / WAN / VLANx  
- Address Family: IPv4 (или IPv4+IPv6)  
- Protocol: TCP / UDP / ICMP / any  
- Source: Single host / Network / Alias  
- Source Port Range: any / specific  
- Destination: Single host / Network / Alias / WAN address  
- Destination Port Range: specific ports  
- Advanced: Gateway / Schedule / Logging / Description

### Примеры правил (UI-ready)

**Allow admin SSH to DMZ server**
```

Action: Pass
Interface: LAN
Address Family: IPv4
Protocol: TCP
Source: Single host 192.168.10.10
Source Port Range: any
Destination: Single host 192.168.20.10
Destination Port Range: 22
Description: Allow admin SSH to DMZ
Log: (optional) yes

```

**Block LAN → DMZ (explicit)**
```

Action: Block
Interface: LAN
Protocol: any
Source: LAN net
Destination: 192.168.20.0/24
Description: Block LAN->DMZ default

```

**Allow Users → Internet (HTTP/HTTPS only)**
```

Action: Pass
Interface: VLAN20
Protocol: TCP
Source: VLAN20 net
Destination: any
Destination Ports: from 80 to 80, and separate rule for 443

```

**WAN deny bogon/private**
```

Action: Block
Interface: WAN
Source: !RFC1918? (use alias for bogon networks)
Destination: WAN address

```

---

## 8. Multi-WAN и PBR — практическая часть

### Multi-WAN config
1. Add second WAN interface (WAN2) physical NIC or PPPoE.  
2. System → Routing → Gateways → Add second gateway.  
3. System → Routing → Groups → create group with tiering or failover (optional).

### Policy Based Routing (PBR)
- In Firewall rule → Advanced → Gateway → select specific gateway or gateway group.  
- Use for routing certain sources (VLAN, host) via particular ISP.

### Example: route SQL backups via cheaper ISP2
```

Firewall → Rules → LAN
Action: Pass
Source: 192.168.10.50 (db host)
Destination: 1.2.3.4 (backup host)
Gateway: GW2

```

---

## 9. DHCP / DNS

### DHCP:
UI: `Services → DHCP Server → <interface>`  
- Enable, Range, static DHCP mappings (MAC->IP), DNS servers per interface.

### DNS Resolver vs DNS Forwarder:
- **Resolver (unbound)** — recursive resolver, default in modern pfSense.  
- **Forwarder (dnsmasq)** — forwards to upstream resolvers.  
Choice: Resolver is recommended for autonomy. If you need to force upstream provider, use Forwarder.

### Split DNS / Overrides:
- `Services → DNS Resolver → Host Overrides` — useful for internal name resolution (e.g., webserver.example.local).

---

## 10. IDS/IPS — Suricata / Snort — максимально подробно

> Рекомендация: Suricata предпочтительнее. Snort аналогичен по принципу.

### 10.1 Установка
UI: `System → Package Manager → Available Packages → suricata → Install`

### 10.2 Основные сущности
- **Interfaces** — где слушаем (WAN/LAN/DVLAN).  
- **Rules** — списки сигнатур (ET Open, Emerging Threats, Snort).  
- **EVE JSON** — основной лог в JSON для Filebeat / Elastic / Kibana.  
- **IPS Mode** — блокировка (drop) при inline / NFQUEUE support.

### 10.3 Настройка интерфейса
`Services → Suricata → Interfaces → Add`

Поля:
- Interface: e.g., WAN  
- Enable: ✔  
- Promiscuous Mode: ✔  
- Check Box: IPS Mode (Enabled/Disabled) — start with **Disabled (IDS)**  
- Pattern Matcher: Hyperscan (increase perf if supported)  
- Rulesets: ET Open, Emerging Threats, etc.  
- Logging: EVE JSON enabled, output to `/var/log/suricata/eve.json`

Save → Apply.

### 10.4 Modes explained
- **Alert (IDS)** — Suricata only logs alerts, does not block. Safe for testing.  
- **Inline/IPS** — Suricata blocks matching traffic. Requires proper packet handling (NFQUEUE) / pf integration. Use only after test.

### 10.5 Update rules
`Services → Suricata → Updates` → Update Rules.  
Rules retained in `/usr/local/etc/suricata/rules/`.

### 10.6 Custom rules (quick sample)
Create `local.rules` or add in UI custom rules:

Example: detect simple web-shell uri
```

alert http any any -> any any (msg:"WEB-SHELL attempt /shell.php"; uricontent:"/shell.php"; nocase; sid:1000001; rev:1;)

```

Place in custom rules and reload Suricata.

### 10.7 Logging & Integration
- EVE JSON used by Filebeat -> Elastic -> Kibana  
- Or send logs to remote syslog/Graylog

### 10.8 Testing Suricata
- Example payloads:
  - `curl "http://target/shell.php?cmd=ls"`  
  - `curl "http://target/?id=1 UNION SELECT 1"` (SQLi signature)
- Check `Status → System Logs → Suricata` or `clog /var/log/suricata/eve.json | tail -n 200`.

### 10.9 Common Suricata pitfalls
- **Hardware offloading** (e.g., TSO/GSO) may break packet inspection — disable offloading on NICs (Settings → System → Advanced → Networking → disable Hardware Checksum Offload, TSO, LRO).  
- **Promisc / VLAN tags** — ensure Suricata listens on trunk or correct NIC/VLAN.
- **High CPU** — reduce rulesets, use Hyperscan, increase resources.

---

## 11. Hardware Offloading / Performance — что проверить

### Offloading check (console):
```

ifconfig igb1

# or ethtool -k (on host)

```

### Отключить offloading в pfSense (UI):
`System → Advanced → Networking`  
- Uncheck: Hardware Checksum, TCP Segmentation Offload, Large Receive Offload, etc.  
Перезагрузить NIC / Suricata если необходимо.

### Tuning Suricata:
- Pattern matcher: **Hyperscan** if CPU supports.  
- Use AF_PACKET for high throughput capture (Suricata config).  
- Limit rulesets to necessary (Critical/High).

---

## 12. Диагностика: консольные команды и что смотреть

### 12.1 Просмотр interface / routes
```

ifconfig -a
netstat -rn
route -n

```

### 12.2 pf / rules / states
```

pfctl -sr            # show rules
pfctl -s nat
pfctl -s state
pfctl -sa            # all info

```

### 12.3 Логи (clog — circular log)
```

clog /var/log/filter.log | tail -n 200
clog /var/log/system.log | tail -n 200
clog /var/log/dhcpd.log | tail -n 200
clog /var/log/suricata/eve.json | tail -n 200

```

### 12.4 tcpdump
```

tcpdump -ni igb0 host 192.168.20.10 and port 80 -vv -c 200

# capture to file

tcpdump -ni igb0 -w /tmp/capture.pcap host 192.168.20.10

```

### 12.5 Проверка NAT
```

pfctl -s nat

```

### 12.6 Перезапуск сервисов
```

/etc/rc.reload_all   # reload config
/etc/rc.restart_webgui
/etc/rc.d/suricata restart  # or via service manager

```

---

## 13. Тестирование: тест-кейсы (обязательные)

### 13.1 Базовый
- Ping из LAN -> DMZ  
- Access external web via NAT (curl WAN:80)  
- Try SSH from admin host to DMZ

### 13.2 Безопасность
- From Users (VLAN20) try access DMZ web: should not be allowed (unless specified)  
- Simulate brute force SSH: `hydra -l root -P passlist.txt ssh://<ip>` — Suricata/IDS should log/alert (only if signatures permit)

### 13.3 IDS
- Run specific payloads that known rules detect:
  - SQLi: `curl "http://<target>/?id=1 UNION SELECT"`  
  - RCE patterns: `curl "http://<target>/?cmd=ls"`  
- Confirm Suricata created alert in `eve.json`.

### 13.4 Load tests (be careful)
- Use `ab` or `wrk` for web server load; check pfSense CPU, Suricata CPU.

---

## 14. Частые ошибки и пошаговые исправления

### Ошибка: LAN нет интернета
**Симптом:** IP есть, но нет выхода.
**Проверки:**
- `pfctl -s nat` — есть ли NAT правило?
- `Firewall → NAT → Outbound` — Automatic? Если Manual — есть ли правило для LAN?
**Fix:** Включить Automatic или добавить Manual rule Source LAN -> Translation: Interface address.

### Ошибка: Port Forward не работает
**Симптом:** Проброс создан, но извне не доступно.
**Проверки:**
- Rule added to `Firewall → Rules → WAN`? (если Add associated filter rule не стояла, правило могло не создаться)
- DMZ server firewall (iptables/Windows Firewall) не блокирует порт?
- Provider NAT / CGNAT — внешний IP может быть не публичным.
**Fix:** Add firewall rule for WAN port manually или re-create PF с checked Add associated rule. Проверить external IP (whatismyip).

### Ошибка: VLAN клиенты не получают DHCP
**Симптом:** Клиент получает 169.254.x.x или нет адреса.
**Проверки:**
- Switch trunk настроен? (port to pfSense must be trunk with allowed VLAN tags)
- `Interfaces → Assignments` has VLAN interfaces?  
**Fix:** Configure switch trunk; ensure pfSense VLAN interfaces created and DHCP server enabled.

### Ошибка: Suricata ничего не ловит
**Симптом:** Тестовые payloads нет в logs.
**Проверки:**
- Suricata enabled on correct interface?  
- EVE logging enabled?  
- NIC offloading enabled (breaks inspection) — disable via System → Advanced.
- Is traffic actually going through that interface? (tcpdump check)
**Fix:** Disable offloading, ensure Suricata listens on interface with traffic, enable proper rules.

### Ошибка: Too many states / high memory
**Symptom:** pfctl -s state huge number, memory high.
**Fix:** Increase state limits: `System → Advanced → Firewall & NAT` → 'Maximum states', kill old states if needed, adjust timeouts.

### Ошибка: ssh to pfSense fails after config change
**Fix:** Use console (VM/serial) to correct `sshd` or restore config.xml. Keep an active console session when editing SSH settings.

---

## 15. Журнал действий — шаблон отчёта (готово к отправке экспертам)

```

Title: pfSense Configuration & Hardening — WSK Task X
Date: YYYY-MM-DD
Author: <Your name / Team>

1. Overview

* Topology: WAN (DHCP) / LAN 192.168.10.0/24 / DMZ 192.168.20.0/24
* Objective: Allow public HTTP to DMZ, admin SSH from LAN to DMZ, isolate LAN clients from DMZ, enable IDS.

2. Changes performed (timestamped)
   [09:00] Login to UI [https://192.168.1.1](https://192.168.1.1) — success
   [09:02] Interfaces assigned: WAN=igb0, LAN=igb1, DMZ=igb2
   [09:05] LAN configured: 192.168.10.1/24; DHCP enabled (range .50-.200)
   [09:07] DMZ configured: 192.168.20.1/24; DHCP disabled
   [09:10] NAT: Port Forward WAN:80 -> 192.168.20.10:80; associated rule added
   [09:12] Firewall rules LAN: Allow HTTP/HTTPS; Allow AdminHost->DMZ:22; Block LAN->DMZ
   [09:15] Installed Suricata on WAN; mode: Alert; ET Open rules enabled
   [09:20] Tests: curl http://<WAN_IP>:80 -> 200 OK; Suricata alert logged -> PASS
   [09:25] Backup config.xml downloaded: config_wsktask_<timestamp>.xml

3. IOC / Evidence

* Firewall logs: /var/log/filter.log (clog)
* Suricata alerts: /var/log/suricata/eve.json
* NAT: pfctl -s nat output saved

4. Recommendations

* Keep Suricata in Alert mode until valid rules confirmed.
* Use Manual Outbound NAT only when necessary; prefer Automatic for speed.
* Disable NIC offloading when running IDS.

5. Rollback plan

* Restore config from config_wsktask_<timestamp>.xml via Diagnostics -> Backup & Restore

```

---

## 16. Быстрые сниппеты (copy/paste готовые команды и правила)

### Консоль: show rules
```

pfctl -sr

```

### Log tail
```

clog /var/log/filter.log | tail -n 200

```

### Suricata eve tail
```

clog /var/log/suricata/eve.json | tail -n 200

```

### tcpdump capture 60 seconds
```

tcpdump -ni igb0 -w /tmp/cap.pcap -G 60 -W 1 'port 80 or port 443'

```

### Reapply pf rules
```

pfctl -f /etc/pf.conf

```

---

## 17. Чек-лист перед сдачей (обязательно пройти)

- [ ] Interfaces assigned and IPs set  
- [ ] DHCP on required interfaces and leases verified  
- [ ] Outbound NAT correct (Automatic or Manual rules added)  
- [ ] Port Forward rules created and tested from external host  
- [ ] Firewall rules in place (order checked) — run `pfctl -sr`  
- [ ] IDS/Suricata installed & alert mode active, sample alerts logged  
- [ ] Hardware offloading disabled if IDS used  
- [ ] Backup config.xml created and downloaded  
- [ ] Journal / timestamped actions saved in report  
- [ ] All tests passed (external curl, internal access, blocked access)

---

### Примечания / Best Practices
- Всегда держи одну рабочую консоль с root/console доступом при правках SSH / GUI.  
- Не переводить IDS в IPS (block) без тестов — можно заблокировать легитимный трафик.  
- Для соревнований: понятная, краткая документация + временная линия (таймлайн) — половина успеха.

---

# Конец руководства (pfSense — WorldSkills Edition)
```

---

Если нужно — делаю дополнительные вещи сразу:

* экспортирую это в TXT / PDF / DOCX и дам ссылку (скачиваемый файл),
* подгоню журнал под твой IP-план (скинь IP-план: WAN ip(s), LAN subnets, DMZ ips, admin hosts),
* сгенерирую 5 практических упражнений + ответы (тренировка).

Что делаем дальше — экспортировать файл (TXT/PDF/DOCX) или правим под твою топологию?
