import fs from 'node:fs';
import path from 'node:path';

// New code-native art. Fixed seeds make every floor / prop reproducible.
// SVGs are imported once as textures by Godot; no paths are drawn at runtime.
const root = path.resolve(import.meta.dirname, '..', 'assets', 'art', 'r33');
fs.mkdirSync(root, { recursive: true });
let state = 33001;
const rnd = () => { state = (Math.imul(state, 1664525) + 1013904223) >>> 0; return state / 4294967296; };
const n = v => v.toFixed(2);
const palettes = {
  rift_void: { stone: '#36435c', light: '#526786', edge: '#7891af', dark: '#252a40', stain: '#37455d', metal: '#b9a67a', accent: '#897bcd', moss: '#4a5570' },
  wasteland_farm: { stone: '#414957', light: '#65747c', edge: '#91a7b0', dark: '#2b333e', stain: '#455c66', metal: '#c7b584', accent: '#72c3bd', moss: '#4a6a70' },
  ember_rift: { stone: '#4b4250', light: '#786b7e', edge: '#a397ae', dark: '#302837', stain: '#58485b', metal: '#cab080', accent: '#d28fc5', moss: '#67566d' },
};
function svg(w, h, p, body) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs><linearGradient id="stone" x1="0" x2=".65" y1="0" y2="1"><stop stop-color="${p.light}"/><stop offset=".5" stop-color="${p.stone}"/><stop offset="1" stop-color="${p.dark}"/></linearGradient><linearGradient id="metal" x1="0" x2="1" y1="0" y2="1"><stop stop-color="${p.metal}"/><stop offset=".45" stop-color="${p.edge}"/><stop offset="1" stop-color="${p.dark}"/></linearGradient><radialGradient id="shadow"><stop stop-color="#05080a" stop-opacity=".7"/><stop offset="1" stop-color="#05080a" stop-opacity="0"/></radialGradient><radialGradient id="glow"><stop stop-color="${p.accent}" stop-opacity=".26"/><stop offset="1" stop-color="${p.accent}" stop-opacity="0"/></radialGradient></defs>${body}</svg>`;
}
for (const [theme, p] of Object.entries(palettes)) {
  state = { rift_void: 33001, wasteland_farm: 33119, ember_rift: 33371 }[theme];
  let body = `<rect width="960" height="768" fill="${p.dark}"/>`;
  for (let row = -1; row < 9; row++) for (let col = -1; col < 9; col++) {
    const x = col * 120 + (row % 2 ? 60 : 0), y = row * 96;
    const cut = 4 + rnd() * 6;
    const pts = [[x+cut,y+3],[x+112,y+3],[x+117,y+cut],[x+117,y+86],[x+109,y+92],[x+8,y+92],[x+3,y+84],[x+3,y+cut]];
    const points = pts.map(q => q.map(n).join(',')).join(' ');
    body += `<polygon points="${points}" fill="url(#stone)" opacity="${n(.72+rnd()*.21)}"/><path d="M ${n(x+cut)} ${y+4} H ${x+111} L ${x+116} ${n(y+cut)}" fill="none" stroke="${p.edge}" stroke-width=".9" opacity=".22"/><path d="M ${x+4} ${y+83} L ${x+9} ${y+91} H ${x+109}" fill="none" stroke="#070b0e" stroke-width="1.2" opacity=".16"/>`;
    for (let s = 0; s < 7; s++) {
      const qx = x+8+rnd()*101, qy=y+8+rnd()*78, light = rnd()>.7;
      body += `<path d="M ${n(qx)} ${n(qy)} l ${n(1+rnd()*10)} ${n(-1+rnd()*1.7)}" stroke="${light?p.edge:p.dark}" opacity="${n(.025+rnd()*.05)}" stroke-width="${n(.3+rnd()*.7)}"/>`;
    }
    if (rnd() < .29) {
      const qx=x+20+rnd()*65, qy=y+3;
      body+=`<path d="M ${n(qx)} ${n(qy)} l -3 18 6 11 -12 14 4 20" fill="none" stroke="${p.dark}" stroke-width="1.4" opacity=".3"/><path d="M ${n(qx+1)} ${n(qy+1)} l -3 18 6 11 -12 14 4 20" fill="none" stroke="${p.edge}" stroke-width=".5" opacity=".16"/>`;
    }
    if (theme === 'wasteland_farm' && rnd()<.22) {
      for(let a=0;a<8;a++)body+=`<ellipse cx="${n(x+4+rnd()*106)}" cy="${n(y+90+rnd()*3)}" rx="${n(3+rnd()*8)}" ry="${n(1+rnd()*2)}" fill="${p.moss}" opacity="${n(.3+rnd()*.35)}"/>`;
    }
    if(rnd()<.12) {
      const glyph = theme==='rift_void' ? `M ${x+45} ${y+43} l 13 -12 13 12 -13 12 Z M ${x+58} ${y+26} v 34 M ${x+40} ${y+43} h 36` : theme==='wasteland_farm' ? `M ${x+45} ${y+53} Q ${x+58} ${y+24} ${x+72} ${y+53} M ${x+58} ${y+53} v -27 M ${x+45} ${y+44} l 13 9 14 -9` : `M ${x+45} ${y+53} l 13 -23 13 23 -13 -6 Z M ${x+44} ${y+58} h 28`;
      body+=`<path d="${glyph}" fill="none" stroke="${p.metal}" stroke-width=".8" opacity=".09"/>`;
    }
  }
  for (let a=0;a<32;a++) body+=`<ellipse cx="${n(rnd()*960)}" cy="${n(rnd()*768)}" rx="${n(6+rnd()*45)}" ry="${n(3+rnd()*17)}" fill="${rnd()>.6?p.moss:p.stain}" opacity="${n(.03+rnd()*.06)}"/>`;
  // Testers found the repeated seams too prominent. Blend toward the existing
  // midtone, preserving stage brightness while lowering floor-only contrast.
  body+=`<rect width="960" height="768" fill="${p.stone}" opacity=".22"/>`;
  fs.writeFileSync(path.join(root,`${theme}_floor.svg`), svg(960,768,p,body));

  // Low cut column: elliptical top, weight-bearing pedestal and contact shadow.
  body=`<ellipse cx="104" cy="145" rx="79" ry="25" fill="url(#shadow)"/><path d="M43 117 L53 106 H121 L141 122 V139 L116 153 H60 L43 141Z" fill="${p.dark}"/><path d="M43 117 L67 103 H120 L141 122 116 138 H64Z" fill="url(#stone)" stroke="${p.edge}" stroke-opacity=".36"/><path d="M68 70 L71 119 Q95 135 124 119 L126 65Z" fill="url(#stone)" stroke="${p.dark}" stroke-width="2"/><path d="M78 80 v39 M92 79 v46 M110 81 v43" stroke="${p.dark}" stroke-width="3" opacity=".7"/><path d="M80 80 v36 M94 81 v40 M112 81 v38" stroke="${p.edge}" stroke-width="1" opacity=".43"/><path d="M64 67 L80 53 100 57 114 47 132 66 123 81 103 83 79 79Z" fill="url(#stone)" stroke="${p.edge}" stroke-opacity=".45"/><path d="M80 54 l12 16 -7 11 M113 50 l-3 18 13 13" stroke="${p.dark}" stroke-width="2" fill="none"/><path d="M84 58 l-2 7 15 1" stroke="${p.edge}" opacity=".5" fill="none"/>`;
  fs.writeFileSync(path.join(root,`${theme}_column.svg`),svg(200,180,p,body));
  // Low rubble shares the same stone facets, shadow direction, and 3/4 view.
  body='<ellipse cx="97" cy="78" rx="86" ry="24" fill="url(#shadow)"/>';
  const chunks=[[48,52,29,21],[92,62,32,17],[131,48,24,23],[152,77,18,12],[63,82,18,12],[21,82,12,9]];
  for(const [x,y,w,h]of chunks)body+=`<path d="M ${x-w} ${y} L ${x-w+4} ${y-h} ${x+7} ${y-h-5} ${x+w} ${y-8} ${x+w-4} ${y+10} ${x} ${y+14}Z" fill="${p.dark}" stroke="${p.dark}"/><path d="M ${x-w} ${y} L ${x-w+4} ${y-h} ${x+7} ${y-h-5} ${x+w} ${y-8} ${x+3} ${y+3}Z" fill="url(#stone)" stroke="${p.edge}" stroke-opacity=".24"/><path d="M ${x-w+4} ${y-h} l 15 -3 9 8" fill="none" stroke="${p.edge}" opacity=".4"/>`;
  fs.writeFileSync(path.join(root,`${theme}_rubble.svg`),svg(190,115,p,body));
  // Weathered grave marker / ward. Never an enormous screen border.
  body=`<ellipse cx="92" cy="186" rx="78" ry="28" fill="url(#shadow)"/><path d="M49 174 L71 160 130 166 145 183 122 198 63 193Z" fill="url(#stone)" stroke="${p.edge}" stroke-opacity=".25"/><path d="M73 56 L93 27 110 42 126 172 103 184 64 173Z" fill="url(#stone)" stroke="${p.dark}" stroke-width="2"/><path d="M73 56 L93 27 99 176 64 173Z" fill="${p.light}" opacity=".5"/><path d="M94 29 L110 43 126 172 103 184 99 176Z" fill="${p.dark}" opacity=".65"/><path d="M84 69 L94 77 86 87 93 113 83 127 87 157" fill="none" stroke="${p.dark}" stroke-width="2"/><path d="M80 98 l9 -12 9 12 -9 12Z M89 82 v34" fill="none" stroke="${p.metal}" stroke-width="1.5" opacity=".57"/><path d="M77 136 l11 2 M78 145 l11 2" stroke="${p.edge}" opacity=".35"/>`;
  fs.writeFileSync(path.join(root,`${theme}_ward.svg`),svg(190,225,p,body));
  // A sunken, traversable stone seal: its proportions match the ground plane.
  body=`<ellipse cx="260" cy="189" rx="244" ry="126" fill="url(#shadow)"/><ellipse cx="250" cy="155" rx="224" ry="132" fill="${p.dark}"/><ellipse cx="250" cy="151" rx="218" ry="127" fill="url(#stone)" stroke="${p.edge}" stroke-width="3" stroke-opacity=".35"/><ellipse cx="250" cy="151" rx="188" ry="108" fill="none" stroke="${p.metal}" stroke-width="5" opacity=".43"/><ellipse cx="250" cy="151" rx="180" ry="103" fill="none" stroke="${p.dark}" stroke-width="2"/><ellipse cx="250" cy="151" rx="145" ry="83" fill="${p.stone}" stroke="${p.edge}" stroke-width="1" stroke-opacity=".26"/>`;
  for(let a=0;a<24;a++){const t=a*Math.PI/12;const x=250+205*Math.cos(t),y=151+118*Math.sin(t);body+=`<path d="M ${n(x)} ${n(y)} l ${n(-13*Math.cos(t))} ${n(-8*Math.sin(t))}" stroke="${p.dark}" stroke-width="2"/>`;}
  const emblem = theme==='rift_void' ? 'M250 88 L309 150 250 213 191 150Z M250 88 V213 M191 150 H309 M209 107 L291 191 M291 107 L209 191' : theme==='wasteland_farm' ? 'M250 90 Q170 112 250 210 Q330 112 250 90Z M190 151 Q220 96 280 96 M190 151 Q220 207 280 207 M250 92 V210 M198 151 H302' : 'M250 94 L315 174 250 149 185 174Z M250 125 L287 195 250 177 213 195Z M199 151 H301';
  body+=`<path d="${emblem}" fill="none" stroke="${p.metal}" stroke-width="2.2" opacity=".58"/><ellipse cx="250" cy="151" rx="40" ry="24" fill="${p.dark}" stroke="${p.metal}" stroke-width="2" opacity=".7"/><path d="M81 93 l41 26 19 -4 13 12 M407 210 l-48 -13 -10 -25 -24 -9 M188 263 l13 -34 -11 -18" fill="none" stroke="${p.dark}" stroke-width="3"/><path d="M83 94 l40 26 19 -4 13 12" fill="none" stroke="${p.edge}" stroke-width=".7" opacity=".45"/>`;
  for (const [gx,gy] of [[250,41],[440,151],[250,262],[61,151]]) body+=`<ellipse cx="${gx}" cy="${gy}" rx="26" ry="16" fill="url(#glow)"/><path d="M${gx-12} ${gy} l12 -9 12 9 -12 9Z" fill="${p.dark}" stroke="${p.metal}" stroke-width="2"/><path d="M${gx-8} ${gy} l8 -6 8 6 -8 6Z" fill="${p.accent}"/><path d="M${gx-8} ${gy} l8 -6 v6Z" fill="#e5dcfc" opacity=".73"/>`;
  fs.writeFileSync(path.join(root,`${theme}_seal.svg`),svg(512,320,p,body));
  // A brazier is contained emissive detail, with light falling onto its base.
  body=`<ellipse cx="85" cy="149" rx="81" ry="37" fill="url(#glow)"/><ellipse cx="89" cy="151" rx="66" ry="22" fill="url(#shadow)"/><path d="M50 145 L71 132 H108 L126 148 108 163 H70Z" fill="url(#stone)" stroke="${p.edge}" stroke-opacity=".25"/><path d="M70 128 L73 98 H109 L112 139 87 149Z" fill="url(#metal)"/><path d="M58 83 L61 108 Q87 127 119 110 L126 86Z" fill="${p.dark}" stroke="${p.metal}" stroke-width="2"/><ellipse cx="92" cy="86" rx="34" ry="17" fill="${p.metal}"/><ellipse cx="92" cy="84" rx="29" ry="13" fill="${p.dark}"/><path d="M75 85 Q61 69 81 56 Q75 70 87 66 Q78 46 96 32 Q86 61 107 65 Q111 54 119 52 Q126 80 105 89Z" fill="${p.accent}" opacity=".8"/><path d="M83 83 Q80 71 94 60 Q91 73 107 76 L102 85Z" fill="#e0b875" opacity=".6"/><path d="M63 102 Q88 117 116 103" fill="none" stroke="${p.metal}" stroke-width="1.2"/>`;
  body+=`<path d="M89 84 Q85 77 97 68 Q92 78 99 84Z" fill="#eee9fd" opacity=".86"/>`;
  fs.writeFileSync(path.join(root,`${theme}_brazier.svg`),svg(180,190,p,body));
}
console.log(`R33_ART_BUILD assets=18 ground=960x768 seeds=fixed output=${root}`);
