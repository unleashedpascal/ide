{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit UnleashedComponents;

{$warn 5023 off : no warning about unused units}
interface

uses
  AppTheme, RangeSlider, ControlPaint, ToggleSwitch, SearchEdit, SplitButton, 
  LinkLabel, SegmentedControl, ColorPickers, BusyIndicator, ProgressRing, 
  SuggestEdit, Badge, Rating, Led, Sparkline, Marquee, Knob, Gauge, Clock, 
  RichLabel, PasswordEdit, HotKeyEdit, DurationEdit, ImageViewer, QRCode, 
  JsonTreeView, TagEditor, LogView, DropZone, DateRangePicker, TimelineView, 
  Toast, Divider, CardPanel, ExpanderPanel, SideNav, SplitView, Debouncer, 
  BackgroundTask, StackPanel, GridPanel, Accordion, BreadcrumbBar, 
  WizardControl, OverlayPanel, Carousel, PageIndicator, AppInstance, 
  CommandPalette, UndoStack, RecentFiles, PopupWindow, CalendarView, 
  DatePicker, NumberBox, FontComboBox, SevenSegment, StatCard, Avatar, Barcodes, 
  TerminalView, EmptyState, CheckGroupBox, FormLayout, FieldRow, TabStrip, 
  CommandBar, InfoBar, Popover, SplashScreen, ProgressDialog, Animator, 
  Validator, SerialPort, DataTable, PropertyGrid, Countdown, ChartLite, 
  ColorSwatchButton, SettingsStore, KanbanBoard, ShortcutMap, TourGuide, 
  NotificationCenters, MarkdownLabel, PlotCanvas, CheckComboBox, 
  HeatmapCalendar, HexEditor, DiffView, ImageCropper, FolderTree, FileList, 
  PaintCanvas, GanttChart, NodeEditor, SchedulerView, TreeGrid, DockPanel, 
  ChatView, CodeReaders, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('UnleashedComponents', @Register);
end.
