#!/usr/bin/env python3
"""Export a Touying deck as a self-contained HTML player or a PowerPoint file.

    python3 export-deck.py html DB26fa-QueryOpt     # writes DB26fa-QueryOpt.html
    python3 export-deck.py pptx DB26fa-QueryOpt     # writes DB26fa-QueryOpt.pptx

A PDF gives every reveal step its own page. Both exports group the steps of a slide
under one slide number, using the overlay metadata in DECK.pdfpc, so build that (and
DECK.pdf, for slide titles) first; the Makefile does. Pages come from typst itself:
SVG for the HTML player, PNG for PowerPoint, where each step is a full-slide picture
that appears on click over the previous one. Speaker notes come from DECK.pdfpc and go
into the HTML player's speaker window only; the PowerPoint copy carries no notes.
Needs only Python 3 and typst; pdftotext and pdfinfo (poppler) add titles if present.
Set TYPST and TYPST_FLAGS in the environment to override the typst command.
"""
import html
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import zipfile
from xml.sax.saxutils import escape, quoteattr

PNG_PPI = 216  # 2880 x 1620 for a 960 x 540 pt page: sharp on a 3x display


def typst_pages(deck, fmt, out_dir, extra=()):
    cmd = [*shlex.split(os.environ.get('TYPST', 'typst')), 'compile',
           *shlex.split(os.environ.get('TYPST_FLAGS', '')), '--format', fmt, *extra,
           f'{deck}.typ', os.path.join(out_dir, '{0p}.' + fmt)]
    subprocess.run(cmd, check=True)
    names = sorted(f for f in os.listdir(out_dir) if f.endswith('.' + fmt))
    return [os.path.join(out_dir, f) for f in names]


