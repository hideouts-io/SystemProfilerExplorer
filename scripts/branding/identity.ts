/** Editable Open Layers geometry, reconstructed from the approved imagegen concept. */
export interface Palette {
  readonly front: string;
  readonly middle: string;
  readonly back: string;
  readonly ink: string;
  readonly secondary: string;
  readonly background: string;
}

export const light: Palette = {
  front: '#073754', middle: '#00bfc0', back: '#08608c',
  ink: '#073754', secondary: '#526675', background: '#f7f9fb',
};
export const dark: Palette = {
  front: '#c2fae5', middle: '#00d5cd', back: '#009b99',
  ink: '#f4f9fa', secondary: '#b4cbd4', background: '#07121b',
};
export const monoInk: Palette = { ...light, front: light.ink, middle: light.ink, back: light.ink };
export const monoWhite: Palette = { ...dark, front: '#ffffff', middle: '#ffffff', back: '#ffffff' };

export function svgDocument(width: number, height: number, content: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${content}</svg>`;
}

export function cardShape(x: number, y: number): string {
  return `<g transform="translate(${x} ${y}) matrix(1 .33 0 1 0 0)"><rect width="460" height="300" rx="48"/></g>`;
}

/** Masked overlaps preserve transparent breathing room and two true cutout data slots. */
export function mark(palette: Palette, id: string): string {
  return `<defs>
    <mask id="${id}-rear" maskUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000">
      <rect width="1000" height="1000" fill="white"/>
      <g fill="black" stroke="black" stroke-width="34">${cardShape(270, 265)}</g>
    </mask>
    <mask id="${id}-middle" maskUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000">
      <rect width="1000" height="1000" fill="white"/>
      <g fill="black" stroke="black" stroke-width="34">${cardShape(150, 390)}</g>
    </mask>
    <mask id="${id}-front" maskUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000">
      <rect width="1000" height="1000" fill="white"/>
      <g transform="translate(150 390) matrix(1 .33 0 1 0 0)" fill="black">
        <rect x="78" y="88" width="265" height="42" rx="21"/>
        <rect x="78" y="177" width="176" height="42" rx="21"/>
      </g>
    </mask>
  </defs>
  <g fill="${palette.back}" mask="url(#${id}-rear)">${cardShape(390, 140)}</g>
  <g fill="${palette.middle}" mask="url(#${id}-middle)">${cardShape(270, 265)}</g>
  <g fill="${palette.front}" mask="url(#${id}-front)">${cardShape(150, 390)}</g>`;
}

export function positionedMark(palette: Palette, id: string, x: number, y: number, size: number): string {
  return `<g transform="translate(${x} ${y}) scale(${size / 1000})">${mark(palette, id)}</g>`;
}

export function logoSvg(palette: Palette): string {
  return svgDocument(1000, 1000, mark(palette, 'logo'));
}

export function text(x: number, y: number, size: number, weight: number, ink: string, value: string): string {
  return `<text x="${x}" y="${y}" font-family="Helvetica Neue,Arial,sans-serif" font-size="${size}" font-weight="${weight}" fill="${ink}">${value}</text>`;
}

export function wordmarkSvg(palette: Palette): string {
  return svgDocument(1800, 420,
    positionedMark(palette, 'lockup', -35, -25, 455)
    + text(465, 182, 126, 650, palette.ink, 'System Profiler')
    + text(465, 325, 126, 350, palette.ink, 'Explorer'));
}

export function appIconSvg(): string {
  return svgDocument(1024, 1024, `<defs>
    <linearGradient id="tile" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#122d3f"/><stop offset="1" stop-color="#06131d"/></linearGradient>
    <linearGradient id="edge" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#80e8da" stop-opacity=".23"/><stop offset="1" stop-color="#80e8da" stop-opacity=".03"/></linearGradient>
  </defs>
  <rect x="40" y="40" width="944" height="944" rx="210" fill="url(#tile)"/>
  <rect x="41" y="41" width="942" height="942" rx="209" fill="none" stroke="url(#edge)" stroke-width="2"/>
  ${positionedMark(dark, 'app', 42, 48, 940)}`);
}

export function headerSvg(palette: Palette): string {
  return svgDocument(1600, 500,
    `<rect width="1600" height="500" rx="26" fill="${palette.background}"/>`
    + positionedMark(palette, 'header', 32, -4, 500)
    + text(560, 190, 72, 650, palette.ink, 'System Profiler')
    + text(560, 279, 72, 350, palette.ink, 'Explorer')
    + text(562, 351, 28, 400, palette.secondary, 'System information, made clear.')
    + text(562, 408, 20, 450, palette.secondary, 'Organized findings · Clear explanations · Local-first'));
}

export function reportSymbol(palette: Palette): string {
  return svgDocument(256, 256, `<g fill="none" stroke="${palette.front}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"><rect x="51" y="31" width="154" height="194" rx="26"/><path d="M84 79h88M84 125h88M84 171h56"/></g>`);
}

export function explanationSymbol(palette: Palette): string {
  return svgDocument(256, 256, `<path d="M57 39h142a27 27 0 0 1 27 27v97a27 27 0 0 1-27 27h-70l-48 31v-31H57a27 27 0 0 1-27-27V66a27 27 0 0 1 27-27Z" fill="none" stroke="${palette.front}" stroke-width="13" stroke-linejoin="round"/><g fill="${palette.front}"><circle cx="128" cy="83" r="9"/><rect x="121" y="110" width="14" height="47" rx="7"/></g>`);
}

export function comparisonSymbol(palette: Palette): string {
  return svgDocument(256, 256, `<g fill="none" stroke="${palette.front}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"><rect x="24" y="42" width="84" height="169" rx="18"/><rect x="148" y="42" width="84" height="169" rx="18"/><path d="M96 88h64m-16-16 16 16-16 16M160 165H96m16-16-16 16 16 16"/></g>`);
}
