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
		return Promise.all([
			L.resolveDefault(uci.load('rotate_imei'), null),
			uci.load('glinet_privacy'),
			glpJson('imei_preview')
		]);
	},

	render: function (data) {
		var prev = data[2];
		var m = new form.Map('rotate_imei', _('IMEI rotation'));
		var s = m.section(form.NamedSection, 'main', _('Quectel / cellular'));
		s.option(form.Flag, 'enabled', _('Enable on boot'));
		s.option(form.Flag, 'cron_enabled', _('Cron rotation'));
		s.option(form.Value, 'cron_interval_hours', _('Cron interval (hours)'));
		s.option(form.Flag, 'cron_suppress_legal_log', _('Suppress legal notice in syslog'));
		s.option(form.Value, 'imei_tac', _('IMEI TAC (8 digits)'));
		s.option(form.Value, 'modem_tty', _('Modem TTY'));
		s.option(form.Value, 'wwan_if', _('WWAN interface'));

		return m.render().then(function (node) {
			var pre = E('div', { class: 'cbi-section' }, [
				E('h4', {}, [_('Detected hardware')]),
				E('p', {}, [_('Profile') + ': ' + String(prev.slug || '?')]),
				E('p', {}, [_('TTY candidates') + ': ' + String((prev.tty_scan || []).join(', ') || '—')]),
				E('p', {}, [_('Network interfaces') + ': ' + String((prev.iface_list || []).join(', ') || '—')])
			]);
			var btn = E('div', { class: 'cbi-section' }, [
				E('button', {
					class: 'btn cbi-button',
					click: ui.createHandlerFn(this, function () {
						return Promise.all([
							fs.exec('/etc/init.d/rotate_imei', ['enable']),
							fs.exec('/usr/libexec/glinet-privacy/apply-rotate-imei-cron.sh')
						]).then(function () {
							ui.addNotification(null, E('p', {}, [_('rotate_imei + cron updated.')]));
						});
					})
				}, [_('Apply cron / init')])
			]);
			return E('div', {}, [
				E('h2', {}, [_('IMEI rotation')]),
				E('p', { class: 'alert-message warning' }, [
					_('Legal risk on public networks — read docs/devices.md before enabling.')
				]),
				pre,
				node,
				btn
			]);
		});
	}
});
