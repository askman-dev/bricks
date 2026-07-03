# Puzzle Pack Maker

Puzzle Pack Maker is a Flutter iOS/Web app for creating printable puzzle workbook packs.

Current shell:

- GitHub login through the Bricks backend OAuth flow.
- Independent native callback scheme: `puzzlepackmaker://auth/github/callback`.
- Three authenticated tabs: Create, Gallery, and Library.
- Web deployment target: `/puzzle-pack-maker` under `https://craft.bricks.cool`.

Useful commands:

```sh
flutter test
flutter analyze
flutter build web --release --base-href /puzzle-pack-maker/
```
