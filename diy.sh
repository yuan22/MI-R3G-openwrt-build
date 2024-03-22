#!/bin/bash
svn_export() {
	# 参数1是分支名, 参数2是子目录, 参数3是目标目录, 参数4仓库地址
 	echo -e "clone $4/$2 to $3"
	TMP_DIR="$(mktemp -d)" || exit 1
 	ORI_DIR="$PWD"
	[ -d "$3" ] || mkdir -p "$3"
	TGT_DIR="$(cd "$3"; pwd)"
	git clone --depth 1 -b "$1" "$4" "$TMP_DIR" >/dev/null 2>&1 && \
	cd "$TMP_DIR/$2" && rm -rf .git >/dev/null 2>&1 && \
	cp -af . "$TGT_DIR/" && cd "$ORI_DIR"
	rm -rf "$TMP_DIR"
}

trap 'rm -rf "$TMPDIR"' EXIT
TMPDIR=$(mktemp -d) || exit 1

rm -rf feeds/packages/lang/golang 

git clone https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

curl -sfL https://github.com/immortalwrt/luci/raw/master/modules/luci-base/root/usr/share/luci/menu.d/luci-base.json > feeds/luci/modules/luci-base/root/usr/share/luci/menu.d/luci-base.json
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall-packages
git clone --depth 1 https://github.com/fw876/helloworld package/helloworld
git clone --depth 1 https://github.com/chenmozhijin/luci-app-adguardhome package/luci-app-adguardhome
git clone --depth 1 https://github.com/sbwml/luci-app-daed-next package/daed-next
svn_export "main" "luci-app-passwall" "package/luci-app-passwall" "https://github.com/xiaorouji/openwrt-passwall"
svn_export "master" "applications/luci-app-zerotier" "feeds/luci/applications/luci-app-zerotier" "https://github.com/immortalwrt/luci"
svn_export "master" "applications/luci-app-vlmcsd" "feeds/luci/applications/luci-app-vlmcsd" "https://github.com/immortalwrt/luci"
svn_export "master" "applications/luci-app-webadmin" "feeds/luci/applications/luci-app-webadmin" "https://github.com/immortalwrt/luci"
svn_export "master" "applications/luci-app-autoreboot" "feeds/luci/applications/luci-app-autoreboot" "https://github.com/immortalwrt/luci"
svn_export "master" "net/ddns-scripts_aliyun" "feeds/packages/net/ddns-scripts_aliyun" "https://github.com/immortalwrt/packages"
svn_export "master" "net/ddns-scripts_dnspod" "feeds/packages/net/ddns-scripts_dnspod" "https://github.com/immortalwrt/packages"
svn_export "master" "net/vlmcsd" "feeds/packages/net/vlmcsd" "https://github.com/immortalwrt/packages"
svn_export "master" "package/emortal" "package/emortal" "https://github.com/immortalwrt/immortalwrt"

# turboacc 补丁
git clone --depth=1 --single-branch --branch "package" https://github.com/chenmozhijin/turboacc "$TMPDIR/package" || exit 1
git clone --depth=1 --single-branch https://github.com/fullcone-nat-nftables/nft-fullcone "$TMPDIR/turboacc/nft-fullcone" || exit 1
git clone --depth=1 --single-branch https://github.com/chenmozhijin/turboacc "$TMPDIR/turboacc/turboacc" || exit 1
cp -r "$TMPDIR/turboacc/turboacc/luci-app-turboacc" "$TMPDIR/turboacc/luci-app-turboacc"
rm -rf "$TMPDIR/turboacc/turboacc"
cp -r "$TMPDIR/package/shortcut-fe" "$TMPDIR/turboacc/shortcut-fe"
cp -f "$TMPDIR/package/hack-6.1/952-add-net-conntrack-events-support-multiple-registrant.patch" "./target/linux/generic/hack-6.1/952-add-net-conntrack-events-support-multiple-registrant.patch"
cp -f "$TMPDIR/package/hack-6.1/953-net-patch-linux-kernel-to-support-shortcut-fe.patch" "./target/linux/generic/hack-6.1/953-net-patch-linux-kernel-to-support-shortcut-fe.patch"
cp -f "$TMPDIR/package/pending-6.1/613-netfilter_optional_tcp_window_check.patch" "./target/linux/generic/pending-6.1/613-netfilter_optional_tcp_window_check.patch"

