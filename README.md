# 极GO (HC5611) 定制 OpenWrt 固件

为现场调试场景定制。**中文界面、上网方式配置、LED 指示、调试工具全部打包进固件本体**（只读分区），
所以**恢复出厂设置也不会丢失**。

## LED 指示灯（一眼辨识场景 + 有没有网）

颜色 = 当前场景，闪烁 = 互联网状态。每 30 秒自动检测一次外网连通性。

| 灯 | 含义 |
|---|---|
| 🟢 **绿灯常亮** | 网口上网（DHCP / 静态IP / PPPoE），互联网**已通** |
| 🟢 **绿灯慢闪** | 网口上网，但互联网**不通**（线没插好 / 上联没网） |
| 🟡 **黄灯常亮** | 无线桥接，现场 WiFi 已连上且互联网**已通** |
| 🟡 **黄灯慢闪** | 无线桥接，但互联网**不通**（WiFi 没连上） |
| 🔴 **红灯常亮** | 独立热点（本来就不联网，本机做 DHCP 服务器） |
| 🔴 **红灯快闪** | 启动中 |

> 硬件只有红、绿两个 LED，黄灯是红绿同时点亮混出来的。判断互联网用的是 ping `223.5.5.5` / `114.114.114.114`。
> 如果现场网络禁了 ICMP，灯会显示"不通"，但实际能上网——这种情况看网页状态更准。

## 六种上网方式

| 方式 | 上行走哪 | 网口 | 需要填什么 |
|---|---|---|---|
| **自动探测**（默认） | 开机探测网口 | 有 DHCP → WAN，无 → LAN | 不用填 |
| **自动获取 IP**（DHCP） | 网线 | WAN | 不用填 |
| **手动指定 IP**（静态） | 网线 | WAN | IP、子网掩码、网关、DNS |
| **宽带拨号**（PPPoE） | 网线 | WAN | 宽带账号、密码 |
| **无线桥接** | 现场 WiFi | LAN | 现场 WiFi 名称、密码 |
| **不联网** | 无 | LAN | 不用填 |

**开机自适应原理**：起来后网口先跑 DHCP 客户端探 10 秒左右，收到回应就当 WAN 用自动获取 IP，
没插线或没人理就当 LAN 变成独立热点。这就是小米/华为/GL.iNet 上"网口自适应"的同一套逻辑。
> 注意：自动探测只认 DHCP。如果现场是**固定 IP**，请在网页里手动选「手动指定 IP」，机器猜不出来。

## 固定约定

| 项 | 值 |
|---|---|
| 管理地址 | **10.10.10.1**（任何上网方式下都不变，可在网页改） |
| 本机 WiFi | **Go**，默认无密码开放网络 |
| WiFi 归属 | **永远在 LAN 桥接里** → 任何方式下连上 `Go` 都能进管理页 |
| root 密码 | 无（现场临时用，方便） |

## 稳定性保障（切换失败也不会失联）

每次切换上网方式，脚本会自动做四件事：

1. **切换前备份** `network` / `wireless` / `dhcp` / `firewall` 配置
2. **重启网络后强制把网口挂回 LAN 桥**（实测 `network restart` 偶尔不会真正把 `eth0` 挂进 `br-lan`）
3. **自检**：4 秒后检查局域网是否拿到管理地址 `10.10.10.1`
4. **失败自动回滚**：没拿到就还原刚才的配置并重启网络

所以无论切到哪种方式、填错什么参数，管理页 `http://10.10.10.1` 始终能进——
最坏情况不过是回到上一个能用的模式。

## 管理界面（仿极GO出厂风格）

打开 `http://10.10.10.1` 直接进入新界面，不用再进 LuCI：

- **登录页**：蓝色渐变 + 白色卡片，默认密码 `admin`
- **状态卡**：一眼看到当前上网方式、联网状态、LED 含义
- **上网方式**：六个大按钮（自动探测 / 自动获取 / 静态 IP / 宽带拨号 / 无线桥接 /
  独立热点）。选中「无线桥接」会展开上级 WiFi 名称和密码，选「宽带拨号」展开账号密码，
  选「静态 IP」展开地址 / 掩码 / 网关 / DNS
- **无线网络**：改 WiFi 名称、密码、管理地址
- **已连接设备**：列出设备名和 IP
- **系统**：重启、进高级设置（LuCI）、查看状态 JSON

