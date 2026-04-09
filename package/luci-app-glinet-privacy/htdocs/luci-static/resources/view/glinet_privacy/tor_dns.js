'use strict';
'require view';
'require dom';
'require fs';
'require uci';
'require form';
'require ui';

function glpJson(sub) {
	return fs.exec('/usr/libexec/glinet-privacy/luci-json.sh', [sub]).then(function (r) {
		if (r.code !== 0)
			throw new Error(r.stderr || 'luci-json failed');
		return JSON.parse(r.stdout || '{}');
	});
}

return view.extend({
	load: function () {
		return Promise.all([uci.load('glinet_privacy'), glpJson('net_probe')]);
	},

	render: function (data) {
		var net = data[1];
		var m = new form.Map('glinet_privacy', _('Tor, DNS & telemetry'));

		var shw = m.section(form.NamedSection, 'hw', _('Device profile'));
		shw.option(form.Flag, 'auto_wan', _('Auto WAN detection'));

		var st = m.section(form.NamedSection, 'tor', _('Transparent Tor'));
		st.option(form.Flag, 'tor_transparent', _('Enable transparent Tor NAT'));
		st.option(form.Value, 'lan_cidr', _('LAN CIDR'));
		st.option(form.Value, 'router_lan_ip', _('Router LAN IP'));
		st.option(form.Value, 'lan_dev', _('LAN device override'));
		st.option(form.Value, 'tor_trans_port', _('Tor TransPort'));
		st.option(form.Value, 'tor_dns_port', _('Tor DNSPort'));

		var tel = m.section(form.NamedSection, 'tel', _('Telemetry'));
		tel.option(form.Flag, 'block_domains', _('Block telemetry DNS'));
		tel.option(form.Flag, 'disable_vendor_cloud', _('Disable vendor cloud'));
		tel.option(form.Flag, 'remove_cloud_packages', _('Remove cloud packages (opkg)'));

		var dns = m.section(form.NamedSection, 'dns', _('DNS policy'));
		var o = dns.option(form.ListValue, 'dns_policy', _('DNS policy'));
		o.value('default', _('Default (router)'));
		o.value('tor_dnsmasq', _('Forward to Tor (dnsmasq)'));
		dns.option(form.Flag, 'redirect_tcp_dns', _('Redirect TCP/53 to Tor'));
		dns.option(form.Flag, 'block_lan_dot', _('Block LAN DoT (TCP/853)'));

		return m.render().then(function (node) {
			var hint = net ? (_('Profile') + ': ' + (net.slug || '?')) : '';
			var btn = E('div', { class: 'cbi-section' }, [
				E('button', {
					class: 'btn cbi-button-positive',
					click: ui.createHandlerFn(this, function () {
						return Promise.all([
							fs.exec('/usr/libexec/glinet-privacy/apply-dns-policy.sh'),
							fs.exec('/etc/init.d/firewall', ['reload']),
							fs.exec('/usr/libexec/glinet-privacy/apply-telemetry.sh'),
							fs.exec('/etc/init.d/dnsmasq', ['restart'])
						]).then(function () {
							ui.addNotification(null, E('p', {}, [_('DNS / firewall / telemetry applied.')]));
						});
					})
				}, [_('Apply DNS + firewall + telemetry')])
			]);
			return E('div', {}, [E('h2', {}, [_('Tor, DNS & telemetry')]), E('p', {}, [hint]), node, btn]);
		});
	}
});