def poppler(tool, *args):
    if not shutil.which(tool):
        return ''
    r = subprocess.run([tool, *args], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ''


def load_slides(deck):
    """Group pdfpc pages into slides: [{label, title, note, pages: [page index...]}]."""
    with open(f'{deck}.pdfpc', encoding='utf-8') as f:
        pages = json.load(f)['pages']
    texts = poppler('pdftotext', '-enc', 'UTF-8', f'{deck}.pdf', '-').split('\f')
    slides = []
    for p in pages:
        if p.get('hidden'):
            continue
        if slides and slides[-1]['label'] == p['label']:
            slides[-1]['pages'].append(p['idx'])
            continue
        text = texts[p['idx']] if p['idx'] < len(texts) else ''
        title = next((line.strip() for line in text.splitlines() if line.strip()), '')
        slides.append({'label': p['label'], 'title': title,
                       'note': p.get('note', '').strip(), 'pages': [p['idx']]})
    info = poppler('pdfinfo', f'{deck}.pdf')
    meta = dict(re.findall(r'^(Title|Author):\s*(.*)$', info, re.M))
    return slides, len(pages), meta.get('Title', deck), meta.get('Author', '')


def check_page_count(deck, files, expected):
    if len(files) != expected:
        sys.exit(f'{deck}.typ renders {len(files)} pages but {deck}.pdfpc lists {expected}; '
                 f'rebuild {deck}.pdfpc')


# ---------------------------------------------------------------- HTML

TAG = re.compile(r'<(/?)([A-Za-z][\w:.-]*)[^>]*?(/?)>')


def top_level(xml):
    """Split a run of sibling XML elements (no comments or CDATA) into strings."""
    out, depth, start = [], 0, 0
    for m in TAG.finditer(xml):
        if m.group(1):
            depth -= 1
        elif not m.group(3):
            depth += 1
        if depth == 0:
            out.append(xml[start:m.end()].strip())
            start = m.end()
    if depth or xml[start:].strip():
        raise ValueError('unbalanced <defs> content')
    return [e for e in out if e]


def split_svg(text):
    """Return (viewBox, body, [(id, element)]) with every <defs> child hoisted out."""
    text = text.strip()
    m = re.match(r'<svg\b([^>]*)>', text)
    if not m or not text.endswith('</svg>'):
        raise ValueError('not a single <svg> document')
    view_box = re.search(r'viewBox="([^"]+)"', m.group(1)).group(1)
    inner = text[m.end():-len('</svg>')]
    defs = []
    for d in re.findall(r'<defs>(.*?)</defs>', inner, re.S):
        for el in top_level(d):
            el_id = re.match(r'<[\w:.-]+[^>]*?\sid="([^"]+)"', el)
            if not el_id:
                raise ValueError('a <defs> child without an id: ' + el[:80])
            defs.append((el_id.group(1), el))
    body = re.sub(r'<defs>.*?</defs>', '', inner, flags=re.S)
    if re.search(r'\sid="', body) or '<defs' in body:
        raise ValueError('page body has its own ids; teach split_svg to rename them')
    return view_box, body, defs


def build_html(deck):
    slides, n_pages, title, author = load_slides(deck)
    with tempfile.TemporaryDirectory() as tmp:
        files = typst_pages(deck, 'svg', tmp)
        check_page_count(deck, files, n_pages)
        shared, bodies, view_box = {}, [], None
        for i, path in enumerate(files):
            with open(path, encoding='utf-8') as f:
                vb, body, defs = split_svg(f.read())
            view_box = view_box or vb
            if vb != view_box:
                sys.exit(f'page {i + 1} has viewBox {vb}, page 1 has {view_box}')
            for el_id, el in defs:
                if shared.get(el_id, el) != el:
                    # Typst ids are content hashes, so this should not happen; rename to be safe.
                    new = f'{el_id}-p{i}'
                    body = re.sub(f'#{re.escape(el_id)}(?=[")])', '#' + new, body)
                    el, el_id = el.replace(f'id="{el_id}"', f'id="{new}"', 1), new
                shared[el_id] = el
            bodies.append(f'<g id="p{i}">{body}</g>')
    sprite = '\n'.join([*shared.values(), *bodies])
    data = {'id': deck, 'title': title, 'viewBox': view_box,
            'slides': [{k: s[k] for k in ('label', 'title', 'note', 'pages')} for s in slides]}
    data_json = json.dumps(data, ensure_ascii=False).replace('</', '<\\/')
    page = (HTML_TEMPLATE.replace('__TITLE__', html.escape(title))
            .replace('__AUTHOR__', html.escape(author))
            .replace('__DATA__', data_json)
            .replace('__SPRITE__', sprite))
    with open(f'{deck}.html', 'w', encoding='utf-8') as f:
        f.write(page)
    steps = sum(len(s['pages']) for s in slides)
    print(f'{deck}.html: {len(slides)} slides, {steps} steps, '
          f'{os.path.getsize(deck + ".html") / 1e6:.1f} MB')


HTML_TEMPLATE = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="author" content="__AUTHOR__">
<title>__TITLE__</title>
<style>
:root { --muted: #a0a0a0; --line: #3a3a3c; --mark: #d9534f; --panel: #121214; }
* { box-sizing: border-box; }
html, body { margin: 0; height: 100%; overflow: hidden; background: #000; color: #eee;
  font: 16px/1.45 -apple-system, "Helvetica Neue", Arial, sans-serif; }
[hidden] { display: none !important; }
#sprite { position: absolute; width: 0; height: 0; overflow: hidden; }
svg.page { display: block; width: 100%; height: 100%; }
#stage { position: fixed; inset: 0; }
body.idle #stage { cursor: none; }
#blank { position: fixed; inset: 0; background: #000; }
.toast { position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%); padding: 7px 16px;
  border-radius: 7px; background: rgba(0, 0, 0, .8); color: #fff; font-size: 15px;
  pointer-events: none; transition: opacity .8s; white-space: nowrap; }
.toast.gone { opacity: 0; }
.sheet { position: fixed; inset: 0; overflow: auto; background: var(--panel); }
#help .box { max-width: 560px; margin: 8vh auto; padding: 0 24px; }
#help h2 { font-size: 20px; margin: 0 0 12px; }
#help table { border-collapse: collapse; width: 100%; }
#help td { padding: 6px 0; border-bottom: 1px solid var(--line); vertical-align: top; }
#help td:first-child { width: 46%; color: var(--muted); }
kbd { font: 13px Menlo, monospace; border: 1px solid #555; border-radius: 4px; padding: 1px 5px; }
#overview .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr));
  gap: 18px; padding: 22px; }
#overview figure { margin: 0; cursor: pointer; }
#overview svg { width: 100%; height: auto; display: block; background: #fff; outline: 1px solid var(--line); }
#overview figure.here svg { outline: 3px solid var(--mark); }
#overview figcaption { margin-top: 5px; font-size: 13px; color: var(--muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
#speaker { display: grid; grid-template-rows: auto minmax(0, 1fr); height: 100%; background: #161618; }
#speaker header { display: flex; gap: 22px; align-items: baseline; padding: 10px 20px;
  border-bottom: 1px solid var(--line); font-size: 20px; font-variant-numeric: tabular-nums; }
