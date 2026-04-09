'use strict';
'require view';
'require dom';
'require fs';
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
		return glpJson('net_probe');
	},

	render: function (net) {
		var out = E('div', {}, [
			E('h2', {}, [_('Verify')]),
			E('p', {}, [_('Browser checks use external sites from this device. Router check uses api.ipify.org from the router.')])
		]);
		if (net && net.router_lan_ip) {
			out.appendChild(E('p', {}, [_('Router LAN'), ': ', E('code', {}, [String(net.router_lan_ip)])]));
		}

		var res = E('pre', { id: 'glp-vfy-out', style: 'padding:10px;background:#f5f5f5' });
		res.textContent = '—';
		var btnR = E('button', {
			class: 'btn cbi-button',
			click: ui.createHandlerFn(this, function () {
				return glpJson('verify_ip').then(function (j) {
					res.textContent = JSON.stringify(j, null, 2);
				}).catch(function (e) {
					res.textContent = String(e);
				});
			})
		}, [_('Router WAN IP (ipify)')]);

		var btnB = E('button', {
			class: 'btn cbi-button',
			click: ui.createHandlerFn(this, function () {
				return fetch('https://api.ipify.org?format=json')
					.then(function (r) { return r.json(); })
					.then(function (j) {
						res.textContent = 'browser: ' + JSON.stringify(j);
					})
					.catch(function (e) {
						res.textContent = 'browser fetch failed: ' + e;
					});
			})
		}, [_('This browser public IP (ipify)')]);

		out.appendChild(E('div', { class: 'cbi-section' }, [btnR, ' ', btnB, res]));
		return out;
	}
});
