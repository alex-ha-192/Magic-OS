// SPDX-License-Identifier: GPL-3.0-or-later
// Magic installer UI. Talks to server.py on the same origin.
'use strict';

const STEPS = ['get online', 'where you are', 'about you', 'how to install', 'protect your files', 'your software', 'ready'];
const GB = 1024 ** 3;

const ACCENTS = {
  ember:   { ac: '#c2410c', at: '#ff8a4c', wp: '#4b2412', hover: '#a8370a' },
  magenta: { ac: '#c4125f', at: '#ff5fa2', wp: '#4a1236', hover: '#a30f4f' },
  teal:    { ac: '#0f766e', at: '#5eead4', wp: '#0c3b3a', hover: '#0c5f59' },
  blue:    { ac: '#1d5fc4', at: '#7db3ff', wp: '#10305f', hover: '#174ea2' },
  violet:  { ac: '#6d3fc0', at: '#b79cff', wp: '#2d1a58', hover: '#5a33a0' },
  green:   { ac: '#15803d', at: '#6ee7a1', wp: '#123d22', hover: '#116a33' },
};

// [locale, name, keyboard layout, keyboard variant, time zone, clock]
const LANGS = [
  ['en_GB.UTF-8', 'English (United Kingdom)', 'gb', '', 'Europe/London', '24'],
  ['en_US.UTF-8', 'English (United States)', 'us', '', 'America/New_York', '12'],
  ['en_IE.UTF-8', 'English (Ireland)', 'ie', '', 'Europe/Dublin', '24'],
  ['en_CA.UTF-8', 'English (Canada)', 'us', '', 'America/Toronto', '12'],
  ['en_AU.UTF-8', 'English (Australia)', 'us', '', 'Australia/Sydney', '12'],
  ['en_NZ.UTF-8', 'English (New Zealand)', 'us', '', 'Pacific/Auckland', '12'],
  ['de_DE.UTF-8', 'Deutsch (Deutschland)', 'de', '', 'Europe/Berlin', '24'],
  ['de_AT.UTF-8', 'Deutsch (Österreich)', 'at', '', 'Europe/Vienna', '24'],
  ['de_CH.UTF-8', 'Deutsch (Schweiz)', 'ch', '', 'Europe/Zurich', '24'],
  ['fr_FR.UTF-8', 'Français (France)', 'fr', '', 'Europe/Paris', '24'],
  ['fr_BE.UTF-8', 'Français (Belgique)', 'be', '', 'Europe/Brussels', '24'],
  ['fr_CA.UTF-8', 'Français (Canada)', 'ca', '', 'America/Montreal', '24'],
  ['es_ES.UTF-8', 'Español (España)', 'es', '', 'Europe/Madrid', '24'],
  ['es_MX.UTF-8', 'Español (México)', 'latam', '', 'America/Mexico_City', '12'],
  ['it_IT.UTF-8', 'Italiano', 'it', '', 'Europe/Rome', '24'],
  ['nl_NL.UTF-8', 'Nederlands', 'us', 'euro', 'Europe/Amsterdam', '24'],
  ['pt_PT.UTF-8', 'Português (Portugal)', 'pt', '', 'Europe/Lisbon', '24'],
  ['pt_BR.UTF-8', 'Português (Brasil)', 'br', '', 'America/Sao_Paulo', '24'],
  ['pl_PL.UTF-8', 'Polski', 'pl', '', 'Europe/Warsaw', '24'],
  ['sv_SE.UTF-8', 'Svenska', 'se', '', 'Europe/Stockholm', '24'],
  ['da_DK.UTF-8', 'Dansk', 'dk', '', 'Europe/Copenhagen', '24'],
  ['nb_NO.UTF-8', 'Norsk bokmål', 'no', '', 'Europe/Oslo', '24'],
  ['fi_FI.UTF-8', 'Suomi', 'fi', '', 'Europe/Helsinki', '24'],
  ['cs_CZ.UTF-8', 'Čeština', 'cz', '', 'Europe/Prague', '24'],
  ['el_GR.UTF-8', 'Ελληνικά', 'gr', '', 'Europe/Athens', '24'],
  ['tr_TR.UTF-8', 'Türkçe', 'tr', '', 'Europe/Istanbul', '24'],
  ['uk_UA.UTF-8', 'Українська', 'ua', '', 'Europe/Kyiv', '24'],
  ['ja_JP.UTF-8', '日本語', 'jp', '', 'Asia/Tokyo', '24'],
  ['ko_KR.UTF-8', '한국어', 'kr', '', 'Asia/Seoul', '12'],
  ['zh_CN.UTF-8', '中文（简体）', 'cn', '', 'Asia/Shanghai', '24'],
  ['zh_TW.UTF-8', '中文（繁體）', 'tw', '', 'Asia/Taipei', '12'],
];
const KEYBOARDS = [
  ['gb', '', 'English (UK)'], ['us', '', 'English (US)'], ['us', 'intl', 'English (US, international)'],
  ['ie', '', 'English (Ireland)'], ['de', '', 'German'], ['at', '', 'German (Austria)'], ['ch', '', 'German (Switzerland)'],
  ['ch', 'fr', 'French (Switzerland)'], ['fr', '', 'French'], ['be', '', 'Belgian'], ['ca', '', 'French (Canada)'],
  ['es', '', 'Spanish'], ['latam', '', 'Spanish (Latin America)'], ['it', '', 'Italian'], ['us', 'euro', 'Dutch (US layout with €)'],
  ['pt', '', 'Portuguese'], ['br', '', 'Portuguese (Brazil)'], ['pl', '', 'Polish'], ['se', '', 'Swedish'], ['dk', '', 'Danish'],
  ['no', '', 'Norwegian'], ['fi', '', 'Finnish'], ['cz', '', 'Czech'], ['gr', '', 'Greek'], ['tr', '', 'Turkish'],
  ['ua', '', 'Ukrainian'], ['jp', '', 'Japanese'], ['kr', '', 'Korean'], ['cn', '', 'Chinese'], ['tw', '', 'Taiwanese'],
];
const BROWSERS = [['vivaldi', 'Vivaldi', 'Looks and feels like Chrome · simple layout by default'], ['firefox', 'Firefox', 'Not Chrome-like · its own engine, very private']];
const OFFICES = [['libreoffice', 'LibreOffice', 'Opens Word, Excel and PowerPoint files'], ['onlyoffice', 'ONLYOFFICE', 'Looks the most like Microsoft Office'], ['none', 'None', 'I use Google Docs or Office online']];
const EMAILS = [['thunderbird', 'Thunderbird', 'Works with Gmail, Outlook and more'], ['kmail', 'KMail', 'Part of Plasma, matches Magic'], ['none', 'None', 'I use webmail in my browser']];
const EXTRAS = [['vlc', 'VLC media player'], ['zotero', 'Zotero'], ['zoom', 'Zoom'], ['spotify', 'Spotify'], ['signal', 'Signal'], ['discord', 'Discord'], ['bitwarden', 'Bitwarden passwords'], ['steam', 'Steam'], ['gimp', 'GIMP photo editor'], ['kdenlive', 'Kdenlive video editor'], ['audacity', 'Audacity'], ['obs', 'OBS Studio'], ['calibre', 'Calibre e-books']];
const RECOMMENDED = [['internet', 'Vivaldi'], ['documents, spreadsheets, slides', 'LibreOffice'], ['email', 'Thunderbird'], ['photos', 'Gwenview'], ['pdf files', 'Okular'], ['music & video', 'VLC']];