#speaker .where { font-weight: 600; }
#speaker .step, #speaker .label { color: var(--muted); }
#speaker .timer { margin-left: auto; cursor: pointer; }
#speaker .main { display: grid; grid-template-columns: minmax(0, 3fr) minmax(0, 2fr); gap: 20px; padding: 20px; min-height: 0; }
#speaker .now svg, #speaker .next svg { width: 100%; height: auto; display: block; background: #fff; }
#speaker .side { display: grid; grid-template-rows: auto auto minmax(0, 1fr); gap: 8px; min-height: 0; }
#speaker .label { font-size: 14px; }
#speaker .notes { overflow: auto; font-size: var(--notes, 20px); line-height: 1.5; white-space: pre-wrap;
  padding: 10px 6px 0 0; border-top: 1px solid var(--line); margin-top: 6px; }
#speaker .notes a { color: #8ab4f8; }
@media (max-width: 760px) {
  #speaker .main { grid-template-columns: minmax(0, 1fr); overflow: auto; }
}
</style>
</head>
<body>
<svg id="sprite" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" focusable="false"><defs>
__SPRITE__
</defs></svg>
<div id="stage"></div>
<div id="speaker" hidden>
  <header><span class="where"></span><span class="step"></span>
    <span class="timer" title="Click to restart the timer">0:00</span><span class="clock"></span></header>
  <div class="main"><div class="now"></div>
    <div class="side"><div class="label next-label"></div><div class="next"></div><div class="notes"></div></div></div>
</div>
<div id="overview" class="sheet" hidden><div class="grid"></div></div>
<div id="help" class="sheet" hidden><div class="box">
  <h2>Keys</h2>
  <table>
    <tr><td><kbd>→</kbd> <kbd>Space</kbd> <kbd>Page Down</kbd>, click</td><td>Next step or slide</td></tr>
    <tr><td><kbd>←</kbd> <kbd>Page Up</kbd> <kbd>Backspace</kbd></td><td>Previous step or slide</td></tr>
    <tr><td><kbd>↓</kbd> / <kbd>↑</kbd></td><td>Next / previous slide, skipping steps</td></tr>
    <tr><td><kbd>Home</kbd> / <kbd>End</kbd></td><td>First / last slide</td></tr>
    <tr><td>number, then <kbd>Enter</kbd></td><td>Go to that slide</td></tr>
    <tr><td><kbd>S</kbd></td><td>Open the speaker window: notes, next step, timer</td></tr>
    <tr><td><kbd>O</kbd></td><td>Overview of all slides</td></tr>
    <tr><td><kbd>F</kbd></td><td>Full screen</td></tr>
    <tr><td><kbd>B</kbd> or <kbd>.</kbd></td><td>Black screen</td></tr>
    <tr><td><kbd>+</kbd> / <kbd>−</kbd></td><td>Larger / smaller notes (speaker window)</td></tr>
    <tr><td><kbd>?</kbd> or <kbd>Esc</kbd></td><td>Show / hide this list</td></tr>
  </table>
  <p style="color: var(--muted)">The address ends in the slide number, then the step: <code>#18.3</code>
  is the third step of slide 18.</p>