界面按手机优先设计，现场用手机操作也顺手。

后端接口 `/cgi-bin/api`：

| 动作 | 说明 |
|---|---|
| `?action=status` | 查询状态（JSON） |
| `action=login` | 登录（默认密码 `admin`，可用 `uci set gomode.main.admin_pass=xxx` 改） |
| `action=setmode` | 切换上网方式 |
| `action=setwifi` | 改 WiFi / 管理地址 |
| `action=setpass` | 改管理密码 |
| `action=reboot` | 重启 |
| `action=scan` + `?action=scan_result` | 扫描附近 WiFi（异步：先启动扫描，再轮询取结果） |

切换动作一律后台执行并立刻返回，前端靠轮询看结果，所以网络抖动不会让页面卡死。

- **扫描选 WiFi**：上级 WiFi 名称旁边有个「选择」按钮，点了会扫描附近网络，
  按信号从强到弱列出（带信号格、是否加密），点一下自动填名称，只补密码就行。
  扫描时 WiFi 会短暂断开几秒，属正常；手动输入依然保留（隐藏网络用得上）

## Web 快速配置页面

位置：**网络 → 场景模式**，按小米/TP-Link 设置向导的逻辑分四块：

1. **① 上网设置** — 选上网方式，选了「手动指定 IP」才出现 IP/掩码/网关/DNS，
   选「宽带拨号」才出现账号密码，选「无线桥接」才出现现场 WiFi 名称密码（按需显示，不堆一堆框）
2. **② 本机 WiFi** — WiFi 名称、WiFi 密码（留空 = 开放网络）
3. **③ 局域网** — 管理地址、DHCP 起始/结束地址
4. **④ 指示灯含义** — 对照表，现场忘了看这里

保存即自动应用（后台重启网络，WiFi 会断几秒后恢复）。

## 目录结构

```
custom-firmware/
├── build.sh
├── .github/workflows/build.yml
└── files/                                   # 原样塞进固件
    ├── usr/bin/gomode                       # 上网方式配置主脚本
    ├── usr/bin/gomode-led                   # LED 状态指示（每30秒检测）
    ├── etc/init.d/gomode                    # 开机网口探测
    ├── etc/init.d/gomode-led                # LED 服务自启
    ├── etc/config/gomode                    # 配置（Web 页面读写这个）
    ├── etc/config/wireless                  # 开机 WiFi：Go，无密码
    ├── etc/uci-defaults/99-hc5611-custom    # 中文/时区/地址/自启/网页按钮
    └── usr/lib/lua/luci/                    # LuCI 配置页面
        ├── controller/gomode.lua
        └── model/cbi/gomode.lua
```

## 固件里装的软件

| 类别 | 包 | 装后体积 |
|---|---|---|
| 中文界面 | `luci-i18n-base/firewall/package-manager/commands-zh-cn` | 约 200 KB |
| **UI 主题** | `luci-theme-material`（默认）+ `luci-theme-openwrt`（备用） | 约 140 KB |
| 网页配置页 | `luci-lua-runtime` + `luci-compat` + `luci-app-commands` | 约 420 KB |
| 网页终端 | `ttyd` + `luci-app-ttyd` | 约 460 KB |
| PPPoE 拨号 | `ppp` + `ppp-mod-pppoe` | 约 370 KB |
| 现场调试 | `tcpdump`、`iperf3`、`ethtool`、`arp-scan` | 约 930 KB |
| 端口扫描 | `nmap` | **约 11.9 MB** |

## 体积与性能（实测数据）

Flash 固件分区 **15.44 MB**（`mtd3: 00f70000`），官方纯净镜像 5.5 MB。

| 项 | 大小 |
|---|---|
| 官方基础镜像 | 5.5 MB |
| 新增软件（压缩后实际计入固件） | 约 3.6 MB |
| **实测固件总大小** | **10 MB** |
| 剩余余量 | 约 5.4 MB ✅ |

> 上表"装后体积"是解压占用，固件里 squashfs 是压缩存储的。
> 比如 nmap 解压后 11.9 MB，但压缩进固件只占 2.37 MB——这是它能装下的原因。

**对性能的影响**：

| 方面 | 影响 |
|---|---|
| 网络转发 / WiFi 速率 | **零影响**，LuCI 只是管理界面，数据转发走内核不经过它 |
| 内存 | LuCI 每次请求占几 MB，设备有 122 MB，无压力 |
| 打开管理页面 | 575MHz 单核渲染约 0.3~1 秒，主题多几十 KB 的 CSS/JS，感知不到差异 |
| nmap 首次运行 | 存在压缩分区里要解压读取，比别的命令多等 2~3 秒 |

