# Flutter Web → GitHub Pages Setup

## Project: worksheets.cc

### Repository Structure

```
worksheets-cc/
├── .github/workflows/deploy.yml
├── CNAME
├── lib/
├── web/
└── pubspec.yaml
```

### 1. Create CNAME File (repo root)

```
worksheets.cc
```

### 2. Create `.github/workflows/deploy.yml`

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - run: flutter pub get
      - run: flutter build web --release --base-href /

      - name: Add CNAME
        run: cp CNAME build/web/

      - name: Deploy to gh-pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

### 3. GitHub Repo Settings

1. Settings → Pages
2. Source: Deploy from branch
3. Branch: `gh-pages` / `/ (root)`
4. Custom domain: `worksheets.cc`
5. Enforce HTTPS: ✓

### 4. DNS Records

| Type | Name | Value |
|------|------|-------|
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |
| CNAME | www | sjhorn.github.io |

### Workflow

1. Push to `main` triggers build
2. Action builds Flutter web
3. Copies CNAME into build output
4. Deploys `build/web/` to `gh-pages` branch
5. GitHub Pages serves from `gh-pages`
