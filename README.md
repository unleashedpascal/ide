# Unleashed Pascal IDE

<img align="left" src="images/splash_logo.png" width="300">

**Unleashed Pascal IDE** is a community-driven fork of **Lazarus IDE** built specifically for the [Unleashed Pascal](https://github.com/unleashedpascal/freepascal) compiler. Stock Lazarus has no idea about Unleashed mode features - it underlines `match`, `defer`, contextual `step`, inline `var ... := ...`, and the rest as syntax errors, and code completion stops working the moment you cross into anything Unleashed adds. This fork makes the IDE understand the language as it actually compiles.

It also ships with an Unleashed-aware default project template (new units start in `{$mode unleashed}`) and visible branding so you do not accidentally launch a stock Lazarus and wonder why your code stops getting highlighted.

<br clear="left"/>

## What's different from stock Lazarus

- Syntax highlighting for `match`, `defer`, contextual `step`, FAM `count`, inline `var ... := ...` declarations, `^T` pointers in inline-var, and other Unleashed keywords/constructs.
- Codetools parses inline `var`, `autofree`, `with`-block bindings, multi-line strings, statement expressions, anonymous tuples, and scoped cleanup. Auto-complete works on all of them.
- New project templates emit `{$mode unleashed}` by default. Form units inherit the mode from their parent package.
- Splash, About dialog, and window title say "Unleashed Pascal IDE" - so you can have stock Lazarus and Unleashed Pascal IDE side-by-side without confusion.

## Installation

Unleashed Pascal IDE only builds against the [Unleashed Pascal](https://github.com/unleashedpascal/freepascal) compiler - install both together. The full procedure is in the [**Unleashed Pascal README**](https://github.com/unleashedpascal/freepascal#installation).

## Links

- Project website: https://unleashedpascal.org/
- Compiler repository: https://github.com/unleashedpascal/freepascal
