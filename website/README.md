# Magical Haskell — book website

A responsive, one-page landing page for **Magical Haskell** by Anton Antich. Built with React, TypeScript, and Vinext (Vite), using the Sites starter. All photography, the book cover, and fonts are served locally.

## Run locally

Requires Node.js 22.13 or newer.

```sh
cd website
npm run install:ci
npm run dev -- --host 127.0.0.1 --port 3000
```

Open <http://127.0.0.1:3000/>. If the system Node installation is broken, use a working Node version through your version manager (this checkout was verified with Node 24.20.0).

## Build and verify

```sh
npx tsc --noEmit
npm run build
npm run verify:static
npm start -- --port 3000
```

The build exports static HTML, CSS, JavaScript, images, and fonts to `dist/client/`. The `start` command serves those files locally. No application server or Cloudflare Worker is needed in production.

## GitHub Pages deployment

The workflow in `../.github/workflows/pages.yml` checks and builds the website on pull requests. Pushes to `main` affecting the website or workflow also publish `dist/client/` to GitHub Pages. You can run it manually from the Actions tab. Deployment uses the `github-pages` environment and GitHub’s short-lived deployment credentials; no repository secrets are required.

Repository Pages settings must use **GitHub Actions** as the source and **magicalhaskell.com** as the custom domain. The canonical URL and social metadata use `https://magicalhaskell.com/`. Because the site is served at the custom domain root, do not add a `/magicalhaskell` base path.

Configure the root domain with GitHub Pages’ four A records (`185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`) and `www` as a CNAME to `aantich.github.io`. Enable **Enforce HTTPS** once GitHub provisions the certificate. The `public/CNAME` file records the intended domain; the repository Pages setting controls the domain for Actions deployments.

`npm run verify:static` checks that the exported homepage, canonical metadata, structured data, domain file, and referenced local assets exist before deployment.

## Editing

- `app/page.tsx`: page content, navigation, chapter previews, social and purchase links.
- `app/globals.css`: design, local font declarations, and responsive layouts.
- `app/layout.tsx`: title, search/social metadata, and book structured data.
- `public/images/`: the official cover and author photograph.
- `public/fonts/`: self-hosted typefaces and their SIL Open Font Licenses.

The chapter labels are shortened editorial summaries, grouped into three learning stages; the full table of contents links to the publisher. The small Haskell example is an original illustration, not an extract from the book. The code-copy button copies the complete Git clone command and shows a selectable fallback if clipboard access is unavailable.

## Sources and assets

Verified on 6 November 2026:

- [Apress / Springer book page](https://link.springer.com/book/10.1007/979-8-8688-1282-8): title, subtitle, 13 chapters, 74 illustrations, publication year, formats, and author background. Paperback ISBN: `979-8-8688-1281-1`; eBook ISBN: `979-8-8688-1282-8`.
- [Official publisher cover](https://media.springernature.com/full/springer-static/cover-hires/book/979-8-8688-1282-8): downloaded at 827 × 1254 pixels, used to promote this book. The original publisher artwork is retained unchanged.
- [Amazon listing](https://www.amazon.com/dp/B0DQGF9SL7): purchase destination. The publisher was used to verify details because automated access to Amazon was unavailable.
- [Anton on Medium](https://medium.com/@aantich): verified profile and source of the public [author portrait](https://miro.medium.com/v2/resize:fill:640:640/1*lNzYFQ4Wzw7kGxPmMi_27g.jpeg).
- [Anton on LinkedIn](https://www.linkedin.com/in/aantich/), [X / Twitter](https://x.com/aantich), and [GitHub](https://github.com/aantich).
- [Author companion repository](https://github.com/aantich/magicalhaskell) and [Apress companion repository](https://github.com/Apress/Magical-Haskell).
- [Instrument Serif](https://github.com/google/fonts/tree/main/ofl/instrumentserif), [DM Sans](https://github.com/google/fonts/tree/main/ofl/dmsans), and [DM Mono](https://github.com/google/fonts/tree/main/ofl/dmmono), distributed under their included SIL Open Font Licenses.

Prices, ratings, sales counts, and testimonials are deliberately absent so the page does not present unverified or quickly outdated claims.

## Accessibility and behavior

Semantic landmarks, a skip link, visible keyboard focus, native chapter disclosures, a mobile navigation toggle, reduced-motion support, descriptive image text, and live clipboard feedback. Fonts are self-hosted; the page has no contact form or login.

## Analytics

Production builds load Google Tag Manager container `GTM-MSPJWKQS` from the root layout, including the data-layer/`gtag` initialization and Tag Manager's startup event. A hidden `noscript` iframe provides the standard fallback. Development builds leave tracking disabled.

The `GTM-` ID identifies a Tag Manager container. Google Analytics collection depends on an Analytics tag being configured and published inside that container; no separate Analytics measurement ID is assumed by the website. See [Google's Tag Manager guidance](https://developers.google.com/tag-platform/devguides/existing).

The retained Sites starter tooling under `scripts/`, `worker/`, and `.openai/` is available for future use. The active Vite configuration exports the site without a Worker. Generated dependencies, builds, logs, and local state are ignored by Git.
