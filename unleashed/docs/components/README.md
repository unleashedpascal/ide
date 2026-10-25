# Unleashed Components

99 components for LCL applications, in one package: `components/unleashedcomponents`. They draw through the theme engine, so a `TAppTheme` on the main form recolors all of them together with the native controls, and they are written for Windows and Linux alike, with no platform-specific code paths.

Each page below has the properties, the events, the runtime methods, a usage example that compiles as written, and pictures from the demo application: the component as it sits on the form, its states (a drop-down open, a panel folded, a dialog up) and, where it has one, every value of its style property.

## Input

| Component | What it is |
|---|---|
| [`TAppTheme`](apptheme.md) | puts a color theme on every window of the application, native controls included, and keeps it on the windows made later |
| [`TSearchEdit`](searchedit.md) | a search field: a magnifier, the text, a cross that clears it |
| [`TSuggestEdit`](suggestedit.md) | an edit with a list of suggestions dropping under it as the user types: the matches from Items, or whatever OnGetSuggestions fills in |
| [`TPasswordEdit`](passwordedit.md) | a password field with an eye that reveals the text, a strength bar and a caps lock warning |
| [`TNumberBox`](numberbox.md) | a number typed, stepped or dragged: Up and Down step it, Page Up and Page Down take the large step, the wheel steps it while the field has the focus, a drag up or down on the buttons scrubs through the values |
| [`THotKeyEdit`](hotkeyedit.md) | a field that takes a keyboard shortcut: press the keys and they show as text |
| [`TDurationEdit`](durationedit.md) | a duration typed field by field: digits fill the active field, Left and Right move between fields, Up, Down and the wheel step the active one |
| [`TDatePicker`](datepicker.md) | a date typed part by part, or picked on the calendar it drops: digits fill the active part, Left and Right move between the parts, Up, Down and the wheel step it, Alt+Down and F4 open the calendar |
| [`TDateRangePicker`](daterangepicker.md) | a field holding a range of dates: a drop down shows two calendars and a list of presets |
| [`TTagEditor`](tageditor.md) | a field of tags: each one a chip with a cross, the typing goes into the free end of the field |
| [`TColorPicker`](colorpicker.md) | a color picked in place: a saturation and value field under a hue bar, an alpha bar when wanted, a row of swatches and the hex code of the result |
| [`TFontComboBox`](fontcombobox.md) | a font picked from a list that shows every name in its own face, with the fonts used last on top |
| [`TRangeSlider`](rangeslider.md) | a track with two thumbs picking a range from LowValue to HighValue |
| [`TToggleSwitch`](toggleswitch.md) | an on/off switch: a pill with a thumb sliding between the two ends, the caption beside it |
| [`TSegmentedControl`](segmentedcontrol.md) | a row of segments with one selected, a radio group drawn as one bar |
| [`TKnob`](knob.md) | a rotary control: the mark turns from StartAngle through SweepAngle as the value runs from Min to Max |
| [`TRating`](rating.md) | a row of stars to rate with: the mouse picks a star, or half of one, the arrow keys step the value |
| [`TSplitButton`](splitbutton.md) | a push button with a menu arrow at its end |
| [`TDropZone`](dropzone.md) | a target for files dragged from the desktop: a dashed frame with a hint, lit while a drop is possible |
| [`TColorSwatchButton`](colorswatchbutton.md) | a button that shows a color and drops a palette of swatches, a picker or both to change it |
| [`TCheckComboBox`](checkcombobox.md) | a combo box that takes more than one choice: the drop-down lists the items with a check box each, the box shows the chosen ones as a list, a count or a caption of its own |

## Display