**结论**：换主题几乎免费（+23 KB），真正的大头只有 nmap 一个。
要省空间第一个就删它：编辑 `build.sh`，从 `TOOLS_PKGS` 里去掉 `nmap`。

### UI 主题

默认用 **Material Design** 风格（卡片、阴影、动效，比 OpenWrt 原生的 Bootstrap 现代得多），
官方默认主题也一并装了，两个都在：

```sh
# 切回官方默认主题（网页打不开时也能用这条命令救回来）
uci set luci.main.mediaurlbase='/luci-static/openwrt'; uci commit luci

# 切回 Material
uci set luci.main.mediaurlbase='/luci-static/material'; uci commit luci
```

网页里也能切：**系统 → 系统 → 语言与界面**。

---

## 构建

OpenWrt 官方构建工具只提供 Linux x86_64 版，Apple Silicon Mac 跑不了，用 GitHub 免费 Linux 服务器最省事。

1. 打开 https://github.com/new 新建仓库（名字随意，选 Public，**不要**勾选初始化 README）
2. 终端执行（把 `你的用户名`、`仓库名` 换成你的）：

```sh
cd /Users/besos/CodeBuddy/20261101200559/custom-firmware
git init
git add -A
git commit -m "JiGo custom firmware"
git branch -M main
git remote add origin https://github.com/你的用户名/仓库名.git
git push -u origin main
```

> push 如果要密码，**别填登录密码**，填 Personal Access Token：
> https://github.com/settings/tokens → Generate new token (classic) → 勾选 `repo`

3. 打开 `https://github.com/你的用户名/仓库名/actions`，「构建极路由Go定制固件」在跑，**5~15 分钟**变绿
4. 点进去 → 页面下方 **Artifacts** → 下载 `openwrt-hc5611-custom`
5. 解压得到 `openwrt-24.10.8-custom-ramips-mt76x8-hiwifi_hc5611-squashfs-sysupgrade.bin`（10 MB）

**如果构建报固件过大**：编辑 `build.sh`，从 `TOOLS_PKGS` 里去掉 `nmap` 重跑。
**本地构建（可选）**：装 OrbStack（`brew install --cask orbstack`）后跑 build.sh。

---

## 刷入

**务必用 `-n`（不保留配置）**，否则旧配置会盖掉固件里新的默认配置：

```sh
scp 固件.bin root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'sysupgrade -n -v /tmp/固件.bin'
```

刷完开机：WiFi 直接出现 `Go`（无密码），连上后开 `http://10.10.10.1`。

## 日常使用

### 网页（推荐）

- **网络 → 场景模式**：改上网方式
- **系统 → 自定义命令**：「扫描局域网设备」「查看当前状态」
- **系统 → 终端**（ttyd）：网页里敲命令行

### 命令行

```sh
gomode                 # 看当前状态（含互联网是否通）
gomode auto            # 重新探测网口
gomode dhcp            # 自动获取 IP
gomode static          # 静态 IP（先在网页填好 IP 和网关）
gomode pppoe           # 宽带拨号
gomode bridge          # 无线桥接
gomode none            # 不联网，独立热点
```

### 现场调试常用命令

```sh
arp-scan --localnet          # 扫出局域网所有设备的 IP 和 MAC（找调试设备地址）
tcpdump -i br-lan -n         # 抓包看设备通信
iperf3 -s                    # 本机当测速服务端；iperf3 -c 对端IP 当客户端
ethtool eth0                 # 看网线是否接通、速率多少
nmap -sn 10.10.10.0/24       # 扫活着的主机
```

## 恢复出厂设置后

长按 RESET 5 秒（或 LuCI 里恢复出厂），重启后：

- 中文界面 ✓、WiFi `Go` ✓、`gomode` 命令 ✓、调试工具 ✓、LED 指示 ✓ —— 都在固件里，不会丢
- 上网方式回到「自动探测」，开机重新判断

## 安全提醒

WiFi 无密码 + root 无密码 = **连上 `Go` 的任何人都能改路由器配置**。
现场临时调试没问题，别在公共场合长期开着。要加密码在「网络 → 无线」或配置页 ② 里设。
