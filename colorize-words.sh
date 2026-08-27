#!/bin/bash
# MessageDisplay hook: tint a fixed vocabulary in assistant output as it streams.
# Display-only — the stored transcript and what the model sees are unaffected.
#
# Kill switch: `touch ~/.claude/hooks/OFF` silences it, `rm` brings it back.
# Exiting without output leaves displayContent undefined, so the original text shows.
[ -e ~/.claude/hooks/OFF ] && exit 0
#
# Each family gets one color, derived from its first form, so inflections of the
# same word share a hue. Hue comes from a hash of that word; lightness and chroma
# are pinned, so every color is equally readable and none of them are mud.

# jq -j (not -r) so jq adds no newline of its own; the printf/strip pair below
# protects the delta's own trailing newlines from command substitution.
delta=$(jq -j '.delta // ""' | perl -0777 -pe '
use Digest::MD5 qw(md5);

my @families = (
  [qw(house houses)],      [qw(minotaur minotaurs)],
  [qw(load-bearing)],      [qw(quietly)],        [qw(latent)],
  [qw(survive survives survived surviving)],
  [qw(genuine genuinely)], [qw(seam seams)],     [qw(ladder ladders)],
  [qw(carries carrying)],  [qw(pre-fix)],        [qw(byte-identical)],
  [qw(halves)],            [qw(refusal refusals)],
  [qw(stamped)],           [qw(asserted)],       [qw(deliberately)],
  [qw(untouched)],         [qw(collapse collapses collapsed)],
  [qw(folds folded)],      [qw(loses)],          [qw(loudly)],
  [qw(inert)],             [qw(gained)],         [qw(precedent precedents)],
  [qw(alone)],             [qw(ceiling ceilings)],
  [qw(fan-out fan-outs)],
);

# House of Leaves prints "house" in blue and "minotaur" in red. These two are
# quoted rather than derived, so they sit outside the generated palette on purpose.
my %fixed = (house => "4E8FE8", minotaur => "D63A2F");

# OKLCH -> sRGB. Perceptual lightness, so one L means one brightness at any hue.
my ($LIGHT, $CHROMA) = (0.78, 0.13);
sub rgb {
  my $h = shift;
  my ($a, $b) = ($CHROMA * cos($h), $CHROMA * sin($h));
  my @cone = map { $_ ** 3 } (
    $LIGHT + 0.3963377774*$a + 0.2158037573*$b,
    $LIGHT - 0.1055613458*$a - 0.0638541728*$b,
    $LIGHT - 0.0894841775*$a - 1.2914855480*$b,
  );
  my @lin = (
     4.0767416621*$cone[0] - 3.3077115913*$cone[1] + 0.2309699292*$cone[2],
    -1.2684380046*$cone[0] + 2.6097574011*$cone[1] - 0.3413193965*$cone[2],
    -0.0041960863*$cone[0] - 0.7034186147*$cone[1] + 1.7076147010*$cone[2],
  );
  map {
    my $v = $_ < 0 ? 0 : $_ > 1 ? 1 : $_;                       # clamp to gamut
    $v = $v <= 0.0031308 ? 12.92*$v : 1.055 * $v**(1/2.4) - 0.055;
    int(($v < 0 ? 0 : $v > 1 ? 1 : $v) * 255 + 0.5)
  } @lin;
}

my %prefix;
for my $family (@families) {
  my $key = lc $family->[0];
  my ($r, $g, $b) = $fixed{$key}
    ? map { hex } ($fixed{$key} =~ /(..)(..)(..)/)
    : rgb((unpack("N", md5($key)) % 3600) / 3600 * 2 * 3.14159265358979);
  $prefix{lc $_} = "\e[38;2;$r;$g;${b}m" for @$family;
}

# longest-first so a compound wins over any word nested inside it
my $re = join "|", map { quotemeta } sort { length($b) <=> length($a) } keys %prefix;
s/\b((?:$re))\b/$prefix{lc $1} . $1 . "\e[39m"/gie;
'; printf x)
delta=${delta%x}

jq -nc --arg d "$delta" \
  '{hookSpecificOutput: {hookEventName: "MessageDisplay", displayContent: $d}}'
