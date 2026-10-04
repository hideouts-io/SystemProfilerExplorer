/** Reproduce vector-derived assets and exact-text layouts around the retained imagegen artwork. */
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { copyFile, mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import { appIconSvg, comparisonSymbol, dark, explanationSymbol, headerSvg, light, logoSvg, monoInk, monoWhite, positionedMark, reportSymbol, svgDocument, text, wordmarkSvg } from './identity.ts';

interface Size { readonly width: number; readonly height: number; }
interface AssetRecord {
  readonly path: string;
  readonly width: number | null;
  readonly height: number | null;
  readonly transparent: boolean | null;
  readonly bytes: number;
  readonly sha256: string;
  readonly use: string;
}

const ROOT: string = fileURLToPath(new URL('../..', import.meta.url));
const ASSETS: string = join(ROOT, 'branding/open-layers');
const CATALOG: string = join(ROOT, 'SystemProfilerExplorer/Resources/Assets.xcassets');
const TAGLINE: string = 'System information, made clear.';

async function saveText(path: string, value: string): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, value, 'utf8');
}

async function renderSvg(path: string, svg: string, size: Size): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await sharp(Buffer.from(svg)).resize(size.width, size.height).png({ compressionLevel: 9 }).toFile(path);
}

async function saveVectorPair(stem: string, svg: string, size: Size): Promise<void> {
  await saveText(join(ASSETS, `${stem}.svg`), svg);
  await renderSvg(join(ASSETS, `${stem}.png`), svg, size);
}

async function logoAssets(): Promise<void> {
  const variants = [ ['light', light], ['dark', dark], ['mono-ink', monoInk], ['mono-white', monoWhite] ] as const;
  for (const [name, palette] of variants) {
    const svg: string = logoSvg(palette);
    await saveText(join(ASSETS, `sources/mark-${name}.svg`), svg);
    await saveVectorPair(`logos/logo-${name}`, svg, { width: 1024, height: 1024 });
  }
  for (const [name, palette] of [['light', light], ['dark', dark]] as const) {
    await saveVectorPair(`logos/wordmark-${name}`, wordmarkSvg(palette), { width: 1800, height: 420 });
    await saveVectorPair(`github/readme-header-${name}`, headerSvg(palette), { width: 1600, height: 500 });
  }
  await copyFile(join(ASSETS, 'github/readme-header-dark.png'), join(ASSETS, 'github/readme-header.png'));
  await copyFile(join(ASSETS, 'logos/logo-light.png'), join(ROOT, 'docs/images/system-profiler-explorer-logo.png'));
}

async function iconAssets(): Promise<void> {
  const svg: string = appIconSvg();
  await saveVectorPair('icons/app-icon', svg, { width: 1024, height: 1024 });
  const sizes: readonly number[] = [16, 32, 64, 128, 256, 512, 1024];
  for (const size of sizes) {
    await renderSvg(join(ASSETS, `icons/app-icon-${size}.png`), svg, { width: size, height: size });
    const filename: string = size === 1024 ? 'AppIcon.png' : `AppIcon-${size}.png`;
    await copyFile(join(ASSETS, `icons/app-icon-${size}.png`), join(CATALOG, 'AppIcon.appiconset', filename));
  }
  const iconset: string = join(ASSETS, 'icons/AppIcon.iconset');
  await mkdir(iconset, { recursive: true });
  for (const size of [16, 32, 128, 256, 512] as const) {
    await copyFile(join(ASSETS, `icons/app-icon-${size}.png`), join(iconset, `icon_${size}x${size}.png`));
    await copyFile(join(ASSETS, `icons/app-icon-${size * 2}.png`), join(iconset, `icon_${size}x${size}@2x.png`));
  }
  execFileSync('/usr/bin/iconutil', ['-c', 'icns', iconset, '-o', join(ASSETS, 'icons/AppIcon.icns')], { stdio: 'inherit' });
  await renderSvg(join(ASSETS, 'website/favicon-32.png'), svg, { width: 32, height: 32 });
  await renderSvg(join(ASSETS, 'website/apple-touch-icon.png'), svg, { width: 180, height: 180 });
  await renderSvg(join(ASSETS, 'website/web-icon-192.png'), svg, { width: 192, height: 192 });
  await renderSvg(join(ASSETS, 'website/web-icon-512.png'), svg, { width: 512, height: 512 });
  await copyFile(join(ASSETS, 'icons/app-icon.png'), join(ASSETS, 'website/app-icon.png'));
  await copyFile(join(ASSETS, 'website/web-icon-192.png'), join(ASSETS, 'website/web-app-icon-192.png'));
  await copyFile(join(ASSETS, 'website/web-icon-512.png'), join(ASSETS, 'website/web-app-icon-512.png'));
  await copyFile(join(ASSETS, 'logos/logo-light.svg'), join(ASSETS, 'website/logo-on-light.svg'));
  await copyFile(join(ASSETS, 'logos/logo-dark.svg'), join(ASSETS, 'website/logo-on-dark.svg'));
  await saveText(join(ASSETS, 'website/favicon.svg'), svg);
  const icoImages: readonly Buffer[] = await Promise.all([16, 32].map(async (size: number): Promise<Buffer> => readFile(join(ASSETS, `icons/app-icon-${size}.png`))));
  const icoHeader: Buffer = Buffer.alloc(6 + 16 * icoImages.length);
  icoHeader.writeUInt16LE(1, 2);
  icoHeader.writeUInt16LE(icoImages.length, 4);
  let offset: number = icoHeader.length;
  for (const [index, image] of icoImages.entries()) {
    const size: number = index === 0 ? 16 : 32;
    const entry: number = 6 + index * 16;
    icoHeader[entry] = size;
    icoHeader[entry + 1] = size;
    icoHeader.writeUInt16LE(1, entry + 4);
    icoHeader.writeUInt16LE(32, entry + 6);
    icoHeader.writeUInt32LE(image.length, entry + 8);
    icoHeader.writeUInt32LE(offset, entry + 12);
    offset += image.length;
  }
  await writeFile(join(ASSETS, 'website/favicon.ico'), Buffer.concat([icoHeader, ...icoImages]));
}

