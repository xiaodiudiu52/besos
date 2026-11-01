local sys = require "luci.sys"

m = Map("gomode", translate("极GO 快速配置"),
	translate("按现场情况选上网方式，保存后自动生效。管理地址和本机 WiFi 与上网方式无关，任何情况下连上 WiFi 都能进管理页。"))

s = m:section(TypedSection, "main", "")
s.anonymous = true
s.addremove = false

-- ========== ① 上网设置 ==========
o = s:option(DummyValue, "_t1", translate("① 上网设置"))

o = s:option(ListValue, "mode", translate("上网方式"),
	translate("「自动探测」= 开机看网口：有 DHCP 服务器就用自动获取 IP，没插线或没人理就变成独立热点"))
o:value("auto", translate("自动探测（推荐）"))
o:value("dhcp", translate("自动获取 IP（DHCP）"))
o:value("static", translate("手动指定 IP（上联没有 DHCP）"))
o:value("pppoe", translate("宽带拨号（PPPoE）"))
o:value("bridge", translate("无线桥接（连现场 WiFi）"))
o:value("none", translate("不联网（本机做 DHCP 服务器）"))
o.default = "auto"

o = s:option(Value, "ipaddr", translate("IP 地址"))
o:depends("mode", "static")
o.datatype = "ip4addr"

o = s:option(Value, "netmask", translate("子网掩码"))
o:depends("mode", "static")
o.datatype = "ip4addr"
o.default = "255.255.255.0"

o = s:option(Value, "gateway", translate("网关"))
o:depends("mode", "static")
o.datatype = "ip4addr"

o = s:option(Value, "dns1", translate("主 DNS"))
o:depends("mode", "static")
o.datatype = "ip4addr"

o = s:option(Value, "dns2", translate("备用 DNS"))
o:depends("mode", "static")
o.datatype = "ip4addr"

o = s:option(Value, "pppoe_user", translate("宽带账号"))
o:depends("mode", "pppoe")

o = s:option(Value, "pppoe_pass", translate("宽带密码"))
o:depends("mode", "pppoe")
o.password = true

o = s:option(Value, "up_ssid", translate("现场 WiFi 名称"),
	translate("极GO 要去连的那个 WiFi"))
o:depends("mode", "bridge")

o = s:option(Value, "up_key", translate("现场 WiFi 密码"))
o:depends("mode", "bridge")
o.password = true

-- ========== ② 本机 WiFi ==========
o = s:option(DummyValue, "_t2", translate("② 本机 WiFi"))

o = s:option(Value, "ap_ssid", translate("WiFi 名称"),
	translate("极GO 自己发射的信号，任何上网方式下都属于局域网"))
o.default = "Go"

o = s:option(Value, "ap_key", translate("WiFi 密码"),
	translate("留空 = 开放网络，不用密码直接连"))
o.password = true

-- ========== ③ 局域网 ==========
o = s:option(DummyValue, "_t3", translate("③ 局域网"))

o = s:option(Value, "lan_ip", translate("管理地址"),
	translate("建议保持 10.10.10.1，现场极少有这个网段，不会冲突"))
o.datatype = "ip4addr"
o.default = "10.10.10.1"

o = s:option(Value, "dhcp_start", translate("DHCP 起始地址"),
	translate("调试设备从这里开始拿 IP"))
o.datatype = "uinteger"
o.default = "100"

o = s:option(Value, "dhcp_end", translate("DHCP 结束地址"))
o.datatype = "uinteger"
o.default = "250"

-- ========== ④ 指示灯 ==========
o = s:option(DummyValue, "_t4", translate("④ 指示灯含义"))
o.value = translate("绿灯常亮=网口上网已联网 · 绿灯慢闪=网口上网但没网 · 黄灯=无线桥接（常亮有网/慢闪没网）· 红灯常亮=独立热点 · 红灯快闪=启动中")

function m.on_commit(map)
	sys.call("/usr/bin/gomode apply >/tmp/gomode_apply.log 2>&1 &")
end

return m
