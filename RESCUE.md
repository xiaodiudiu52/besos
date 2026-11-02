# 极GO（HiWiFi HC5611）救砖与备份资料

这台机器改过的所有东西、以及刷机前抢救出来的原始分区，都放在这个仓库里。
**遇到问题时按这份文档来，基本都能救回来。**

---

## 一、备份文件清单

| 文件 | 大小 | MD5 | 是什么 / 什么时候用 |
|---|---|---|---|
| `backup/original-partitions/mtd2_factory.bin` | 64 KB | `1ad4f482b7326431dc28b07979543b3f` | **最重要**。存 MAC 地址和无线校准数据。丢了 WiFi 会失效或信号极差。救砖优先保它 |
| `backup/original-partitions/mtd0_u-boot.bin` | 192 KB | `539892f14b780b9075b3677d427a0144` | bootloader。只有它彻底坏了才会真变砖，**不要随便刷** |
| `backup/original-partitions/mtd8_bdinfo.bin` | 64 KB | `9b28ef4725cce9fc077f66ff0850fd0c` | 板子信息，里面有明文 MAC：`Vfac_mac = D4:EE:07:36:71:6C` |
| `backup/original-partitions/mtd7_oem.bin` | 128 KB | `0009c6a46fa1183b0139508ef18caf15` | 原厂 OEM 数据 |
| `backup/original-partitions/mtd9_backup.bin` | 64 KB | `ad21ea8b21e1513a731716745a490684` | 原厂 backup 分区 |
| `backup/original-firmware-hc5611-stock.bin` | 8.9 MB | `5b7dc898c8a68886470154771a2aa8ed` | 极路由原厂固件（MD5 与官方公布一致）。想回原厂就用它 |
| `firmware/openwrt-24.10.8-custom-*.bin` | 10 MB | 见同目录 `sha256sums` | 定制固件（当前在用的这个） |

> 校验命令：`md5 backup/original-partitions/mtd2_factory.bin`

---

## 二、设备分区布局

| 分区 | 大小 | 内容 | 能不能动 |
|---|---|---|---|
| mtd0 `u-boot` | 192 KB | bootloader | 别动，动了可能真砖 |
| mtd1 `hw_panic` | 64 KB | 崩溃日志 | — |
| mtd2 `factory` | 64 KB | **MAC + 无线校准** | 别乱写，坏了 WiFi 废 |
| mtd3 `firmware` | 15.44 MB | 内核 + 根文件系统（刷的就是这里） | 随便刷 |
| mtd4 `kernel` | — | 内核（在 firmware 内） | 跟随固件 |
| mtd5 `rootfs` | — | 根文件系统（在 firmware 内） | 跟随固件 |
| mtd6 `rootfs_data` | 5.43 MB | 你的配置（overlay） | `sysupgrade -n` 会清空 |
| mtd7 `oem` | 128 KB | 原厂数据 | 保留 |
| mtd8 `bdinfo` | 64 KB | 板信息 + MAC 明文 | 保留 |
| mtd9 `backup` | 64 KB | 原厂备份 | 保留 |

管理地址 `10.10.10.1`，默认管理密码 `admin`。

---

## 三、出问题了怎么办（按严重程度从轻到重）

### 情况 1：还能进系统（SSH 或网页能打开）

这是最简单的情况，直接重刷：

```bash
# 从本机把固件传上去（用网线或连 WiFi "Go" 都行）
ssh root@10.10.10.1 "cat > /tmp/fw.bin" < firmware/openwrt-24.10.8-custom-*.bin

# 在路由器上校验后再刷，校验不对千万别刷
ssh root@10.10.10.1 "sha256sum /tmp/fw.bin"

# 确认和 firmware/sha256sums 里的一致后执行
ssh root@10.10.10.1 "sysupgrade -n /tmp/fw.bin"
```

`-n` 表示不保留配置（干净重来）。想保留配置就把 `-n` 去掉。
刷完等 **1～4 分钟**，开机要跑初始化和网口探测，前两分钟连不上是正常的，别急着按 RESET。

### 情况 2：系统起不来了，但 u-boot 还在（绝大部分"变砖"都是这种）