</div></div>
<div id="blank" hidden></div>
<div id="goto" class="toast gone"></div>
<div id="hint" class="toast gone">Press ? for keys · S for speaker notes</div>
<script id="deck-data" type="application/json">__DATA__</script>
<script>
(() => {
  'use strict';
  const D = JSON.parse(document.getElementById('deck-data').textContent);
  const S = D.slides, N = S.length, SVGNS = 'http://www.w3.org/2000/svg';
  const isSpeaker = new URLSearchParams(location.search).has('speaker');
  const $ = sel => document.querySelector(sel);
  let pos = { s: 0, k: 0 }, blank = false, peer = isSpeaker ? window.opener : null;

  const steps = s => S[s].pages.length;
  function view(page) {
    const svg = document.createElementNS(SVGNS, 'svg');
    svg.setAttribute('viewBox', D.viewBox);
    svg.setAttribute('class', 'page');
    svg.setAttribute('role', 'img');
    svg.appendChild(document.createElementNS(SVGNS, 'use'));
    if (page != null) show(svg, page);
    return svg;
  }
  function show(svg, page) {
    svg.firstChild.setAttribute('href', '#p' + page);
    const s = S.findIndex(x => x.pages.includes(page));
    svg.setAttribute('aria-label', 'Slide ' + S[s].label + (S[s].title ? ': ' + S[s].title : ''));
  }

  function clamp(p) {
    const s = Math.max(0, Math.min(N - 1, p.s | 0));
    return { s, k: Math.max(0, Math.min(steps(s) - 1, p.k | 0)) };
  }
  function after(p) {
    if (p.k + 1 < steps(p.s)) return { s: p.s, k: p.k + 1 };
    return p.s + 1 < N ? { s: p.s + 1, k: 0 } : null;
  }
  function before(p) {
    if (p.k > 0) return { s: p.s, k: p.k - 1 };
    return p.s > 0 ? { s: p.s - 1, k: steps(p.s - 1) - 1 } : null;
  }
  const hashOf = p => '#' + S[p.s].label + (p.k > 0 ? '.' + (p.k + 1) : '');
  function fromHash() {
    const m = /^#([^.]+)(?:\.(\d+))?$/.exec(decodeURIComponent(location.hash));
    if (!m) return null;
    const s = S.findIndex(x => x.label === m[1]);
    return s < 0 ? null : clamp({ s, k: m[2] ? m[2] - 1 : 0 });
  }

  function go(p, fromPeer) {
    if (!p) return;
    pos = clamp(p);
    render();
    if (!fromPeer) tell();
  }
  function tell(extra) {
    try {
      if (peer && !peer.closed) peer.postMessage(Object.assign({ deck: D.id, s: pos.s, k: pos.k, blank }, extra), '*');
    } catch (e) { /* the other window went away */ }
  }
  window.addEventListener('message', e => {
    const m = e.data;
    if (!m || m.deck !== D.id) return;
    if (!peer || peer.closed) peer = e.source;
    if (m.hello) { tell(); return; }
    blank = !!m.blank;
    go({ s: m.s, k: m.k }, true);
  });

  const stage = $('#stage'), main = isSpeaker ? null : view(null);
  let now, next, notesFor = -1;
  if (isSpeaker) {
    document.body.classList.add('speaker');
    $('#stage').hidden = true;
    $('#speaker').hidden = false;
    now = view(null); next = view(null);
    $('#speaker .now').appendChild(now);
    $('#speaker .next').appendChild(next);
  } else {
    stage.appendChild(main);
  }

  function render() {
    const sl = S[pos.s];
    document.title = sl.label + ' / ' + N + ' · ' + D.title;
    try { history.replaceState(null, '', hashOf(pos)); } catch (e) { /* some file:// setups refuse */ }
    $('#blank').hidden = !blank || isSpeaker;
    if (!isSpeaker) {
      show(main, sl.pages[pos.k]);
    } else {
      $('#speaker .where').textContent = 'Slide ' + sl.label + ' of ' + N + (blank ? ' · screen black' : '');
      $('#speaker .step').textContent = steps(pos.s) > 1 ? 'step ' + (pos.k + 1) + ' of ' + steps(pos.s) : '';
      show(now, sl.pages[pos.k]);
      const n = after(pos);
      next.style.visibility = n ? '' : 'hidden';
      if (n) show(next, S[n.s].pages[n.k]);
      $('.next-label').textContent = !n ? 'End of the deck'
        : n.s === pos.s ? 'Next: step ' + (n.k + 1) + ' of ' + steps(n.s)
        : 'Next: slide ' + S[n.s].label + (S[n.s].title ? ' · ' + S[n.s].title : '');
      if (notesFor !== pos.s) {
        const notes = $('#speaker .notes');
        notes.innerHTML = linkify(sl.note);
        notes.scrollTop = 0;
        notesFor = pos.s;
      }
    }
    if (!$('#overview').hidden) mark();
  }
  function linkify(text) {
    const esc = t => t.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
    return text.split(/(https?:\/\/[^\s<>"]*[^\s<>".,;:)])/).map((part, i) =>
      i % 2 ? '<a href="' + esc(part) + '" target="_blank" rel="noopener">' + esc(part) + '</a>' : esc(part)).join('');
  }

  // Overview: one thumbnail per slide, in its final step.
  let built = false;
  function overview(open) {
    const ov = $('#overview');
    if (open && !built) {
      const grid = ov.querySelector('.grid');
      S.forEach((sl, i) => {
        const fig = document.createElement('figure'), cap = document.createElement('figcaption');
        fig.appendChild(view(sl.pages[sl.pages.length - 1]));
        cap.textContent = sl.label + (sl.title ? ' · ' + sl.title : '');
        fig.appendChild(cap);
        fig.addEventListener('click', () => { overview(false); go({ s: i, k: 0 }); });
        grid.appendChild(fig);
      });
      built = true;
    }
    ov.hidden = !open;
    if (open) { mark(); ov.querySelector('.here').scrollIntoView({ block: 'center' }); }
  }
  function mark() {
    $('#overview .grid').querySelectorAll('figure').forEach((f, i) => f.classList.toggle('here', i === pos.s));
  }

  function toast(el, text, ms) {
    if (text != null) el.textContent = text;
    el.classList.remove('gone');
    clearTimeout(el.timer);
    if (ms) el.timer = setTimeout(() => el.classList.add('gone'), ms);
  }
  function fullscreen() {
    const d = document, el = d.documentElement;
    if (d.fullscreenElement || d.webkitFullscreenElement) (d.exitFullscreen || d.webkitExitFullscreen).call(d);
    else (el.requestFullscreen || el.webkitRequestFullscreen).call(el);
  }
  function openSpeaker() {
    const url = location.href.replace(/[?#].*$/, '') + '?speaker' + hashOf(pos);
    const w = window.open(url, 'speaker-' + D.id, 'popup,width=1280,height=800');
    if (w) { peer = w; w.focus(); }
  }
  let notesSize = 20;
  try { notesSize = +localStorage.getItem('deck-notes-size') || 20; } catch (e) { /* storage off */ }
  function notes(delta) {
    notesSize = Math.max(12, Math.min(48, notesSize + delta));
    document.documentElement.style.setProperty('--notes', notesSize + 'px');
    try { localStorage.setItem('deck-notes-size', notesSize); } catch (e) { /* storage off */ }
  }
  notes(0);

  let digits = '';
  const gotoEl = $('#goto');
  window.addEventListener('keydown', e => {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    const k = e.key, help = $('#help'), ov = $('#overview');
    if (/^[0-9]$/.test(k)) { digits += k; toast(gotoEl, 'Go to slide ' + digits); }
    else if (digits && k === 'Enter') {
      const s = S.findIndex(x => x.label === digits);
      go(s >= 0 ? { s, k: 0 } : { s: +digits - 1, k: 0 });
      digits = ''; toast(gotoEl, null, 1);
      overview(false);
    }
    else if (digits && k === 'Backspace') { digits = digits.slice(0, -1); toast(gotoEl, 'Go to slide ' + digits, digits ? 0 : 1); }
    else if (digits && k === 'Escape') { digits = ''; toast(gotoEl, null, 1); }
    else if (k === 'Escape' || k === '?' || (k === 'h' && !help.hidden)) {
      if (k === 'Escape' && help.hidden && ov.hidden) return;
      if (!ov.hidden) overview(false); else help.hidden = !help.hidden;
    }
    else if (k === 'h') help.hidden = false;
    else if (k === 'o' || k === 'O') overview(ov.hidden);
    else if (!help.hidden || !ov.hidden) return;
    else if (k === ' ' && e.shiftKey) go(before(pos));
    else if (['ArrowRight', ' ', 'PageDown', 'Enter', 'n', 'N'].includes(k)) go(after(pos));
    else if (['ArrowLeft', 'PageUp', 'Backspace', 'p', 'P'].includes(k)) go(before(pos));
    else if (k === 'ArrowDown') { if (pos.s + 1 < N) go({ s: pos.s + 1, k: 0 }); }
    else if (k === 'ArrowUp') { if (pos.s > 0) go({ s: pos.s - 1, k: steps(pos.s - 1) - 1 }); }
    else if (k === 'Home') go({ s: 0, k: 0 });
    else if (k === 'End') go({ s: N - 1, k: steps(N - 1) - 1 });
    else if (k === 'b' || k === 'B' || k === '.') { blank = !blank; render(); tell(); }
    else if ((k === 'f' || k === 'F') && !isSpeaker) fullscreen();
    else if ((k === 's' || k === 'S') && !isSpeaker) openSpeaker();
    else if (k === '+' || k === '=') notes(2);
    else if (k === '-' || k === '_') notes(-2);
    else return;
    e.preventDefault();
  });

  if (!isSpeaker) {
    let tx = null, idle;
    stage.addEventListener('click', () => go(after(pos)));
    stage.addEventListener('touchstart', e => { tx = e.changedTouches[0].clientX; }, { passive: true });
    stage.addEventListener('touchend', e => {
      if (tx == null) return;
      const dx = e.changedTouches[0].clientX - tx;
      tx = null;
      if (Math.abs(dx) > 40) { e.preventDefault(); go(dx < 0 ? after(pos) : before(pos)); }
    }, { passive: false });
    window.addEventListener('mousemove', () => {
      document.body.classList.remove('idle');
      clearTimeout(idle);
      idle = setTimeout(() => document.body.classList.add('idle'), 2000);
    });
    $('#blank').addEventListener('click', () => { blank = false; render(); tell(); });
    toast($('#hint'), null, 4000);
  } else {
    let t0 = Date.now();
    const pad = n => String(n).padStart(2, '0');
    const tick = () => {
      const t = Math.floor((Date.now() - t0) / 1000), h = Math.floor(t / 3600);
      $('#speaker .timer').textContent = (h ? h + ':' + pad(Math.floor(t / 60) % 60) : Math.floor(t / 60)) + ':' + pad(t % 60);
      const d = new Date();
      $('#speaker .clock').textContent = d.getHours() + ':' + pad(d.getMinutes());
    };
    $('#speaker .timer').addEventListener('click', () => { t0 = Date.now(); tick(); });
    setInterval(tick, 1000); tick();
    $('#speaker .now').addEventListener('click', () => go(after(pos)));
  }

  window.addEventListener('hashchange', () => go(fromHash()));
  pos = fromHash() || pos;
  render();
  if (isSpeaker && peer) {
    try { peer.postMessage({ deck: D.id, hello: true }, '*'); } catch (e) { /* no audience window */ }
  }
})();
</script>
</body>
</html>
'''


# ---------------------------------------------------------------- PPTX

EMU_PER_PT = 12700
NS = ('xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"')
XML = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
CT = 'application/vnd.openxmlformats-officedocument.'
EMPTY_TREE = ('<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
              '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
              '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>')
CLR_MAP = ('<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" '
           'accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" '
           'hlink="hlink" folHlink="folHlink"/>')


def rels(items):
    body = ''.join(f'<Relationship Id="{rid}" Type="{typ}" Target="{target}"/>'
                   for rid, typ, target in items)
    return (XML + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            + body + '</Relationships>')


def theme(name):
    colors = [('dk2', '44546A'), ('lt2', 'E7E6E6'), ('accent1', '4472C4'), ('accent2', 'ED7D31'),
              ('accent3', 'A5A5A5'), ('accent4', 'FFC000'), ('accent5', '5B9BD5'),
              ('accent6', '70AD47'), ('hlink', '0563C1'), ('folHlink', '954F72')]
    solid = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    return (XML + f'<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="{name}">'
            '<a:themeElements><a:clrScheme name="Office">'
            '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
            '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
            + ''.join(f'<a:{k}><a:srgbClr val="{v}"/></a:{k}>' for k, v in colors) +
            '</a:clrScheme><a:fontScheme name="Office">'
            '<a:majorFont><a:latin typeface="Helvetica Neue"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
            '<a:minorFont><a:latin typeface="Helvetica Neue"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>'
            '</a:fontScheme><a:fmtScheme name="Office">'
            '<a:fillStyleLst>' + solid * 3 + '</a:fillStyleLst><a:lnStyleLst>'
            + ''.join(f'<a:ln w="{w}">{solid}</a:ln>' for w in (6350, 12700, 19050)) +
            '</a:lnStyleLst><a:effectStyleLst>' + '<a:effectStyle><a:effectLst/></a:effectStyle>' * 3 +
            '</a:effectStyleLst><a:bgFillStyleLst>' + solid * 3 + '</a:bgFillStyleLst>'
            '</a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>')


def appear_timing(shape_ids):
    """One click per shape, each making it appear (PowerPoint's 'Appear' entrance)."""
    n, clicks = 2, []
    for spid in shape_ids:
        a, b, c, d = n + 1, n + 2, n + 3, n + 4
        n += 4
        clicks.append(
            f'<p:par><p:cTn id="{a}" fill="hold"><p:stCondLst><p:cond delay="indefinite"/></p:stCondLst>'
            f'<p:childTnLst><p:par><p:cTn id="{b}" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst>'
            f'<p:childTnLst><p:par><p:cTn id="{c}" presetID="1" presetClass="entr" presetSubtype="0" '
            f'fill="hold" nodeType="clickEffect"><p:stCondLst><p:cond delay="0"/></p:stCondLst>'
            f'<p:childTnLst><p:set><p:cBhvr><p:cTn id="{d}" dur="1" fill="hold"><p:stCondLst>'
            f'<p:cond delay="0"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="{spid}"/></p:tgtEl>'
            f'<p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr>'
            f'<p:to><p:strVal val="visible"/></p:to></p:set></p:childTnLst></p:cTn></p:par>'
            f'</p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par>')
    return ('<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot">'
            '<p:childTnLst><p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" '
            'nodeType="mainSeq"><p:childTnLst>' + ''.join(clicks) + '</p:childTnLst></p:cTn>'
            '<p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>'
            '<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>'
            '</p:seq></p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>')


def build_pptx(deck):
    slides, n_pages, title, author = load_slides(deck)
    with tempfile.TemporaryDirectory() as tmp:
        files = typst_pages(deck, 'png', tmp, ('--ppi', str(PNG_PPI)))
        check_page_count(deck, files, n_pages)
        with open(files[0], 'rb') as f:
            head = f.read(24)
        px_w, px_h = int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')
        cx = 960 * EMU_PER_PT
        cy = round(cx * px_h / px_w)
        parts = {}
        ctypes = [('/ppt/presentation.xml', CT + 'presentationml.presentation.main+xml'),
                  ('/ppt/slideMasters/slideMaster1.xml', CT + 'presentationml.slideMaster+xml'),
                  ('/ppt/slideLayouts/slideLayout1.xml', CT + 'presentationml.slideLayout+xml'),
                  ('/ppt/theme/theme1.xml', CT + 'theme+xml'),
                  ('/ppt/presProps.xml', CT + 'presentationml.presProps+xml'),
                  ('/ppt/viewProps.xml', CT + 'presentationml.viewProps+xml'),
                  ('/ppt/tableStyles.xml', CT + 'presentationml.tableStyles+xml'),
                  ('/docProps/core.xml', 'application/vnd.openxmlformats-package.core-properties+xml'),
                  ('/docProps/app.xml', CT + 'extended-properties+xml')]
        pres_rels = [('rId1', REL + 'slideMaster', 'slideMasters/slideMaster1.xml'),
                     ('rId3', REL + 'theme', 'theme/theme1.xml'),
                     ('rId4', REL + 'presProps', 'presProps.xml'),
                     ('rId5', REL + 'viewProps', 'viewProps.xml'),
                     ('rId6', REL + 'tableStyles', 'tableStyles.xml')]
        media = {}
        slide_ids = []
        for n, sl in enumerate(slides, 1):
            pics, srels = [], [('rId1', REL + 'slideLayout', '../slideLayouts/slideLayout1.xml')]
            for k, page in enumerate(sl['pages']):
                media[f'ppt/media/page{page + 1}.png'] = files[page]
                rid = f'rId{k + 3}'
                srels.append((rid, REL + 'image', f'../media/page{page + 1}.png'))
                name = f'Slide {sl["label"]}' + (f', step {k + 1}' if len(sl['pages']) > 1 else '')
                pics.append(
                    f'<p:pic><p:nvPicPr><p:cNvPr id="{k + 2}" name={quoteattr(name)} '
                    f'descr={quoteattr(sl["title"] or name)}/><p:cNvPicPr><a:picLocks noChangeAspect="1"/>'
                    f'</p:cNvPicPr><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="{rid}"/>'
                    f'<a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="0" y="0"/>'
                    f'<a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
                    f'</p:spPr></p:pic>')
            timing = appear_timing(range(3, len(sl['pages']) + 2)) if len(sl['pages']) > 1 else ''
            parts[f'ppt/slides/slide{n}.xml'] = (
                XML + f'<p:sld {NS}><p:cSld><p:spTree>{EMPTY_TREE}{"".join(pics)}</p:spTree></p:cSld>'
                '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>' + timing + '</p:sld>')
            parts[f'ppt/slides/_rels/slide{n}.xml.rels'] = rels(srels)
            ctypes.append((f'/ppt/slides/slide{n}.xml', CT + 'presentationml.slide+xml'))
            pres_rels.append((f'rId{n + 10}', REL + 'slide', f'slides/slide{n}.xml'))
            slide_ids.append(f'<p:sldId id="{n + 255}" r:id="rId{n + 10}"/>')

        parts['[Content_Types].xml'] = (
            XML + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Default Extension="png" ContentType="image/png"/>'
            + ''.join(f'<Override PartName="{p}" ContentType="{t}"/>' for p, t in ctypes) + '</Types>')
        parts['_rels/.rels'] = rels([
            ('rId1', REL + 'officeDocument', 'ppt/presentation.xml'),
            ('rId2', 'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties',
             'docProps/core.xml'),
            ('rId3', REL + 'extended-properties', 'docProps/app.xml')])
        parts['ppt/presentation.xml'] = (
            XML + f'<p:presentation {NS} saveSubsetFonts="1">'
            '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
            f'<p:sldIdLst>{"".join(slide_ids)}</p:sldIdLst>'
            f'<p:sldSz cx="{cx}" cy="{cy}"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>')
        parts['ppt/_rels/presentation.xml.rels'] = rels(pres_rels)
        parts['ppt/slideMasters/slideMaster1.xml'] = (
            XML + f'<p:sldMaster {NS}><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef>'
            f'</p:bg><p:spTree>{EMPTY_TREE}</p:spTree></p:cSld>{CLR_MAP}'
            '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
            '<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>')
        parts['ppt/slideMasters/_rels/slideMaster1.xml.rels'] = rels(
            [('rId1', REL + 'slideLayout', '../slideLayouts/slideLayout1.xml'),
             ('rId2', REL + 'theme', '../theme/theme1.xml')])
        parts['ppt/slideLayouts/slideLayout1.xml'] = (
            XML + f'<p:sldLayout {NS} type="blank" preserve="1"><p:cSld name="Blank"><p:spTree>{EMPTY_TREE}'
            '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>')
        parts['ppt/slideLayouts/_rels/slideLayout1.xml.rels'] = rels(
            [('rId1', REL + 'slideMaster', '../slideMasters/slideMaster1.xml')])
        parts['ppt/theme/theme1.xml'] = theme('Slides')
        parts['ppt/presProps.xml'] = XML + f'<p:presentationPr {NS}/>'
        parts['ppt/viewProps.xml'] = (XML + f'<p:viewPr {NS}><p:normalViewPr><p:restoredLeft sz="15620"/>'
                                      '<p:restoredTop sz="80000"/></p:normalViewPr></p:viewPr>')
        parts['ppt/tableStyles.xml'] = (XML + '<a:tblStyleLst xmlns:a="http://schemas.openxmlformats.org/'
                                        'drawingml/2006/main" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>')
        parts['docProps/core.xml'] = (
            XML + '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/'
            'core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">'
            f'<dc:title>{escape(title)}</dc:title><dc:creator>{escape(author)}</dc:creator></cp:coreProperties>')
        parts['docProps/app.xml'] = (
            XML + '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
            f'<Application>export-deck.py</Application><Slides>{len(slides)}</Slides>'
            '<Notes>0</Notes></Properties>')

        out = f'{deck}.pptx'
        stamp = (2026, 1, 1, 0, 0, 0)  # fixed, so an unchanged deck gives an identical file
        with zipfile.ZipFile(out + '.tmp', 'w') as z:
            for name in ['[Content_Types].xml', *sorted(p for p in parts if p != '[Content_Types].xml')]:
                z.writestr(zipfile.ZipInfo(name, stamp), parts[name], zipfile.ZIP_DEFLATED)
            for name, path in sorted(media.items()):
                with open(path, 'rb') as f:
                    z.writestr(zipfile.ZipInfo(name, stamp), f.read(), zipfile.ZIP_STORED)
        os.replace(out + '.tmp', out)
    steps = sum(len(s['pages']) for s in slides)
    print(f'{out}: {len(slides)} slides, {steps} steps, {os.path.getsize(out) / 1e6:.1f} MB')


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('html', 'pptx'):
        sys.exit(__doc__)
    deck = re.sub(r'\.(typ|pdf|pdfpc)$', '', sys.argv[2])
    {'html': build_html, 'pptx': build_pptx}[sys.argv[1]](deck)
