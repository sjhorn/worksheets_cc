# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-02-02

### Added
- Spreadsheet grid with 60fps scrolling and 10%-400% zoom via `worksheet` package
- Formula engine with 43 built-in functions via `worksheet_formula` package
- Cell formatting: bold, italic, text/background colours, number formats
- Multiple sheet support with tab management (add, rename, delete)
- Formula bar showing cell reference and formula text
- Auto-save to browser localStorage with 2-second debounce
- JSON file export and import
- Row and column resizing
- Circular reference detection and dependency-based recalculation
- Zoom controls with slider and percentage display
- GitHub Actions CI/CD pipeline with test gate
- Deployment to GitHub Pages at worksheets.cc
