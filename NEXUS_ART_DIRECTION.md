# 🎨 NEXUS — Art Direction Bible
## macOS Developer Command Center

**Version:** 1.0
**Date:** February 2026
**Designer:** Claude + Birahim
**Style:** Dark Pro — Puissant & Précis

---

## 🎯 Vision Statement

**Nexus** est le **command center ultime** pour développeurs orchestrant plusieurs sessions AI de développement. Interface **puissante, précise, sans fioritures** — un outil professionnel qui respire l'efficacité.

**Concept Visuel:** *"Mission Control pour développeurs"*
- **Centre**: Chat Claude Code (interaction active)
- **Périphérie**: Terminaux de logs (monitoring passif)
- **Énergie**: Cockpit spatial moderne, GitHub Dark meets VS Code Pro

---

## 🎨 Color System — Dark Pro Palette

### Primary Colors

```
# Background Layers (du plus profond au plus élevé)
--bg-app:      #0d1117    // App background (GitHub Dark base)
--bg-canvas:   #010409    // Deep canvas (terminaux de logs)
--bg-surface:  #161b22    // Cards, panels (chat central)
--bg-elevated: #1c2128    // Hover states, elevated UI

# Text Hierarchy
--text-primary:   #e6edf3  // Titres, contenu principal
--text-secondary: #7d8590  // Labels, métadonnées
--text-tertiary:  #484f58  // Placeholders, disabled
--text-inverse:   #0d1117  // Sur backgrounds clairs

# Border System
--border-default: #30363d  // Borders subtiles
--border-muted:   #21262d  // Borders très discrètes
--border-accent:  #388bfd  // Borders actives/focus
```

### Accent Colors (Status & Actions)

```
# Primary Action (Claude AI)
--accent-primary:      #388bfd  // Bleu Claude Code
--accent-primary-hover: #4493ff
--accent-primary-glow:  rgba(56, 139, 253, 0.15)

# Success (Running, Active)
--status-success:      #3fb950  // Vert GitHub
--status-success-glow: rgba(63, 185, 80, 0.15)

# Warning (Pending, Processing)
--status-warning:      #d29922  // Jaune/Orange
--status-warning-glow: rgba(210, 153, 34, 0.15)

# Error (Failed, Stopped)
--status-error:        #f85149  // Rouge GitHub
--status-error-glow:   rgba(248, 81, 73, 0.15)

# Info (Idle, Logs)
--status-info:         #79c0ff  // Bleu clair
--status-info-glow:    rgba(121, 192, 255, 0.15)

# Terminal Accent (Output highlighting)
--terminal-green:  #58a6ff  // Commandes réussies
--terminal-cyan:   #79c0ff  // Info logs
--terminal-yellow: #d29922  // Warnings
--terminal-red:    #ff7b72  // Erreurs
```

### Semantic Usage

| Element | Color | Usage |
|---------|-------|-------|
| **Chat Central BG** | `--bg-surface` | Surface principale du chat |
| **Terminaux Logs BG** | `--bg-canvas` | Fond des terminaux périphériques |
| **App Background** | `--bg-app` | Background général de l'app |
| **Session Cards** | `--bg-surface` | Cards de sessions dans sidebar |
| **Status Indicators** | Accent colors | Badges de status (running/idle/error) |
| **Focus Ring** | `--accent-primary` | Focus states, sélection active |
| **Hover States** | `--bg-elevated` | Survol des éléments interactifs |

---

## ✍️ Typography System — Monospace Pro

### Font Stack

```css
/* Primary: Monospace for code feel */
--font-mono: 'SF Mono', 'Monaco', 'Cascadia Code', 'Fira Code', monospace;

/* Secondary: System for UI labels */
--font-system: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;

/* Weights */
--font-normal:  400
--font-medium:  500
--font-semibold: 600
--font-bold:    700
```

### Type Scale

```css
/* Display — Session titles, headers */
--text-display: 24px / --font-mono / --font-semibold
--text-h1:      20px / --font-mono / --font-semibold
--text-h2:      16px / --font-mono / --font-medium

/* Body — Chat, logs */
--text-body:    14px / --font-mono / --font-normal
--text-small:   12px / --font-mono / --font-normal
--text-xs:      11px / --font-system / --font-normal

/* Monospace sizes for terminal logs */
--text-terminal: 13px / --font-mono / --font-normal
--text-code:     13px / --font-mono / --font-normal

/* Line Heights */
--leading-tight:  1.2
--leading-normal: 1.5
--leading-relaxed: 1.7
```

