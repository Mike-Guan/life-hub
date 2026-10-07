// Generates Sources/CompanionKit/RunnerArt.swift from the layered RUNNER SVG, or KuroArt.swift from the
// KURO SVG with `--kuro`.
//
//   node Packages/CompanionKit/Tools/gen-runner-art.mjs [--kuro] [--preview out.svg]
//
// Every <g id="…"> that directly contains shapes becomes one part. Shapes are flattened to
// absolute move/line/quad/cubic commands (arcs, circles, ellipses and rounded rects become cubics,
// group transforms are baked in), so the Swift side only has to replay them. Clip paths and linear
// gradients are kept per shape.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../..');
const kuro = process.argv.includes('--kuro');
const NAME = kuro ? 'Kuro' : 'Runner';
const SVG = kuro ? 'kuro-v1-layers.svg' : 'runner-v5-layers.svg';
const SRC = path.join(repo, 'docs/03 Product/companion', SVG);
const OUT = path.join(here, `../Sources/CompanionKit/${NAME}Art.swift`);

// Named colors. Every color in the SVG must be listed here.
const RUNNER_PALETTE = {
  '#111111': 'ink', '#111': 'ink',
  '#F2F4FA': 'hair', '#AFC6E3': 'hairShade', '#F3CFAE': 'skin', '#B98B6E': 'eyebag',
  '#FFFFFF': 'white', '#FFF': 'white', '#fff': 'white',
  '#6C7A89': 'deadPupil', '#1FB8C9': 'iris', '#FFE14D': 'catYellow', '#FF8FA3': 'blush',
  '#15161F': 'mask', '#3A3D52': 'maskLine', '#3EF0FF': 'neonCyan', '#FF3EA5': 'neonPink',
  '#2D3250': 'hood', '#1B1C26': 'jacket', '#FF3B4E': 'boxingRed', '#FFD23F': 'gold',
  '#C3C8D2': 'canLid', '#7CFF4F': 'monsterGreen', '#EADCC2': 'beige', '#C9B794': 'beigeShade',
  '#D9AE6E': 'cardboard', '#B58A4E': 'cardboardTape', '#E6C08A': 'cardboardFlap',
  '#FFF6E5': 'cream', '#E8D9BC': 'creamShade', '#FF9F43': 'catOrange', '#C96F1E': 'catStripe',
  // Not in the SVG: per-mode jacket colors from the RUNNER v5 sheet.
  '#3A6B58': 'jacketChill', '#121219': 'jacketMoney',
};
const KURO_PALETTE = {
  '#111111': 'ink', '#111': 'ink', '#FFFFFF': 'white', '#fff': 'white',
  '#2A2438': 'hair', '#7B5CFF': 'violet', '#C9B8FF': 'lilac', '#B9A2FF': 'lavender', '#F2E8FF': 'mist',
  '#15161F': 'mask', '#2D3250': 'navy', '#FDDCC4': 'skin', '#B98B6E': 'skinLine', '#C9A07E': 'lowLid',
  '#FF8FA3': 'pink', '#FF3B4E': 'red', '#FFD23F': 'gold', '#7FB7FF': 'sky', '#E6E9EF': 'tablet',
  '#4A2A1A': 'irisTop', '#7A4A2E': 'irisMid', '#B07A4E': 'irisBottom', '#3A2016': 'pupil', '#2A1A14': 'lashLine',
  '#8B5A3C': 'iris', '#FF3EA5': 'neonPink',
};
const PALETTE = kuro ? KURO_PALETTE : RUNNER_PALETTE;

const raw = fs.readFileSync(SRC, 'utf8').replace(/<metadata>[\s\S]*?<\/metadata>/g, '');

