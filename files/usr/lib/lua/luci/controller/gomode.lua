module("luci.controller.gomode", package.seeall)

function index()
	entry({"admin", "network", "gomode"}, cbi("gomode"), _("场景模式"), 60).dependent = false
end