async function appAssets(): Promise<void> {
  const logoCatalog: string = join(CATALOG, 'BrandLogo.imageset');
  const welcomeCatalog: string = join(CATALOG, 'WelcomeArtwork.imageset');
  await mkdir(logoCatalog, { recursive: true });
  await mkdir(welcomeCatalog, { recursive: true });
  await renderSvg(join(logoCatalog, 'brand-logo-light.png'), logoSvg(light), { width: 512, height: 512 });
  await renderSvg(join(logoCatalog, 'brand-logo-dark.png'), logoSvg(dark), { width: 512, height: 512 });
  await saveText(join(logoCatalog, 'Contents.json'), JSON.stringify({ images: [
    { filename: 'brand-logo-light.png', idiom: 'universal' },
    { appearances: [{ appearance: 'luminosity', value: 'dark' }], filename: 'brand-logo-dark.png', idiom: 'universal' },
  ], info: { author: 'xcode', version: 1 } }, null, 2) + '\n');
  await sharp(join(ASSETS, 'sources/imagegen-welcome.png')).resize(1024, 512).png().toFile(join(ASSETS, 'app/welcome-artwork.png'));
  await copyFile(join(ASSETS, 'app/welcome-artwork.png'), join(welcomeCatalog, 'welcome-artwork.png'));
  await saveText(join(welcomeCatalog, 'Contents.json'), JSON.stringify({ images: [{ filename: 'welcome-artwork.png', idiom: 'universal' }], info: { author: 'xcode', version: 1 } }, null, 2) + '\n');
  const aboutSvg: string = svgDocument(1200, 600, `<rect width="1200" height="600" rx="32" fill="${dark.background}"/>`
    + positionedMark(dark, 'about', 370, 12, 440)
    + text(286, 425, 48, 650, dark.ink, 'System Profiler Explorer')
    + text(362, 481, 27, 400, dark.secondary, TAGLINE)
    + text(235, 543, 22, 450, dark.secondary, 'Organized findings · Clear explanations · Local-first'));
  await saveVectorPair('app/about-artwork', aboutSvg, { width: 1200, height: 600 });
  for (const [name, createSvg] of [['report', reportSymbol], ['explain', explanationSymbol], ['compare', comparisonSymbol]] as const) {
    for (const [theme, palette] of [['light', light], ['dark', dark]] as const) {
      await saveVectorPair(`app/feature-${name}-${theme}`, createSvg(palette), { width: 256, height: 256 });
    }
  }
}

function desktopCopy(): string {
  return positionedMark(dark, 'hero', 80, 22, 195)
    + text(108, 297, 88, 650, dark.ink, 'System Profiler')
    + text(108, 393, 88, 350, dark.ink, 'Explorer')
    + text(110, 479, 34, 400, dark.secondary, TAGLINE)
    + text(110, 541, 23, 450, dark.secondary, 'Organized findings · Clear explanations · Local-first');
}

