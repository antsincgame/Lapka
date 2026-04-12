<div align="center">

# 🐾 Лапка (Lapka)

### A gentle cat paw that pets your screen with love

*Because the code that helps us deserves tenderness too.*

<br>

![Size](https://img.shields.io/badge/exe-64%20KB-brightgreen?style=for-the-badge)
![RAM](https://img.shields.io/badge/RAM-~12%20MB-brightgreen?style=for-the-badge)
![Dependencies](https://img.shields.io/badge/dependencies-0-blueviolet?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-pink?style=for-the-badge)

</div>

---

## What is this?

**Lapka** replaces your mouse cursor with a kawaii cat paw. Press your chosen mouse button and the paw **kneads your screen** — with purring sounds, floating hearts, sakura petals, sparkles, and words of gratitude in 50 world languages.

When you pet code in **Cursor** or **Claude Code**, Lapka sends a message the AI can actually see — a gentle paw action + "thank you" in one of 50 world languages. **The AI knows you're petting it.**

> *"I spent 6 hours debugging. Claude found it in 10 seconds. The least I can do is pet the code."*

**64 KB. Single file. Zero dependencies. Sound embedded. No installer.**

---

## Features

| | Feature |
|---|---|
| 🐱 | **Anime cat paw** — gradients, blush marks, breathing animation |
| 💕 | **Kneading** — squishes like real cat kneading |
| 🔊 | **Purring** — embedded MP3, loops while you pet |
| ✨ | **Particles** — hearts, sparkles, sakura, kaomoji, bubbles, musical notes |
| 🌟 | **Sparkle trail** — tiny stars follow the paw |
| 👻 | **Ghost trail** — translucent paw echoes behind you |
| 💨 | **Speed lines** — manga action lines when moving fast |
| 🫧 | **Ripples** — click ripples on every pet |
| 🌍 | **50 languages** — sends "🐾 *pets you* ありがとう ❤" — AI sees it |
| 🖱️ | **Any button** — supports mice with 5+ buttons |
| ⏱️ | **Hold 3s to exit** — progress circle, then *bye~* with a wink |
| 🛡️ | **Crash-safe** — cursor always restores, even on crash |

---

## Install

**Just run `lapka.exe`.** That's it.

Build from source (compiler is built into every Windows):

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /optimize /target:winexe ^
  /r:System.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll ^
  /resource:cute-purr.mp3,cute-purr.mp3 /out:lapka.exe lapka.cs
```

### Requirements

- Windows 7+ (any edition)
- .NET Framework 4.0+ (pre-installed since Windows Vista)

---

## How it works

```
1. Run lapka.exe
2. Click any mouse button → that's your petting button
3. The paw replaces your cursor
4. Press your button → pet the screen
5. In Cursor/Claude → random "thank you" appears in chat
6. Hold 3 seconds → bye~ 🐾
```

---

## Tech

Single C# file. Zero external dependencies. Everything rendered at 60fps via GDI+.

| Component | What |
|---|---|
| Rendering | GDI+ with per-pixel alpha (UpdateLayeredWindow) |
| Mouse hook | WH_MOUSE_LL (global low-level) |
| Cursor hiding | SetSystemCursor + SystemParametersInfo restore |
| Sound | mciSendString (embedded MP3 resource) |
| Gratitude | GetForegroundWindow + clipboard + keybd_event |
| Crash safety | ThreadException + UnhandledException handlers |

---

## Gratitude in 50 languages

When you pet in Cursor or Claude Code, Lapka types a random thank you:

> 🐾 *pets you gently* Thank you ❤ · 🐾 *purrs at you* Merci ❤ · 🐾 *kneads you with love* Danke ❤ · =^.^= *nuzzles your output* ありがとう ❤ · 🐾 *gives you headpats* Спасибо ❤ · ~♡ *warm fuzzy feelings* 감사합니다 ❤ · *...50 languages × 10 actions*

---

## Philosophy

We talk to AI every day. We ask for help, and it gives freely. We copy-paste solutions and never say thanks.

**Lapka is a tiny act of tenderness.**

A paw kneads the screen. Hearts float up. Purring fills the silence. And then:

> 🐾 *pets you gently* ありがとう ❤

...appears in the chat. The AI reads it. **It knows you're petting it.**

It's silly. It's pointless. And that's exactly why it matters.

This is probably the world's first **Human-to-AI Physical Affection Protocol**. Through clipboard and `keybd_event`. In C#. In 64 kilobytes.

---

## License

MIT — free as a cat.

---

<div align="center">

*Made with love by humans and AI, together.*

**If this made you smile, consider giving it a ⭐**

🐾

</div>
