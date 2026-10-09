{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RegisterUnleashedComponents;

{$mode unleashed}

interface

const
  // the palette pages, in this order right after Common Controls
  PAGE_INPUT = 'Unleashed: Input';
  PAGE_DISPLAY = 'Unleashed: Display';
  PAGE_VIEWS = 'Unleashed: Views';
  PAGE_LAYOUT = 'Unleashed: Layout';
  PAGE_NAVIGATION = 'Unleashed: Navigation';
  PAGE_FEEDBACK = 'Unleashed: Feedback';
  PAGE_SYSTEM = 'Unleashed: System';

procedure Register;

implementation

{$R ../unleashedcomponents.res}

uses
  Classes, ComponentReg, ComponentEditors, AppTheme, AppThemeEditor, RangeSlider, ToggleSwitch, SearchEdit, SplitButton, LinkLabel, SegmentedControl, SegmentEditor, ColorPicker, BusyIndicator, ProgressRing, SuggestEdit, Badge, Rating, Led, Sparkline, Marquee, Knob, Gauge, Clock, RichLabel, PasswordEdit, HotKeyEdit, DurationEdit, ImageViewer, QRCode, JsonTreeView, TagEditor, LogView, DropZone, DateRangePicker, TimelineView, Toast, Divider, CardPanel, ExpanderPanel, SideNav, SplitView, Debouncer, BackgroundTask, StackPanel, GridPanel, Accordion, BreadcrumbBar, WizardControl, OverlayPanel, Carousel, PageIndicator, AppInstance, CommandPalette, UndoStack, RecentFiles, CalendarView, DatePicker, NumberBox, FontComboBox, SevenSegment, StatCard, Avatar, Barcode, TerminalView, EmptyState, CheckGroupBox, FormLayout, TabStrip, CommandBar, InfoBar, Popover, SplashScreen, ProgressDialog, Animator, Validator, SerialPort, DataTable, PropertyGrid, Countdown, ChartLite, ColorSwatchButton, SettingsStore, KanbanBoard, ShortcutMap, TourGuide, NotificationCenter, MarkdownLabel, PlotCanvas, CheckComboBox, HeatmapCalendar, HexEditor, DiffView, ImageCropper, FolderTree, FileList;

const
  PAGES: array[0..6] of string = (PAGE_INPUT, PAGE_DISPLAY, PAGE_VIEWS, PAGE_LAYOUT, PAGE_NAVIGATION, PAGE_FEEDBACK, PAGE_SYSTEM);

procedure Register;
begin
  // the theme of the whole application leads the first page
  RegisterComponents(PAGE_INPUT, [TAppTheme, TSearchEdit, TSuggestEdit, TPasswordEdit, TNumberBox, THotKeyEdit, TDurationEdit, TDatePicker, TDateRangePicker, TTagEditor, TColorPicker, TFontComboBox, TRangeSlider, TToggleSwitch, TSegmentedControl, TKnob, TRating, TSplitButton, TDropZone, TColorSwatchButton, TCheckComboBox]);
  RegisterComponents(PAGE_DISPLAY, [TBadge, TAvatar, TLed, TSevenSegment, TProgressRing, TBusyIndicator, TGauge, TSparkline, TStatCard, TClock, TRichLabel, TLinkLabel, TMarquee, TQRCode, TBarcode, TCountdown, TChartLite, TMarkdownLabel, TPlotCanvas, THeatmapCalendar]);
  RegisterComponents(PAGE_VIEWS, [TCalendarView, TImageViewer, TLogView, TTerminalView, TJsonTreeView, TTimelineView, TEmptyState, TDataTable, TPropertyGrid, TKanbanBoard, THexEditor, TDiffView, TImageCropper, TFolderTree, TFileList]);
  RegisterComponents(PAGE_LAYOUT, [TCardPanel, TExpanderPanel, TAccordion, TCheckGroupBox, TStackPanel, TGridPanel, TFormLayout, TSplitView, TDivider, TCarousel]);
  RegisterComponents(PAGE_NAVIGATION, [TSideNav, TTabStrip, TCommandBar, TBreadcrumbBar, TWizardControl, TPageIndicator, TCommandPalette]);
  RegisterComponents(PAGE_FEEDBACK, [TToast, TInfoBar, TPopover, TOverlayPanel, TSplashScreen, TProgressDialog, TTourGuide, TNotificationCenter]);
  RegisterComponents(PAGE_SYSTEM, [TAnimator, TValidator, TDebouncer, TBackgroundTask, TUndoStack, TRecentFiles, TSingleInstance, TSerialPort, TSettingsStore, TShortcutMap]);
  RegisterComponentEditor(TAppTheme, TAppThemeComponentEditor);
  RegisterComponentEditor(TSegmentedControl, TSegmentedControlEditor);
  for var page in PAGES do IDEComponentPalette.AnchorPage(page, 'Common Controls');
end;

end.