function socialCopy(width: number, height: number): string {
  const scale: number = width / 1280;
  return `<g transform="scale(${scale})">`
    + positionedMark(dark, 'social', 39, 28, 190)
    + text(69, 290, 64, 650, dark.ink, 'System Profiler')
    + text(69, 369, 64, 350, dark.ink, 'Explorer')
    + text(71, 442, 28, 400, dark.secondary, TAGLINE)
    + text(72, height / scale - 58, 18, 450, dark.secondary, 'Organized findings · Clear explanations · Local-first')
    + '</g>';
}

function mobileCopy(): string {
  return positionedMark(dark, 'mobile', 42, 29, 270)
    + text(75, 414, 80, 650, dark.ink, 'System Profiler')
    + text(75, 511, 80, 350, dark.ink, 'Explorer')
    + text(78, 608, 41, 400, dark.secondary, 'System information,')
    + text(78, 665, 41, 400, dark.secondary, 'made clear.')
    + text(79, 751, 26, 450, dark.secondary, 'Organized findings')
    + text(79, 794, 26, 450, dark.secondary, 'Clear explanations · Local-first');
}

async function composeBackground(path: string, source: string, size: Size, copy: string, position: string): Promise<void> {
  const overlay: Buffer = Buffer.from(svgDocument(size.width, size.height, copy));
  await sharp(source).resize(size.width, size.height, { fit: 'cover', position }).composite([{ input: overlay }]).png({ compressionLevel: 9 }).toFile(path);
}

async function promotionalAssets(): Promise<void> {
  const landscape: string = join(ASSETS, 'sources/imagegen-hero-landscape.png');
  const portrait: string = join(ASSETS, 'sources/imagegen-hero-portrait.png');
  await composeBackground(join(ASSETS, 'website/hero-desktop.png'), landscape, { width: 2000, height: 667 }, desktopCopy(), 'centre');
  const tablet: string = svgDocument(1536, 1024, `<rect width="1536" height="1024" fill="#06121b"/>`
    + positionedMark(dark, 'tablet', 61, 14, 195)
    + text(87, 275, 75, 650, dark.ink, 'System Profiler')
    + text(87, 360, 75, 350, dark.ink, 'Explorer')
    + text(90, 434, 31, 400, dark.secondary, TAGLINE)
    + text(90, 489, 22, 450, dark.secondary, 'Organized findings · Clear explanations · Local-first'));
  const tabletArt: Buffer = await sharp(landscape).resize(1536, 512).png().toBuffer();
  await sharp(Buffer.from(tablet)).composite([{ input: tabletArt, left: 0, top: 512 }]).png().toFile(join(ASSETS, 'website/hero-tablet.png'));
  await composeBackground(join(ASSETS, 'website/hero-mobile.png'), portrait, { width: 941, height: 1672 }, mobileCopy(), 'centre');
  const shade: string = `<defs><linearGradient id="shade"><stop stop-color="#06121b"/><stop offset=".53" stop-color="#06121b" stop-opacity=".88"/><stop offset=".82" stop-color="#06121b" stop-opacity=".12"/></linearGradient></defs>`;
  for (const [filename, size] of [
    ['github/social-preview.png', { width: 1280, height: 640 }],
    ['website/social-preview.png', { width: 1200, height: 630 }],
    ['website/project-card.png', { width: 1200, height: 675 }],
  ] as const) {
    const copy: string = `${shade}<rect width="${size.width}" height="${size.height}" fill="url(#shade)"/>${socialCopy(size.width, size.height)}`;
    await composeBackground(join(ASSETS, filename), landscape, size, copy, 'east');
  }
  const features: string = svgDocument(1600, 900, `<rect width="1600" height="900" rx="28" fill="${dark.background}"/>`
    + text(92, 105, 46, 650, dark.ink, 'Explore. Understand. Compare.')
    + text(94, 163, 28, 400, dark.secondary, 'System information, made clear.')
    + text(145, 770, 30, 600, dark.ink, 'Organized findings')
    + text(632, 770, 30, 600, dark.ink, 'Clear explanations')
    + text(1115, 770, 30, 600, dark.ink, 'Snapshot comparison')
    + text(145, 822, 21, 400, dark.secondary, 'Browse subjects and source values')
    + text(632, 822, 21, 400, dark.secondary, 'Understand meaning and limits')
    + text(1115, 822, 21, 400, dark.secondary, 'Review what changed over time'));
  const illustration: Buffer = await sharp(join(ASSETS, 'sources/imagegen-welcome.png')).resize(1420, 710).png().toBuffer();
  await sharp(Buffer.from(features)).composite([{ input: illustration, left: 90, top: 90 }]).png().toFile(join(ASSETS, 'website/features-overview.png'));
  await copyFile(join(ASSETS, 'website/features-overview.png'), join(ASSETS, 'github/features-overview.png'));
  await copyFile(join(ASSETS, 'website/social-preview.png'), join(ASSETS, 'website/og-image.png'));
  for (const filename of ['hero-desktop', 'hero-tablet', 'hero-mobile', 'project-card', 'features-overview'] as const) {
    await sharp(join(ASSETS, `website/${filename}.png`)).webp({ quality: 94 }).toFile(join(ASSETS, `website/${filename}.webp`));
  }
  await sharp(join(ASSETS, 'website/social-preview.png')).webp({ quality: 94 }).toFile(join(ASSETS, 'website/social-sharing.webp'));
}