// ------------------------------------------------------------------ state
const DEFAULTS = {
  step: 0, locale: 'en_GB.UTF-8', kb_layout: 'gb', kb_variant: '', clock: '24', timezone: 'Europe/London', tz_query: '',
  tz_touched: false, full_name: '', computer_name: '', cn_touched: false, password: '', password2: '', username: '',
  more: false, accent: 'ember', disk: '', mode: '', magic_size_gb: 0, erase_ok: false, encrypt: true, unlock: 'tpm',
  startup_password: '', startup_password2: '', rk_saved: false, software: 'recommended', choosing: false,
  browser: 'vivaldi', office: 'libreoffice', email: 'thunderbird', extras: { vlc: true },
};
let S = Object.assign({}, DEFAULTS);
try { Object.assign(S, JSON.parse(localStorage.getItem('magic-installer') || '{}')); } catch (e) { /* fresh start */ }
const save = () => { try { const c = Object.assign({}, S); delete c.password; delete c.password2; delete c.startup_password; delete c.startup_password2; localStorage.setItem('magic-installer', JSON.stringify(c)); } catch (e) {} };
// Passwords are kept in memory only, except across the keyboard restart (session storage).
try { const p = JSON.parse(sessionStorage.getItem('magic-pw') || '{}'); Object.assign(S, p); sessionStorage.removeItem('magic-pw'); } catch (e) {}

// Design preview (used to check the screens): #preview=<step> fills in sample answers.
const PREVIEW = /preview=(\w+)/.exec(location.hash);
if (PREVIEW) {
  S = Object.assign({}, DEFAULTS, { full_name: 'Alex Morgan', computer_name: "Alex's laptop", cn_touched: true, password: 'dragonfruit-lamp-42', password2: 'dragonfruit-lamp-42', disk: '/dev/nvme0n1', mode: 'alongside', magic_size_gb: 120, timezone: 'Europe/London' });
  if (/^\d+$/.test(PREVIEW[1])) S.step = +PREVIEW[1];
}
let ST = { net: { online: false }, tpm: false, secure_boot: false, recovery_key: '', install: {} };
let DISKS = null, ZONES = [], WIFI = null, WIFI_SEL = null, WIFI_MSG = '', BUSY = false, PHASE = 'steps', PROG = null;