**好消息：这台机器的 u-boot 自带 TFTP 恢复功能**（从备份里确认过，
里面有 `System Load Linux Kernel then write to Flash via TFTP` 的菜单项）。
所以只要 u-boot 没坏，不需要拆机就能救。

步骤：

1. 电脑用网线直连极GO 的网口，给电脑设静态 IP：
   - IP `192.168.1.2`，掩码 `255.255.255.0`（这是 ramips 机器最常见的组合）
   - 如果不行，再试 `10.10.10.3` / `10.10.10.2`
2. 电脑上起一个 TFTP 服务器，把固件放进去：
   ```bash
   # macOS 自带 tftpd，用这个启动（把固件放到 /private/tftpboot）
   sudo cp firmware/openwrt-24.10.8-custom-*.bin /private/tftpboot/recovery.bin
   sudo launchctl load -F /System/Library/LaunchDaemons/tftp.plist
   ```
3. 极GO **断电**，**按住 RESET 不放**，再**通电**，继续按住约 10 秒后松开。
4. u-boot 会进入恢复菜单，选通过 TFTP 加载固件写入 Flash 的那一项。
5. 等它写完自动重启，之后按情况 1 验证。

> 如果 u-boot 提示 `*** ERROR: 'serverip' not set`，说明它没记住 TFTP 服务器地址，
> 需要在串口里手动设 `setenv serverip 192.168.1.2; setenv ipaddr 192.168.1.1` 再 `tftpboot`。
> 这一步需要串口线（见情况 3）。

### 情况 3：u-boot 也坏了（真砖）

这种只能硬件介入：拆机，找到主板上的串口针脚（一般标着 TX/RX/GND/VCC，
HC5611 的串口波特率是 **57600**），用 USB-TTL 转换线（CH340/CP2102 都行）连上，
就能看到 u-boot 的输出、进命令行重新烧录。

如果连 u-boot 都烧不进去，就得用编程器（夹子或焊下 flash 芯片）直接写
`mtd0_u-boot.bin` + 固件。**这种情况建议找修手机的帮忙**，工具成本比机器本身还高。

---

## 四、想刷回极路由原厂固件

```bash
ssh root@10.10.10.1 "cat > /tmp/stock.bin" < backup/original-firmware-hc5611-stock.bin
ssh root@10.10.10.1 "md5sum /tmp/stock.bin"   # 应为 5b7dc898c8a68886470154771a2aa8ed
ssh root@10.10.10.1 "sysupgrade -n /tmp/stock.bin"
```

**注意**：原厂固件的管理地址是 `192.168.199.1`（域名 `hiwifi.com`），不是 `10.10.10.1`。
另外原厂首次进会强制走两步设置向导，且它依赖的云端服务（激活、插件、手机 App 遥控）
早就停了，所以能进系统但联网激活那套大概率用不了。

---

## 五、几条保命建议

1. **刷任何东西之前，先重新备份一次分区**，尤其是 `factory`：
   ```bash
   ssh root@10.10.10.1 "dd if=/dev/mtd2 of=/tmp/factory_$(date +%m%d).bin"
   # 然后把它拷回电脑保存
   ```
2. **`factory` 分区永远不要覆盖写**，除非你明确知道在干什么。它是整机唯一一份
   MAC 和无线校准数据，写坏了没有第二份。
3. 现在的固件**网口/WiFi 切换都有自检和自动回滚**：切换后 4 秒内局域网拿不到
   `10.10.10.1` 就会自动还原上一个配置。所以就算填错了 WiFi 密码或选错模式，
   也不会把自己锁在门外——管理页 `http://10.10.10.1` 始终能进。
4. 开机慢是正常的（初始化 + 网口探测），**等 1～4 分钟**再说。

---

## 六、目前还没实测过的部分

留个底，免得以后踩坑时不知道为什么：

- **宽带拨号（PPPoE）** 和 **静态 IP** 两种模式没实测过（当时没有宽带账号和
  上级网络参数）。它们和其他模式共用同一套"备份 + 自检 + 回滚"逻辑，
  理论上不会锁死，但第一次到现场用时留意一下。
- 长时间连续运行（几天以上）和十台以上设备并发，没测过。