async function previewAssets(): Promise<void> {
  const tests: string = svgDocument(1200, 570, `<rect width="600" height="570" fill="${light.background}"/><rect x="600" width="600" height="570" fill="${dark.background}"/>`
    + text(35, 56, 22, 600, light.ink, 'Light background')
    + text(635, 56, 22, 600, dark.ink, 'Dark background')
    + positionedMark(light, 'preview-light', 95, 65, 410)
    + positionedMark(dark, 'preview-dark', 695, 65, 410));
  await renderSvg(join(ASSETS, 'previews/logo-light-dark.png'), tests, { width: 1200, height: 570 });
  const iconPreview: string = svgDocument(1200, 270, `<rect width="1200" height="270" fill="${dark.background}"/>`
    + text(30, 49, 23, 500, dark.ink, 'Native icon sizes · actual pixels, no enlarged substitutes')
    + text(36, 229, 17, 450, dark.secondary, '16px') + text(126, 229, 17, 450, dark.secondary, '32px')
    + text(239, 229, 17, 450, dark.secondary, '64px') + text(412, 229, 17, 450, dark.secondary, '128px'));
  const layers = await Promise.all(([16, 32, 64, 128] as const).map(async (size: number, index: number) => ({
    input: await readFile(join(ASSETS, `icons/app-icon-${size}.png`)),
    left: [40, 130, 240, 400][index]!, top: 178 - size,
  })));
  await sharp(Buffer.from(iconPreview)).composite(layers).png().toFile(join(ASSETS, 'previews/icon-small-sizes.png'));
  const welcome: Buffer = await sharp(join(ASSETS, 'app/welcome-artwork.png')).resize(340, 170).toBuffer();
  const welcomePreview: string = svgDocument(800, 240, `<rect width="400" height="240" fill="${light.background}"/><rect x="400" width="400" height="240" fill="${dark.background}"/>`
    + text(30, 34, 18, 450, light.ink, 'Welcome artwork · actual display size')
    + text(430, 34, 18, 450, dark.ink, 'Welcome artwork · actual display size'));
  await sharp(Buffer.from(welcomePreview)).composite([{ input: welcome, left: 30, top: 55 }, { input: welcome, left: 430, top: 55 }]).png().toFile(join(ASSETS, 'previews/welcome-light-dark.png'));
  const previews: readonly string[] = ['previews/logo-light-dark.png', 'icons/app-icon.png', 'github/readme-header-dark.png', 'github/social-preview.png', 'website/hero-desktop.png', 'website/hero-mobile.png', 'app/about-artwork.png', 'website/features-overview.png', 'previews/icon-small-sizes.png'];
  const tiles = await Promise.all(previews.map(async (path: string, index: number) => {
    const thumbnail: Buffer = await sharp(join(ASSETS, path)).resize(470, 240, { fit: 'contain', background: '#07121b' }).png().toBuffer();
    return { input: thumbnail, left: 15 + (index % 3) * 500, top: 50 + Math.floor(index / 3) * 300 };
  }));
  const labels: string = previews.map((path: string, index: number): string => text(22 + (index % 3) * 500, 321 + Math.floor(index / 3) * 300, 17, 450, dark.ink, path)).join('');
  await sharp(Buffer.from(svgDocument(1500, 950, `<rect width="1500" height="950" fill="#07121b"/>${labels}`))).composite(tiles).png().toFile(join(ASSETS, 'previews/contact-sheet.png'));
}

