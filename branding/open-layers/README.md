# Open Layers identity

The approved System Profiler Explorer identity is three offset information cards with two open data slots. It represents organized findings and expanding explanations, not a security verdict. The original logo is not part of this design.

## Production files

The [asset inventory](asset-inventory.json) records dimensions, transparency, intended use and file hashes. The [preview gallery](index.html) and [contact sheet](previews/contact-sheet.png) show the collection together.

| Folder | Intended use |
| --- | --- |
| `logos/` | Transparent marks, light/dark treatments, monochrome marks and wordmarks |
| `icons/` | macOS icon master, complete iconset and ICNS |
| `app/` | Welcome, About and complementary in-app artwork |
| `github/` | Theme-aware README headers and repository social preview |
| `website/` | Responsive hideouts.io heroes, sharing images, project card and favicons |
| `sources/` | Editable production SVG masters, original imagegen artwork and exact prompts |
| `previews/` | Contact sheet, light/dark artwork checks and actual-size icon checks |

The exact product name is **System Profiler Explorer**. The brand line is **System information, made clear.** Feature copy describes organized findings, clear explanations and local-first processing. Do not imply that a profiler report proves compromise, completeness or a clean bill of health.

## Editable originals and generated artwork

The production mark is an editable geometric SVG reconstruction of the approved Open Layers concept. Light, dark and monochrome treatments share the same geometry; no PNG is embedded inside these logo SVGs. Wordmark SVGs retain editable text and use system sans-serif fonts; rendering may vary with available fonts.

The standalone raster reference, atmospheric landscape/portrait artwork and transparent welcome illustration were generated with the built-in imagegen tool. Their exact prompts are in [sources/generation-prompts.json](sources/generation-prompts.json). Promotional artwork is an illustration, not a screenshot of app behavior. The native app UI and report screenshots remain distinct from it.

Use the navy-front mark on light surfaces and the mint-front mark on dark surfaces. Preserve transparent inter-card gaps and the two front-card slots. Use the self-contained navy app tile where one asset must work in either theme. Do not stretch the mark, place it over busy backgrounds, add security badges or reuse the former logo.

## Reproduce the assets

From the repository root, with Node 24 or later and macOS iconutil:

```sh
npm --prefix scripts/branding ci
npm --prefix scripts/branding run check
npm --prefix scripts/branding run render
```

Dependencies are isolated in the branding tool package, not installed globally. Rendering updates production assets and their local app resource copies; review the resulting diff before publication. Original generated artwork is retained unchanged.

## Integration and publication boundary

The app resource catalog consumes the new app icon and adaptive logo, plus welcome artwork. The local README consumes the new light/dark header. The local hideouts.io project entry points to the new icon, responsive hero, social image and favicon family.

GitHub's repository social preview requires uploading `github/social-preview.png` in repository settings. Local asset changes do not change an existing GitHub release or website deployment. Commit, push, social-preview upload, website deployment and any new app release require explicit approval. No Developer ID certificate or notarization has been added.

## Presentation references

[The app repository](https://github.com/hideouts-io/SystemProfilerExplorer) informed the product scope and interpretation limits. [hideouts.io](https://hideouts.io/), [ManPagesCatalog](https://github.com/hideouts-io/ManPagesCatalog), [DriveTrace](https://github.com/hideouts-io/DriveTrace) and the local RVI project asset families informed presentation quality and delivery formats, without borrowing their symbols.