### Typography Hierarchy

| Element | Size | Weight | Color | Usage |
|---------|------|--------|-------|-------|
| **App Title** | 24px | Semibold | `--text-primary` | "NEXUS" dans titlebar |
| **Session Name** | 16px | Medium | `--text-primary` | Nom des sessions |
| **Chat Messages** | 14px | Normal | `--text-primary` | Messages Claude/User |
| **Terminal Logs** | 13px | Normal | `--text-secondary` | Logs défilants |
| **Status Labels** | 12px | Normal | `--text-secondary` | Labels UI, timestamps |
| **Metadata** | 11px | Normal | `--text-tertiary` | Path, branch, metadata |

---

## 🧩 Component Library — UI Building Blocks

### 1. Chat Central Window

**Architecture:** Fenêtre principale au centre de l'app

```
┌─────────────────────────────────────────┐
│ 💬 Claude Code — Session Alpha          │ ← Header bar
├─────────────────────────────────────────┤
│                                         │
│  [User message bubble]                  │
│                                         │
│            [Claude response bubble]     │
│                                         │
│  [User message bubble]                  │
│                                         │
│         ▌ Claude is typing...           │ ← Typing indicator
│                                         │
├─────────────────────────────────────────┤
│ > Type your message...          [Send]  │ ← Input bar
└─────────────────────────────────────────┘
```

