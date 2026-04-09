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
		return Promise.all([uci.load('privacy'), glpJson('net_probe')]);
	},

	render: function (data) {
		var net = data[1];
		var m = new form.Map('privacy', _('Kill switch'));
		var s = m.section(form.NamedSection, 'main', _('Watchdog settings'));
		s.option(form.Flag, 'enabled', _('Kill switch watchdog enabled'));
		s.option(form.Value, 'wg_if', _('WireGuard interface name'));
		s.option(form.Flag, 'require_wg', _('Require WireGuard'));
		s.option(form.Flag, 'require_tor', _('Require Tor'));
		s.option(form.Value, 'lan_dev', _('LAN device (optional)'));
		s.option(form.Value, 'wan_dev', _('WAN device (optional)'));
		var o = s.option(form.ListValue, 'vendor_gl_vpn_killswitch', _('GL.iNet VPN kill switch sync'));
		o.value('leave', _('Leave (do not change)'));
		o.value('on', _('On'));
		o.value('off', _('Off'));

		return m.render().then(function (node) {
			var hint = '';
			if (net && net.watchdog_lan)
				hint = _('Watchdog LAN') + ': ' + net.watchdog_lan + ' · ' + _('WAN') + ': ' + (net.watchdog_wan || '—');
			var btn = E('div', { class: 'cbi-section' }, [
				E('button', {
					class: 'btn cbi-button',
					click: ui.createHandlerFn(this, function () {
						return Promise.all([
							fs.exec('/usr/libexec/glinet-privacy/apply-vendor-vpn-killswitch.sh'),
							fs.exec('/usr/bin/privacy-killswitch-watchdog.sh'),
							fs.exec('/etc/init.d/firewall', ['reload'])
						]).then(function () {
							ui.addNotification(null, E('p', {}, [_('Vendor VPN + watchdog + firewall reload done.')]));
						});
					})
				}, [_('Apply vendor VPN + watchdog')])
			]);
			return E('div', {}, [E('h2', {}, [_('Kill switch')]), E('p', {}, [hint]), node, btn]);
		});
	}
});
