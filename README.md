# colorize-words

A Claude Code `MessageDisplay` hook that tints a chosen vocabulary in Claude's
replies as they stream. Useful for noticing how often a word shows up — the
terminal equivalent of syntax highlighting for your own tics.

It is display-only. The stored transcript and what the model sees are unaffected,
so nothing here changes what Claude writes, only what you see.

## Kill switch

```sh
touch ~/.claude/hooks/OFF   # silence it
rm ~/.claude/hooks/OFF      # bring it back
```

Effective on the next flush, no restart. A hook that exits 0 without output
leaves `displayContent` undefined, and Claude Code then draws the original text —
the same path it takes when a hook errors. The script checks for the file on
every invocation, so the toggle is immediate.

To remove it entirely rather than pause it, delete the `hooks` block from
`~/.claude/settings.json`. That one needs a restart.

## Install

```sh
cp colorize-words.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/colorize-words.sh
```

Then in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "MessageDisplay": [
      { "hooks": [ { "type": "command",
                     "command": "/Users/you/.claude/hooks/colorize-words.sh" } ] }
    ]
  }
}
```

Requires `jq` and `perl`. Hook config is read at session start, so the first
install needs a restart; edits to the script itself do not.

## Adding words

Each row of `@families` is one word and its inflections, sharing a color:

```perl
[qw(survive survives survived surviving)],
```

Add a form to an existing row to give it that row's color, or add a new row to
mint a new one. Matching is case-insensitive on whole words, so `seam` will not
fire inside `seamless`, and a plural needs listing explicitly.

## How the colors are picked

Hue comes from an MD5 of the row's first word; lightness and chroma are fixed in
OKLCH and converted to sRGB. Pinning perceptual lightness is what keeps the blues
from going muddy while the yellows glare — at a fixed HSL lightness they would.

Twenty-odd rows drawn from a 360° wheel will collide; a few will look like the
same color. Spacing the hues evenly and probing to the next free slot on a
collision fixes that, at the cost of reshuffling when you add a word.

## Notes

- Fires per batch of completed lines while a message streams, roughly every
  100ms. This script costs ~27ms, comfortably inside that.
- Text with no matches passes through byte-identical. Getting that wrong eats
  the newlines and collapses tables and paragraph breaks into one run-on line.
- Escape codes the *model* emits are neutralized before render; escape codes a
  hook injects are not. That asymmetry is the only reason this works.
