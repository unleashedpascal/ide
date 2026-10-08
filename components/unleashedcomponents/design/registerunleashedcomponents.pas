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
  Classes, ComponentReg, ComponentEditors, AppTheme, AppThemeEditor, RangeSlider, ToggleSwitch, SearchEdit, SplitButton, LinkLabel, SegmentedControl, SegmentEditor, ColorPicker, BusyIndicator, ProgressRing, SuggestEdit, Badge, Rating, Led, Sparkline, Marquee, Knob, Gauge, Clock, RichLabel, PasswordEdit, HotKeyEdit, DurationEdit, ImageViewer, QRCode, JsonTreeView, TagEditor, LogView, DropZone, DateRangePicker, TimelineView, Toast, Divider, CardPanel, ExpanderPanel, SideNav, SplitView, Debouncer, BackgroundTask, StackPanel, GridPanel, Accordion, BreadcrumbBar, WizardControl, OverlayPanel, Carousel, PageIndicator, AppInstance, CommandPalette, UndoStack, RecentFiles, CalendarView, DatePicker, NumberBox, FontComboBox, SevenSegment, StatCard, Avatar, Barcode;

const
  PAGES: array[0..6] of string = (PAGE_INPUT, PAGE_DISPLAY, PAGE_VIEWS, PAGE_LAYOUT, PAGE_NAVIGATION, PAGE_FEEDBACK, PAGE_SYSTEM);

procedure Register;
begin
  // the theme of the whole application leads the first page
  RegisterComponents(PAGE_INPUT, [TAppTheme, TSearchEdit, TSuggestEdit, TPasswordEdit, TNumberBox, THotKeyEdit, TDurationEdit, TDatePicker, TDateRangePicker, TTagEditor, TColorPicker, TFontComboBox, TRangeSlider, TToggleSwitch, TSegmentedControl, TKnob, TRating, TSplitButton, TDropZone]);
  RegisterComponents(PAGE_DISPLAY, [TBadge, TAvatar, TLed, TSevenSegment, TProgressRing, TBusyIndicator, TGauge, TSparkline, TStatCard, TClock, TRichLabel, TLinkLabel, TMarquee, TQRCode, TBarcode]);
  RegisterComponents(PAGE_VIEWS, [TCalendarView, TImageViewer, TLogView, TJsonTreeView, TTimelineView]);
  RegisterComponents(PAGE_LAYOUT, [TCardPanel, TExpanderPanel, TAccordion, TStackPanel, TGridPanel, TSplitView, TDivider, TCarousel]);
  RegisterComponents(PAGE_NAVIGATION, [TSideNav, TBreadcrumbBar, TWizardControl, TPageIndicator, TCommandPalette]);
  RegisterComponents(PAGE_FEEDBACK, [TToast, TOverlayPanel]);
  RegisterComponents(PAGE_SYSTEM, [TDebouncer, TBackgroundTask, TUndoStack, TRecentFiles, TSingleInstance]);
  RegisterComponentEditor(TAppTheme, TAppThemeComponentEditor);
  RegisterComponentEditor(TSegmentedControl, TSegmentedControlEditor);
  for var page in PAGES do IDEComponentPalette.AnchorPage(page, 'Common Controls');
end;

end.
