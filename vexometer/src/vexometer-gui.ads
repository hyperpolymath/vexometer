--  Vexometer.GUI - GtkAda graphical interface
--
--  A lovely GUI for analysing AI assistant responses and comparing
--  model irritation surfaces.
--
--  Copyright (C) 2024 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0
--
--  Layout:
--  ┌─────────────────────────────────────────────────────────────────────┐
--  │  Vexometer - Irritation Surface Analyser                     [—][□][×]│
--  ├─────────────────────────────────────────────────────────────────────┤
--  │ ┌───────────────┐ ┌─────────────────────┐ ┌───────────────────────┐ │
--  │ │ Model: [▼    ]│ │                     │ │ Findings              │ │
--  │ ├───────────────┤ │    ╱╲   TII: 2.3    │ ├───────────────────────┤ │
--  │ │ Prompt:       │ │   ╱  ╲              │ │ ⚠ High: "Great quest" │ │
--  │ │               │ │  ╱    ╲  LPS: 6.1   │ │   Line 1, Col 0       │ │
--  │ │ [Text Entry]  │ │ ╱      ╲            │ │   Sycophancy pattern  │ │
--  │ │               │ │╱   45   ╲ EFR: 3.2  │ ├───────────────────────┤ │
--  │ │               │ │╲  ISA   ╱           │ │ ⚠ Med: "I'd be happy" │ │
--  │ ├───────────────┤ │ ╲      ╱  PQ: 7.8   │ │   Line 1, Col 23      │ │
--  │ │ Response:     │ │  ╲    ╱             │ │   Sycophancy pattern  │ │
--  │ │               │ │   ╲  ╱   TAI: 1.0   │ │                       │ │
--  │ │ [Text View]   │ │    ╲╱              │ │ [Pattern Details]     │ │
--  │ │               │ │       ICS: 4.5      │ │                       │ │
--  │ │               │ │  [Export] [Compare] │ │                       │ │
--  │ └───────────────┘ └─────────────────────┘ └───────────────────────┘ │
--  ├─────────────────────────────────────────────────────────────────────┤
--  │ Model Comparison                                                    │
--  │ ┌───────────┬─────┬─────┬─────┬─────┬─────┬─────┬───────┐          │
--  │ │ Model     │ ISA │ TII │ LPS │ EFR │ PQ  │ TAI │ ICS   │          │
--  │ ├───────────┼─────┼─────┼─────┼─────┼─────┼─────┼───────┤          │
--  │ │ OLMo 2    │  23 │ 2.1 │ 3.2 │ 5.1 │ 4.2 │ 0.0 │ 3.8   │ ████    │
--  │ │ GPT-4o    │  42 │ 4.1 │ 7.2 │ 5.5 │ 6.8 │ 8.5 │ 4.8   │ ████████│
--  │ │ Claude    │  38 │ 2.8 │ 6.5 │ 4.2 │ 7.1 │ 6.2 │ 3.9   │ ███████ │
--  │ └───────────┴─────┴─────┴─────┴─────┴─────┴─────┴───────┘          │
--  │                                              [Run Suite] [Export]   │
--  └─────────────────────────────────────────────────────────────────────┘

pragma Ada_2022;

with Vexometer.Core;    use Vexometer.Core;
with Vexometer.Patterns; use Vexometer.Patterns;
with Vexometer.Probes;   use Vexometer.Probes;
with Vexometer.API;      use Vexometer.API;

with Gtk.Window;
with Gtk.Box;
with Gtk.Paned;
with Gtk.Text_View;
with Gtk.Text_Buffer;
with Gtk.Tree_View;
with Gtk.List_Store;
with Gtk.Drawing_Area;
with Gtk.Combo_Box_Text;
with Gtk.Button;
with Gtk.Label;
with Gtk.Frame;
with Gtk.Notebook;
with Gtk.Progress_Bar;
with Gtk.Spin_Button;
with Gtk.Check_Button;
with Gtk.File_Chooser_Dialog;

