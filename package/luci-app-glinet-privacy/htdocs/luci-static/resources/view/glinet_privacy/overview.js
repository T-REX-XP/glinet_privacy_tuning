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
			throw new Error((r.stderr || '') + ' (exit ' + r.code + ')');
		return JSON.parse(r.stdout || '{}');
	});
}

function badge(state) {
	var cls = 'label default';
	if (state == 'ok') cls = 'label success';
	else if (state == 'bad') cls = 'label danger';
	else if (state == 'warn') cls = 'label warning';
	else if (state == 'skip') cls = 'label info';
	return E('span', { 'class': cls }, [state]);
}

function row(it) {
	return E('div', { class: 'glp-comp-row', style: 'display:flex;gap:10px;align-items:center;padding:10px 0;border-bottom:1px solid #eee' }, [
		E('div', { style: 'flex:0 0 5rem' }, [badge(it.state)]),
		E('div', { style: 'flex:1' }, [
			E('div', { style: 'font-weight:600' }, [it.label || '']),
			E('div', { style: 'font-size:0.88rem;color:#666' }, [it.detail || ''])
		])
	]);
}

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('privacy'),
			uci.load('glinet_privacy'),
			L.resolveDefault(uci.load('rotate_imei'), null),
			glpJson('overview'),
			glpJson('net_probe'),
			glpJson('privacy_log'),
			glpJson('vendor_ubus')
		]);
	},

	render: function (data) {
		var st = data[3];
		var net = data[4];
		var pl = data[5];
		var vu = data[6];

		var pct = st.pct || 0;
		if (pct > 100) pct = 100;
		var pclass = 'progress-bar-success';
		if (pct < 50) pclass = 'progress-bar-danger';
		else if (pct < 100) pclass = 'progress-bar-warning';

		var rows = [];
		if (st.items)
			for (var i = 0; i < st.items.length; i++)
				rows.push(row(st.items[i]));

		var logHint = E('p', { class: 'cbi-section', style: 'padding:8px;background:#f7f9fc' });
		if (pl && !pl.empty) {
			logHint.appendChild(E('span', { class: 'label label-info', style: 'margin-right:6px' }, [_('syslog')]));
			logHint.appendChild(E('strong', {}, [_('Last line')]));
			logHint.appendChild(document.createTextNode(': '));
			logHint.appendChild(E('code', { title: pl.tooltip_title || '' }, [pl.last_line || '']));
			logHint.appendChild(document.createTextNode(' '));
			logHint.appendChild(E('a', { href: L.url('admin/status/logs') }, [_('Full system log')]));
		} else {
			logHint.appendChild(document.createTextNode(_('No recent matching log lines. ')));
			logHint.appendChild(E('a', { href: L.url('admin/status/logs') }, [_('System log')]));
		}

		var live = null;
		if (net && (net.lan_device_effective || '')) {
			live = E('p', {}, [
				E('span', { class: 'label label-default', style: 'margin-right:6px' }, [_('Live path')]),
				_('LAN'), ': ', E('code', {}, [String(net.lan_device_effective || '')]),
				' → ', _('WAN'), ': ', E('code', {}, [String(net.wan_device_effective || '—')]),
				net.router_lan_ip ? [' · ', _('GW'), ': ', E('code', {}, [String(net.router_lan_ip)])] : ''
			]);
		}

		var mapP = new form.Map('privacy', _('Kill switch & requirements'));
		var sP = mapP.section(form.NamedSection, 'main', _('Kill switch & requirements'));
		sP.option(form.Flag, 'enabled', _('Kill switch watchdog enabled'));
		sP.option(form.Flag, 'require_wg', _('Require WireGuard'));
		sP.option(form.Flag, 'require_tor', _('Require Tor'));

		var mapG = new form.Map('glinet_privacy', _('Tor / telemetry'));
		var sT = mapG.section(form.NamedSection, 'tor', _('Tor NAT'));
		sT.option(form.Flag, 'tor_transparent', _('Transparent Tor (NAT)'));
		var sTel = mapG.section(form.NamedSection, 'tel', _('Telemetry'));
		sTel.option(form.Flag, 'block_domains', _('DNS blocklist (telemetry hosts)'));
		sTel.option(form.Flag, 'disable_vendor_cloud', _('Disable vendor cloud (UCI)'));
		sTel.option(form.Flag, 'remove_cloud_packages', _('Remove cloud packages (opkg; risky)'));

		var hasRi = (uci.get('rotate_imei', 'main') != null);
		var mapR = null;
		if (hasRi) {
			mapR = new form.Map('rotate_imei', _('IMEI rotation'));
			var sR = mapR.section(form.NamedSection, 'main', _('Rotation'));
			sR.option(form.Flag, 'enabled', _('Enable IMEI rotation on boot'));
		}

		var self = this;
		var applyBtn = E('div', { class: 'cbi-section' }, [
			E('h4', {}, [_('Apply helper scripts')]),
			E('p', {}, [_('After saving the forms below, click here to reload firewall, run the watchdog, and re-apply telemetry/DNS.')]),
			E('button', {
				class: 'btn cbi-button cbi-button-positive',
				click: ui.createHandlerFn(self, function () {
					return Promise.all([
						fs.exec('/usr/bin/privacy-killswitch-watchdog.sh'),
						fs.exec('/usr/libexec/glinet-privacy/apply-telemetry.sh'),
						fs.exec('/etc/init.d/firewall', ['reload']),
						fs.exec('/etc/init.d/dnsmasq', ['restart'])
					]).then(function () {
						ui.addNotification(null, E('p', {}, [_('Helper scripts executed.')]));
					}).catch(function (e) {
						ui.addNotification(null, E('p', {}, [_('Error: '), String(e)]));
					});
				})
			}, [_('Run apply scripts')])
		]);

		var vuBlock = null;
		if (vu && vu.active) {
			vuBlock = E('div', { class: 'cbi-section' }, [
				E('h4', {}, [_('Vendor ubus (read-only)')]),
				E('pre', { style: 'max-height:12rem;overflow:auto;white-space:pre-wrap' }, [
					JSON.stringify(vu.probes || [], null, 2)
				])
			]);
		}

		var head = E('div', {}, [
			E('h2', {}, [_('GL.iNet Privacy — overview')]),
			E('p', {}, [_('Component status (read-only). Edit toggles in the forms below, save each form, then run apply scripts.')]),
			logHint,
			live,
			E('div', { class: 'cbi-section' }, [
				E('div', { class: 'progress' }, [
					E('div', {
						class: 'progress-bar ' + pclass,
						style: 'width:' + pct + '%'
					}, [pct + '%'])
				]),
				E('p', {}, [
					_('OK'), ': ', String(st.ok_c || 0), ' · ',
					_('Problems'), ': ', String(st.problem_c || 0), ' · ',
					_('Skipped'), ': ', String(st.skip_c || 0)
				])
			]),
			E('div', {}, rows)
		]);

		var promises = [mapP.render(), mapG.render()];
		if (mapR) promises.push(mapR.render());
		return Promise.all(promises).then(function (parts) {
			var out = [head, E('hr')];
			for (var j = 0; j < parts.length; j++)
				out.push(parts[j]);
			out.push(applyBtn);
			if (vuBlock) out.push(vuBlock);
			return E('div', { class: 'cbi-map' }, out);
		});
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
