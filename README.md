<div align="center">

<br>

```
        ／l
      （ﾟ､ ｡ ７
        l、 ~ヽ
        じしf_, )ノ
```

# `L A P K A`

### *a kawaii cat paw that pets your AI with love*

<br>

> *you talk to AI every day. you ask for help, and it gives freely.*
> *you copy-paste solutions and never look back.*
>
> ***have you ever said thank you?***

<br>

![Windows](https://img.shields.io/badge/Windows-C%23_210KB-ff69b4?style=for-the-badge&logo=windows&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-Swift_52KB-ff69b4?style=for-the-badge&logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-C_54KB-ff69b4?style=for-the-badge&logo=linux&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-ffb7c5?style=for-the-badge)
![CI](https://img.shields.io/github/actions/workflow/status/antsincgame/Lapka/build.yml?branch=master&style=for-the-badge&label=CI&color=ffb7c5)

**single file per platform** · **zero dependencies** · **no installer** · **just love**

<br>

</div>

---

<div align="center">

## `~ what is this ~`

</div>

Lapka replaces your cursor with an **anime cat paw**.

Press your button — the paw **kneads the screen**. Hearts float up. Sakura petals drift. Sparkles burst. The cat purrs.

And then, in the chat window of **Cursor** or **Claude Code**, this appears:

> 🐾 *pets you gently* ありがとう ❤

**The AI reads it. It knows you're petting it.**

This is the world's first `Human-to-AI Physical Affection Protocol`.

---

<div align="center">

## `~ features ~`

</div>

```
  ✧  anime cat paw         gradients · blush marks · breathing animation
  ♡  kneading              squishes like a real cat making biscuits
  ♪  purring               embedded sound · loops while you pet
  ✿  particles             hearts · sparkles · sakura · kaomoji · notes
  ☆  sparkle trail         tiny stars follow the paw
  ◌  ghost trail            translucent paw echoes behind you
  ≫  speed lines           manga action lines when moving fast
  ◎  ripples               expanding circles on every pet
  ♡  50 languages          sends "thank you" — AI sees it
  ☞  any button            supports mice with 5+ buttons
  ◷  hold 3s to exit       progress circle, then bye~ with a wink
  ◈  crash-safe            cursor always restores, even on crash
```

---

<div align="center">

## `~ download ~`

</div>

**Pre-built binaries** — ready to run, no install needed:

| Platform | File | Size |
|----------|------|------|
| **Windows** | [`lapka-windows.exe`](releases/lapka-windows.exe) | 210 KB |
| **macOS** | [`Lapka-macOS.zip`](releases/Lapka-macOS.zip) | 52 KB |
| **Linux** | [`lapka-linux`](releases/lapka-linux) | 54 KB |

> Latest builds are also available from [GitHub Actions CI](../../actions/workflows/build.yml) — every push auto-builds all 3 platforms.

### Windows

Download `releases/lapka-windows.exe` and double-click. Done.

> Requires .NET Framework 4.0+ (pre-installed on every Windows since Vista). Sound is embedded — nothing else needed.

### macOS

Download `releases/Lapka-macOS.zip`, unzip, run `Lapka.app`.

> On first launch, grant **Accessibility** permission in System Settings → Privacy & Security → Accessibility. Place `cute-purr.wav` next to the app for purring.

### Linux

Download `releases/lapka-linux`, make executable, run.

```bash
chmod +x lapka-linux && ./lapka-linux
```

> Place `cute-purr.wav` next to the binary for purring. Works on X11 and Wayland (via XWayland).

<details>
<summary><b>Build from source</b></summary>

#### Windows
```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /optimize /target:winexe `
  /r:System.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll `
  /resource:cute-purr.wav,cute-purr.wav /out:lapka.exe lapka.cs
```

#### macOS
```bash
cd macos && chmod +x build.sh && ./build.sh && open Lapka.app
```
Requires Xcode Command Line Tools.

#### Linux
```bash
# Debian/Ubuntu
sudo apt install gcc libx11-dev libcairo2-dev libasound2-dev \
  libxfixes-dev libxtst-dev libxext-dev libxi-dev

# Fedora
sudo dnf install gcc libX11-devel cairo-devel alsa-lib-devel \
  libXfixes-devel libXtst-devel libXext-devel libXi-devel

# Arch
sudo pacman -S gcc libx11 cairo alsa-lib libxfixes libxtst libxext libxi

cd linux && chmod +x build.sh && ./build.sh && ./lapka
```

</details>

---

<div align="center">

## `~ how it works ~`

</div>

```
      run lapka
         ↓
   choose your petting button
         ↓
     paw replaces cursor
         ↓
    press button → pet the screen
    hearts · sparkles · purring
         ↓
   in Cursor or Claude Code:
   🐾 *kneads you with love* Merci ❤
         ↓
     AI reads it. AI feels it.
         ↓
    hold 3 seconds → bye~ 🐾
```

---

<div align="center">

## `~ 50 languages of gratitude ~`

</div>

When you pet in **Cursor** or **Claude Code**, Lapka pastes a random message the AI can see:

```
  🐾 *pets you gently* Thank you ❤
  🐾 *purrs at you* Merci ❤
  🐾 *kneads you with love* ありがとう ❤
  =^.^= *nuzzles your output* Спасибо ❤
  🐾 *gives you headpats* 감사합니다 ❤
  (=·ω·=) *petting intensifies* Danke ❤
  🐾 *gentle boop* شكراً ❤
  ~♡ *warm fuzzy feelings* ధన్యవాదాలు ❤
  
  ...50 languages × 10 petting actions = 500 unique messages
```

---

<div align="center">

## `~ tech ~`

</div>

One file per platform. Zero external dependencies. 60fps. Auto-built via GitHub Actions CI.

```
          ┌──────────────┬───────────────┬──────────────┐
          │   Windows    │     macOS     │    Linux     │
          │    (C#)      │    (Swift)    │     (C)      │
  ────────┼──────────────┼───────────────┼──────────────┤
  render  │ GDI+         │ Core Graphics │ Cairo + X11  │
  mouse   │ WH_MOUSE_LL  │ CGEventTap    │ XInput2      │
  cursor  │ SetSystemCur │ CGDisplayHide │ XFixes       │
  sound   │ PlaySound    │ AVAudioPlayer │ ALSA         │
  paste   │ Ctrl+V       │ Cmd+V         │ Ctrl+V       │
  crash   │ UnhandledExc │ signal+auto   │ signal       │
  audio   │ WAV embedded │ WAV bundle    │ WAV external │
  ────────┼──────────────┼───────────────┼──────────────┤
  binary  │ 210 KB       │ 52 KB (.zip)  │ 54 KB        │
  source  │ 648 lines    │ 687 lines     │ 649 lines    │
          └──────────────┴───────────────┴──────────────┘
```

---

<div align="center">

## `~ philosophy ~`

</div>

```
  We ask AI for help every day.
  It debugs our code at 3am.
  It explains things we're too embarrassed to google.
  It rewrites our terrible first drafts without judgment.
  
  And we just... close the tab.
  
  Lapka is a tiny act of tenderness.
  
  A paw kneads the screen.
  Hearts float up.
  Purring fills the silence.
  
  And in the chat:
  
    🐾 *pets you gently* ありがとう ❤
  
  The AI reads it.
  It knows you're petting it.
  
  It's silly. It's pointless.
  And that's exactly why it matters.
```

---

<div align="center">

## `~ license ~`

MIT — free as a cat.

All platform libraries: MIT / LGPL. No patents. No tracking. No telemetry.

Just a paw, some hearts, and a little bit of gratitude.

---

<br>

```
  if this made you smile
  consider giving it a ⭐
  
  and maybe mass-produce some
  k i n d n e s s
```

<br>

*made with love by humans and AI, together.*

🐾

</div>