| Component | What it is |
|---|---|
| [`TBadge`](badge.md) | a small counter or dot pinned to a corner of another control: Value shows as a number up to Max, then as "Max+" |
| [`TAvatar`](avatar.md) | a picture of a person cut to a circle or a rounded square, or the initials of the name on a color the name picks, with a dot for the presence |
| [`TLed`](led.md) | an indicator light: on, off or blinking, with a caption beside it |
| [`TSevenSegment`](sevensegment.md) | a seven segment display: digits, the hex letters and the letters the segments can form, a decimal point after any digit and colons between them |
| [`TProgressRing`](progressring.md) | progress as an arc closing a ring, the number in the middle |
| [`TBusyIndicator`](busyindicator.md) | an activity marker for a wait of unknown length |
| [`TGauge`](gauge.md) | a dial: an arc scale from StartAngle through SweepAngle, colored zones on it, a needle at the value and the number below |
| [`TSparkline`](sparkline.md) | a tiny chart without axes: a line, a filled area or bars over the last MaxPoints values |
| [`TStatCard`](statcard.md) | a card with one figure: a title, the value in large type, its change with an arrow, a line under it and a small chart of the trend |
| [`TClock`](clock.md) | a clock face or a digital readout |
| [`TRichLabel`](richlabel.md) | a label with styled runs inside one caption: <b>, <i>, <u>, <s> for bold, italic, underlined and struck text, <c=#RRGGBB> or <c=clRed> for a color, <size=N> for a point size, <br> for a line break, <a href="url"> for a link |
| [`TLinkLabel`](linklabel.md) | a label whose caption holds links: the text between <a href="..."> and </a> shows as a link and opens its target when clicked, unless OnLinkClick handles it |
| [`TMarquee`](marquee.md) | a caption rolling across the control, like a ticker |
| [`TQRCode`](qrcode.md) | a QR code of Text, drawn to fill the control |
| [`TBarcode`](barcode.md) | a linear barcode of Text with the text under it |
| [`TCountdown`](countdown.md) | counts down from Duration: a ring or a bar runs out, the time left shows as text, OnFinish fires at zero |
| [`TChartLite`](chartlite.md) | bars, lines, areas and pies from a few series of numbers: no axes objects, no transformations, a chart in a minute |
| [`TMarkdownLabel`](markdownlabel.md) | a label that reads Markdown: headings, paragraphs, bullet and numbered lists, quotes, code spans and blocks, rules, bold, italic and links |
| [`TPlotCanvas`](plotcanvas.md) | x and y pairs as curves on two axes with ticks and a grid: a measurement, a function, a rolling signal |
| [`THeatmapCalendar`](heatmapcalendar.md) | a year of days as a grid of squares, one column per week, the color of a square growing with its value: commits, steps, sales, anything counted per day |

## Views