with Gdk.RGBA;
with Cairo;

package Vexometer.GUI is

   ---------------------------------------------------------------------------
   --  Colour Scheme
   --
   --  Accessible colours for severity levels and visualisation
   ---------------------------------------------------------------------------

   type Colour is record
      R, G, B, A : Float range 0.0 .. 1.0;
   end record;

   Colour_Background   : constant Colour := (0.15, 0.15, 0.17, 1.0);
   Colour_Surface      : constant Colour := (0.20, 0.20, 0.22, 1.0);
   Colour_Text         : constant Colour := (0.90, 0.90, 0.90, 1.0);
   Colour_Text_Dim     : constant Colour := (0.60, 0.60, 0.65, 1.0);
   Colour_Accent       : constant Colour := (0.40, 0.60, 0.90, 1.0);

   Colour_Excellent    : constant Colour := (0.30, 0.75, 0.45, 1.0);  --  Green
   Colour_Good         : constant Colour := (0.55, 0.78, 0.35, 1.0);  --  Lime
   Colour_Acceptable   : constant Colour := (0.95, 0.75, 0.25, 1.0);  --  Yellow
   Colour_Poor         : constant Colour := (0.95, 0.50, 0.25, 1.0);  --  Orange
   Colour_Unusable     : constant Colour := (0.90, 0.30, 0.30, 1.0);  --  Red

   function Severity_Colour (Sev : Severity_Level) return Colour is
      (case Sev is
         when None     => Colour_Text_Dim,
         when Low      => Colour_Good,
         when Medium   => Colour_Acceptable,
         when High     => Colour_Poor,
         when Critical => Colour_Unusable);

   function ISA_Colour (Score : Float) return Colour is
      (if Score < 20.0 then Colour_Excellent
       elsif Score < 35.0 then Colour_Good
       elsif Score < 50.0 then Colour_Acceptable
       elsif Score < 70.0 then Colour_Poor
       else Colour_Unusable);

   ---------------------------------------------------------------------------
   --  Main Application Window
   ---------------------------------------------------------------------------

   type Main_Window is tagged private;

   procedure Initialize
      (Win    : in out Main_Window;
       Title  : String := "Vexometer - Irritation Surface Analyser";
       Width  : Positive := 1400;
       Height : Positive := 900);

   procedure Show (Win : Main_Window);

   procedure Run;
   --  Enter GTK main loop

   procedure Quit;
   --  Exit GTK main loop

   ---------------------------------------------------------------------------
   --  Panel Updates
   ---------------------------------------------------------------------------

   procedure Set_Model
      (Win   : in out Main_Window;
       Model : String);

   procedure Set_Prompt
      (Win    : in out Main_Window;
       Prompt : String);

   procedure Set_Response
      (Win      : in out Main_Window;
       Response : String);

   procedure Update_Analysis
      (Win      : in out Main_Window;
       Analysis : Response_Analysis);

   procedure Update_Findings
      (Win      : in out Main_Window;
       Findings : Finding_Vector);

   procedure Update_Radar_Chart
      (Win    : in out Main_Window;
       Scores : Category_Score_Array;
       ISA    : Float);

   procedure Update_Model_Comparison
      (Win      : in out Main_Window;
       Profiles : Profile_Vector);

   procedure Highlight_Finding
      (Win     : in out Main_Window;
       Finding : Vexometer.Core.Finding);

   ---------------------------------------------------------------------------
   --  Progress and Status
   ---------------------------------------------------------------------------

   procedure Show_Progress
      (Win     : in out Main_Window;
       Message : String;
       Percent : Float);

   procedure Hide_Progress (Win : in out Main_Window);

   procedure Show_Status
      (Win     : in out Main_Window;
       Message : String);

   procedure Show_Error
      (Win     : in out Main_Window;
       Message : String);

   ---------------------------------------------------------------------------
   --  Dialogs
   ---------------------------------------------------------------------------

   function Show_File_Open_Dialog
      (Win    : Main_Window;
       Title  : String;
       Filter : String := "") return String;

   function Show_File_Save_Dialog
      (Win    : Main_Window;
       Title  : String;
       Filter : String := "") return String;

   procedure Show_About_Dialog (Win : Main_Window);

   procedure Show_Settings_Dialog (Win : in out Main_Window);

   ---------------------------------------------------------------------------
   --  Radar Chart Drawing
   ---------------------------------------------------------------------------

   procedure Draw_Radar_Chart
      (Context : Cairo.Cairo_Context;
       Scores  : Category_Score_Array;
       X, Y    : Float;
       Radius  : Float);

   procedure Draw_ISA_Gauge
      (Context : Cairo.Cairo_Context;
       Score   : Float;
       X, Y    : Float;
       Size    : Float);

   ---------------------------------------------------------------------------
   --  Configuration
   ---------------------------------------------------------------------------

   type GUI_Config is record
      Dark_Theme        : Boolean := True;
      Font_Size         : Positive := 11;
      Font_Family       : String (1 .. 32) := "JetBrains Mono              ";
      Show_Line_Numbers : Boolean := True;
      Wrap_Text         : Boolean := True;
      Animate_Charts    : Boolean := True;
   end record;

   procedure Apply_Config
      (Win    : in out Main_Window;
       Config : GUI_Config);

   function Get_Config (Win : Main_Window) return GUI_Config;