**Visual Specs:**
- **Background**: `--bg-surface` (#161b22)
- **Border**: `--border-default` (1px, #30363d)
- **Border Radius**: 12px
- **Padding**: 20px
- **Shadow**: `0 4px 24px rgba(0,0,0,0.4)`

**Header Bar:**
- Height: 48px
- Background: `--bg-elevated` (#1c2128)
- Title: `--text-h2` (16px, medium)
- Status badge: Right side, colored dot + label

**Message Bubbles:**
- User: Background `--accent-primary-glow`, Text `--text-primary`
- Claude: Background `--bg-elevated`, Text `--text-primary`
- Border radius: 8px
- Padding: 12px 16px
- Max width: 75%

**Input Bar:**
- Height: 56px
- Background: `--bg-elevated`
- Border top: `--border-default`
- Input: `--text-body`, placeholder `--text-tertiary`
- Send button: `--accent-primary`, 36px height

### 2. Terminal Log Windows (Périphérie)

**Architecture:** Panels autour du chat central

```
┌───────────────────────────────┐
│ 📋 Git Operations             │ ← Header
├───────────────────────────────┤
│ [2026-02-02 18:30:15] INFO   │
│ > git worktree add...         │
│ [2026-02-02 18:30:16] SUCCESS│
│ ✓ Worktree created            │
│ [2026-02-02 18:30:17] INFO   │
│ > git checkout -b session-1   │
│                               │
│ ▌ Live scrolling...           │ ← Auto-scroll
└───────────────────────────────┘
```

**Visual Specs:**
- **Background**: `--bg-canvas` (#010409)
- **Border**: `--border-muted` (1px, #21262d)
- **Border Radius**: 8px
- **Padding**: 16px
- **Max Height**: Flexible, auto-scroll

**Header:**
- Height: 36px
- Icon + Title: `--text-small` (12px)
- Close/minimize buttons: Right side

**Log Lines:**
- Font: `--text-terminal` (13px, mono)
- Color: `--text-secondary` (default)
- Timestamps: `--text-tertiary`
- Success: `--terminal-green`
- Error: `--terminal-red`
- Warning: `--terminal-yellow`
- Info: `--terminal-cyan`

**Scrollbar:**
- Width: 8px
- Thumb: `--border-default`
- Track: Transparent
- Auto-hide when inactive

### 3. Session Cards (Sidebar)

**Architecture:** Liste verticale de sessions actives

```
┌─────────────────────────┐
│ 🟢 Session Alpha        │ ← Status dot + name
│ feature/ai-integration  │ ← Branch name
│ ~/projects/nexus        │ ← Path (truncated)
│ ───────────────────────│
│ Running • 2h 34m        │ ← Status + duration
└─────────────────────────┘
```

**Visual Specs:**
- **Background**: `--bg-surface` (#161b22)
- **Background (hover)**: `--bg-elevated` (#1c2128)
- **Background (active)**: `--accent-primary-glow`
- **Border**: `--border-default` (1px)
- **Border (active)**: `--accent-primary` (2px)
- **Border Radius**: 8px
- **Padding**: 12px
- **Min Height**: 96px

**Status Indicator:**
- Size: 8px circle
- Running: `--status-success`
- Idle: `--status-info`
- Error: `--status-error`
- With glow effect: `box-shadow: 0 0 8px var(--glow-color)`

**Typography:**
- Session name: `--text-body` (14px, medium)
- Branch/Path: `--text-small` (12px, normal), `--text-tertiary`
- Status label: `--text-xs` (11px), status color

### 4. Status Badges

**Variants:**

```
🟢 Running    // Green, with pulse animation
🟡 Pending    // Yellow
🔴 Error      // Red, with shake on error
🔵 Idle       // Blue
⚪ Stopped     // Gray
```

**Visual Specs:**
- **Size**: 20px height
- **Padding**: 4px 8px
- **Border Radius**: 6px
- **Font**: `--text-xs` (11px, medium)
- **Background**: Status color with 15% opacity
- **Text**: Status color (full opacity)
- **Icon**: 6px dot, same color

**Animations:**
- Running: Pulse (subtle breathing effect)
- Error: Shake once on state change
- Pending: Gentle rotation (spinner)

### 5. Action Buttons

**Primary (Send, Create, Start):**
- Background: `--accent-primary`
- Text: `--text-inverse`
- Height: 36px
- Padding: 0 16px
- Border radius: 6px
- Font: `--text-small` (12px, medium)
- Hover: `--accent-primary-hover`
- Shadow: `0 2px 8px rgba(56, 139, 253, 0.3)`

**Secondary (Cancel, Close):**
- Background: Transparent
- Border: 1px solid `--border-default`
- Text: `--text-secondary`
- Hover: `--bg-elevated`

**Danger (Delete, Stop):**
- Background: `--status-error`
- Text: `--text-inverse`
- Hover: Darken 10%

### 6. Input Fields

**Text Input:**
- Background: `--bg-canvas`
- Border: 1px solid `--border-default`
- Border (focus): 2px solid `--accent-primary`
- Border radius: 6px
- Padding: 8px 12px
- Font: `--text-body` (14px, mono)
- Placeholder: `--text-tertiary`

**Textarea (Multiline):**
- Same as text input
- Min height: 80px
- Resize: vertical

---

## 🎬 Animation & Interaction System

### Timing Functions

```css
--ease-out: cubic-bezier(0.16, 1, 0.3, 1)     // Smooth exit
--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1)   // Standard
--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1) // Playful bounce
```

### Animation Catalog

| Element | Animation | Duration | Easing |
|---------|-----------|----------|--------|
| **Message appear** | Fade + slide up | 200ms | ease-out |
| **Session card hover** | Background transition | 150ms | ease-in-out |
| **Status badge pulse** | Scale 1 → 1.05 → 1 | 2000ms | ease-in-out (loop) |
| **Log line appear** | Fade in | 100ms | ease-out |
| **Modal open** | Scale 0.95 → 1 + fade | 250ms | ease-spring |
| **Button press** | Scale 0.98 | 100ms | ease-out |
| **Focus ring** | Expand from center | 200ms | ease-out |
| **Error shake** | Translate X -4px → 4px → 0 | 400ms | ease-in-out |

### Micro-interactions

**Typing Indicator (Claude):**
```
▌ Claude is typing...
```
- 3 dots, animated wave
- Color: `--text-tertiary`
- Animation: Each dot bounces sequentially (300ms cycle)

**Auto-scroll Indicator (Logs):**
```
↓ New logs below
```
- Appears when not at bottom
- Click to scroll to bottom
- Gentle bounce animation

**Copy to Clipboard:**
- Button appears on hover over code blocks
- Icon: 📋 → ✓ (transition on click)
- Toast notification: "Copied!"

---

## 🏗️ Layout Architecture — Command Center

### App Structure (macOS Window)

```
┌──────────────────────────────────────────────────────────────┐
│  NEXUS                                    ⚫ 🟡 🟢           │ ← Titlebar
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────┐   ┌─────────────────────────┐   ┌────────────┐ │
│  │        │   │                         │   │            │ │
│  │ Sessions   │   Chat Central          │   │  Git Logs  │ │
│  │  List  │   │   (Primary Focus)       │   │ (Terminal) │ │
│  │        │   │                         │   │            │ │
│  │  Card  │   │  [Chat messages...]     │   │ [Logs...]  │ │
│  │  Card  │   │                         │   │            │ │
│  │  Card  │   │  > Input field...       │   │            │ │
│  │        │   │                         │   │            │ │
│  └────────┘   └─────────────────────────┘   └────────────┘ │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Process Logs (Terminal)                                ││
│  │  [Scrolling logs from all processes...]                 ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Layout Specs

**Window:**
- Min size: 1280x800px
- Default: 1440x900px
- Background: `--bg-app`

**Sidebar (Sessions List):**
- Width: 240px (fixed)
- Background: `--bg-surface`
- Border right: `--border-default`
- Padding: 16px
- Scroll: Auto (when overflow)

**Chat Central:**
- Flex: 1 (takes remaining space)
- Min width: 480px
- Centered vertically and horizontally
- Max width: 800px (for readability)

**Terminal Logs (Right):**
- Width: 320px (fixed)
- Background: `--bg-canvas`
- Border left: `--border-muted`

**Process Logs (Bottom):**
- Height: 200px (resizable)
- Background: `--bg-canvas`
- Border top: `--border-muted`
- Collapsible

### Responsive Behavior

**Narrow window (<1280px):**
- Hide right terminal logs
- Show toggle button to open as overlay

**Very narrow (<900px):**
- Collapse sidebar to icons only
- Chat central takes full width

---

## 📸 Visual Moodboard — AI Generation Prompts

### 1. Hero Screenshot (App Overview)

**Midjourney/DALL-E Prompt:**
```
macOS application window, dark theme developer tool interface,
central chat window with AI conversation, surrounding terminal
logs with green text, GitHub dark color scheme, professional
command center layout, blue accent highlights, modern software
UI design, clean and minimal --ar 16:10 --v 6
```

**Unsplash Keywords:** developer tools, dark UI, terminal, code editor, command center

### 2. Chat Interface Detail

**Prompt:**
```
Close-up of modern chat interface, dark mode, message bubbles
with rounded corners, blue accent color, monospace font, typing
indicator, GitHub dark theme, professional developer tool,
clean UI design --ar 16:9 --v 6
```

**Unsplash Keywords:** chat UI, messaging app, dark theme, modern interface

### 3. Terminal Logs Visual

**Prompt:**
```
Terminal window with scrolling logs, green and cyan text on
black background, timestamps, command line output, developer
tool interface, GitHub dark style, professional coding
environment --ar 16:9 --v 6
```

**Unsplash Keywords:** terminal, command line, code, developer, logs

### 4. Status Indicators

**Prompt:**
```
Set of status badges, green running indicator with pulse
animation, yellow pending, red error, blue idle, dark
background, modern UI design, developer tool style --ar 3:1 --v 6
```

**Unsplash Keywords:** status indicators, UI badges, notifications

### 5. Overall App Atmosphere

**Prompt:**
```
Professional developer workspace at night, multiple monitors
showing dark theme coding interfaces, blue accent lighting,
modern tech aesthetic, command center vibe, focused productive
atmosphere --ar 16:9 --v 6
```

**Unsplash Keywords:** developer workspace, coding at night, tech setup, command center

---

## 🎯 Brand Identity — Nexus

### Logo Concept

**Primary Logo:**
```
╔═══╗
║ N ║  NEXUS
╚═══╝
```

**Characteristics:**
- Monospace font (SF Mono Bold)
- Icon: Geometric "N" in a bordered square
- Border: `--accent-primary` (2px)
- Background: Transparent or `--bg-surface`
- Size variants: 32px, 48px, 64px

**Icon Only (App Icon):**
- Rounded square (macOS style)
- Dark background gradient: `#0d1117` → `#161b22`
- "N" letter: `--accent-primary` (#388bfd)
- Subtle glow effect around "N"

### Tagline

**"Command Your Development."**

Alternative: "Orchestrate AI. Master Code."

### Voice & Tone

- **Professional but not corporate**: Parle aux devs comme un dev
- **Précis et efficace**: Pas de fluff, instructions claires
- **Empowering**: "You're in control"
- **Technical but accessible**: Assume knowledge, explain clearly

---

## 📋 Component Usage Guidelines

### Do's ✅

- **Use monospace fonts** for anything code-related (chat, logs, paths)
- **Maintain dark backgrounds** — this is a pro tool for focused work
- **Status colors are semantic** — green = running, red = error, always
- **Subtle animations only** — no distractions from work
- **Generous spacing** — let content breathe (16px, 20px, 24px)
- **High contrast text** — WCAG AA minimum for accessibility

### Don'ts ❌

- **No bright colors** — keep it dark and professional
- **No playful animations** — this isn't a consumer app
- **No mixed font styles** — stick to mono + system
- **No heavy shadows** — keep UI flat with subtle elevation
- **No rounded "bubbly" UI** — maintain sharp, precise aesthetic
- **No empty states with illustrations** — simple text is enough

---

## 🚀 Implementation Roadmap

### Phase 1: Core Components (Week 1)
- [ ] Color system CSS variables
- [ ] Typography system
- [ ] Chat central window
- [ ] Basic session cards
- [ ] Status badges

### Phase 2: Terminal Logs (Week 2)
- [ ] Log window components
- [ ] Auto-scroll behavior
- [ ] Color-coded log types
- [ ] Timestamp formatting

### Phase 3: Layout & Navigation (Week 3)
- [ ] Full layout structure
- [ ] Sidebar sessions list
- [ ] Window resizing logic
- [ ] Collapsible panels

### Phase 4: Polish & Animation (Week 4)
- [ ] Micro-interactions
- [ ] Typing indicators
- [ ] Status pulse animations
- [ ] Smooth transitions

---

## 📦 Developer Handoff Assets

### Figma/Design Files
- Component library with all variants
- Color styles and typography styles
- Layout grids and spacing system
- Animation timing specifications

### Code Exports
```css
/* CSS Variables (copy-paste ready) */
:root {
  /* Backgrounds */
  --bg-app: #0d1117;
  --bg-canvas: #010409;
  --bg-surface: #161b22;
  --bg-elevated: #1c2128;

  /* Text */
  --text-primary: #e6edf3;
  --text-secondary: #7d8590;
  --text-tertiary: #484f58;

  /* Accents */
  --accent-primary: #388bfd;
  --status-success: #3fb950;
  --status-warning: #d29922;
  --status-error: #f85149;

  /* Typography */
  --font-mono: 'SF Mono', Monaco, monospace;
  --text-body: 14px;
  --text-small: 12px;

  /* Spacing */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;

  /* Border Radius */
  --radius-sm: 6px;
  --radius-md: 8px;
  --radius-lg: 12px;
}
```

### SwiftUI Color Extensions
```swift
extension Color {
    // Backgrounds
    static let bgApp = Color(hex: "#0d1117")
    static let bgCanvas = Color(hex: "#010409")
    static let bgSurface = Color(hex: "#161b22")
    static let bgElevated = Color(hex: "#1c2128")

    // Text
    static let textPrimary = Color(hex: "#e6edf3")
    static let textSecondary = Color(hex: "#7d8590")
    static let textTertiary = Color(hex: "#484f58")

    // Accents
    static let accentPrimary = Color(hex: "#388bfd")
    static let statusSuccess = Color(hex: "#3fb950")
    static let statusWarning = Color(hex: "#d29922")
    static let statusError = Color(hex: "#f85149")
}
```

---

## ✨ Final Notes

Cette direction artistique crée une **identité visuelle cohérente et puissante** pour Nexus. Chaque décision de design sert l'objectif: créer un **command center professionnel** pour développeurs orchestrant plusieurs sessions AI.

**Points clés:**
- **Dark Pro aesthetic** — familier aux devs (VS Code, GitHub)
- **Chat central + terminaux périphériques** — architecture claire
- **Status colors sémantiques** — compréhension instantanée
- **Animations subtiles** — polish sans distraction
- **Typographie monospace** — cohérence avec environnement code

**Prochaine étape:** Utiliser cette bible pour créer les mockups Figma ou commencer l'implémentation SwiftUI directement avec les specs fournies.

---

**🎨 Designed for developers, by developers.**