| Component | What it is |
|---|---|
| [`TCalendarView`](calendarview.md) | a calendar drawn in the colors of the theme |
| [`TImageViewer`](imageviewer.md) | a picture with zoom and pan: the wheel zooms around the mouse, a drag moves the picture, a double click fits it again |
| [`TLogView`](logview.md) | an append-only log: a line per message with its level in color, the time before it, the newest at the bottom and the view following them |
| [`TChatView`](chatview.md) | a conversation as bubbles under each other: the own ones on one side, the others on the other with a name, an avatar and a time, days apart by a separator, with a typing bubble at the end |
| [`TTerminalView`](terminalview.md) | a console: runs a command and shows what it writes, the ANSI colors and styles included, and sends the lines typed into the input line at the bottom to it |
| [`TJsonTreeView`](jsontreeview.md) | a tree of a JSON document: an object member per node, "key: value" for the leaves, "key {n}" and "key [n]" for the containers |
| [`TTimelineView`](timelineview.md) | events along a vertical line, each with a dot, a time, a title and a description, newest first or last as sorted |
| [`TEmptyState`](emptystate.md) | what a list or a view shows while it has nothing: a picture in a soft circle, a title, a line or two of text and a button that does something about it |
| [`TDataTable`](datatable.md) | a table of text cells with a header: a click on a header sorts, a text filters the rows, the rows select, scroll and answer the keyboard |
| [`TPropertyGrid`](propertygrid.md) | the published properties of an object, one per row, with the value editable in place: text and numbers in a box, booleans and enums from a list, colors from a dialog, sets as yes or no per element under the set |
| [`TKanbanBoard`](kanbanboard.md) | columns of cards the mouse drags from one to another and up and down inside one: a task board, a pipeline, a sorting tray |
| [`THexEditor`](hexeditor.md) | bytes in hex and as text side by side: an offset column, a cursor that types nibbles or characters over the bytes, a selection, insert and delete, a search |
| [`TDiffView`](diffview.md) | two texts compared line by line, the lines aligned by patience and Myers, the words that differ inside a changed pair marked on their own: side by side with the change map between the panes, or as one unified listing with the map at the edge |
| [`TImageCropper`](imagecropper.md) | a picture with a crop frame over it: the frame moves and resizes by its edges and corners, keeps a ratio when asked, the rest is dimmed |
| [`TFolderTree`](foldertree.md) | the folders under a root as a tree, read as they open |
| [`TFileList`](filelist.md) | the files of one folder as rows: name, size, modified, type, with a colored mark per extension, a mask, sorting by any column and a double click that opens |
| [`TPaintCanvas`](paintcanvas.md) | a surface to draw on: a pen, lines, arrows, rectangles, ellipses, text and a highlighter, each stroke kept as a shape so undo takes it back and the picture renders at any size |
| [`TGanttChart`](ganttchart.md) | tasks as bars on a time scale: a name column on the left, days, weeks or months across the top, progress inside the bars, arrows between a task and the one it waits for, a line for today |
| [`TNodeEditor`](nodeeditor.md) | boxes with ports and curves between them, on a canvas that pans with a drag of the background and zooms with the wheel |
| [`TSchedulerView`](schedulerview.md) | a day, a week or a month of events: in the day and week views the hours run down and the events are blocks that move and stretch with the mouse, events that overlap share the column |
| [`TTreeGrid`](treegrid.md) | a tree whose rows have columns: an outline on the left, cells to the right, a header that sorts and resizes, check boxes, in-place editing, children loaded when a node opens |

## Layout

| Component | What it is |
|---|---|
| [`TCardPanel`](cardpanel.md) | a container drawn as a card: rounded, framed, with a soft shadow and a header strip carrying the caption |
| [`TExpanderPanel`](expanderpanel.md) | a container folding down to its header: a click on the header, Space or Enter shows or hides the children |
| [`TAccordion`](accordion.md) | stacks the expander panels dropped on it and, unless MultiOpen is set, keeps one of them open: opening a panel folds the others |
| [`TCheckGroupBox`](checkgroupbox.md) | a group box with a check box in its caption: unchecked, the controls in it turn off, or the box folds down to its caption line |
| [`TStackPanel`](stackpanel.md) | lays its children out one after the other, in the order of their position along the stack, with Spacing between them and Padding around |
| [`TGridPanel`](gridpanel.md) | lays its children out on a grid of Columns by Rows, left to right and top to bottom in the order of their position |
| [`TFormLayout`](formlayout.md) | fields of a form under each other, each with its caption in a column on the left or above it |
| [`TFieldRow`](fieldrow.md) | a caption and the controls it names in one row: the caption, measured with the real font, on the left, the right or above the controls, the controls side by side in the order of their position |
| [`TSplitView`](splitview.md) | a host for a side pane and the content beside it: drop two containers on it and name one as the PaneControl, the other one fills the rest |
| [`TDivider`](divider.md) | a line separating two parts of a form, with an optional caption set into it |
| [`TCarousel`](carousel.md) | shows one of its children at a time, as a page: the pages slide sideways on their way in and out, the arrows and the dots move between them, AutoPlay moves on its own |
| [`TDockPanel`](dockpanel.md) | five zones around a center, each a stack of tabbed panels: a tab brings its panel up, a drag of a tab moves it to another zone, the splitters between the zones resize them, a cross closes |