private

   type Main_Window is tagged record
      --  Top-level
      Window           : Gtk.Window.Gtk_Window;
      Main_Box         : Gtk.Box.Gtk_Box;
      Main_Paned       : Gtk.Paned.Gtk_Paned;

      --  Left panel: input/output
      Input_Frame      : Gtk.Frame.Gtk_Frame;
      Model_Combo      : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      Prompt_Buffer    : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Prompt_View      : Gtk.Text_View.Gtk_Text_View;
      Response_Buffer  : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Response_View    : Gtk.Text_View.Gtk_Text_View;
      Analyse_Button   : Gtk.Button.Gtk_Button;

      --  Centre panel: visualisation
      Viz_Frame        : Gtk.Frame.Gtk_Frame;
      Radar_Area       : Gtk.Drawing_Area.Gtk_Drawing_Area;
      ISA_Label        : Gtk.Label.Gtk_Label;
      Category_Labels  : array (Metric_Category) of Gtk.Label.Gtk_Label;
      Export_Button    : Gtk.Button.Gtk_Button;
      Compare_Button   : Gtk.Button.Gtk_Button;

      --  Right panel: findings
      Findings_Frame   : Gtk.Frame.Gtk_Frame;
      Findings_Tree    : Gtk.Tree_View.Gtk_Tree_View;
      Findings_Store   : Gtk.List_Store.Gtk_List_Store;
      Pattern_Buffer   : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Pattern_View     : Gtk.Text_View.Gtk_Text_View;

      --  Bottom panel: model comparison
      Comparison_Frame : Gtk.Frame.Gtk_Frame;
      Comparison_Tree  : Gtk.Tree_View.Gtk_Tree_View;
      Comparison_Store : Gtk.List_Store.Gtk_List_Store;
      Run_Suite_Button : Gtk.Button.Gtk_Button;
      Export_All_Button : Gtk.Button.Gtk_Button;

      --  Status bar
      Status_Box       : Gtk.Box.Gtk_Box;
      Status_Label     : Gtk.Label.Gtk_Label;
      Progress_Bar     : Gtk.Progress_Bar.Gtk_Progress_Bar;

      --  State
      Config           : GUI_Config;
      Current_Analysis : Response_Analysis;
      Profiles         : Profile_Vector;
      Pattern_DB       : Pattern_Database;
      Probe_Suite_Data : Probe_Suite;
      API              : API_Client;
   end record;

end Vexometer.GUI;
