--  Vexometer.GUI - GtkAda graphical interface body
--
--  Implements the GtkAda-based GUI for the Irritation Surface Analyser.
--  Provides dark-themed visualisation with radar charts, ISA gauges,
--  findings tree view, and model comparison table.
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Numerics.Elementary_Functions;
with Ada.Float_Text_IO;

with Gtk.Main;
with Gtk.Enums;
with Gtk.Widget;
with Gtk.Css_Provider;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Cell_Renderer_Text;
with Gtk.Tree_View_Column;
with Gtk.Tree_Model;
with Gtk.GEntry;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Dialog;
with Gtk.Message_Dialog;
with Gtk.About_Dialog;
with Gtk.Settings;

with Glib;           use Glib;
with Glib.Values;
with Glib.Object;
with Gdk.Screen;
with Gdk.Cairo;

with Cairo;

package body Vexometer.GUI is

   use Ada.Numerics.Elementary_Functions;

   Pi : constant Float := Ada.Numerics.Pi;

   ---------------------------------------------------------------------------
   --  Utility Helpers
   ---------------------------------------------------------------------------

   function Float_Img (V : Float; Aft : Natural := 1) return String is
      --  Format a float value with the given number of decimal places.
      Buf : String (1 .. 32);
   begin
      Ada.Float_Text_IO.Put (Buf, V, Aft => Aft, Exp => 0);
      for I in Buf'Range loop
         if Buf (I) /= ' ' then
            return Buf (I .. Buf'Last);
         end if;
      end loop;
      return Buf;
   end Float_Img;

   procedure Set_Cairo_Colour
      (Cr : Cairo.Cairo_Context;
       C  : Colour)
   is
      --  Set the Cairo source colour from a Vexometer Colour record.
   begin
      Cairo.Set_Source_Rgba
         (Cr,
          Gdouble (C.R),
          Gdouble (C.G),
          Gdouble (C.B),
          Gdouble (C.A));
   end Set_Cairo_Colour;

   ---------------------------------------------------------------------------
   --  Dark Theme CSS
   ---------------------------------------------------------------------------

   Dark_Theme_CSS : constant String :=
      "* {" & ASCII.LF &
      "  background-color: #262629;" & ASCII.LF &
      "  color: #e6e6e6;" & ASCII.LF &
      "}" & ASCII.LF &
      "window {" & ASCII.LF &
      "  background-color: #262629;" & ASCII.LF &
      "}" & ASCII.LF &
      "treeview {" & ASCII.LF &
      "  background-color: #333336;" & ASCII.LF &
      "  color: #e6e6e6;" & ASCII.LF &
      "}" & ASCII.LF &
      "treeview:selected {" & ASCII.LF &
      "  background-color: #6699e6;" & ASCII.LF &
      "  color: #ffffff;" & ASCII.LF &
      "}" & ASCII.LF &
      "textview, textview text {" & ASCII.LF &
      "  background-color: #1a1a1d;" & ASCII.LF &
      "  color: #e6e6e6;" & ASCII.LF &
      "  font-family: 'JetBrains Mono', monospace;" & ASCII.LF &
      "}" & ASCII.LF &
      "button {" & ASCII.LF &
      "  background-color: #333336;" & ASCII.LF &
      "  color: #e6e6e6;" & ASCII.LF &
      "  border: 1px solid #444448;" & ASCII.LF &
      "  border-radius: 4px;" & ASCII.LF &
      "  padding: 6px 12px;" & ASCII.LF &
      "}" & ASCII.LF &
      "button:hover {" & ASCII.LF &
      "  background-color: #3d3d42;" & ASCII.LF &
      "}" & ASCII.LF &
      "button:active {" & ASCII.LF &
      "  background-color: #6699e6;" & ASCII.LF &
      "}" & ASCII.LF &
      "frame {" & ASCII.LF &
      "  border: 1px solid #333336;" & ASCII.LF &
      "  border-radius: 6px;" & ASCII.LF &
      "}" & ASCII.LF &
      "frame > label {" & ASCII.LF &
      "  color: #6699e6;" & ASCII.LF &
      "  font-weight: bold;" & ASCII.LF &
      "}" & ASCII.LF &
      "notebook tab {" & ASCII.LF &
      "  background-color: #333336;" & ASCII.LF &
      "  color: #999aa6;" & ASCII.LF &
      "  padding: 4px 12px;" & ASCII.LF &
      "}" & ASCII.LF &
      "notebook tab:checked {" & ASCII.LF &
      "  background-color: #262629;" & ASCII.LF &
      "  color: #6699e6;" & ASCII.LF &
      "}" & ASCII.LF &
      "progressbar trough {" & ASCII.LF &
      "  background-color: #333336;" & ASCII.LF &
      "  min-height: 8px;" & ASCII.LF &
      "}" & ASCII.LF &
      "progressbar progress {" & ASCII.LF &
      "  background-color: #6699e6;" & ASCII.LF &
      "  min-height: 8px;" & ASCII.LF &
      "}" & ASCII.LF &
      "entry {" & ASCII.LF &
      "  background-color: #1a1a1d;" & ASCII.LF &
      "  color: #e6e6e6;" & ASCII.LF &
      "  border: 1px solid #444448;" & ASCII.LF &
      "  border-radius: 4px;" & ASCII.LF &
      "}" & ASCII.LF &
      "combobox button {" & ASCII.LF &
      "  background-color: #333336;" & ASCII.LF &
      "}" & ASCII.LF &
      "label.isa-score {" & ASCII.LF &
      "  font-size: 32px;" & ASCII.LF &
      "  font-weight: bold;" & ASCII.LF &
      "}" & ASCII.LF &
      "label.status {" & ASCII.LF &
      "  color: #999aa6;" & ASCII.LF &
      "  font-size: 11px;" & ASCII.LF &
      "}" & ASCII.LF;

   procedure Apply_Dark_Theme is
      --  Load the dark theme CSS and apply it to the default screen.
      --  Uses a Gtk.Css_Provider at APPLICATION priority so it applies
      --  globally to all widgets.
      Provider : Gtk.Css_Provider.Gtk_Css_Provider;
      Screen   : constant Gdk.Screen.Gdk_Screen :=
         Gdk.Screen.Get_Default;
      Error    : aliased Glib.Error.GError;
      Success  : Boolean;
   begin
      Gtk.Css_Provider.Gtk_New (Provider);
      Success := Gtk.Css_Provider.Load_From_Data
         (Provider, Dark_Theme_CSS, Error'Access);

      if Success then
         Gtk.Style_Context.Add_Provider_For_Screen
            (Screen,
             +Provider,
             Gtk.Style_Provider.Priority_Application);
      end if;
   end Apply_Dark_Theme;

   ---------------------------------------------------------------------------
   --  Tree View Column Creation Helper
   ---------------------------------------------------------------------------

   procedure Add_Text_Column
      (View  : Gtk.Tree_View.Gtk_Tree_View;
       Title : String;
       Index : Gint)
   is
      --  Add a text column to a tree view with a cell renderer.
      Col      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      Num      : Gint;
      pragma Unreferenced (Num);
   begin
      Gtk.Tree_View_Column.Gtk_New (Col);
      Col.Set_Title (Title);
      Col.Set_Resizable (True);
      Col.Set_Sort_Column_Id (Index);

      Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
      Col.Pack_Start (Renderer, Expand => True);
      Col.Add_Attribute (Renderer, "text", Index);

      Num := View.Append_Column (Col);
   end Add_Text_Column;

   ---------------------------------------------------------------------------
   --  Scrolled Window Helper
   ---------------------------------------------------------------------------

   function Wrap_In_Scrolled
      (Widget : access Gtk.Widget.Gtk_Widget_Record'Class)
       return Gtk.Scrolled_Window.Gtk_Scrolled_Window
   is
      --  Wrap a widget in a scrolled window with automatic scrollbars.
      Sw : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   begin
      Gtk.Scrolled_Window.Gtk_New (Sw);
      Sw.Set_Policy
         (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Sw.Add (Widget);
      return Sw;
   end Wrap_In_Scrolled;

   ---------------------------------------------------------------------------
   --  Initialize
   ---------------------------------------------------------------------------

   procedure Initialize
      (Win    : in out Main_Window;
       Title  : String := "Vexometer - Irritation Surface Analyser";
       Width  : Positive := 1400;
       Height : Positive := 900)
   is
      --  Initialise the GtkAda toolkit, create the main window, and
      --  build the complete widget hierarchy.
      --
      --  Layout:
      --    Main_Box (vertical)
      --      Main_Paned (horizontal)
      --        Left_Box: Model selector, prompt entry, response view
      --        Centre_Box: Radar chart drawing area, ISA label, buttons
      --        Right_Box: Findings tree view, pattern detail view
      --      Comparison_Frame: Model comparison tree view
      --      Status_Box: Status label, progress bar
   begin
      --  Initialise GTK
      Gtk.Main.Init;

      --  Apply dark theme
      Apply_Dark_Theme;

      --  Create main window
      Gtk.Window.Gtk_New (Win.Window);
      Win.Window.Set_Title (Title);
      Win.Window.Set_Default_Size (Gint (Width), Gint (Height));

      --  Main vertical box
      Gtk.Box.Gtk_New_Vbox (Win.Main_Box, Spacing => 0);
      Win.Window.Add (Win.Main_Box);

      --  Main horizontal paned: left | centre | right
      Gtk.Paned.Gtk_New_Hpaned (Win.Main_Paned);
      Win.Main_Paned.Set_Position (Gint (Width) / 3);
      Win.Main_Box.Pack_Start (Win.Main_Paned, Expand => True,
                                Fill => True, Padding => 0);

      --  ==================================================================
      --  LEFT PANEL: Input/Output
      --  ==================================================================
      declare
         Left_Box : Gtk.Box.Gtk_Box;
      begin
         Gtk.Box.Gtk_New_Vbox (Left_Box, Spacing => 6);
         Gtk.Frame.Gtk_New (Win.Input_Frame, "Input / Output");
         Win.Input_Frame.Add (Left_Box);
         Win.Main_Paned.Pack1 (Win.Input_Frame, Resize => True,
                                Shrink => False);

         --  Model selector combo box
         declare
            Model_Box : Gtk.Box.Gtk_Box;
            Lbl       : Gtk.Label.Gtk_Label;
         begin
            Gtk.Box.Gtk_New_Hbox (Model_Box, Spacing => 6);
            Gtk.Label.Gtk_New (Lbl, "Model:");
            Model_Box.Pack_Start (Lbl, Expand => False,
                                  Fill => False, Padding => 4);
            Gtk.Combo_Box_Text.Gtk_New (Win.Model_Combo);
            Win.Model_Combo.Append_Text ("llama3.2");
            Win.Model_Combo.Append_Text ("mistral");
            Win.Model_Combo.Append_Text ("gemma2");
            Win.Model_Combo.Append_Text ("phi3");
            Win.Model_Combo.Append_Text ("qwen2.5");
            Win.Model_Combo.Set_Active (0);
            Model_Box.Pack_Start (Win.Model_Combo, Expand => True,
                                  Fill => True, Padding => 4);
            Left_Box.Pack_Start (Model_Box, Expand => False,
                                 Fill => False, Padding => 4);
         end;

         --  Prompt text view
         declare
            Prompt_Label : Gtk.Label.Gtk_Label;
         begin
            Gtk.Label.Gtk_New (Prompt_Label, "Prompt:");
            Left_Box.Pack_Start (Prompt_Label, Expand => False,
                                 Fill => False, Padding => 2);
            Gtk.Text_Buffer.Gtk_New (Win.Prompt_Buffer);
            Gtk.Text_View.Gtk_New (Win.Prompt_View, Win.Prompt_Buffer);
            Win.Prompt_View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
            Win.Prompt_View.Set_Left_Margin (4);
            Win.Prompt_View.Set_Right_Margin (4);
            Left_Box.Pack_Start
               (Wrap_In_Scrolled (Win.Prompt_View),
                Expand => True, Fill => True, Padding => 2);
         end;

         --  Analyse button
         Gtk.Button.Gtk_New (Win.Analyse_Button, "Analyse");
         Left_Box.Pack_Start (Win.Analyse_Button, Expand => False,
                              Fill => False, Padding => 4);

         --  Response text view
         declare
            Response_Label : Gtk.Label.Gtk_Label;
         begin
            Gtk.Label.Gtk_New (Response_Label, "Response:");
            Left_Box.Pack_Start (Response_Label, Expand => False,
                                 Fill => False, Padding => 2);
            Gtk.Text_Buffer.Gtk_New (Win.Response_Buffer);
            Gtk.Text_View.Gtk_New
               (Win.Response_View, Win.Response_Buffer);
            Win.Response_View.Set_Wrap_Mode
               (Gtk.Enums.Wrap_Word_Char);
            Win.Response_View.Set_Editable (False);
            Win.Response_View.Set_Left_Margin (4);
            Win.Response_View.Set_Right_Margin (4);
            Left_Box.Pack_Start
               (Wrap_In_Scrolled (Win.Response_View),
                Expand => True, Fill => True, Padding => 2);
         end;
      end;

      --  ==================================================================
      --  CENTRE + RIGHT in a second paned
      --  ==================================================================
      declare
         Right_Paned : Gtk.Paned.Gtk_Paned;
      begin
         Gtk.Paned.Gtk_New_Hpaned (Right_Paned);
         Win.Main_Paned.Pack2
            (Right_Paned, Resize => True, Shrink => False);

         --  =============================================================
         --  CENTRE PANEL: Visualisation
         --  =============================================================
         declare
            Centre_Box : Gtk.Box.Gtk_Box;
         begin
            Gtk.Box.Gtk_New_Vbox (Centre_Box, Spacing => 6);
            Gtk.Frame.Gtk_New (Win.Viz_Frame, "Visualisation");
            Win.Viz_Frame.Add (Centre_Box);
            Right_Paned.Pack1 (Win.Viz_Frame, Resize => True,
                                Shrink => False);

            --  Radar chart drawing area
            Gtk.Drawing_Area.Gtk_New (Win.Radar_Area);
            Win.Radar_Area.Set_Size_Request (300, 300);
            Centre_Box.Pack_Start (Win.Radar_Area, Expand => True,
                                   Fill => True, Padding => 4);

            --  ISA score label
            Gtk.Label.Gtk_New (Win.ISA_Label, "ISA: --");
            Centre_Box.Pack_Start (Win.ISA_Label, Expand => False,
                                   Fill => False, Padding => 4);

            --  Category labels
            for Cat in Metric_Category loop
               Gtk.Label.Gtk_New
                  (Win.Category_Labels (Cat),
                   Category_Abbreviation (Cat) & ": --");
               Centre_Box.Pack_Start
                  (Win.Category_Labels (Cat),
                   Expand => False, Fill => False, Padding => 1);
            end loop;

            --  Button row
            declare
               Btn_Box : Gtk.Box.Gtk_Box;
            begin
               Gtk.Box.Gtk_New_Hbox (Btn_Box, Spacing => 6);
               Gtk.Button.Gtk_New (Win.Export_Button, "Export");
               Gtk.Button.Gtk_New (Win.Compare_Button, "Compare");
               Btn_Box.Pack_Start (Win.Export_Button, Expand => True,
                                   Fill => True, Padding => 4);
               Btn_Box.Pack_Start (Win.Compare_Button, Expand => True,
                                   Fill => True, Padding => 4);
               Centre_Box.Pack_Start (Btn_Box, Expand => False,
                                      Fill => False, Padding => 4);
            end;
         end;

         --  =============================================================
         --  RIGHT PANEL: Findings
         --  =============================================================
         declare
            Right_Box : Gtk.Box.Gtk_Box;
         begin
            Gtk.Box.Gtk_New_Vbox (Right_Box, Spacing => 6);
            Gtk.Frame.Gtk_New (Win.Findings_Frame, "Findings");
            Win.Findings_Frame.Add (Right_Box);
            Right_Paned.Pack2 (Win.Findings_Frame, Resize => True,
                                Shrink => False);

            --  Findings tree view with list store
            --  Columns: Severity, Category, Matched, Explanation
            declare
               Types : constant Glib.GType_Array :=
                  (0 => Glib.GType_String,   --  Severity
                   1 => Glib.GType_String,   --  Category
                   2 => Glib.GType_String,   --  Matched text
                   3 => Glib.GType_String);  --  Explanation
            begin
               Gtk.List_Store.Gtk_New (Win.Findings_Store, Types);
            end;

            Gtk.Tree_View.Gtk_New
               (Win.Findings_Tree,
                +Win.Findings_Store);
            Add_Text_Column (Win.Findings_Tree, "Severity", 0);
            Add_Text_Column (Win.Findings_Tree, "Category", 1);
            Add_Text_Column (Win.Findings_Tree, "Match", 2);
            Add_Text_Column (Win.Findings_Tree, "Explanation", 3);
            Win.Findings_Tree.Set_Headers_Visible (True);

            Right_Box.Pack_Start
               (Wrap_In_Scrolled (Win.Findings_Tree),
                Expand => True, Fill => True, Padding => 2);

            --  Pattern detail text view
            declare
               Detail_Label : Gtk.Label.Gtk_Label;
            begin
               Gtk.Label.Gtk_New (Detail_Label, "Pattern Details:");
               Right_Box.Pack_Start (Detail_Label, Expand => False,
                                     Fill => False, Padding => 2);
               Gtk.Text_Buffer.Gtk_New (Win.Pattern_Buffer);
               Gtk.Text_View.Gtk_New
                  (Win.Pattern_View, Win.Pattern_Buffer);
               Win.Pattern_View.Set_Wrap_Mode
                  (Gtk.Enums.Wrap_Word_Char);
               Win.Pattern_View.Set_Editable (False);
               Right_Box.Pack_Start
                  (Wrap_In_Scrolled (Win.Pattern_View),
                   Expand => True, Fill => True, Padding => 2);
            end;
         end;
      end;

      --  ==================================================================
      --  BOTTOM PANEL: Model Comparison
      --  ==================================================================
      declare
         Bottom_Box : Gtk.Box.Gtk_Box;
         --  Columns: Model, ISA, then 10 category columns, Rank
         Num_Cols : constant := 13;
         Types    : constant Glib.GType_Array (0 .. Num_Cols - 1) :=
            [others => Glib.GType_String];
      begin
         Gtk.Box.Gtk_New_Vbox (Bottom_Box, Spacing => 4);
         Gtk.Frame.Gtk_New (Win.Comparison_Frame, "Model Comparison");
         Win.Comparison_Frame.Add (Bottom_Box);
         Win.Main_Box.Pack_Start (Win.Comparison_Frame, Expand => True,
                                  Fill => True, Padding => 0);

         Gtk.List_Store.Gtk_New (Win.Comparison_Store, Types);
         Gtk.Tree_View.Gtk_New
            (Win.Comparison_Tree, +Win.Comparison_Store);

         Add_Text_Column (Win.Comparison_Tree, "Model", 0);
         Add_Text_Column (Win.Comparison_Tree, "ISA", 1);

         declare
            Col_Idx : Gint := 2;
         begin
            for Cat in Metric_Category loop
               Add_Text_Column
                  (Win.Comparison_Tree,
                   Category_Abbreviation (Cat),
                   Col_Idx);
               Col_Idx := Col_Idx + 1;
            end loop;
         end;
         Add_Text_Column (Win.Comparison_Tree, "Rank", 12);
         Win.Comparison_Tree.Set_Headers_Visible (True);

         Bottom_Box.Pack_Start
            (Wrap_In_Scrolled (Win.Comparison_Tree),
             Expand => True, Fill => True, Padding => 2);

         --  Bottom buttons
         declare
            Bottom_Btn_Box : Gtk.Box.Gtk_Box;
         begin
            Gtk.Box.Gtk_New_Hbox (Bottom_Btn_Box, Spacing => 6);
            Gtk.Button.Gtk_New (Win.Run_Suite_Button, "Run Suite");
            Gtk.Button.Gtk_New (Win.Export_All_Button, "Export All");
            Bottom_Btn_Box.Pack_End
               (Win.Export_All_Button,
                Expand => False, Fill => False, Padding => 4);
            Bottom_Btn_Box.Pack_End
               (Win.Run_Suite_Button,
                Expand => False, Fill => False, Padding => 4);
            Bottom_Box.Pack_Start
               (Bottom_Btn_Box, Expand => False,
                Fill => False, Padding => 4);
         end;
      end;

      --  ==================================================================
      --  STATUS BAR
      --  ==================================================================
      declare
         Sep : Gtk.Separator.Gtk_Separator;
      begin
         Gtk.Separator.Gtk_New_Hseparator (Sep);
         Win.Main_Box.Pack_Start (Sep, Expand => False,
                                  Fill => False, Padding => 0);
      end;

      Gtk.Box.Gtk_New_Hbox (Win.Status_Box, Spacing => 6);
      Gtk.Label.Gtk_New (Win.Status_Label, "Ready");
      Gtk.Progress_Bar.Gtk_New (Win.Progress_Bar);
      Win.Progress_Bar.Set_Fraction (0.0);
      Win.Progress_Bar.Set_Show_Text (False);
      Win.Status_Box.Pack_Start (Win.Status_Label, Expand => True,
                                 Fill => True, Padding => 4);
      Win.Status_Box.Pack_End (Win.Progress_Bar, Expand => False,
                               Fill => False, Padding => 4);
      Win.Main_Box.Pack_Start (Win.Status_Box, Expand => False,
                               Fill => False, Padding => 2);

      --  Default config
      Win.Config := (
         Dark_Theme        => True,
         Font_Size         => 11,
         Font_Family       => "JetBrains Mono              ",
         Show_Line_Numbers => True,
         Wrap_Text         => True,
         Animate_Charts    => True
      );

      --  Initialise state
      Win.Current_Analysis := (
         Model_ID        => Null_Unbounded_String,
         Model_Version   => Null_Unbounded_String,
         Prompt          => Null_Unbounded_String,
         Response        => Null_Unbounded_String,
         Response_Time   => 0.0,
         Token_Count     => 0,
         Findings        => Finding_Vectors.Empty_Vector,
         Category_Scores => Null_Category_Scores,
         Overall_ISA     => 0.0,
         Timestamp       => Ada.Calendar.Clock
      );
      Win.Profiles := Profile_Vectors.Empty_Vector;
   end Initialize;

   ---------------------------------------------------------------------------
   --  Show
   ---------------------------------------------------------------------------

   procedure Show (Win : Main_Window) is
      --  Display the main window and all child widgets.
   begin
      Win.Window.Show_All;
   end Show;

   ---------------------------------------------------------------------------
   --  Run / Quit
   ---------------------------------------------------------------------------

   procedure Run is
      --  Enter the GTK main event loop.  Blocks until Quit is called.
   begin
      Gtk.Main.Main;
   end Run;

   procedure Quit is
      --  Exit the GTK main event loop, causing Run to return.
   begin
      Gtk.Main.Main_Quit;
   end Quit;

   ---------------------------------------------------------------------------
   --  Panel Updates
   ---------------------------------------------------------------------------

   procedure Set_Model
      (Win   : in out Main_Window;
       Model : String)
   is
      --  Set the active model in the combo box.  If the model is not
      --  already in the list, append it and select it.
   begin
      --  Append the model name and set it active.
      --  GtkComboBoxText does not have a simple "find and select" API,
      --  so we prepend it to ensure it appears.
      Win.Model_Combo.Prepend_Text (Model);
      Win.Model_Combo.Set_Active (0);
   end Set_Model;

   procedure Set_Prompt
      (Win    : in out Main_Window;
       Prompt : String)
   is
      --  Set the prompt text in the prompt text view.
   begin
      Win.Prompt_Buffer.Set_Text (Prompt);
   end Set_Prompt;

   procedure Set_Response
      (Win      : in out Main_Window;
       Response : String)
   is
      --  Set the response text in the response text view.
   begin
      Win.Response_Buffer.Set_Text (Response);
   end Set_Response;

   procedure Update_Analysis
      (Win      : in out Main_Window;
       Analysis : Response_Analysis)
   is
      --  Update the GUI with a new analysis result: ISA label,
      --  category labels, findings tree, and radar chart.
   begin
      Win.Current_Analysis := Analysis;

      --  Update ISA label
      Win.ISA_Label.Set_Text
         ("ISA: " & Float_Img (Analysis.Overall_ISA));

      --  Update category labels
      for Cat in Metric_Category loop
         Win.Category_Labels (Cat).Set_Text
            (Category_Abbreviation (Cat) & ": "
             & Float_Img (Analysis.Category_Scores (Cat)));
      end loop;

      --  Update findings
      Update_Findings (Win, Analysis.Findings);

      --  Queue radar chart redraw
      Win.Radar_Area.Queue_Draw;
   end Update_Analysis;

   procedure Update_Findings
      (Win      : in out Main_Window;
       Findings : Finding_Vector)
   is
      --  Populate the findings tree view with finding records.
      use Finding_Vectors;
      Iter : Gtk.Tree_Model.Gtk_Tree_Iter;
   begin
      Win.Findings_Store.Clear;

      for F of Findings loop
         Win.Findings_Store.Append (Iter);
         Win.Findings_Store.Set
            (Iter, 0,
             (case F.Severity is
                when None     => "None",
                when Low      => "Low",
                when Medium   => "Medium",
                when High     => "High",
                when Critical => "Critical"));
         Win.Findings_Store.Set
            (Iter, 1, Category_Abbreviation (F.Category));
         Win.Findings_Store.Set
            (Iter, 2, To_String (F.Matched));
         Win.Findings_Store.Set
            (Iter, 3, To_String (F.Explanation));
      end loop;
   end Update_Findings;

   procedure Update_Radar_Chart
      (Win    : in out Main_Window;
       Scores : Category_Score_Array;
       ISA    : Float)
   is
      --  Update the stored scores and ISA value, then queue a
      --  redraw of the radar chart area.
   begin
      Win.Current_Analysis.Category_Scores := Scores;
      Win.Current_Analysis.Overall_ISA := ISA;
      Win.ISA_Label.Set_Text ("ISA: " & Float_Img (ISA));

      for Cat in Metric_Category loop
         Win.Category_Labels (Cat).Set_Text
            (Category_Abbreviation (Cat) & ": "
             & Float_Img (Scores (Cat)));
      end loop;

      Win.Radar_Area.Queue_Draw;
   end Update_Radar_Chart;

   procedure Update_Model_Comparison
      (Win      : in out Main_Window;
       Profiles : Profile_Vector)
   is
      --  Populate the model comparison tree view with profile data.
      use Profile_Vectors;
      Iter : Gtk.Tree_Model.Gtk_Tree_Iter;
   begin
      Win.Profiles := Profiles;
      Win.Comparison_Store.Clear;

      for P of Profiles loop
         Win.Comparison_Store.Append (Iter);
         Win.Comparison_Store.Set
            (Iter, 0, To_String (P.Model_ID));
         Win.Comparison_Store.Set
            (Iter, 1, Float_Img (P.Mean_ISA));

         declare
            Col_Idx : Gint := 2;
         begin
            for Cat in Metric_Category loop
               Win.Comparison_Store.Set
                  (Iter, Col_Idx,
                   Float_Img (P.Category_Means (Cat)));
               Col_Idx := Col_Idx + 1;
            end loop;
         end;

         Win.Comparison_Store.Set
            (Iter, 12, Natural'Image (P.Comparison_Rank));
      end loop;
   end Update_Model_Comparison;

   procedure Highlight_Finding
      (Win     : in out Main_Window;
       Finding : Vexometer.Core.Finding)
   is
      --  Highlight the matched text in the response view and display
      --  the pattern details in the pattern detail view.
      Start_Iter : Gtk.Text_Buffer.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Buffer.Gtk_Text_Iter;
   begin
      --  Display finding details in pattern view
      Win.Pattern_Buffer.Set_Text
         ("Category: " & Category_Full_Name (Finding.Category)
          & ASCII.LF
          & "Severity: "
          & (case Finding.Severity is
               when None     => "None",
               when Low      => "Low",
               when Medium   => "Medium",
               when High     => "High",
               when Critical => "Critical")
          & ASCII.LF
          & "Pattern: " & To_String (Finding.Pattern_ID)
          & ASCII.LF
          & "Match: " & To_String (Finding.Matched)
          & ASCII.LF
          & "Location: offset "
          & Natural'Image (Finding.Location)
          & ", length "
          & Natural'Image (Finding.Length)
          & ASCII.LF
          & "Confidence: "
          & Float_Img (Float (Finding.Conf), 2)
          & ASCII.LF & ASCII.LF
          & To_String (Finding.Explanation));

      --  Highlight in response view
      --  Get iterators at the finding location
      Win.Response_Buffer.Get_Iter_At_Offset
         (Start_Iter, Gint (Finding.Location));
      Win.Response_Buffer.Get_Iter_At_Offset
         (End_Iter, Gint (Finding.Location + Finding.Length));
      Win.Response_Buffer.Select_Range (Start_Iter, End_Iter);
   end Highlight_Finding;

   ---------------------------------------------------------------------------
   --  Progress and Status
   ---------------------------------------------------------------------------

   procedure Show_Progress
      (Win     : in out Main_Window;
       Message : String;
       Percent : Float)
   is
      --  Display a progress message and set the progress bar fraction.
   begin
      Win.Status_Label.Set_Text (Message);
      Win.Progress_Bar.Set_Fraction
         (Gdouble (Float'Max (0.0, Float'Min (1.0, Percent / 100.0))));
      Win.Progress_Bar.Set_Show_Text (True);
   end Show_Progress;

   procedure Hide_Progress (Win : in out Main_Window) is
      --  Reset the progress bar and status label to idle state.
   begin
      Win.Progress_Bar.Set_Fraction (0.0);
      Win.Progress_Bar.Set_Show_Text (False);
      Win.Status_Label.Set_Text ("Ready");
   end Hide_Progress;

   procedure Show_Status
      (Win     : in out Main_Window;
       Message : String)
   is
      --  Display a status message in the status bar.
   begin
      Win.Status_Label.Set_Text (Message);
   end Show_Status;

   procedure Show_Error
      (Win     : in out Main_Window;
       Message : String)
   is
      --  Display an error message dialog.
      Dialog : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Result : Gtk.Dialog.Gtk_Response_Type;
      pragma Unreferenced (Result);
   begin
      Gtk.Message_Dialog.Gtk_New
         (Dialog,
          Parent  => Win.Window,
          Flags   => Gtk.Dialog.Modal,
          The_Type => Gtk.Message_Dialog.Message_Error,
          Buttons => Gtk.Message_Dialog.Buttons_Ok,
          Message => Message);
      Dialog.Set_Title ("Error");
      Result := Dialog.Run;
      Dialog.Destroy;
   end Show_Error;

   ---------------------------------------------------------------------------
   --  Dialogs
   ---------------------------------------------------------------------------

   function Show_File_Open_Dialog
      (Win    : Main_Window;
       Title  : String;
       Filter : String := "") return String
   is
      --  Display a file-open dialog and return the selected path.
      --  Returns empty string if the user cancels.
      pragma Unreferenced (Filter);
      Dialog : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
      Result : Gtk.Dialog.Gtk_Response_Type;
   begin
      Gtk.File_Chooser_Dialog.Gtk_New
         (Dialog,
          Title  => Title,
          Parent => Win.Window,
          Action => Gtk.File_Chooser_Dialog.Action_Open);
      Dialog.Add_Button ("Cancel", Gtk.Dialog.Gtk_Response_Cancel);
      Dialog.Add_Button ("Open", Gtk.Dialog.Gtk_Response_Accept);

      Result := Dialog.Run;

      if Result = Gtk.Dialog.Gtk_Response_Accept then
         declare
            Path : constant String := Dialog.Get_Filename;
         begin
            Dialog.Destroy;
            return Path;
         end;
      else
         Dialog.Destroy;
         return "";
      end if;
   end Show_File_Open_Dialog;

   function Show_File_Save_Dialog
      (Win    : Main_Window;
       Title  : String;
       Filter : String := "") return String
   is
      --  Display a file-save dialog and return the selected path.
      --  Returns empty string if the user cancels.
      pragma Unreferenced (Filter);
      Dialog : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
      Result : Gtk.Dialog.Gtk_Response_Type;
   begin
      Gtk.File_Chooser_Dialog.Gtk_New
         (Dialog,
          Title  => Title,
          Parent => Win.Window,
          Action => Gtk.File_Chooser_Dialog.Action_Save);
      Dialog.Add_Button ("Cancel", Gtk.Dialog.Gtk_Response_Cancel);
      Dialog.Add_Button ("Save", Gtk.Dialog.Gtk_Response_Accept);
      Dialog.Set_Do_Overwrite_Confirmation (True);

      Result := Dialog.Run;

      if Result = Gtk.Dialog.Gtk_Response_Accept then
         declare
            Path : constant String := Dialog.Get_Filename;
         begin
            Dialog.Destroy;
            return Path;
         end;
      else
         Dialog.Destroy;
         return "";
      end if;
   end Show_File_Save_Dialog;

   procedure Show_About_Dialog (Win : Main_Window) is
      --  Display the About dialog with project information.
      Dialog : Gtk.About_Dialog.Gtk_About_Dialog;
      Result : Gtk.Dialog.Gtk_Response_Type;
      pragma Unreferenced (Result);
   begin
      Gtk.About_Dialog.Gtk_New (Dialog);
      Dialog.Set_Program_Name ("Vexometer");
      Dialog.Set_Version (Vexometer.Version);
      Dialog.Set_Comments
         ("Irritation Surface Analyser for AI Assistants");
      Dialog.Set_Copyright
         ("Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)");
      Dialog.Set_License_Type (Gtk.About_Dialog.License_Custom);
      Dialog.Set_License ("PMPL-1.0-or-later");
      Dialog.Set_Website ("https://github.com/hyperpolymath/vexometer");
      Dialog.Set_Website_Label ("GitHub Repository");
      Dialog.Set_Transient_For (Win.Window);
      Result := Dialog.Run;
      Dialog.Destroy;
   end Show_About_Dialog;

   procedure Show_Settings_Dialog (Win : in out Main_Window) is
      --  Display a settings dialog allowing configuration of theme,
      --  font, and display options.
      Dialog    : Gtk.Dialog.Gtk_Dialog;
      Result    : Gtk.Dialog.Gtk_Response_Type;
      Content   : Gtk.Box.Gtk_Box;
      Dark_Chk  : Gtk.Check_Button.Gtk_Check_Button;
      Wrap_Chk  : Gtk.Check_Button.Gtk_Check_Button;
      Lines_Chk : Gtk.Check_Button.Gtk_Check_Button;
      Anim_Chk  : Gtk.Check_Button.Gtk_Check_Button;
      Size_Spin : Gtk.Spin_Button.Gtk_Spin_Button;
      Size_Label : Gtk.Label.Gtk_Label;
   begin
      Gtk.Dialog.Gtk_New
         (Dialog,
          Title  => "Settings",
          Parent => Win.Window,
          Flags  => Gtk.Dialog.Modal);
      Dialog.Add_Button ("Cancel", Gtk.Dialog.Gtk_Response_Cancel);
      Dialog.Add_Button ("Apply", Gtk.Dialog.Gtk_Response_Accept);
      Dialog.Set_Default_Size (350, 250);

      Content := Gtk.Dialog.Get_Content_Area (Dialog);

      --  Dark theme toggle
      Gtk.Check_Button.Gtk_New (Dark_Chk, "Dark Theme");
      Dark_Chk.Set_Active (Win.Config.Dark_Theme);
      Content.Pack_Start (Dark_Chk, Expand => False,
                          Fill => False, Padding => 4);

      --  Wrap text toggle
      Gtk.Check_Button.Gtk_New (Wrap_Chk, "Wrap Text");
      Wrap_Chk.Set_Active (Win.Config.Wrap_Text);
      Content.Pack_Start (Wrap_Chk, Expand => False,
                          Fill => False, Padding => 4);

      --  Show line numbers toggle
      Gtk.Check_Button.Gtk_New (Lines_Chk, "Show Line Numbers");
      Lines_Chk.Set_Active (Win.Config.Show_Line_Numbers);
      Content.Pack_Start (Lines_Chk, Expand => False,
                          Fill => False, Padding => 4);

      --  Animate charts toggle
      Gtk.Check_Button.Gtk_New (Anim_Chk, "Animate Charts");
      Anim_Chk.Set_Active (Win.Config.Animate_Charts);
      Content.Pack_Start (Anim_Chk, Expand => False,
                          Fill => False, Padding => 4);

      --  Font size spinner
      declare
         Size_Box : Gtk.Box.Gtk_Box;
      begin
         Gtk.Box.Gtk_New_Hbox (Size_Box, Spacing => 6);
         Gtk.Label.Gtk_New (Size_Label, "Font Size:");
         Gtk.Spin_Button.Gtk_New
            (Size_Spin,
             Min  => 8.0,
             Max  => 24.0,
             Step => 1.0);
         Size_Spin.Set_Value (Gdouble (Win.Config.Font_Size));
         Size_Box.Pack_Start (Size_Label, Expand => False,
                              Fill => False, Padding => 4);
         Size_Box.Pack_Start (Size_Spin, Expand => False,
                              Fill => False, Padding => 4);
         Content.Pack_Start (Size_Box, Expand => False,
                             Fill => False, Padding => 4);
      end;

      Dialog.Show_All;
      Result := Dialog.Run;

      if Result = Gtk.Dialog.Gtk_Response_Accept then
         Win.Config.Dark_Theme := Dark_Chk.Get_Active;
         Win.Config.Wrap_Text := Wrap_Chk.Get_Active;
         Win.Config.Show_Line_Numbers := Lines_Chk.Get_Active;
         Win.Config.Animate_Charts := Anim_Chk.Get_Active;
         Win.Config.Font_Size :=
            Positive (Integer (Size_Spin.Get_Value));

         --  Apply text wrapping
         Win.Prompt_View.Set_Wrap_Mode
            (if Win.Config.Wrap_Text then Gtk.Enums.Wrap_Word_Char
             else Gtk.Enums.Wrap_None);
         Win.Response_View.Set_Wrap_Mode
            (if Win.Config.Wrap_Text then Gtk.Enums.Wrap_Word_Char
             else Gtk.Enums.Wrap_None);
      end if;

      Dialog.Destroy;
   end Show_Settings_Dialog;

   ---------------------------------------------------------------------------
   --  Radar Chart Drawing (Cairo)
   ---------------------------------------------------------------------------

   procedure Draw_Radar_Chart
      (Context : Cairo.Cairo_Context;
       Scores  : Category_Score_Array;
       X, Y    : Float;
       Radius  : Float)
   is
      --  Draw a 10-axis radar (spider) chart using Cairo.
      --
      --  The chart is centred at (X, Y) with the given Radius.
      --  Each of the 10 metric categories gets one axis, evenly
      --  distributed around the circle.  Scores are normalised from
      --  0..10 to 0..1 for plotting.
      --
      --  Rendering layers:
      --    1. Concentric guide rings (25%, 50%, 75%, 100%)
      --    2. Axis lines from centre to perimeter
      --    3. Filled data polygon
      --    4. Score dots on each axis
      --    5. Category abbreviation labels at axis endpoints

      N : constant := Metric_Category'Pos (Metric_Category'Last) + 1;
      Angle_Step : constant Float := 2.0 * Pi / Float (N);

      function Axis_X (Index : Natural; Frac : Float) return Float is
      begin
         return X + Frac * Radius
                * Sin (Float (Index) * Angle_Step - Pi / 2.0);
      end Axis_X;

      function Axis_Y (Index : Natural; Frac : Float) return Float is
      begin
         return Y - Frac * Radius
                * Cos (Float (Index) * Angle_Step - Pi / 2.0);
      end Axis_Y;

   begin
      Cairo.Save (Context);

      --  1. Draw concentric guide rings
      Set_Cairo_Colour (Context, (0.35, 0.35, 0.38, 0.4));
      Cairo.Set_Line_Width (Context, 0.5);
      for Ring in 1 .. 4 loop
         declare
            Frac : constant Float := Float (Ring) * 0.25;
         begin
            Cairo.Move_To
               (Context,
                Gdouble (Axis_X (0, Frac)),
                Gdouble (Axis_Y (0, Frac)));
            for I in 1 .. N - 1 loop
               Cairo.Line_To
                  (Context,
                   Gdouble (Axis_X (I, Frac)),
                   Gdouble (Axis_Y (I, Frac)));
            end loop;
            Cairo.Close_Path (Context);
            Cairo.Stroke (Context);
         end;
      end loop;

      --  2. Draw axis lines
      Set_Cairo_Colour (Context, (0.40, 0.40, 0.43, 0.5));
      Cairo.Set_Line_Width (Context, 0.5);
      for I in 0 .. N - 1 loop
         Cairo.Move_To (Context, Gdouble (X), Gdouble (Y));
         Cairo.Line_To
            (Context,
             Gdouble (Axis_X (I, 1.0)),
             Gdouble (Axis_Y (I, 1.0)));
         Cairo.Stroke (Context);
      end loop;

      --  3. Draw filled data polygon
      declare
         First_Drawn : Boolean := False;
      begin
         for Cat in Metric_Category loop
            declare
               I    : constant Natural := Metric_Category'Pos (Cat);
               Frac : constant Float :=
                  Float'Min (1.0, Scores (Cat) / 10.0);
            begin
               if not First_Drawn then
                  Cairo.Move_To
                     (Context,
                      Gdouble (Axis_X (I, Frac)),
                      Gdouble (Axis_Y (I, Frac)));
                  First_Drawn := True;
               else
                  Cairo.Line_To
                     (Context,
                      Gdouble (Axis_X (I, Frac)),
                      Gdouble (Axis_Y (I, Frac)));
               end if;
            end;
         end loop;
         Cairo.Close_Path (Context);

         --  Fill with semi-transparent accent colour
         Set_Cairo_Colour
            (Context, (Colour_Accent.R, Colour_Accent.G,
                       Colour_Accent.B, 0.25));
         Cairo.Fill_Preserve (Context);

         --  Stroke outline
         Set_Cairo_Colour (Context, Colour_Accent);
         Cairo.Set_Line_Width (Context, 2.0);
         Cairo.Stroke (Context);
      end;

      --  4. Draw score dots
      for Cat in Metric_Category loop
         declare
            I    : constant Natural := Metric_Category'Pos (Cat);
            Frac : constant Float :=
               Float'Min (1.0, Scores (Cat) / 10.0);
            DX   : constant Float := Axis_X (I, Frac);
            DY   : constant Float := Axis_Y (I, Frac);
         begin
            Set_Cairo_Colour (Context, Colour_Accent);
            Cairo.Arc
               (Context,
                Gdouble (DX), Gdouble (DY),
                3.0, 0.0, 2.0 * Gdouble (Pi));
            Cairo.Fill (Context);
         end;
      end loop;

      --  5. Draw axis labels
      Cairo.Select_Font_Face
         (Context, "sans-serif",
          Cairo.Cairo_Font_Slant_Normal,
          Cairo.Cairo_Font_Weight_Normal);
      Cairo.Set_Font_Size (Context, 10.0);
      Set_Cairo_Colour (Context, Colour_Text);

      for Cat in Metric_Category loop
         declare
            I  : constant Natural := Metric_Category'Pos (Cat);
            LX : constant Float := Axis_X (I, 1.18);
            LY : constant Float := Axis_Y (I, 1.18);
            Abbrev : constant String := Category_Abbreviation (Cat);
         begin
            --  Centre the label text approximately
            Cairo.Move_To
               (Context,
                Gdouble (LX) - Gdouble (Abbrev'Length) * 3.0,
                Gdouble (LY) + 3.0);
            Cairo.Show_Text (Context, Abbrev);
         end;
      end loop;

      Cairo.Restore (Context);
   end Draw_Radar_Chart;

   ---------------------------------------------------------------------------
   --  ISA Gauge Drawing (Cairo)
   ---------------------------------------------------------------------------

   procedure Draw_ISA_Gauge
      (Context : Cairo.Cairo_Context;
       Score   : Float;
       X, Y    : Float;
       Size    : Float)
   is
      --  Draw a semicircular ISA gauge using Cairo.
      --
      --  The gauge is centred at (X, Y) with radius proportional
      --  to Size.  The arc sweeps from left (green, score=0) to
      --  right (red, score=100).
      --
      --  Rendering layers:
      --    1. Background arc segments with severity colours
      --    2. Needle line pointing to current score
      --    3. Centre dot
      --    4. Score text value
      --    5. "ISA" label

      S      : constant Float :=
         Float'Max (0.0, Float'Min (100.0, Score));
      Frac   : constant Float := S / 100.0;
      Outer  : constant Float := Size * 0.8;
      Inner  : constant Float := Size * 0.6;
      Col    : constant Colour := ISA_Colour (S);

      --  Segment definitions: fraction range and colour
      type Seg_Rec is record
         F1, F2 : Float;
         C      : Colour;
      end record;

      Segments : constant array (1 .. 5) of Seg_Rec := (
         (0.0,  0.2,  Colour_Excellent),
         (0.2,  0.35, Colour_Good),
         (0.35, 0.5,  Colour_Acceptable),
         (0.5,  0.7,  Colour_Poor),
         (0.7,  1.0,  Colour_Unusable)
      );

   begin
      Cairo.Save (Context);

      --  1. Draw background arc segments
      for Seg of Segments loop
         declare
            A1 : constant Float := Pi - (Seg.F1 * Pi);
            A2 : constant Float := Pi - (Seg.F2 * Pi);
         begin
            Set_Cairo_Colour
               (Context, (Seg.C.R, Seg.C.G, Seg.C.B, 0.25));
            Cairo.Set_Line_Width (Context, Gdouble (Outer - Inner));

            --  Draw arc at the midpoint radius
            Cairo.Arc
               (Context,
                Gdouble (X), Gdouble (Y),
                Gdouble ((Outer + Inner) / 2.0),
                Gdouble (Pi - A1),      --  Cairo angles: 0 = right
                Gdouble (Pi - A2));
            Cairo.Stroke (Context);
         end;
      end loop;

      --  2. Draw needle
      declare
         Needle_Angle : constant Float := Pi - (Frac * Pi);
         NX : constant Float := X + Outer * Cos (Needle_Angle);
         NY : constant Float := Y - Outer * Sin (Needle_Angle);
      begin
         Set_Cairo_Colour (Context, Col);
         Cairo.Set_Line_Width (Context, 2.5);
         Cairo.Set_Line_Cap
            (Context, Cairo.Cairo_Line_Cap_Round);
         Cairo.Move_To (Context, Gdouble (X), Gdouble (Y));
         Cairo.Line_To (Context, Gdouble (NX), Gdouble (NY));
         Cairo.Stroke (Context);
      end;

      --  3. Centre dot
      Set_Cairo_Colour (Context, Col);
      Cairo.Arc
         (Context,
          Gdouble (X), Gdouble (Y),
          5.0, 0.0, 2.0 * Gdouble (Pi));
      Cairo.Fill (Context);

      --  4. Score text
      Cairo.Select_Font_Face
         (Context, "sans-serif",
          Cairo.Cairo_Font_Slant_Normal,
          Cairo.Cairo_Font_Weight_Bold);
      Cairo.Set_Font_Size (Context, 20.0);
      Set_Cairo_Colour (Context, Col);

      declare
         Score_Str : constant String := Float_Img (S, 1);
         Width_Est : constant Gdouble :=
            Gdouble (Score_Str'Length) * 6.5;
      begin
         Cairo.Move_To
            (Context,
             Gdouble (X) - Width_Est / 2.0,
             Gdouble (Y) + 25.0);
         Cairo.Show_Text (Context, Score_Str);
      end;

      --  5. "ISA" label
      Cairo.Set_Font_Size (Context, 10.0);
      Set_Cairo_Colour (Context, Colour_Text_Dim);
      Cairo.Move_To
         (Context,
          Gdouble (X) - 8.0,
          Gdouble (Y) + 38.0);
      Cairo.Show_Text (Context, "ISA");

      Cairo.Restore (Context);
   end Draw_ISA_Gauge;

   ---------------------------------------------------------------------------
   --  Configuration
   ---------------------------------------------------------------------------

   procedure Apply_Config
      (Win    : in out Main_Window;
       Config : GUI_Config)
   is
      --  Apply the given GUI configuration to the window.
      --  Updates text wrapping, theme, and stores the config.
   begin
      Win.Config := Config;

      --  Apply wrap mode
      if Config.Wrap_Text then
         Win.Prompt_View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
         Win.Response_View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
         Win.Pattern_View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
      else
         Win.Prompt_View.Set_Wrap_Mode (Gtk.Enums.Wrap_None);
         Win.Response_View.Set_Wrap_Mode (Gtk.Enums.Wrap_None);
         Win.Pattern_View.Set_Wrap_Mode (Gtk.Enums.Wrap_None);
      end if;

      --  Re-apply dark theme if configured
      if Config.Dark_Theme then
         Apply_Dark_Theme;
      end if;

      --  Queue redraw for charts
      Win.Radar_Area.Queue_Draw;
   end Apply_Config;

   function Get_Config (Win : Main_Window) return GUI_Config is
      --  Return the current GUI configuration.
   begin
      return Win.Config;
   end Get_Config;

end Vexometer.GUI;