async function filePaths(path: string): Promise<readonly string[]> {
  const entries = await readdir(path, { withFileTypes: true });
  const nested: readonly (readonly string[])[] = await Promise.all(entries.map(async (entry): Promise<readonly string[]> => {
    const full: string = join(path, entry.name);
    return entry.isDirectory() ? filePaths(full) : [full];
  }));
  return nested.flat().sort();
}

function usage(path: string): string {
  if (path.startsWith('sources/')) return 'Editable vector master or retained original imagegen source';
  if (path.startsWith('icons/')) return 'macOS application icon and portable icon packaging';
  if (path.startsWith('logos/')) return 'Transparent standalone logo or editable wordmark';
  if (path.startsWith('app/')) return 'Welcome, About, or supporting feature graphic';
  if (path.startsWith('github/')) return 'README branding or manually uploaded GitHub social preview';
  if (path.startsWith('website/')) return 'hideouts.io project presentation, responsive hero, or web icon';
  return 'Local visual validation and review';
}

async function inventory(): Promise<void> {
  const paths: readonly string[] = await filePaths(ASSETS);
  const records: readonly AssetRecord[] = await Promise.all(paths.filter((path: string): boolean => !path.endsWith('asset-inventory.json') && !path.endsWith('index.html')).map(async (path: string): Promise<AssetRecord> => {
    const data: Buffer = await readFile(path);
    const metadata = /\.(png|svg|jpg|webp)$/.test(path) ? await sharp(data).metadata() : null;
    const statistics = metadata?.hasAlpha === true ? await sharp(data).stats() : null;
    const transparent: boolean | null = metadata === null ? null : metadata.hasAlpha === true && statistics !== null && statistics.channels[statistics.channels.length - 1]!.min < 255;
    const local: string = relative(ASSETS, path);
    return { path: local, width: metadata?.width ?? null, height: metadata?.height ?? null, transparent,
      bytes: data.length, sha256: createHash('sha256').update(data).digest('hex'), use: usage(local) };
  }));
  await saveText(join(ASSETS, 'asset-inventory.json'), JSON.stringify({ identity: 'Open Layers', tagline: TAGLINE, vectorSource: 'sources/mark-light.svg', editableFont: 'Helvetica Neue, Arial, sans-serif', assets: records }, null, 2) + '\n');
  const images: readonly AssetRecord[] = records.filter((record: AssetRecord): boolean => record.path.endsWith('.png') && !record.path.includes('AppIcon.iconset') && !record.path.startsWith('sources/'));
  const cards: string = images.map((record: AssetRecord): string => `<figure><a href="${record.path}"><img class="${record.path.endsWith('-light.png') || record.path.includes('mono-ink') ? 'light-preview' : 'dark-preview'}" src="${record.path}" alt="${record.path}" loading="lazy"/></a><figcaption>${record.path}<small>${record.width} × ${record.height} · ${record.transparent ? 'Transparent' : 'Opaque'}</small></figcaption></figure>`).join('\n');
  await saveText(join(ASSETS, 'index.html'), `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>System Profiler Explorer · Open Layers</title><style>body{margin:0;background:#07121b;color:#f4f9fa;font-family:system-ui,sans-serif;padding:32px}h1{font-weight:650}p{color:#b4cbd4}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}figure{margin:0;padding:16px;background:#102431;border-radius:18px}img{display:block;width:100%;height:240px;object-fit:contain;background:linear-gradient(45deg,#1a3443 25%,transparent 25%),linear-gradient(-45deg,#1a3443 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#1a3443 75%),linear-gradient(-45deg,transparent 75%,#1a3443 75%);background-size:20px 20px;background-position:0 0,0 10px,10px -10px,-10px 0}img.light-preview{background-color:#f7f9fb;background-image:linear-gradient(45deg,#e5edf2 25%,transparent 25%),linear-gradient(-45deg,#e5edf2 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#e5edf2 75%),linear-gradient(-45deg,transparent 75%,#e5edf2 75%)}figcaption{margin-top:14px;font-size:14px;overflow-wrap:anywhere}small{display:block;color:#b4cbd4;margin-top:5px}a{color:#5eead4}</style><h1>System Profiler Explorer · Open Layers</h1><p>Approved identity · System information, made clear.</p><p><a href="asset-inventory.json">Asset dimensions, uses, transparency, and SHA-256 inventory</a></p><main>${cards}</main></html>\n`);
  console.log(JSON.stringify({ assetCount: records.length, inventory: join(ASSETS, 'asset-inventory.json'), gallery: join(ASSETS, 'index.html') }));
}

await logoAssets();
await iconAssets();
await appAssets();
await promotionalAssets();
await previewAssets();
await inventory();