// ---------- tiny XML walk ----------
const tagRe = /<(\/?)([a-zA-Z][\w:-]*)((?:\s+[\w:-]+="[^"]*")*)\s*(\/?)>|([^<]+)/g;
const attrs = s => Object.fromEntries([...s.matchAll(/([\w:-]+)="([^"]*)"/g)].map(m => [m[1], m[2]]));
const I = [1, 0, 0, 1, 0, 0];
const mul = (a, b) => [a[0]*b[0]+a[2]*b[1], a[1]*b[0]+a[3]*b[1], a[0]*b[2]+a[2]*b[3], a[1]*b[2]+a[3]*b[3], a[0]*b[4]+a[2]*b[5]+a[4], a[1]*b[4]+a[3]*b[5]+a[5]];
function parseTransform(t) {
  let m = I;
  for (const [, fn, args] of (t || '').matchAll(/(\w+)\(([^)]*)\)/g)) {
    const v = args.split(/[\s,]+/).filter(Boolean).map(Number);
    if (fn === 'translate') m = mul(m, [1, 0, 0, 1, v[0], v[1] || 0]);
    else if (fn === 'rotate') { const r = v[0] * Math.PI / 180, c = Math.cos(r), s = Math.sin(r); m = mul(m, [c, s, -s, c, 0, 0]); }
    else if (fn === 'scale') m = mul(m, [v[0], 0, 0, v[1] ?? v[0], 0, 0]);
    else throw new Error('transform ' + fn);
  }
  return m;
}
const ap = (m, x, y) => [m[0]*x + m[2]*y + m[4], m[1]*x + m[3]*y + m[5]];

// ---------- path data → absolute M/L/Q/C/Z ----------
function arcToCubics(x1, y1, rx, ry, phi, fa, fs, x2, y2) {
  if (rx === 0 || ry === 0) return [['L', x2, y2]];
  const p = phi * Math.PI / 180, cp = Math.cos(p), sp = Math.sin(p);
  const dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
  const x1p = cp*dx + sp*dy, y1p = -sp*dx + cp*dy;
  rx = Math.abs(rx); ry = Math.abs(ry);
  const lam = x1p*x1p/(rx*rx) + y1p*y1p/(ry*ry);
  if (lam > 1) { rx *= Math.sqrt(lam); ry *= Math.sqrt(lam); }
  const num = rx*rx*ry*ry - rx*rx*y1p*y1p - ry*ry*x1p*x1p;
  let co = Math.sqrt(Math.max(0, num / (rx*rx*y1p*y1p + ry*ry*x1p*x1p)));
  if (fa === fs) co = -co;
  const cxp = co * rx * y1p / ry, cyp = -co * ry * x1p / rx;
  const cx = cp*cxp - sp*cyp + (x1 + x2)/2, cy = sp*cxp + cp*cyp + (y1 + y2)/2;
  const ang = (ux, uy, vx, vy) => { const a = Math.atan2(ux*vy - uy*vx, ux*vx + uy*vy); return a; };
  const t1 = ang(1, 0, (x1p - cxp)/rx, (y1p - cyp)/ry);
  let dt = ang((x1p - cxp)/rx, (y1p - cyp)/ry, (-x1p - cxp)/rx, (-y1p - cyp)/ry);
  if (!fs && dt > 0) dt -= 2*Math.PI; else if (fs && dt < 0) dt += 2*Math.PI;
  const n = Math.ceil(Math.abs(dt) / (Math.PI/2) - 1e-9), d = dt / n, k = 4/3 * Math.tan(d/4);
  const pt = t => [cx + rx*Math.cos(t)*cp - ry*Math.sin(t)*sp, cy + rx*Math.cos(t)*sp + ry*Math.sin(t)*cp];
  const der = t => [-rx*Math.sin(t)*cp - ry*Math.cos(t)*sp, -rx*Math.sin(t)*sp + ry*Math.cos(t)*cp];
  const out = [];
  for (let i = 0; i < n; i++) {
    const a = t1 + i*d, b = a + d, [ax, ay] = pt(a), [bx, by] = pt(b), [dax, day] = der(a), [dbx, dby] = der(b);
    out.push(['C', ax + k*dax, ay + k*day, bx - k*dbx, by - k*dby, bx, by]);
  }
  return out;
}
function parseD(d) {
  const toks = d.match(/[MmLlHhVvQqCcZzAa]|-?(?:\d*\.\d+|\d+\.?)(?:e-?\d+)?/g);
  const out = []; let i = 0, cmd = '', x = 0, y = 0, sx = 0, sy = 0;
  const num = () => Number(toks[i++]);
  while (i < toks.length) {
    if (/[a-zA-Z]/.test(toks[i])) cmd = toks[i++];
    const rel = cmd === cmd.toLowerCase(), C = cmd.toUpperCase();
    const ox = rel ? x : 0, oy = rel ? y : 0;
    if (C === 'Z') { out.push(['Z']); x = sx; y = sy; continue; }
    if (C === 'M') { x = ox + num(); y = oy + num(); sx = x; sy = y; out.push(['M', x, y]); cmd = rel ? 'l' : 'L'; }
    else if (C === 'L') { x = ox + num(); y = oy + num(); out.push(['L', x, y]); }
    else if (C === 'H') { x = ox + num(); out.push(['L', x, y]); }
    else if (C === 'V') { y = oy + num(); out.push(['L', x, y]); }
    else if (C === 'Q') { const a = ox + num(), b = oy + num(); x = ox + num(); y = oy + num(); out.push(['Q', a, b, x, y]); }
    else if (C === 'C') { const a = ox + num(), b = oy + num(), c = ox + num(), e = oy + num(); x = ox + num(); y = oy + num(); out.push(['C', a, b, c, e, x, y]); }
    else if (C === 'A') { const rx = num(), ry = num(), ph = num(), fa = num(), fs = num(); const nx = ox + num(), ny = oy + num(); out.push(...arcToCubics(x, y, rx, ry, ph, fa, fs, nx, ny)); x = nx; y = ny; }
    else throw new Error('path cmd ' + cmd);
  }
  return out;
}
const ellipse = (cx, cy, rx, ry) => parseD(`M${cx + rx} ${cy} A${rx} ${ry} 0 0 1 ${cx} ${cy + ry} A${rx} ${ry} 0 0 1 ${cx - rx} ${cy} A${rx} ${ry} 0 0 1 ${cx} ${cy - ry} A${rx} ${ry} 0 0 1 ${cx + rx} ${cy} Z`);
const rect = (x, y, w, h, r) => r > 0
  ? parseD(`M${x + r} ${y} H${x + w - r} A${r} ${r} 0 0 1 ${x + w} ${y + r} V${y + h - r} A${r} ${r} 0 0 1 ${x + w - r} ${y + h} H${x + r} A${r} ${r} 0 0 1 ${x} ${y + h - r} V${y + r} A${r} ${r} 0 0 1 ${x + r} ${y} Z`)
  : parseD(`M${x} ${y} H${x + w} V${y + h} H${x} Z`);
const xform = (cmds, m) => cmds.map(([c, ...v]) => { const o = [c]; for (let j = 0; j < v.length; j += 2) o.push(...ap(m, v[j], v[j + 1])); return o; });

// ---------- walk ----------
const parts = []; // {id, inks: []}
const texts = [];
const stack = [{ id: null, m: I, style: {} }];
let pendingText = null;
const gradients = {}; // id → {x1, y1, x2, y2, stops: [[offset, color]]}
const clips = {}; // id → [cmds]
let gradient = null, clip = null;
const STYLE_KEYS = ['fill', 'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin', 'stroke-dasharray', 'opacity', 'fill-opacity', 'clip-path', 'font-size', 'font-weight'];
function partFor(id) { let p = parts.find(q => q.id === id); if (!p) { p = { id, inks: [] }; parts.push(p); } return p; }
for (const mt of raw.matchAll(tagRe)) {
  const [, close, tag, attrStr, selfClose, text] = mt;
  const top = stack[stack.length - 1];
  if (text !== undefined) { if (pendingText && text.trim()) pendingText.text += text.trim(); continue; }
  if (close) {
    if (tag === 'text') { texts.push(pendingText); pendingText = null; }
    if (tag === 'g' || tag === 'svg' || tag === 'defs') stack.pop();
    if (tag === 'linearGradient') gradient = null;
    if (tag === 'clipPath') clip = null;
    continue;
  }
  const a = attrs(attrStr || '');
  const style = { ...top.style }; for (const k of STYLE_KEYS) if (a[k] !== undefined) style[k] = a[k];
  const m = mul(top.m, parseTransform(a.transform));
  if (tag === 'svg') { stack.push({ id: null, m, style }); continue; }
  if (tag === 'defs') { if (!selfClose) stack.push({ ...top, m, style }); continue; }
  if (tag === 'linearGradient') {
    gradient = gradients[a.id] = { x1: +(a.x1 ?? 0), y1: +(a.y1 ?? 0), x2: +(a.x2 ?? 1), y2: +(a.y2 ?? 0), stops: [] };
    if (selfClose) gradient = null;
    continue;
  }
  if (tag === 'stop') { gradient.stops.push([Number(a.offset), a['stop-color']]); continue; }
  if (tag === 'clipPath') { clip = clips[a.id] = []; if (selfClose) clip = null; continue; }
  if (tag === 'g') { const g = { id: a.id || top.id, m, style }; if (!selfClose) stack.push(g); continue; }
  if (tag === 'text') { const [x, y] = ap(m, Number(a.x || 0), Number(a.y || 0)); partFor(top.id); pendingText = { part: top.id, x, y, size: Number(style['font-size']), fill: style.fill, text: '' }; continue; }
  let cmds;
  if (tag === 'path') cmds = parseD(a.d);
  else if (tag === 'circle') cmds = ellipse(+(a.cx || 0), +(a.cy || 0), +a.r, +a.r);
  else if (tag === 'ellipse') cmds = ellipse(+(a.cx || 0), +(a.cy || 0), +a.rx, +a.ry);
  else if (tag === 'rect') cmds = rect(+(a.x || 0), +(a.y || 0), +a.width, +a.height, +(a.rx || 0));
  else if (tag === 'line') cmds = [['M', +a.x1, +a.y1], ['L', +a.x2, +a.y2]];
  else throw new Error('unsupported tag ' + tag);
  if (clip) { clip.push(...xform(cmds, m)); continue; }
  if (!top.id) throw new Error(tag + ' outside a named group');
  partFor(top.id).inks.push({ cmds: xform(cmds, m), style });
}
if (pendingText) throw new Error('unclosed text');

// ---------- emit ----------
const camel = s => s.replace(/_([a-zA-Z])/g, (_, c) => c.toUpperCase());
const color = c => { if (!c || c === 'none') return null; const n = PALETTE[c] ?? PALETTE[c.toUpperCase()]; if (!n) throw new Error('color not in palette: ' + c); return n; };
const f = v => { const r = Math.round(v * 100) / 100; return Number.isInteger(r) ? r.toFixed(0) : String(r); };
const pt = (x, y) => `.init(x: ${f(x)}, y: ${f(y)})`;
let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
for (const p of parts) for (const ink of p.inks) {
  const pad = Number(ink.style.stroke && ink.style.stroke !== 'none' ? ink.style['stroke-width'] || 1 : 0) / 2;
  for (const [c, ...v] of ink.cmds) for (let j = 0; j < v.length; j += 2) {
    minX = Math.min(minX, v[j] - pad); maxX = Math.max(maxX, v[j] + pad); minY = Math.min(minY, v[j + 1] - pad); maxY = Math.max(maxY, v[j + 1] + pad);
  }
}
minX = Math.floor(minX) - 2; minY = Math.floor(minY) - 2; maxX = Math.ceil(maxX) + 2; maxY = Math.ceil(maxY) + 2;

const usedColors = [...new Set(Object.values(PALETTE))];
const hexOf = n => Object.entries(PALETTE).find(([h, v]) => v === n && h.length === 7)[0].slice(1).toUpperCase();
const lines = [];
lines.push(`// Generated by Tools/gen-runner-art.mjs from docs/03 Product/companion/${SVG}.`);
lines.push('// Do not edit by hand: change the SVG (or the generator) and run the script again.');
lines.push('import SwiftUI', '');
lines.push(kuro ? '/// KURO colors, named after what they paint.' : '/// RUNNER v5 colors, named after what they paint.');
lines.push(`enum ${NAME}Palette {`);
for (const n of usedColors) lines.push(`    static let ${n} = Color(hex: 0x${hexOf(n)})`);
lines.push('}', '');
lines.push(`/// One named, separately movable piece of ${kuro ? 'KURO' : 'RUNNER'}, in back-to-front order.`);
lines.push(`enum ${NAME}Part: String, CaseIterable, Sendable {`);
for (const p of parts) lines.push(p.id === camel(p.id) ? `    case ${p.id}` : `    case ${camel(p.id)} = "${p.id}"`);
lines.push('}', '');
lines.push(`enum ${NAME}Art {`);
lines.push(`    /// Drawing space of every part, in SVG units.`);
if (kuro) {
  // Same frame as RUNNER, so both characters stand at the same size and place.
  lines.push('    static let bounds = RunnerArt.bounds');
} else {
  lines.push(`    static let bounds = CGRect(x: ${minX}, y: ${minY}, width: ${maxX - minX}, height: ${maxY - minY})`);
}
lines.push('');
lines.push(`    static func inks(_ part: ${NAME}Part) -> [RunnerInk] {`);
lines.push('        switch part {');
for (const p of parts) lines.push(`        case .${camel(p.id)}: ${camel(p.id)}()`);
lines.push('        }');
lines.push('    }');
if (texts.length) {
  lines.push('');
  lines.push(`    static func text(_ part: ${NAME}Part) -> RunnerText? {`);
  lines.push('        switch part {');
  for (const t of texts) lines.push(`        case .${camel(t.part)}: ${camel(t.part)}Text`);
  lines.push('        default: nil');
  lines.push('        }');
  lines.push('    }');
}
for (const t of texts) {
  lines.push('');
  lines.push(`    /// Text drawn by \`${camel(t.part)}\`: baseline-centered at (x, y) in SVG units.`);
  lines.push(`    static let ${camel(t.part)}Text = RunnerText(`);
  lines.push(`        string: "${t.text}", x: ${f(t.x)}, y: ${f(t.y)}, size: ${f(t.size)}, color: ${NAME}Palette.${color(t.fill)})`);
}
function pushPath(cmds) {
  for (const [c, ...v] of cmds) {
    let st;
    if (c === 'M') st = `p.move(to: ${pt(v[0], v[1])})`;
    else if (c === 'L') st = `p.addLine(to: ${pt(v[0], v[1])})`;
    else if (c === 'Q') st = `p.addQuadCurve(to: ${pt(v[2], v[3])}, control: ${pt(v[0], v[1])})`;
    else if (c === 'C') st = `p.addCurve(to: ${pt(v[4], v[5])}, control1: ${pt(v[0], v[1])}, control2: ${pt(v[2], v[3])})`;
    else st = 'p.closeSubpath()';
    if (st.length + 20 > 120) {
      // Keep generated lines inside swift-format's 120 columns.
      const call = st.slice(0, st.indexOf('(') + 1);
      const args = st.slice(st.indexOf('(') + 1, -1).split(/, (?=(?:to|control1|control2|control): )/);
      lines.push(`                    ${call}`);
      args.forEach((x, i) => lines.push(`                        ${x}${i < args.length - 1 ? ',' : ''}`));
      lines.push('                    )');
    } else lines.push(`                    ${st}`);
  }
}
// Gradients use objectBoundingBox units, so the end points come from the shape's bounds.
function gradientArg(g, cmds) {
  const xs = cmds.flatMap(([, ...v]) => v.filter((_, j) => j % 2 === 0));
  const ys = cmds.flatMap(([, ...v]) => v.filter((_, j) => j % 2 === 1));
  const x0 = Math.min(...xs), y0 = Math.min(...ys), w = Math.max(...xs) - x0, h = Math.max(...ys) - y0;
  const colors = g.stops.map(([, c]) => `${NAME}Palette.${color(c)}`).join(', ');
  const stops = g.stops.map(([o]) => f(o)).join(', ');
  return [
    'gradient: RunnerGradient(',
    `    colors: [${colors}],`,
    `    locations: [${stops}],`,
    `    start: ${pt(x0 + g.x1 * w, y0 + g.y1 * h)},`,
    `    end: ${pt(x0 + g.x2 * w, y0 + g.y2 * h)}`,
    ')',
  ].join('\n                ');
}
for (const p of parts) {
  lines.push('');
  lines.push(`    private static func ${camel(p.id)}() -> [RunnerInk] {`);
  if (!p.inks.length) { lines.push('        []', '    }'); continue; }
  lines.push('        [');
  p.inks.forEach((ink, inkIndex) => {
    const s = ink.style, stroke = color(s.stroke);
    const gradientId = /^url\(#(\w+)\)$/.exec(s.fill ?? '')?.[1];
    const fill = gradientId ? null : color(s.fill ?? (stroke ? 'none' : '#111111'));
    lines.push('            RunnerInk(');
    lines.push('                path: Path { p in');
    pushPath(ink.cmds);
    lines.push('                },');
    const args = [];
    if (fill) args.push(`fill: ${NAME}Palette.${fill}`);
    if (stroke) {
      args.push(`stroke: ${NAME}Palette.${stroke}`, `lineWidth: ${f(Number(s['stroke-width'] || 1))}`);
      if (s['stroke-linecap']) args.push(`cap: .${s['stroke-linecap']}`);
      if (s['stroke-linejoin']) args.push(`join: .${s['stroke-linejoin']}`);
      if (s['stroke-dasharray']) args.push(`dash: [${s['stroke-dasharray'].split(/[\s,]+/).map(Number).map(f).join(', ')}]`);
    }
    if (s.opacity !== undefined) args.push(`opacity: ${f(Number(s.opacity))}`);
    if (s['fill-opacity'] !== undefined) args.push(`fillOpacity: ${f(Number(s['fill-opacity']))}`);
    if (gradientId) args.push(gradientArg(gradients[gradientId], ink.cmds));
    args.forEach((x, i) => lines.push(`                ${x}${i < args.length - 1 || s['clip-path'] ? ',' : ''}`));
    if (s['clip-path']) {
      const clipId = /^url\(#(\w+)\)$/.exec(s['clip-path'])[1];
      lines.push('                clip: Path { p in');
      pushPath(clips[clipId]);
      lines.push('                }');
    }
    // swift-format keeps trailing commas only in multi-element collections.
    lines.push(p.inks.length > 1 ? '            ),' : '            )');
  });
  lines.push('        ]');
  lines.push('    }');
}
lines.push('}', '');
fs.writeFileSync(OUT, lines.join('\n'));
console.log(`wrote ${path.relative(repo, OUT)}: ${parts.length} parts, ${parts.reduce((n, p) => n + p.inks.length, 0)} inks, bounds ${minX},${minY} ${maxX - minX}x${maxY - minY}`);

// Optional: re-emit the flattened data as SVG, to eyeball that nothing was lost.
const pi = process.argv.indexOf('--preview');
if (pi > 0) {
  const d = cmds => cmds.map(([c, ...v]) => c + v.map(f).join(' ')).join('');
  const show = new Set(process.argv[pi + 2] ? process.argv[pi + 2].split(',') : parts.map(p => p.id));
  const defs = Object.entries(gradients).map(([id, g]) => `<linearGradient id="${id}" x1="${g.x1}" y1="${g.y1}" x2="${g.x2}" y2="${g.y2}">${g.stops.map(([o, c]) => `<stop offset="${o}" stop-color="${c}"/>`).join('')}</linearGradient>`).join('') +
    Object.entries(clips).map(([id, cmds]) => `<clipPath id="${id}"><path d="${d(cmds)}"/></clipPath>`).join('');
  const body = `<defs>${defs}</defs>` + parts.filter(p => show.has(p.id)).map(p => p.inks.map(({ cmds, style: s }) =>
    `<path d="${d(cmds)}"${s['clip-path'] ? ` clip-path="${s['clip-path']}"` : ''}${s['fill-opacity'] ? ` fill-opacity="${s['fill-opacity']}"` : ''} fill="${s.fill ?? (s.stroke && s.stroke !== 'none' ? 'none' : '#111')}" stroke="${s.stroke ?? 'none'}" stroke-width="${s['stroke-width'] ?? 1}" stroke-linecap="${s['stroke-linecap'] ?? 'butt'}" stroke-linejoin="${s['stroke-linejoin'] ?? 'miter'}"${s['stroke-dasharray'] ? ` stroke-dasharray="${s['stroke-dasharray']}"` : ''} opacity="${s.opacity ?? 1}"/>`).join('')).join('');
  const tx = texts.filter(t => show.has(t.part)).map(t => `<text x="${f(t.x)}" y="${f(t.y)}" text-anchor="middle" font-size="${t.size}" font-weight="700" font-family="sans-serif" fill="${t.fill}">${t.text}</text>`).join('');
  fs.writeFileSync(process.argv[pi + 1], `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${minX} ${minY} ${maxX - minX} ${maxY - minY}" width="${(maxX - minX) * 3}" height="${(maxY - minY) * 3}"><rect x="${minX}" y="${minY}" width="${maxX - minX}" height="${maxY - minY}" fill="#7FB7FF"/>${body}${tx}</svg>`);
}