## Navigation

| Component | What it is |
|---|---|
| [`TSideNav`](sidenav.md) | a column of entries for the sections of a window, with an icon and a caption each |
| [`TTabStrip`](tabstrip.md) | a row of tabs without pages, for documents or views: one is active, a tab can close, a drag moves it, the wheel or the arrows scroll the row when it does not fit, and a plus button asks for a new one |
| [`TCommandBar`](commandbar.md) | a row of commands with icons and captions: buttons, toggles that stay pressed, drop-downs that open a menu and separators between groups |
| [`TBreadcrumbBar`](breadcrumbbar.md) | the path to the current place as a row of clickable parts |
| [`TWizardControl`](wizardcontrol.md) | steps along the top, the page of the step in the middle, Back, Next and Finish along the bottom |
| [`TPageIndicator`](pageindicator.md) | a row of dots standing for pages, one of them lit |
| [`TCommandPalette`](commandpalette.md) | a popup with a search box over the actions of an action list and the commands added by hand: the shortcut opens it, typing filters, Enter runs the command under the bar |

## Feedback

| Component | What it is |
|---|---|
| [`TToast`](toast.md) | shows notices in a corner of the screen or of its form: a title, a text, an icon after the kind, a close button and a bar running out with the time left |
| [`TInfoBar`](infobar.md) | a message that stays in the form, unlike a toast: a tinted bar with the icon of its severity, a bold title, the text wrapped under it, a button that does something about it and a close button |
| [`TPopover`](popover.md) | a bubble with an arrow pointing at a control: a title and text, or a control of the form shown inside it |
| [`TOverlayPanel`](overlaypanel.md) | a veil over its parent while something runs: Active covers the whole parent, dims it, shows a spinner and the caption, and keeps the mouse from what is underneath |
| [`TSplashScreen`](splashscreen.md) | a borderless window in the middle of the screen while the application starts: a picture, the name, a version line, a status line and a bar |
| [`TProgressDialog`](progressdialog.md) | a window with a bar for work that takes a while, driven by the code doing it: Start, then Position or Step as the work goes, then Finish |
| [`TTourGuide`](tourguide.md) | a guided tour of a form: one callout per step, each pointing at a control, with Next, Back and Skip |
| [`TNotificationCenter`](notificationcenter.md) | the list of what happened: a card per notification with a title, a text, the time it came and a close cross, unread ones marked |

## System

| Component | What it is |
|---|---|
| [`TAnimator`](animator.md) | moves a published property of a component from one value to another over time: numbers, sizes, positions and colors glide, an enumeration or a boolean switches at the end |
| [`TValidator`](validator.md) | checks the fields of a form against rules: required, a pattern, an e-mail address, a number, a range, a length, the same as another field or a check of your own |
| [`TDebouncer`](debouncer.md) | turns a burst of triggers into a single OnFire: typing in a search box, resize messages, a sensor sending too often |
| [`TBackgroundTask`](backgroundtask.md) | runs a method on a thread and brings its progress, its end and its errors back to the main thread as events |
| [`TUndoStack`](undostack.md) | a stack of reversible actions |
| [`TRecentFiles`](recentfiles.md) | the files opened last, newest first, as entries of a menu and as a list kept in a file between the runs |
| [`TSingleInstance`](singleinstance.md) | keeps the application to one running copy: a second start hands its command line to the first one through OnOtherInstance and leaves |
| [`TSerialPort`](serialport.md) | a serial port, read in the background: OnData gets every chunk, OnLine every whole line |
| [`TSettingsStore`](settingsstore.md) | the settings of the application in a text file: typed reads with a default, writes that save on their own, defaults from the designer, the bounds of a form kept across runs |
| [`TShortcutMap`](shortcutmap.md) | the keyboard shortcuts of a form or the application in one list: a name, a caption and a key per item, a handler each or one for all |