const $ = (s) => document.querySelector(s);
const esc = (t) => String(t == null ? '' : t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const api = async (path, body) => {
  const r = await fetch(path, body === undefined ? {} : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  return r.json();
};
const set = (patch, rerender = true) => { Object.assign(S, patch); save(); if (rerender) render(); };
const gb = (b) => Math.round(b / GB);

function applyAccent() {
  const a = ACCENTS[S.accent] || ACCENTS.ember, r = document.documentElement.style;
  r.setProperty('--ac', a.ac); r.setProperty('--at', a.at); r.setProperty('--wp', a.wp); r.setProperty('--ac-hover', a.hover);
}

// ------------------------------------------------------------------ data
async function refreshStatus() { try { ST = await api('/api/status'); } catch (e) {} }
async function loadDisks(force) { try { DISKS = await api('/api/disks' + (force ? '?force' : '')); } catch (e) { DISKS = []; } }
async function scanWifi() { WIFI = null; render(); try { WIFI = await api('/api/wifi'); } catch (e) { WIFI = []; } render(); }

function canTpm() { return ST.tpm && ST.secure_boot; }
function curDisk() { return (DISKS || []).find((d) => d.path === S.disk); }
function langOf(loc) { return LANGS.find((l) => l[0] === loc) || LANGS[0]; }
function kbName() { const k = KEYBOARDS.find((k) => k[0] === S.kb_layout && k[1] === S.kb_variant); return k ? k[2] : S.kb_layout; }
function zone() { return ZONES.find((z) => z.tz === S.timezone) || { tz: S.timezone, city: S.timezone.split('/').pop().replace(/_/g, ' '), country: '' }; }
function utcOffset(tz) {
  try {
    const p = new Intl.DateTimeFormat('en-GB', { timeZone: tz, timeZoneName: 'shortOffset' }).formatToParts(new Date());
    return (p.find((x) => x.type === 'timeZoneName') || {}).value.replace('GMT', 'UTC') || 'UTC';
  } catch (e) { return ''; }
}
function offsetHours(tz) { const m = /UTC([+-−]\d+)?(?::(\d+))?/.exec(utcOffset(tz)); if (!m || !m[1]) return 0; return parseInt(m[1].replace('−', '-'), 10); }
function timeIn(tz) {
  try {
    const d = new Date();
    const t = d.toLocaleTimeString('en-GB', { timeZone: tz, hour: S.clock === '12' ? 'numeric' : '2-digit', minute: '2-digit', hour12: S.clock === '12' });
    const day = d.toLocaleDateString('en-GB', { timeZone: tz, weekday: 'long', day: 'numeric', month: 'long' });
    return `${t} on ${day}`;
  } catch (e) { return ''; }
}
function strength(pw) {
  let s = 0; if (pw.length >= 8) s++; if (pw.length >= 12) s++; if (/[0-9]/.test(pw) && /[a-zA-Z]/.test(pw)) s++; if (/[^a-zA-Z0-9]/.test(pw) || pw.length >= 16) s++;
  return [s, ['too short', 'weak', 'okay', 'good', 'strong'][s]];
}
function defaultUser(name) { const b = (name || '').trim().split(' ')[0].toLowerCase().replace(/[^a-z0-9]/g, ''); return b ? (/^[a-z]/.test(b) ? b : 'u' + b) : ''; }

// ------------------------------------------------------------------ validity
function stepOk(i) {
  switch (i) {
    case 0: return !!(ST.net && ST.net.online);
    case 1: return !!S.timezone && !!S.locale;
    case 2: return S.full_name.trim().length > 0 && S.password.length >= 1 && S.password === S.password2 && (!S.username || /^[a-z_][a-z0-9_-]{0,30}$/.test(S.username));
    case 3: {
      const d = curDisk(); if (!d || !S.mode) return false;
      if (S.mode === 'erase') return S.erase_ok;
      if (S.mode === 'alongside') return S.magic_size_gb >= 40 && S.magic_size_gb <= d.alongside_max_gb && !d.bitlocker && !d.hibernated;
      return true;
    }
    case 4: {
      if (!S.encrypt) return true;
      if (S.rk_saved !== ST.recovery_key) return false;
      if (S.unlock === 'tpm') return canTpm();
      return S.startup_password.length >= 4 && S.startup_password === S.startup_password2;
    }
    case 5: return true;
    default: return true;
  }
}
function blockedHint(i) {
  switch (i) {
    case 0: return 'Connect to the internet to continue';
    case 2: return S.password && S.password !== S.password2 ? "The passwords don't match" : 'Type your name and a password';
    case 3: return S.mode === 'erase' && !S.erase_ok ? 'Tick the box to confirm' : 'Choose where Magic goes';
    case 4: return S.rk_saved !== ST.recovery_key && S.encrypt ? "Confirm you've saved your recovery key to continue" : 'Choose a start-up password';
    default: return '';
  }
}

// ------------------------------------------------------------------ shell
function renderSide() {
  const cur = PHASE === 'steps' ? S.step : STEPS.length;
  $('#steps').innerHTML = STEPS.map((name, i) => {
    const cls = i < cur ? 'done' : i === cur ? 'cur' : '';
    return `<li class="${cls}"><span class="n">${i < cur ? '✓' : i + 1}</span>${esc(name)}</li>`;
  }).join('');
  $('#sidefoot').textContent = 'Nothing changes on your computer until you press install.';
}

function bar(back, next) { $('#bar').innerHTML = `<div>${back || ''}</div><div class="right">${next || ''}</div>`; }
function stdBar() {
  const i = S.step, ok = stepOk(i);
  const back = i > 0 ? '<button class="ghost" onclick="go(-1)">back</button>' : '';
  const hint = ok ? '' : `<span class="hint">${esc(blockedHint(i))}</span>`;
  const next = i === STEPS.length - 1
    ? `<span class="hint">You can still go back until you press install</span><button class="pri big" onclick="startInstall()">install magic</button>`
    : `${hint}<button class="pri" ${ok ? '' : 'disabled'} onclick="go(1)">next</button>`;
  bar(back, next);
}
window.go = (d) => {
  if (d > 0 && !stepOk(S.step)) return;
  S.choosing = false;
  set({ step: Math.max(0, Math.min(STEPS.length - 1, S.step + d)) });
  enterStep();
};
window.jump = (i) => { set({ step: i }); enterStep(); };

function enterStep() {
  if (S.step === 0) { refreshStatus().then(() => { render(); if (!ST.net.online && WIFI === null) scanWifi(); }); }
  if (S.step === 3 && DISKS === null) loadDisks().then(() => { autoPickDisk(); render(); });
  if (S.step === 4) refreshStatus().then(() => { if (!canTpm() && S.unlock === 'tpm') S.unlock = 'password'; render(); });
}

function render() {
  applyAccent();
  renderSide();
  const body = $('#body');
  if (PHASE === 'installing') return renderInstalling(body);
  if (PHASE === 'done') return renderDone(body);
  if (PHASE === 'error') return renderError(body);
  [vOnline, vWhere, vAbout, vHow, vProtect, vSoftware, vReady][S.step](body);
  stdBar();
}

// ------------------------------------------------------------------ 0 online
function vOnline(el) {
  const n = ST.net || {};
  let main;
  if (n.online) {
    main = `<section class="panel" style="max-width:640px"><h2 class="ac">you're online</h2>
      <p class="s" style="margin:0">${n.wired ? 'Connected with a cable.' : n.wifi ? `Connected to <b>${esc(n.wifi)}</b>.` : 'Connected.'} Magic will download the newest version while it installs.</p></section>`;
  } else if (n.has_wifi === false && WIFI && !WIFI.length) {
    main = `<section class="panel" style="max-width:640px"><h2>plug in a network cable</h2><p class="s" style="margin:0">No Wi-Fi was found on this computer. Connect a network cable, then press check again.</p><div><button class="sm" onclick="recheck()">check again</button></div></section>`;
  } else {
    const nets = WIFI === null ? '<div class="hint"><span class="spin"></span>&nbsp; looking for Wi-Fi networks…</div>'
      : WIFI.length ? WIFI.map((w, i) => {
        const on = WIFI_SEL === i;
        const bars = w.signal > 70 ? 'strong' : w.signal > 40 ? 'good' : 'weak';
        return `<button class="opt ${on ? 'on' : ''}" onclick="pickWifi(${i})"><span>${esc(w.ssid)}</span><span class="meta">${w.secure ? '🔒 ' : ''}${bars} signal</span></button>`;
      }).join('') : '<div class="hint">No networks found.</div>';
    let form = '';
    if (WIFI_SEL !== null && WIFI && WIFI[WIFI_SEL]) {
      const w = WIFI[WIFI_SEL];
      form = `<section class="panel"><h2>${esc(w.ssid)}</h2>
        ${w.secure ? '<label class="lbl">Wi-Fi password<input class="fld" id="wpw" type="password" autocomplete="off"></label>' : '<p class="note">This network is open.</p>'}
        <div style="display:flex;gap:12px;align-items:center"><button class="pri" onclick="joinWifi()" ${BUSY ? 'disabled' : ''}>${BUSY ? 'connecting…' : 'connect'}</button><span class="err">${esc(WIFI_MSG)}</span></div></section>`;
    }
    main = `<div class="row"><section class="panel" style="flex:1;min-width:0"><div style="display:flex;justify-content:space-between;align-items:center"><h2>choose your wi-fi</h2><button class="sm" onclick="scanWifi()">look again</button></div><div class="list">${nets}</div></section>
      <div class="col" style="width:420px;flex:none">${form || '<section class="panel"><p class="note" style="margin:0">Pick your network on the left. Using a cable? Plug it in and press check again.</p><div><button class="sm" onclick="recheck()">check again</button></div></section>'}</div></div>`;
  }
  el.innerHTML = `<div><h1 class="t">get online</h1><p class="s">Magic installs the newest version straight from the internet, so it needs a connection for a few minutes.</p></div>${main}`;
  const pw = $('#wpw'); if (pw) { pw.focus(); pw.onkeydown = (e) => { if (e.key === 'Enter') joinWifi(); }; }
}
window.recheck = async () => { await refreshStatus(); render(); };
window.pickWifi = (i) => { WIFI_SEL = i; WIFI_MSG = ''; render(); };
window.joinWifi = async () => {
  const w = WIFI[WIFI_SEL], pw = $('#wpw') ? $('#wpw').value : '';
  BUSY = true; WIFI_MSG = ''; render();
  const r = await api('/api/wifi', { ssid: w.ssid, password: pw });
  BUSY = false; WIFI_MSG = r.ok ? '' : r.message;
  await refreshStatus();
  if (r.ok && !ST.net.online) { await new Promise((res) => setTimeout(res, 3000)); await refreshStatus(); }
  render();
};

// ------------------------------------------------------------------ 1 where
function vWhere(el) {
  const q = (S.tz_query || '').trim().toLowerCase();
  const matches = (q ? ZONES.filter((z) => z.city.toLowerCase().includes(q) || z.country.toLowerCase().includes(q) || z.tz.toLowerCase().includes(q)) : [zone()]).slice(0, 6);
  const off = offsetHours(S.timezone);
  const bands = Array.from({ length: 25 }, (_, i) => `<span class="${i - 12 === off ? 'on' : ''}"></span>`).join('');
  el.innerHTML = `<div><h1 class="t">where are you?</h1><p class="s">This sets the clock, your language and your keyboard. Change anything that's wrong.</p></div>
  <div class="row">
    <section class="panel" style="width:430px;flex:none">
      <label class="lbl">Language<select class="sel" id="lang">${LANGS.map((l) => `<option value="${l[0]}" ${l[0] === S.locale ? 'selected' : ''}>${esc(l[1])}</option>`).join('')}</select></label>
      <label class="lbl">Keyboard<select class="sel" id="kb">${KEYBOARDS.map((k, i) => `<option value="${i}" ${k[0] === S.kb_layout && k[1] === S.kb_variant ? 'selected' : ''}>${esc(k[2])}</option>`).join('')}</select></label>
      <label class="lbl">Try your keyboard<input class="fld" type="text" placeholder="type here: £ @ &quot; # ~ € ü é"></label>
      <fieldset style="border:0;margin:6px 0 0;padding:0;display:flex;flex-direction:column;gap:8px"><legend style="padding:0 0 6px;font-size:14px;color:#d8d2ce">Clock</legend>
        <label class="chk"><input type="radio" name="clk" value="12" ${S.clock === '12' ? 'checked' : ''}>12-hour <span class="hint">(2:32 PM)</span></label>
        <label class="chk"><input type="radio" name="clk" value="24" ${S.clock === '24' ? 'checked' : ''}>24-hour <span class="hint">(14:32)</span></label></fieldset>
    </section>
    <section class="panel" style="flex:1;min-width:0">
      <label class="lbl">Time zone, by nearest city<input class="fld" id="tzq" type="text" value="${esc(S.tz_query || zone().city)}" autocomplete="off"></label>
      <div class="list" role="listbox">${matches.map((z) => `<button class="opt ${z.tz === S.timezone ? 'on' : ''}" onclick="pickTz('${esc(z.tz)}')"><span>${esc(z.city)}${z.country ? ', ' + esc(z.country) : ''}</span><span class="meta">${esc(utcOffset(z.tz))}</span></button>`).join('') || '<div class="hint">No match. Try a bigger city nearby.</div>'}</div>
      <div class="bands" aria-hidden="true">${bands}</div>
      <p style="margin:0;font-size:16px;font-weight:300;color:#e2dcd8;line-height:24px">It's <b style="font-weight:600;color:#fff">${esc(timeIn(S.timezone))}</b> in ${esc(zone().city)}.</p>
    </section>
  </div>`;
  $('#lang').onchange = (e) => {
    const l = langOf(e.target.value), patch = { locale: l[0], clock: l[5] };
    if (l[2] !== S.kb_layout || l[3] !== S.kb_variant) { patch.kb_layout = l[2]; patch.kb_variant = l[3]; setKeyboard(l[2], l[3]); }
    if (!S.tz_touched) { patch.timezone = l[4]; patch.tz_query = ''; }
    set(patch);
  };
  $('#kb').onchange = (e) => { const k = KEYBOARDS[+e.target.value]; set({ kb_layout: k[0], kb_variant: k[1] }, false); setKeyboard(k[0], k[1]); };
  document.querySelectorAll('input[name=clk]').forEach((r) => (r.onchange = () => set({ clock: r.value })));
  const tzq = $('#tzq');
  tzq.oninput = () => { S.tz_query = tzq.value; save(); const pos = tzq.selectionStart; render(); const n = $('#tzq'); n.focus(); n.setSelectionRange(pos, pos); };
}
window.pickTz = (tz) => set({ timezone: tz, tz_touched: true, tz_query: '' });
async function setKeyboard(layout, variant) {
  // The screen restarts with the new layout; keep passwords for this one restart.
  try { sessionStorage.setItem('magic-pw', JSON.stringify({ password: S.password, password2: S.password2, startup_password: S.startup_password, startup_password2: S.startup_password2 })); } catch (e) {}
  save();
  await api('/api/keyboard', { layout, variant });
}

// ------------------------------------------------------------------ 2 about
function vAbout(el) {
  const [sv, sl] = strength(S.password);
  const first = (S.full_name.trim() || 'you').split(' ')[0];
  const cn = S.cn_touched ? S.computer_name : (S.full_name.trim() ? `${first}'s computer` : '');
  if (!S.cn_touched) S.computer_name = cn;
  const mismatch = S.password2 && S.password !== S.password2;
  el.innerHTML = `<div><h1 class="t">about you</h1><p class="s">This is how you'll sign in. Magic keeps your files private to you.</p></div>
  <div class="row">
    <section class="panel" style="flex:1;min-width:0">
      <label class="lbl">Your name<input class="fld" id="nm" type="text" value="${esc(S.full_name)}" autocomplete="off"></label>
      <label class="lbl">Name of this computer<input class="fld" id="cn" type="text" value="${esc(cn)}"><span class="note">Other devices on your home network will see this name.</span></label>
      <label class="lbl">Sign-in password<input class="fld" id="pw" type="password" value="${esc(S.password)}"></label>
      <div style="display:flex;align-items:center;gap:12px"><span class="meter" aria-hidden="true">${[0, 1, 2, 3].map((i) => `<span class="${i < sv ? 'on' : ''}"></span>`).join('')}</span><span style="font-size:14px;font-weight:600;color:var(--at);min-width:70px" id="pws">${S.password ? sl : ''}</span></div>
      <label class="lbl">Type it again<input class="fld ${mismatch ? 'bad' : ''}" id="pw2" type="password" value="${esc(S.password2)}"></label>
      <label class="chk"><input type="checkbox" checked disabled><span style="display:flex;flex-direction:column">Ask for my password when I sign in<span class="note">Always on, so nobody else can open your account.</span></span></label>
      ${S.more ? `<label class="lbl">Username<input class="fld" id="un" type="text" value="${esc(S.username || defaultUser(S.full_name))}"><span class="note">Lowercase letters, numbers, - and _.</span></label>` : '<button class="link" style="align-self:flex-start;font-size:14px" onclick="set({more:true})">more options: username ›</button>'}
    </section>
    <section style="width:430px;flex:none;display:flex;flex-direction:column;gap:10px">
      <span class="hint">This is how you'll appear when you sign in</span>
      <div class="preview"><span class="avatar">${esc(first[0] ? first[0].toUpperCase() : '?')}</span><span style="font-size:34px;font-weight:300;letter-spacing:-1px;text-transform:lowercase">${esc(first)}</span>
        <span style="width:240px;height:40px;background:rgba(255,255,255,.12);border-bottom:2px solid var(--at);display:flex;align-items:center;padding:0 12px;font-size:18px;letter-spacing:3px">••••••••</span>
        <span style="font-size:13px;font-weight:300;color:#e2dcd8">${esc(cn)}</span></div>
      <div style="display:flex;gap:12px;align-items:center;font-size:14px;font-weight:300;color:var(--soft)"><span>Your colour:</span><span class="swatches">${Object.keys(ACCENTS).map((k) => `<button class="sw ${k === S.accent ? 'on' : ''}" title="${k}" aria-label="${k}" style="background:${ACCENTS[k].ac}" onclick="set({accent:'${k}'})"></button>`).join('')}</span></div>
      <span class="note">You can change the colour any time in Settings.</span>
    </section>
  </div>`;
  const keep = (id, fn) => { const n = $('#' + id); n.oninput = () => { fn(n.value); const pos = n.selectionStart; render(); const m = $('#' + id); m.focus(); try { m.setSelectionRange(pos, pos); } catch (e) {} }; };
  keep('nm', (v) => { S.full_name = v; save(); });
  keep('cn', (v) => { S.computer_name = v; S.cn_touched = true; save(); });
  keep('pw', (v) => { S.password = v; });
  keep('pw2', (v) => { S.password2 = v; });
  if ($('#un')) keep('un', (v) => { S.username = v.toLowerCase(); save(); });
}

// ------------------------------------------------------------------ 3 how
function autoPickDisk() {
  if (!DISKS || !DISKS.length) return;
  if (!curDisk()) S.disk = (DISKS.find((d) => !d.usb) || DISKS[0]).path;
  const d = curDisk();
  if (!S.mode || (S.mode === 'alongside' && !d.windows)) S.mode = d.windows && d.alongside_max_gb >= 40 && !d.bitlocker ? 'alongside' : (d.largest_free >= 40 * GB && d.has_data ? 'free' : 'erase');
  if (!S.magic_size_gb && d.alongside_default_gb) S.magic_size_gb = d.alongside_default_gb;
  save();
}
function vHow(el) {
  if (DISKS === null) { el.innerHTML = '<div><h1 class="t">how to install</h1><p class="s"><span class="spin"></span>&nbsp; Looking at your disks…</p></div>'; return; }
  if (!DISKS.length) { el.innerHTML = '<div><h1 class="t">how to install</h1><p class="s">No disk big enough for Magic was found (it needs at least 40 GB).</p></div><div><button class="sm" onclick="DISKS=null;loadDisks(true).then(()=>{autoPickDisk();render()})">look again</button></div>'; return; }
  const d = curDisk();
  const disksel = DISKS.length > 1 ? `<label class="lbl" style="max-width:560px">Disk<select class="sel" id="dsk">${DISKS.map((x) => `<option value="${esc(x.path)}" ${x.path === S.disk ? 'selected' : ''}>${esc(x.name)} · ${gb(x.size)} GB${x.windows ? ' · has Windows' : ''}${x.usb ? ' · USB' : ''}</option>`).join('')}</select></label>` : `<p class="note" style="margin:0">Disk: ${esc(d.name)} · ${gb(d.size)} GB</p>`;
  const cards = [];
  if (d.windows) {
    let why = '', off = false;
    if (d.bitlocker) { why = '<span class="warn">Windows disk protection (BitLocker) is switched on. Turn it off in Windows first, then come back.</span>'; off = true; }
    else if (d.hibernated) { why = "<span class=\"warn\">Windows didn't fully shut down. In Windows, hold Shift while you press Shut down, then start this installer again.</span>"; off = true; }
    else if (d.alongside_max_gb < 40) { why = "<span class=\"warn\">There isn't enough free space in Windows to make room (Magic needs 40 GB).</span>"; off = true; }
    const slider = S.mode === 'alongside' && !off ? `<div style="padding:6px 0 0 30px;display:flex;flex-direction:column;gap:6px" onclick="event.stopPropagation()">
        <input class="slider" type="range" min="40" max="${d.alongside_max_gb}" step="5" value="${S.magic_size_gb}" id="sz" aria-label="Space for Magic in GB">
        <div style="display:flex;justify-content:space-between;font-size:14px;font-weight:300"><span>Magic: <b style="font-weight:600">${S.magic_size_gb} GB</b></span><span class="hint">Windows keeps ${gb(d.ntfs.size) - S.magic_size_gb} GB</span></div></div>` : '';
    cards.push(`<div class="card ${S.mode === 'alongside' ? 'on' : ''} ${off ? 'off' : ''}" ${off ? '' : `onclick="set({mode:'alongside'})"`} role="radio" aria-checked="${S.mode === 'alongside'}"><span class="ttl"><input type="radio" ${S.mode === 'alongside' ? 'checked' : ''} ${off ? 'disabled' : ''}>Next to Windows <span class="tag">recommended</span></span>
      <span class="txt" style="padding-left:30px">Keep Windows and everything in it. Each time you turn on, you pick Windows or Magic.</span>${why ? `<span class="txt" style="padding-left:30px">${why}</span>` : ''}${slider}</div>`);
  }
  if (d.has_data && d.largest_free >= 40 * GB) {
    cards.push(`<div class="card ${S.mode === 'free' ? 'on' : ''}" onclick="set({mode:'free'})" role="radio" aria-checked="${S.mode === 'free'}"><span class="ttl"><input type="radio" ${S.mode === 'free' ? 'checked' : ''}>Use the empty space</span>
      <span class="txt" style="padding-left:30px">Put Magic in the ${gb(d.largest_free)} GB that isn't used yet. Nothing else changes.</span></div>`);
  }
  cards.push(`<div class="card ${S.mode === 'erase' ? 'on' : ''}" onclick="set({mode:'erase'})" role="radio" aria-checked="${S.mode === 'erase'}"><span class="ttl"><input type="radio" ${S.mode === 'erase' ? 'checked' : ''}>Use the whole disk</span>
    <span class="txt" style="padding-left:30px">Magic takes all ${gb(d.size)} GB. ${d.has_data ? '<b style="font-weight:600">Everything on this disk is erased' + (d.windows ? ', including Windows' : '') + '.</b>' : 'The disk is empty.'}</span>
    ${S.mode === 'erase' ? `<label class="chk" style="padding:6px 0 0 30px" onclick="event.stopPropagation()"><input type="checkbox" id="eok" ${S.erase_ok ? 'checked' : ''}>I understand everything on ${esc(d.name)} will be erased</label>` : ''}</div>`);
  el.innerHTML = `<div><h1 class="t">how to install</h1><p class="s">${d.windows ? 'Windows is on this computer. You can keep it and choose each time you turn on.' : 'Choose where Magic goes.'}</p></div>
    ${disksel}<div class="col" style="max-width:900px">${cards.join('')}</div>`;
  if ($('#dsk')) $('#dsk').onchange = (e) => { S.disk = e.target.value; S.mode = ''; S.magic_size_gb = 0; S.erase_ok = false; autoPickDisk(); render(); };
  if ($('#sz')) $('#sz').oninput = (e) => set({ magic_size_gb: +e.target.value });
  if ($('#eok')) $('#eok').onchange = (e) => set({ erase_ok: e.target.checked });
}

// ------------------------------------------------------------------ 4 protect
function vProtect(el) {
  const tpmOk = canTpm();
  const check = (ok, yes, no) => `<span class="${ok ? 'ok' : 'warn'}">${ok ? '✓' : '•'} ${ok ? yes : no}</span>`;
  const rk = (ST.recovery_key || '').split('-');
  const pwMismatch = S.startup_password2 && S.startup_password !== S.startup_password2;
  el.innerHTML = `<div><h1 class="t">protect your files</h1><p class="s">If your computer is lost or stolen, nobody can read what's on it.</p></div>
  <label class="chk" style="padding:12px 18px;background:var(--panel);font-size:18px;align-items:center"><input type="checkbox" id="enc" ${S.encrypt ? 'checked' : ''}><span style="flex:1">Protect this computer with encryption <span class="tag" style="margin-left:8px">recommended</span></span></label>
  ${S.encrypt ? `<div class="row">
    <section style="flex:1.15;display:flex;flex-direction:column;gap:10px;min-width:0">
      <h2>how should it unlock?</h2>
      <div class="card ${S.unlock === 'tpm' ? 'on' : ''} ${tpmOk ? '' : 'off'}" ${tpmOk ? `onclick="set({unlock:'tpm'})"` : ''}><span class="ttl"><input type="radio" ${S.unlock === 'tpm' ? 'checked' : ''} ${tpmOk ? '' : 'disabled'}>Automatically <span class="tag">recommended</span></span>
        <span class="txt" style="padding-left:30px">Unlocks itself when you turn on, using this computer's security chip (TPM 2) and Secure Boot, so there's no extra password. If someone changes the start-up software or removes the disk, it stays locked.</span>
        <span class="status" style="padding:4px 0 0 30px">${check(ST.tpm, 'Security chip found', 'No security chip (TPM 2)')}${check(ST.secure_boot, 'Secure Boot is on', 'Secure Boot is off')}</span></div>
      <div class="card ${S.unlock === 'password' ? 'on' : ''}" onclick="set({unlock:'password'})"><span class="ttl" style="font-weight:${S.unlock === 'password' ? 600 : 300}"><input type="radio" ${S.unlock === 'password' ? 'checked' : ''}>Ask for a password</span>
        <span class="txt" style="padding-left:30px">You type a start-up password each time you turn on.${tpmOk ? '' : ' This is used because automatic unlocking needs a security chip and Secure Boot.'}</span>
        ${S.unlock === 'password' ? `<div style="padding:6px 0 0 30px;display:flex;gap:12px" onclick="event.stopPropagation()"><label class="lbl" style="flex:1">Start-up password<input class="fld" id="sp1" type="password" value="${esc(S.startup_password)}"></label><label class="lbl" style="flex:1">Type it again<input class="fld ${pwMismatch ? 'bad' : ''}" id="sp2" type="password" value="${esc(S.startup_password2)}"></label></div>` : ''}</div>
      <p class="note" style="margin:0">If the start-up software changes, for example after a firmware update, the computer may ask for your recovery key once.</p>
    </section>
    <section class="panel" style="flex:1;min-width:0">
      <h2>your recovery key</h2>
      <p class="note" style="margin:0;font-size:14px;color:var(--soft);line-height:21px">If the computer ever can't unlock itself, or you move the disk, this key is the only way back in. Magic can't recover it for you.</p>
      <div class="key">${esc(rk.slice(0, 3).join('-'))}-<br>${esc(rk.slice(3).join('-'))}</div>
      <p class="note" style="margin:0">Write it down or take a photo of it, and keep it somewhere safe that isn't this computer. Type it with or without the dashes.</p>
      <label class="chk" style="margin-top:auto"><input type="checkbox" id="rks" ${S.rk_saved === ST.recovery_key ? 'checked' : ''}>I've saved my recovery key somewhere safe</label>
    </section></div>`
    : `<section class="panel" style="max-width:760px"><h2 class="ac">not encrypted</h2><p class="s" style="margin:0">Anyone who gets hold of this computer or its disk can read your files. You can't switch encryption on later without reinstalling.</p></section>`}`;
  $('#enc').onchange = (e) => set({ encrypt: e.target.checked });
  if ($('#rks')) $('#rks').onchange = (e) => set({ rk_saved: e.target.checked ? ST.recovery_key : false });
  const keep = (id, k) => { const n = $('#' + id); if (!n) return; n.oninput = () => { S[k] = n.value; const pos = n.selectionStart; render(); const m = $('#' + id); m.focus(); try { m.setSelectionRange(pos, pos); } catch (e) {} }; };
  keep('sp1', 'startup_password'); keep('sp2', 'startup_password2');
}

// ------------------------------------------------------------------ 5 software
function vSoftware(el) {
  if (S.choosing) return vApps(el);
  const card = (id, title, rec, body) => `<button class="card ${S.software === id ? 'on' : ''}" style="padding:22px;text-align:left" onclick="set({software:'${id}'${id === 'own' ? ',choosing:true' : ''}})"><span style="display:flex;align-items:center;justify-content:space-between"><span style="font-size:28px;font-weight:300;letter-spacing:-.5px;text-transform:lowercase">${title}</span>${rec ? '<span class="tag">recommended</span>' : ''}</span><span class="txt">${body}</span></button>`;
  el.innerHTML = `<div><h1 class="t">choose your software</h1><p class="s">Start with our pick, or choose each app yourself. You can add or remove anything later in the App Store.</p></div>
  <div class="row">
    <div class="col" style="width:470px;flex:none">${card('recommended', 'recommended', true, 'A good everyday set that works with Google Docs, streaming sites and Microsoft Office files.')}${card('own', 'let me choose', false, 'Pick your browser, office apps, email program and extras yourself.')}
      ${S.software === 'own' ? '<button class="link" style="align-self:flex-start" onclick="set({choosing:true})">change my picks ›</button>' : ''}</div>
    <section class="panel" style="flex:1;min-width:0"><h2 class="ac">what's in the recommended set</h2>
      <ul style="list-style:none;margin:0;padding:0">${RECOMMENDED.map(([r, a]) => `<li style="display:flex;justify-content:space-between;gap:14px;padding:11px 0;border-bottom:1px solid var(--line);font-size:16px"><span style="font-weight:300;color:var(--soft);text-transform:lowercase">${r}</span><span style="font-weight:600">${a}</span></li>`).join('')}</ul>
      <p class="note" style="margin:0;font-size:14px">Also included: Files, printing and scanning. Apps come from Flathub and update themselves.</p></section>
  </div>`;
}
function vApps(el) {
  const grp = (title, key, opts, maxw) => `<section style="display:flex;flex-direction:column;gap:6px"><h2 class="ac" style="font-size:22px">${title}</h2><div class="pick" style="max-width:${maxw || 'none'}">${opts.map(([id, n, t]) => `<button class="card ${S[key] === id ? 'on' : ''}" style="text-align:left" onclick="set({${key}:'${id}'})"><span class="ttl">${n}</span><span class="txt">${t}</span></button>`).join('')}</div></section>`;
  el.innerHTML = `<div><h1 class="t" style="font-size:40px">pick your apps</h1><p class="s" style="font-size:15px;line-height:22px">Streaming sites and Google Docs work in every browser listed here.</p></div>
  ${grp('internet', 'browser', BROWSERS, '640px')}${grp('office', 'office', OFFICES)}${grp('email', 'email', EMAILS)}
  <section style="display:flex;flex-direction:column;gap:6px"><h2 class="ac" style="font-size:22px">extras</h2><div class="grid4">${EXTRAS.map(([id, n]) => `<label class="chk"><input type="checkbox" data-x="${id}" ${S.extras[id] ? 'checked' : ''}>${n}</label>`).join('')}</div></section>
  <div><button class="link" onclick="set({choosing:false})">‹ back to the software choice</button></div>`;
  document.querySelectorAll('[data-x]').forEach((c) => (c.onchange = () => { S.extras[c.dataset.x] = c.checked; save(); }));
}

// ------------------------------------------------------------------ 6 ready
function softwareLine() {
  if (S.software === 'recommended') return 'Recommended set: Vivaldi, LibreOffice, Thunderbird and more';
  const name = (list, id) => (list.find((x) => x[0] === id) || [0, id])[1];
  const parts = [name(BROWSERS, S.browser)];
  if (S.office !== 'none') parts.push(name(OFFICES, S.office));
  if (S.email !== 'none') parts.push(name(EMAILS, S.email));
  const ex = EXTRAS.filter(([id]) => S.extras[id]).map(([, n]) => n);
  return parts.concat(ex).join(', ');
}
function vReady(el) {
  const d = curDisk() || { name: '?', size: 0 };
  const lang = langOf(S.locale)[1];
  const disk = S.mode === 'alongside' ? `Magic goes next to Windows · ${S.magic_size_gb} GB. Windows keeps its files.`
    : S.mode === 'free' ? `Magic goes in the empty space on ${esc(d.name)}. Nothing else changes.`
      : `<b style="font-weight:600">Erase ${esc(d.name)} (${gb(d.size)} GB)</b> and use all of it for Magic.`;
  const prot = !S.encrypt ? 'Not encrypted' : S.unlock === 'tpm' ? 'Encrypted · unlocks automatically (security chip + Secure Boot) · recovery key saved' : 'Encrypted · asks for a start-up password · recovery key saved';
  const rows = [['you', `${esc(S.full_name)} · ${esc(S.computer_name)}`, 2], ['place', `${esc(zone().city)} (${esc(utcOffset(S.timezone))}) · ${esc(lang)} · ${esc(kbName())} keyboard · ${S.clock}-hour clock`, 1], ['disk', disk, 3], ['protection', prot, 4], ['software', esc(softwareLine()), 5]];
  const next = [S.mode === 'alongside' ? 'Make room next to Windows' : S.mode === 'erase' ? 'Prepare the disk' : 'Prepare the empty space', S.encrypt ? 'Set up encryption' : null, 'Download and install Magic', 'Install your apps', 'Restart into Magic'].filter(Boolean);
  el.innerHTML = `<div><h1 class="t">ready to install</h1><p class="s">Nothing has changed on your computer yet. Have a last look, then press install.</p></div>
  <div class="row"><section class="panel" style="flex:1;gap:0;min-width:0">${rows.map(([k, v, i]) => `<div class="sum"><span class="k">${k}</span><span class="v">${v}</span><button class="link" style="font-size:14px" onclick="jump(${i})">change</button></div>`).join('')}</section>
  <section class="panel" style="width:380px;flex:none"><h2 class="ac">what happens next</h2><ol style="margin:0;padding-left:22px;display:flex;flex-direction:column;gap:10px;font-size:16px;font-weight:300;line-height:23px">${next.map((n) => `<li>${n}</li>`).join('')}</ol>
  <p class="note" style="margin:auto 0 0;font-size:14px;line-height:21px">${S.mode === 'erase' ? 'This takes about 10 to 20 minutes, depending on your internet.' : 'Each time you turn the computer on, you\'ll pick Windows or Magic. Magic is the default.'}</p></section></div>`;
}

// ------------------------------------------------------------------ install
window.startInstall = async () => {
  for (let i = 0; i < STEPS.length - 1; i++) if (!stepOk(i)) { jump(i); return; }
  const extras = Object.keys(S.extras).filter((k) => S.extras[k]);
  const body = {
    full_name: S.full_name.trim(), computer_name: S.computer_name.trim(), password: S.password, username: S.more ? (S.username || '') : '',
    locale: S.locale, kb_layout: S.kb_layout, kb_variant: S.kb_variant, clock: S.clock, timezone: S.timezone, accent: S.accent,
    disk: S.disk, mode: S.mode, magic_size_gb: S.magic_size_gb,
    encryption: !S.encrypt ? 'none' : S.unlock, startup_password: S.startup_password,
    software: S.software, browser: S.browser, office: S.office, email: S.email, extras,
  };
  const r = await api('/api/install', body);
  if (!r.ok) { PHASE = 'error'; PROG = { error: r.message, details: '' }; render(); return; }
  PHASE = 'installing'; render(); poll();
};
async function poll() {
  try { PROG = await api('/api/progress'); } catch (e) { setTimeout(poll, 2000); return; }
  if (PROG.done) { PHASE = 'done'; localStorage.removeItem('magic-installer'); render(); return; }
  if (PROG.error) { PHASE = 'error'; render(); return; }
  if (PHASE === 'installing') renderInstalling($('#body'));
  setTimeout(poll, 1500);
}
function renderInstalling(el) {
  const p = PROG || { stage: 'Starting', percent: 0, log: [] };
  el.innerHTML = `<div><h1 class="t">installing magic</h1><p class="s">This takes a while. You can leave the computer to it, but keep it plugged in and connected.</p></div>
  <section class="panel" style="max-width:900px;gap:16px"><div style="display:flex;justify-content:space-between;align-items:baseline"><h2>${esc(p.stage || '')}</h2><span style="font-size:28px;font-weight:300">${p.percent || 0}%</span></div>
  <div class="progress"><span style="width:${p.percent || 0}%"></span></div>
  <details><summary class="hint" style="cursor:pointer">details</summary><pre class="log">${esc((p.log || []).join('\n'))}</pre></details></section>`;
  bar('', '<span class="hint">Please don\'t turn the computer off</span>');
}
function renderDone(el) {
  el.innerHTML = `<div><h1 class="t">magic is ready</h1><p class="s">Restart to start using it. Remove the USB stick when the screen goes dark.</p></div>
  <section class="panel" style="max-width:760px"><h2 class="ac">when it starts</h2><ul style="margin:0;padding-left:20px;font-size:16px;font-weight:300;line-height:26px">
  ${S.encrypt && S.unlock === 'password' ? '<li>Type your start-up password.</li>' : ''}<li>Sign in as <b style="font-weight:600">${esc(S.full_name || 'you')}</b> with your password.</li>
  <li>Updates download by themselves. When one is ready, restarting installs it.</li></ul></section>`;
  bar('', '<button class="pri big" onclick="api(\'/api/restart\',{})">restart now</button>');
}
function renderError(el) {
  const p = PROG || {};
  el.innerHTML = `<div><h1 class="t">that didn't work</h1><p class="s">${esc(p.error || 'Something went wrong.')}</p></div>
  ${p.details ? `<section class="panel" style="max-width:960px"><details><summary class="hint" style="cursor:pointer">technical details</summary><pre class="log">${esc(p.details)}</pre></details></section>` : ''}`;
  bar('<button class="ghost" onclick="api(\'/api/restart\',{})">restart the computer</button>', `<button class="pri" onclick="PHASE='steps';set({step:${STEPS.length - 1}})">go back and try again</button>`);
}

// ------------------------------------------------------------------ start
(async function init() {
  applyAccent();
  render();
  await refreshStatus();
  if (PREVIEW && PREVIEW[1] === 'installing') { PHASE = 'installing'; PROG = { stage: 'Downloading Magic', percent: 42, log: ['12:01:10 == Downloading Magic (42%)'] }; render(); return; }
  if (PREVIEW && PREVIEW[1] === 'done') { PHASE = 'done'; render(); return; }
  if (PREVIEW && (S.step === 4)) S.rk_saved = ST.recovery_key;
  if (ST.install && ST.install.running) { PHASE = 'installing'; render(); poll(); return; }
  if (ST.install && ST.install.done) { PHASE = 'done'; render(); return; }
  try { ZONES = await api('/api/timezones'); } catch (e) { ZONES = []; }
  if (!S.tz_touched) {
    try { const g = await api('/api/geo'); if (g.timezone) S.timezone = g.timezone; } catch (e) {}
  }
  if (S.step === 0 && ST.net.online && !localStorage.getItem('magic-installer')) { /* stay on 0 so people see they're online */ }
  enterStep();
  render();
  setInterval(() => { if (PHASE === 'steps' && S.step === 0) refreshStatus().then(render); }, 5000);
})();
