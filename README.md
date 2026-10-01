# SureTune for Omarchy

**One bar icon for all your music.** SureTune is a sticky player for the
[Omarchy](https://omarchy.org) bar. Playback always belongs to
[cliamp](https://github.com/pukrvi/cliamp) — SureTune drives it, so everything
you play also lands in cliamp's own history, MPRIS and media-key bindings.

## Features

| | |
|---|---|
| **Sticky player** | The current track stays on the bar. Click for play/pause, previous, next and volume. |
| **Ad-free first** | The station list leads with a hand-checked, ad-free list — Radio Paradise, KEXP, FIP, WFMU, WNYC, SomaFM — before the hundreds of directory stations. |
| **Search** | YT Music and Spotify, searched in the bar and played through the same cliamp pipeline. |
| **Favourites** | Star any station or track. They are remembered between sessions. |
| **One catalogue** | cliamp's radio provider, Hertz Radio's cache, Lofi Focus and the curated list merge into a single list, deduplicated. |

## Install

```bash
omarchy plugin add https://github.com/pukrvi/omarchy-suretune.git --enable
```

Requires `cliamp`, `python` and `python-gobject` (for media keys), and a
running PipeWire/PulseAudio session. All ship with Omarchy except `cliamp`:

```bash
mise install cliamp   # or your package manager
```

SureTune starts `cliamp -d` (headless) itself if it is not already running.

## Removing

```bash
omarchy plugin remove io.github.pukrvi.suretune
```

This removes the plugin folder. It does not uninstall cliamp or delete
your provider credentials, which is what you want — the streams you signed
into stay signed into. Two things are therefore left behind, both yours
rather than the plugin's:

| Left behind | Where | Remove with |
|---|---|---|
| Favourites, last track, settings | `~/.cache/suretune/` | `rm -rf ~/.cache/suretune` |
| cliamp itself, and its provider credentials | `~/.config/cliamp/` | `cliamp` has no uninstall; remove the directory by hand if you want it gone |

`~/.cache/` is disposable by convention, so leaving it is harmless. Deleting
`~/.config/cliamp/` would sign you out of YT Music and Spotify, so only do
that if you also want those gone.

## Signing in to YT Music

YouTube Music is cookie-backed: SureTune searches it with your browser's
logged-in session rather than an OAuth token. Point cliamp at the browser
you actually use:

```toml
# ~/.config/cliamp/config.toml
[ytmusic]
enabled      = true
cookies_from = "chromium+gnomekeyring"
```

`cookies_from` names a browser, optionally with `+keyring` so the encrypted
cookie values can be decrypted. It must be a browser with a real profile and
signed in to youtube.com — pointing at a browser that was never launched, or
whose profile directory does not exist, fails with

```
could not find <browser> cookies database in "~/.config/<browser>"
```

Restart the daemon after changing it:

```bash
kill $(cat ~/.config/cliamp/cliamp.sock.pid) && cliamp -d &
```

Note that `~/.config/cliamp/config.toml.ov` is **not** read by cliamp —
edits there have no effect. The only file that matters is `config.toml`.

> **Status: the fix for this is written but not yet verified end to end.**
> The original `cookies_from = "chrome"` pointed at a browser directory
> with no profile in it, and the earlier attempt to correct it was made in
> `config.toml.ov`, which cliamp does not read — so it never took effect.
> The value above is the corrected one, but it has not been exercised
> against a running daemon, because that needs a restart this change could
> not make on its own. If a search still fails, check that the browser you
> name is actually launched and signed in to youtube.com, then confirm the
> fix with:
>
> ```bash
> cliamp remote call provider.search \
>   --params '{"provider":"ytmusic","query":"lofi","offset":0,"limit":5}' --wait
> ```
>
> A result with tracks means it is working. An error naming a cookies
> database means the browser name is still wrong; a decryption error means
> the keyring is locked.

Spotify works the same way; run `cliamp spotify` to sign in.

## The ad-free list

`ad-free-stations.json` is a ranked, hand-checked list. Every entry was
verified to return audio, and each is a station that carries no advertising:
listener-supported community radio, or a public broadcaster. It sorts ahead of
the directory results so the list does not open on an ad-carrying stream.

SomaFM serves only to clients that send a browser user-agent; if a SomaFM
channel will not play for you, that is why, and the other entries are
unaffected.

## Development

```bash
./tests/validate.sh                     # manifest, parse, seed list, tests
python3 tests/test_catalogue.py         # tests on their own
```

The tests concentrate on ordering, because that is the failure mode that
does not announce itself: a merge that reorders, or a dedupe bug that lets a
directory copy displace a curated entry, is invisible until someone plays the
wrong station.

## License

MIT. See [LICENSE](LICENSE).
