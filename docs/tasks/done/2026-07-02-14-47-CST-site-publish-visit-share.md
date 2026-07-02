# Site Publish Visit and Share Actions

## Background

The site publish dialog exposed publish status and URL metadata, but users still needed to manually copy or open the public link.

## Goals

- Add a Visit action to open the published site.
- Add a Share action that copies a short recommendation plus the public URL.
- Keep the existing Refresh and Publish actions unchanged.

## Implementation

- Added Visit and Share buttons to the site publish dialog.
- Visit opens the public URL through `url_launcher`.
- Share copies `Check out this site I made with Bricks: <url>` to the clipboard and confirms with a snackbar.
- Updated code maps for the expanded site publish dialog actions.

## Validation Commands

- `cd apps/mobile_chat_app && flutter analyze`
- `ruby -e "require 'psych'; Psych.load_file('docs/code_maps/feature_map.yaml'); Psych.load_file('docs/code_maps/logic_map.yaml'); puts 'code maps yaml ok'"`
