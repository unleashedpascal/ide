# Unleashed Pascal IDE - Documentation

This is the index of what the IDE adds on top of stock Lazarus. The editor changes are listed first, then the IDE packages, then the component library for applications. The component library has a page per component under [components/](components/README.md).

## The language in the editor

The IDE is built for the [Unleashed Pascal](https://github.com/unleashedpascal/compiler) compiler and understands `{$mode unleashed}` the way the compiler does:

- **Highlighting** of `match`, `defer`, `autofree`, `async` / `await`, `lock`, contextual `step`, the flexible array `count`, inline `var x := ...` declarations, `^T` pointers in inline declarations, interpolated and multiline strings, and the rest of the mode's keywords.
- **Codetools** parse inline variables, `autofree`, `with var` bindings, multiline strings, statement expressions, anonymous tuples and scoped cleanup. Code completion works on all of them.
- **New projects and units** start in `{$mode unleashed}`. A form unit inherits the mode from its package.
- **Branding** that tells the two IDEs apart: the splash, the About dialog and the window title say Unleashed Pascal IDE, so a stock Lazarus can live next to it.

## IDE packages

Each one is an ordinary IDE package, one directory under `components/unleashed*` in the repository, and can be removed from the IDE like any other package.

| Package | What it does | Where |
|---|---|---|
| **Unleashed Themes** | Switches the whole IDE between the stock look, the system light or dark look and the named themes Frost, Paper, Ocean, Ember, Midnight and Dusk, without a restart. The theme reaches the native controls and the icons. An option generates a syntax highlight profile that matches the theme. Two switches control the hover effects and the border of the focused control. | View > Themes |
| **Unleashed Panes** | A single-window layout: the tool windows (Object Inspector, Messages, Code Explorer, Project Inspector, the debugger windows, and the rest) dock as panes in columns and rows around the source editor. Panes move with the mouse or with Move left / Move right, close with a click, and an empty window, a second editor window or a designer window can be opened. | Panes menu, Tools > Options > Panes |
| **Unleashed Minimap** | A scaled-down picture of the whole unit next to the source editor, with a band marking the lines on screen. The band drags; the colors follow the theme or are set by hand; width and font size are options. | View > Code Minimap, Tools > Options > Code Minimap |
| **Unleashed Form Placer** | A miniature of the desktop in a corner of the docked form designer, with every monitor drawn. Drag the rectangle of the form to decide where the designed window opens; the arrow keys nudge it. | Tools > Options > Form Placer |
| **Unleashed Theme Engine** | The runtime behind the themes: puts a palette on every window of an LCL process, native controls included, and fits the icons to it. The IDE themes and `TAppTheme` in applications both run on it. | used by the packages above |
| **Unleashed Components** | Controls and tools for LCL applications, with `TAppTheme` putting a theme on the whole application. See below. | the component palette |

## Components for applications

The component library adds seven pages to the palette with ninety-seven components: inputs, displays, views, layouts, navigation, feedback and non-visual tools. They draw through the theme engine, so a `TAppTheme` on the main form recolors all of them together with the native controls, and they are written for Windows and Linux alike, with no platform-specific code paths.

The full list, with a page per component (properties, events, runtime methods, a usage example that compiles as written and a picture), is in [components/README.md](components/README.md).

A taste, three of the views:

| | |
|---|---|
| [`TDiffView`](components/diffview.md) | two texts compared line by line, the words that differ marked, split with a change map between the panes or unified like a patch |
| [`TNodeEditor`](components/nodeeditor.md) | boxes with ports and curves between them on a canvas that pans and zooms |
| [`TDataTable`](components/datatable.md) | a sortable, filterable table of text cells, with a virtual mode for a million rows |

## Installation

The IDE builds only against the Unleashed Pascal compiler, so both are installed together. The installer and the fpcupdeluxe route are described in the [compiler README](https://github.com/unleashedpascal/compiler#installation).
