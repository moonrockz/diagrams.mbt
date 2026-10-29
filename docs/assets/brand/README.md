# diagrams.mbt brand assets

The primary logo is **A, Lunar drafter**, selected on 2026-10-28. It shows the pink
Moonrockz bunny drawing a diagram at a drafting table on the moon.

| File | Role |
| --- | --- |
| [diagrams-badge.png](diagrams-badge.png) | Primary logo, candidate A, Lunar drafter |
| [alternatives/diagrams-badge-b-constellation.png](alternatives/diagrams-badge-b-constellation.png) | Branding alternative B, Constellation builder |
| [alternatives/diagrams-badge-c-blueprint.png](alternatives/diagrams-badge-c-blueprint.png) | Branding alternative C, Flowchart explorer |
| [generation-prompts.txt](generation-prompts.txt) | Exact generation prompts and reference sources |

These PNGs are the original generated images, with transparent backgrounds. Keep
the originals when making smaller versions for the landing page, README or icons.
B and C are retained as branding alternatives; A is the selected primary logo.
There is no vector source.

## Icons

[diagrams-icon.png](diagrams-icon.png) is the original simplified bunny-and-pencil
icon derived from A. It keeps the face and pencil large for small displays and
omits the wordmark and drafting table. Its exact prompt is in
[icon-generation-prompt.txt](icon-generation-prompt.txt).

The files below are resized from that original, with transparency preserved.
They are ready for the site to consume when the landing page is updated.

| File | Size | Use |
| --- | --- | --- |
| [icons/favicon.ico](icons/favicon.ico) | 16, 32, 48 px entries | Browser favicon |
| [icons/favicon-16.png](icons/favicon-16.png) | 16 x 16 | Small favicon |
| [icons/favicon-32.png](icons/favicon-32.png) | 32 x 32 | PNG favicon |
| [icons/favicon-48.png](icons/favicon-48.png) | 48 x 48 | Large favicon |
| [icons/logo-64.png](icons/logo-64.png) | 64 x 64 | Site header |
| [icons/apple-touch-icon.png](icons/apple-touch-icon.png) | 180 x 180 | Apple touch icon |
| [icons/icon-192.png](icons/icon-192.png) | 192 x 192 | App icon |
| [icons/icon-512.png](icons/icon-512.png) | 512 x 512 | Large app icon |

Regenerate each PNG with `sips -z SIZE SIZE diagrams-icon.png --out OUTPUT.png`.
The ICO contains the three favicon PNGs as PNG entries, without repainting them.

## Brand references

Generated with the built-in image_gen tool using these two images from
[moonrockz/smithy](https://github.com/moonrockz/smithy) as visual references:

- [Moonrockz organization mascot](https://github.com/moonrockz/smithy/blob/main/site/public/moonrockz.png)
- [Smithy project badge](https://github.com/moonrockz/smithy/blob/main/docs/assets/brand/smithy-badge-1024.png)

Preserve the pink bunny, white muzzle, tall swept ears, navy outlines, lunar
setting and chunky white lettering when developing related assets.