if ! grep -q "CONFIG_NF_CONNTRACK_CHAIN_EVENTS" "./target/linux/generic/config-6.1" ; then
    echo "# CONFIG_NF_CONNTRACK_CHAIN_EVENTS is not set" >> "./target/linux/generic/config-6.1"
fi
if ! grep -q "CONFIG_SHORTCUT_FE" "./target/linux/generic/config-6.1" ; then
    echo "# CONFIG_SHORTCUT_FE is not set" >> "./target/linux/generic/config-6.1"
fi
cp -r "$TMPDIR/turboacc" "./package/turboacc"
rm -rf ./package/libs/libnftnl ./package/network/config/firewall4 ./package/network/utils/nftables
cp -RT "$TMPDIR/package/firewall4-$(grep -o 'FIREWALL4_VERSION=.*' "$TMPDIR/package/version" | cut -d '=' -f 2)/firewall4" ./package/network/config/firewall4
cp -RT "$TMPDIR/package/libnftnl-$(grep -o 'LIBNFTNL_VERSION=.*' "$TMPDIR/package/version" | cut -d '=' -f 2)/libnftnl" ./package/libs/libnftnl
cp -RT "$TMPDIR/package/nftables-$(grep -o 'NFTABLES_VERSION=.*' "$TMPDIR/package/version" | cut -d '=' -f 2)/nftables" ./package/network/utils/nftables

# 安装插件
./scripts/feeds update -l
./scripts/feeds install -a

# 调整菜单位置
sed -i "s|services|system|g" feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i "s|services|network|g" feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
# 个性化设置
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/MI-R3G/' package/base-files/files/bin/config_generate
# 汉化
cd package
curl -sfL -o ./convert_translation.sh https://github.com/kenzok8/small-package/raw/main/.github/diy/convert_translation.sh
chmod +x ./convert_translation.sh && bash ./convert_translation.sh
# 更新passwall规则
curl -sfL -o ./luci-app-passwall/root/usr/share/passwall/rules/gfwlist https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/gfw.txt

# AdguardHome核心
cd ./luci-app-adguardhome/root/usr
mkdir -p ./bin/AdGuardHome && cd ./bin/AdGuardHome
ADG_VER=$(curl -sfL https://api.github.com/repos/AdguardTeam/AdGuardHome/releases 2>/dev/null | grep 'tag_name' | egrep -o "v[0-9].+[0-9.]" | awk 'NR==1')
curl -sfL -o /tmp/AdGuardHome_linux.tar.gz https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADG_VER}/AdGuardHome_linux_mipsle_softfloat.tar.gz
tar -zxf /tmp/*.tar.gz -C /tmp/ && chmod +x /tmp/AdGuardHome/AdGuardHome
upx_latest_ver="$(curl -sfL https://api.github.com/repos/upx/upx/releases/latest 2>/dev/null | egrep 'tag_name' | egrep '[0-9.]+' -o 2>/dev/null)"
curl -sfL -o /tmp/upx-${upx_latest_ver}-amd64_linux.tar.xz "https://github.com/upx/upx/releases/download/v${upx_latest_ver}/upx-${upx_latest_ver}-amd64_linux.tar.xz"
xz -d -c /tmp/upx-${upx_latest_ver}-amd64_linux.tar.xz | tar -x -C "/tmp"
/tmp/upx-${upx_latest_ver}-amd64_linux/upx --ultra-brute /tmp/AdGuardHome/AdGuardHome > /dev/null 2>&1
mv /tmp/AdGuardHome/AdGuardHome ./ && rm -rf /tmp/AdGuardHome
