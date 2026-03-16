--  Vexometer.Reports - Report generation body
--
--  Implements multi-format report generation for ISA analysis results.
--  Supports JSON, HTML (with embedded SVG charts), Markdown, CSV, LaTeX,
--  and LMSYS Chatbot Arena submission format.
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Text_IO;
with Ada.Float_Text_IO;
with Ada.Calendar.Formatting;
with Ada.Numerics.Elementary_Functions;

package body Vexometer.Reports is

   use Ada.Text_IO;
   use Ada.Strings.Unbounded;
   use Ada.Numerics.Elementary_Functions;

   ---------------------------------------------------------------------------
   --  Package State
   ---------------------------------------------------------------------------

   Current_Options : Export_Options := Default_Export;

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   function Escape_JSON (S : String) return String is
      --  Escape a string for safe inclusion in JSON output.
      --  Handles backslash, double-quote, and control characters.
      Result : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '"'  => Append (Result, "\""");
            when '\'  => Append (Result, "\\");
            when ASCII.LF => Append (Result, "\n");
            when ASCII.CR => Append (Result, "\r");
            when ASCII.HT => Append (Result, "\t");
            when others =>
               if Character'Pos (C) < 32 then
                  --  Skip other control characters
                  null;
               else
                  Append (Result, C);
               end if;
         end case;
      end loop;
      return To_String (Result);
   end Escape_JSON;

   function Escape_HTML (S : String) return String is
      --  Escape special HTML characters to prevent XSS and
      --  ensure correct rendering.
      Result : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '&'  => Append (Result, "&amp;");
            when '<'  => Append (Result, "&lt;");
            when '>'  => Append (Result, "&gt;");
            when '"'  => Append (Result, "&quot;");
            when '''  => Append (Result, "&#39;");
            when others => Append (Result, C);
         end case;
      end loop;
      return To_String (Result);
   end Escape_HTML;

   function Escape_LaTeX (S : String) return String is
      --  Escape LaTeX special characters for safe inclusion in
      --  tabular/document environments.
      Result : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '&'  => Append (Result, "\&");
            when '%'  => Append (Result, "\%");
            when '$'  => Append (Result, "\$");
            when '#'  => Append (Result, "\#");
            when '_'  => Append (Result, "\_");
            when '{'  => Append (Result, "\{");
            when '}'  => Append (Result, "\}");
            when '~'  => Append (Result, "\textasciitilde{}");
            when '^'  => Append (Result, "\textasciicircum{}");
            when '\'  => Append (Result, "\textbackslash{}");
            when others => Append (Result, C);
         end case;
      end loop;
      return To_String (Result);
   end Escape_LaTeX;

   function Escape_CSV (S : String) return String is
      --  Wrap the string in double-quotes and escape internal quotes.
      --  Follows RFC 4180 conventions.
      Needs_Quoting : Boolean := False;
      Result        : Unbounded_String;
   begin
      --  Check if quoting is needed
      for C of S loop
         if C = ',' or C = '"' or C = ASCII.LF or C = ASCII.CR then
            Needs_Quoting := True;
            exit;
         end if;
      end loop;

      if not Needs_Quoting then
         return S;
      end if;

      Append (Result, '"');
      for C of S loop
         if C = '"' then
            Append (Result, """""");
         else
            Append (Result, C);
         end if;
      end loop;
      Append (Result, '"');
      return To_String (Result);
   end Escape_CSV;

   function Float_Image (V : Float; Decimals : Natural := 2) return String is
      --  Format a Float value with the specified number of decimal places.
      --  Uses the decimal places configured in Current_Options by default.
      Buf : String (1 .. 32);
      Aft : constant Natural :=
         (if Decimals > 0 then Decimals else Current_Options.Decimal_Places);
   begin
      Ada.Float_Text_IO.Put (Buf, V, Aft => Aft, Exp => 0);
      --  Trim leading spaces
      for I in Buf'Range loop
         if Buf (I) /= ' ' then
            return Buf (I .. Buf'Last);
         end if;
      end loop;
      return Buf;
   end Float_Image;

   function Score_Image (S : Score) return String is
      --  Convert a Score (fixed-point 0..1) to a float string.
   begin
      return Float_Image (Float (S));
   end Score_Image;

   function Severity_Image (S : Severity_Level) return String is
      --  Return human-readable severity level name.
   begin
      return (case S is
         when None     => "None",
         when Low      => "Low",
         when Medium   => "Medium",
         when High     => "High",
         when Critical => "Critical");
   end Severity_Image;

   function NL return String is (1 => ASCII.LF);
   --  Newline shorthand for readability.

   function Timestamp_String (T : Ada.Calendar.Time) return String is
      --  Format a time value as an ISO 8601 timestamp string.
   begin
      return Ada.Calendar.Formatting.Image (T);
   exception
      when others => return "unknown";
   end Timestamp_String;

   function Indent (Level : Natural) return String is
      --  Generate JSON indentation: Level * 2 spaces.
   begin
      return [1 .. Level * 2 => ' '];
   end Indent;

   ---------------------------------------------------------------------------
   --  JSON Format Implementation
   ---------------------------------------------------------------------------

   function Finding_To_JSON (F : Finding) return String is
      --  Serialise a single Finding record to a JSON object string.
      R : Unbounded_String;
      I : constant String := Indent (2);
      I2 : constant String := Indent (3);
   begin
      Append (R, I & "{" & NL);
      Append (R, I2 & """category"": """
              & Category_Abbreviation (F.Category) & """," & NL);
      Append (R, I2 & """severity"": """
              & Severity_Image (F.Severity) & """," & NL);
      Append (R, I2 & """location"": " & F.Location'Image & "," & NL);
      Append (R, I2 & """length"": " & F.Length'Image & "," & NL);
      Append (R, I2 & """pattern_id"": """
              & Escape_JSON (To_String (F.Pattern_ID)) & """," & NL);
      Append (R, I2 & """matched"": """
              & Escape_JSON (To_String (F.Matched)) & """," & NL);
      Append (R, I2 & """explanation"": """
              & Escape_JSON (To_String (F.Explanation)) & """," & NL);
      Append (R, I2 & """confidence"": "
              & Float_Image (Float (F.Conf)) & NL);
      Append (R, I & "}");
      return To_String (R);
   end Finding_To_JSON;

   function Analysis_To_JSON (Analysis : Response_Analysis) return String is
      --  Serialise a full Response_Analysis to a JSON object string.
      --  Includes model info, scores per category, findings, and ISA.
      R : Unbounded_String;
      I : constant String := Indent (1);
      I2 : constant String := Indent (2);
   begin
      Append (R, "{" & NL);
      Append (R, I & """model_id"": """
              & Escape_JSON (To_String (Analysis.Model_ID)) & """," & NL);
      Append (R, I & """model_version"": """
              & Escape_JSON (To_String (Analysis.Model_Version))
              & """," & NL);
      Append (R, I & """overall_isa"": "
              & Float_Image (Analysis.Overall_ISA) & "," & NL);
      Append (R, I & """response_time"": "
              & Float_Image (Float (Analysis.Response_Time)) & "," & NL);
      Append (R, I & """token_count"": "
              & Analysis.Token_Count'Image & "," & NL);

      --  Category scores
      Append (R, I & """category_scores"": {" & NL);
      declare
         First : Boolean := True;
      begin
         for Cat in Metric_Category loop
            if not First then
               Append (R, "," & NL);
            end if;
            Append (R, I2 & """"
                    & Category_Abbreviation (Cat) & """: "
                    & Float_Image (Analysis.Category_Scores (Cat)));
            First := False;
         end loop;
      end;
      Append (R, NL & I & "}," & NL);

      --  Findings array
      Append (R, I & """findings"": [" & NL);
      declare
         use Finding_Vectors;
         First : Boolean := True;
      begin
         for F of Analysis.Findings loop
            if not First then
               Append (R, "," & NL);
            end if;
            Append (R, Finding_To_JSON (F));
            First := False;
         end loop;
      end;
      Append (R, NL & I & "]," & NL);

      Append (R, I & """timestamp"": """
              & Timestamp_String (Analysis.Timestamp) & """" & NL);
      Append (R, "}");
      return To_String (R);
   end Analysis_To_JSON;

   function Profile_To_JSON (Profile : Model_Profile) return String is
      --  Serialise a Model_Profile to a JSON object with aggregate stats,
      --  per-category means/medians/stddevs, and worst patterns.
      R  : Unbounded_String;
      I  : constant String := Indent (1);
      I2 : constant String := Indent (2);
   begin
      Append (R, "{" & NL);
      Append (R, I & """model_id"": """
              & Escape_JSON (To_String (Profile.Model_ID)) & """," & NL);
      Append (R, I & """model_version"": """
              & Escape_JSON (To_String (Profile.Model_Version))
              & """," & NL);
      Append (R, I & """provider"": """
              & Escape_JSON (To_String (Profile.Provider)) & """," & NL);
      Append (R, I & """analysis_count"": "
              & Profile.Analysis_Count'Image & "," & NL);
      Append (R, I & """mean_isa"": "
              & Float_Image (Profile.Mean_ISA) & "," & NL);
      Append (R, I & """std_dev_isa"": "
              & Float_Image (Profile.Std_Dev_ISA) & "," & NL);
      Append (R, I & """median_isa"": "
              & Float_Image (Profile.Median_ISA) & "," & NL);
      Append (R, I & """comparison_rank"": "
              & Profile.Comparison_Rank'Image & "," & NL);

      --  Category means
      Append (R, I & """category_means"": {" & NL);
      declare
         First : Boolean := True;
      begin
         for Cat in Metric_Category loop
            if not First then
               Append (R, "," & NL);
            end if;
            Append (R, I2 & """"
                    & Category_Abbreviation (Cat) & """: "
                    & Float_Image (Profile.Category_Means (Cat)));
            First := False;
         end loop;
      end;
      Append (R, NL & I & "}," & NL);

      --  Category medians
      Append (R, I & """category_medians"": {" & NL);
      declare
         First : Boolean := True;
      begin
         for Cat in Metric_Category loop
            if not First then
               Append (R, "," & NL);
            end if;
            Append (R, I2 & """"
                    & Category_Abbreviation (Cat) & """: "
                    & Float_Image (Profile.Category_Medians (Cat)));
            First := False;
         end loop;
      end;
      Append (R, NL & I & "}," & NL);

      --  Worst patterns
      Append (R, I & """worst_patterns"": [" & NL);
      declare
         use Finding_Vectors;
         First : Boolean := True;
      begin
         for F of Profile.Worst_Patterns loop
            if not First then
               Append (R, "," & NL);
            end if;
            Append (R, Finding_To_JSON (F));
            First := False;
         end loop;
      end;
      Append (R, NL & I & "]," & NL);

      Append (R, I & """evaluated_at"": """
              & Timestamp_String (Profile.Evaluated_At) & """" & NL);
      Append (R, "}");
      return To_String (R);
   end Profile_To_JSON;

   ---------------------------------------------------------------------------
   --  HTML Format Implementation
   ---------------------------------------------------------------------------

   function Dark_Theme_CSS return String is
      --  Embedded CSS for dark-themed HTML reports, using the colour
      --  constants from the GUI spec. Provides styling for all
      --  report elements including tables, gauges, and charts.
   begin
      return
         "<style>" & NL &
         "  :root {" & NL &
         "    --bg: #262629; --surface: #333336;" & NL &
         "    --text: #e6e6e6; --dim: #999aa6;" & NL &
         "    --accent: #6699e6; --excellent: #4dbf73;" & NL &
         "    --good: #8cc759; --acceptable: #f2bf40;" & NL &
         "    --poor: #f28040; --unusable: #e64d4d;" & NL &
         "  }" & NL &
         "  body {" & NL &
         "    background: var(--bg); color: var(--text);" & NL &
         "    font-family: 'Inter', 'Segoe UI', sans-serif;" & NL &
         "    margin: 2rem; line-height: 1.6;" & NL &
         "  }" & NL &
         "  h1, h2, h3 { color: var(--accent); }" & NL &
         "  table {" & NL &
         "    border-collapse: collapse; width: 100%;" & NL &
         "    margin: 1rem 0;" & NL &
         "  }" & NL &
         "  th, td {" & NL &
         "    padding: 0.5rem 1rem; text-align: left;" & NL &
         "    border-bottom: 1px solid var(--surface);" & NL &
         "  }" & NL &
         "  th { color: var(--accent); font-weight: 600; }" & NL &
         "  .metric-card {" & NL &
         "    background: var(--surface); border-radius: 8px;" & NL &
         "    padding: 1rem; margin: 0.5rem; display: inline-block;" & NL &
         "  }" & NL &
         "  .isa-score {" & NL &
         "    font-size: 3rem; font-weight: 700;" & NL &
         "    text-align: center; margin: 1rem 0;" & NL &
         "  }" & NL &
         "  .severity-none { color: var(--dim); }" & NL &
         "  .severity-low { color: var(--good); }" & NL &
         "  .severity-medium { color: var(--acceptable); }" & NL &
         "  .severity-high { color: var(--poor); }" & NL &
         "  .severity-critical { color: var(--unusable); }" & NL &
         "  .chart-container {" & NL &
         "    display: flex; justify-content: center;" & NL &
         "    gap: 2rem; flex-wrap: wrap; margin: 2rem 0;" & NL &
         "  }" & NL &
         "  .findings-list { list-style: none; padding: 0; }" & NL &
         "  .findings-list li {" & NL &
         "    background: var(--surface); border-radius: 4px;" & NL &
         "    padding: 0.75rem; margin: 0.5rem 0;" & NL &
         "    border-left: 3px solid var(--accent);" & NL &
         "  }" & NL &
         "  footer {" & NL &
         "    margin-top: 3rem; padding-top: 1rem;" & NL &
         "    border-top: 1px solid var(--surface);" & NL &
         "    color: var(--dim); font-size: 0.85rem;" & NL &
         "  }" & NL &
         "</style>";
   end Dark_Theme_CSS;

   function Radar_Chart_SVG (Scores : Category_Score_Array) return String is
      --  Generate an SVG radar (spider) chart for all 10 metric categories.
      --  Each axis extends from the centre; scores are plotted as a filled
      --  polygon. Labels are placed at each axis endpoint.
      R      : Unbounded_String;
      CX     : constant Float := 200.0;
      CY     : constant Float := 200.0;
      Radius : constant Float := 150.0;
      N      : constant := Metric_Category'Pos (Metric_Category'Last) + 1;
      Pi     : constant Float := Ada.Numerics.Pi;
      Angle_Step : constant Float := 2.0 * Pi / Float (N);

      --  Compute point on axis at given fraction of radius
      function Axis_X (Index : Natural; Frac : Float) return Float is
      begin
         return CX + Frac * Radius
                * Sin (Float (Index) * Angle_Step - Pi / 2.0);
      end Axis_X;

      function Axis_Y (Index : Natural; Frac : Float) return Float is
      begin
         return CY - Frac * Radius
                * Cos (Float (Index) * Angle_Step - Pi / 2.0);
      end Axis_Y;

   begin
      Append (R, "<svg viewBox=""0 0 400 420"" "
              & "xmlns=""http://www.w3.org/2000/svg"">" & NL);
      Append (R, "  <rect width=""400"" height=""420"" "
              & "fill=""#262629"" rx=""8""/>" & NL);

      --  Draw concentric guide rings at 25%, 50%, 75%, 100%
      for Ring in 1 .. 4 loop
         declare
            Frac : constant Float := Float (Ring) * 0.25;
            Pts  : Unbounded_String;
         begin
            for I in 0 .. N - 1 loop
               if I > 0 then
                  Append (Pts, " ");
               end if;
               Append (Pts, Float_Image (Axis_X (I, Frac), 1)
                       & "," & Float_Image (Axis_Y (I, Frac), 1));
            end loop;
            Append (R, "  <polygon points="""
                    & To_String (Pts) & """ fill=""none"" "
                    & "stroke=""#444"" stroke-width=""0.5""/>" & NL);
         end;
      end loop;

      --  Draw axis lines from centre to each vertex
      for I in 0 .. N - 1 loop
         Append (R, "  <line x1=""" & Float_Image (CX, 1)
                 & """ y1=""" & Float_Image (CY, 1)
                 & """ x2=""" & Float_Image (Axis_X (I, 1.0), 1)
                 & """ y2=""" & Float_Image (Axis_Y (I, 1.0), 1)
                 & """ stroke=""#555"" stroke-width=""0.5""/>" & NL);
      end loop;

      --  Draw data polygon
      --  Scores are in range 0..10 (Category_Score_Array is Float).
      --  Normalise to 0..1 by dividing by 10.
      declare
         Pts : Unbounded_String;
      begin
         for Cat in Metric_Category loop
            declare
               I    : constant Natural := Metric_Category'Pos (Cat);
               Frac : constant Float :=
                  Float'Min (1.0, Scores (Cat) / 10.0);
            begin
               if I > 0 then
                  Append (Pts, " ");
               end if;
               Append (Pts, Float_Image (Axis_X (I, Frac), 1)
                       & "," & Float_Image (Axis_Y (I, Frac), 1));
            end;
         end loop;
         Append (R, "  <polygon points="""
                 & To_String (Pts) & """ "
                 & "fill=""rgba(102,153,230,0.3)"" "
                 & "stroke=""#6699e6"" stroke-width=""2""/>" & NL);
      end;

      --  Draw score dots and axis labels
      for Cat in Metric_Category loop
         declare
            I    : constant Natural := Metric_Category'Pos (Cat);
            Frac : constant Float :=
               Float'Min (1.0, Scores (Cat) / 10.0);
            DX   : constant Float := Axis_X (I, Frac);
            DY   : constant Float := Axis_Y (I, Frac);
            LX   : constant Float := Axis_X (I, 1.15);
            LY   : constant Float := Axis_Y (I, 1.15);
         begin
            --  Score dot
            Append (R, "  <circle cx=""" & Float_Image (DX, 1)
                    & """ cy=""" & Float_Image (DY, 1)
                    & """ r=""3"" fill=""#6699e6""/>" & NL);
            --  Axis label
            Append (R, "  <text x=""" & Float_Image (LX, 1)
                    & """ y=""" & Float_Image (LY, 1)
                    & """ text-anchor=""middle"" "
                    & "fill=""#e6e6e6"" font-size=""10"">"
                    & Category_Abbreviation (Cat)
                    & "</text>" & NL);
         end;
      end loop;

      Append (R, "</svg>");
      return To_String (R);
   end Radar_Chart_SVG;

   function ISA_Gauge_SVG (Score : Float) return String is
      --  Generate an SVG semicircle gauge for ISA score (0-100).
      --  The arc sweeps 180 degrees. Colour transitions from green
      --  through yellow/orange to red based on score severity.
      R    : Unbounded_String;
      Pi   : constant Float := Ada.Numerics.Pi;
      --  Score clamped 0..100
      S    : constant Float := Float'Max (0.0, Float'Min (100.0, Score));
      --  Angle: 0 = left (green), 180 = right (red)
      Frac : constant Float := S / 100.0;
      --  Colour based on ISA score
      Col  : constant String :=
         (if S < 20.0 then "#4dbf73"
          elsif S < 35.0 then "#8cc759"
          elsif S < 50.0 then "#f2bf40"
          elsif S < 70.0 then "#f28040"
          else "#e64d4d");

      --  Gauge geometry
      CX     : constant Float := 150.0;
      CY     : constant Float := 140.0;
      Outer  : constant Float := 120.0;
      Inner  : constant Float := 90.0;

      --  Needle endpoint
      Needle_Angle : constant Float := Pi - (Frac * Pi);
      NX : constant Float := CX + Outer * Cos (Needle_Angle);
      NY : constant Float := CY - Outer * Sin (Needle_Angle);
   begin
      Append (R, "<svg viewBox=""0 0 300 180"" "
              & "xmlns=""http://www.w3.org/2000/svg"">" & NL);
      Append (R, "  <rect width=""300"" height=""180"" "
              & "fill=""#262629"" rx=""8""/>" & NL);

      --  Background arc segments (green to red gradient)
      declare
         type Segment_Rec is record
            Start_Frac, End_Frac : Float;
            Colour : String (1 .. 7);
         end record;
         Segments : constant array (1 .. 5) of Segment_Rec := (
            (0.0,  0.2,  "#4dbf73"),
            (0.2,  0.35, "#8cc759"),
            (0.35, 0.5,  "#f2bf40"),
            (0.5,  0.7,  "#f28040"),
            (0.7,  1.0,  "#e64d4d")
         );
      begin
         for Seg of Segments loop
            declare
               A1 : constant Float := Pi - (Seg.Start_Frac * Pi);
               A2 : constant Float := Pi - (Seg.End_Frac * Pi);
               X1 : constant Float := CX + Outer * Cos (A1);
               Y1 : constant Float := CY - Outer * Sin (A1);
               X2 : constant Float := CX + Outer * Cos (A2);
               Y2 : constant Float := CY - Outer * Sin (A2);
               IX1 : constant Float := CX + Inner * Cos (A1);
               IY1 : constant Float := CY - Inner * Sin (A1);
               IX2 : constant Float := CX + Inner * Cos (A2);
               IY2 : constant Float := CY - Inner * Sin (A2);
            begin
               Append (R, "  <path d=""M "
                       & Float_Image (X1, 1)
                       & " " & Float_Image (Y1, 1)
                       & " A " & Float_Image (Outer, 0)
                       & " " & Float_Image (Outer, 0)
                       & " 0 0 1 "
                       & Float_Image (X2, 1)
                       & " " & Float_Image (Y2, 1)
                       & " L " & Float_Image (IX2, 1)
                       & " " & Float_Image (IY2, 1)
                       & " A " & Float_Image (Inner, 0)
                       & " " & Float_Image (Inner, 0)
                       & " 0 0 0 "
                       & Float_Image (IX1, 1)
                       & " " & Float_Image (IY1, 1)
                       & " Z"" fill=""" & Seg.Colour
                       & """ opacity=""0.3""/>" & NL);
            end;
         end loop;
      end;

      --  Needle line
      Append (R, "  <line x1=""" & Float_Image (CX, 1)
              & """ y1=""" & Float_Image (CY, 1)
              & """ x2=""" & Float_Image (NX, 1)
              & """ y2=""" & Float_Image (NY, 1)
              & """ stroke=""" & Col
              & """ stroke-width=""3"" stroke-linecap=""round""/>" & NL);
      --  Centre dot
      Append (R, "  <circle cx=""" & Float_Image (CX, 1)
              & """ cy=""" & Float_Image (CY, 1)
              & """ r=""5"" fill=""" & Col & """/>" & NL);
      --  Score text
      Append (R, "  <text x=""" & Float_Image (CX, 1)
              & """ y=""" & Float_Image (CY + 25.0, 1)
              & """ text-anchor=""middle"" fill=""" & Col
              & """ font-size=""24"" font-weight=""bold"">"
              & Float_Image (S, 1) & "</text>" & NL);
      --  Label
      Append (R, "  <text x=""" & Float_Image (CX, 1)
              & """ y=""" & Float_Image (CY + 42.0, 1)
              & """ text-anchor=""middle"" fill=""#999aa6"" "
              & "font-size=""11"">ISA Score</text>" & NL);
      Append (R, "</svg>");
      return To_String (R);
   end ISA_Gauge_SVG;

   function Profile_To_HTML
      (Profile  : Model_Profile;
       Metadata : Report_Metadata) return String
   is
      --  Generate a complete HTML document for a single model profile,
      --  including embedded dark-theme CSS, radar chart SVG, ISA gauge
      --  SVG, category scores table, and findings list.
      R : Unbounded_String;
   begin
      --  Document header
      Append (R, "<!DOCTYPE html>" & NL);
      Append (R, "<html lang=""en"">" & NL);
      Append (R, "<head>" & NL);
      Append (R, "  <meta charset=""utf-8"">" & NL);
      Append (R, "  <meta name=""viewport"" "
              & "content=""width=device-width, initial-scale=1"">" & NL);
      Append (R, "  <title>"
              & Escape_HTML (To_String (Metadata.Title)) & "</title>" & NL);

      if Current_Options.Embed_Styles then
         Append (R, Dark_Theme_CSS & NL);
      end if;

      Append (R, "</head>" & NL);
      Append (R, "<body>" & NL);

      --  Report header
      Append (R, "<h1>"
              & Escape_HTML (To_String (Metadata.Title)) & "</h1>" & NL);
      Append (R, "<p>Model: <strong>"
              & Escape_HTML (To_String (Profile.Model_ID))
              & "</strong> (v"
              & Escape_HTML (To_String (Profile.Model_Version))
              & ") &mdash; Provider: "
              & Escape_HTML (To_String (Profile.Provider))
              & "</p>" & NL);
      Append (R, "<p>Generated: "
              & Timestamp_String (Metadata.Generated_At)
              & " | Analyses: " & Profile.Analysis_Count'Image
              & " | Vexometer "
              & To_String (Metadata.Vexometer_Version) & "</p>" & NL);

      --  Charts
      if Current_Options.Include_Charts then
         Append (R, "<div class=""chart-container"">" & NL);
         Append (R, "<div>" & NL);
         Append (R, Radar_Chart_SVG (Profile.Category_Means) & NL);
         Append (R, "</div>" & NL);
         Append (R, "<div>" & NL);
         Append (R, ISA_Gauge_SVG (Profile.Mean_ISA) & NL);
         Append (R, "</div>" & NL);
         Append (R, "</div>" & NL);
      end if;

      --  ISA headline score
      declare
         Col : constant String :=
            (if Profile.Mean_ISA < 20.0 then "excellent"
             elsif Profile.Mean_ISA < 35.0 then "good"
             elsif Profile.Mean_ISA < 50.0 then "acceptable"
             elsif Profile.Mean_ISA < 70.0 then "poor"
             else "unusable");
      begin
         Append (R, "<div class=""isa-score"" style=""color: var(--"
                 & Col & ")"">"
                 & Float_Image (Profile.Mean_ISA, 1) & "</div>" & NL);
      end;

      --  Category scores table
      Append (R, "<h2>Category Scores</h2>" & NL);
      Append (R, "<table>" & NL);
      Append (R, "  <tr><th>Category</th><th>Abbrev</th>"
              & "<th>Mean</th><th>Median</th>"
              & "<th>Std Dev</th></tr>" & NL);
      for Cat in Metric_Category loop
         Append (R, "  <tr>");
         Append (R, "<td>" & Category_Full_Name (Cat) & "</td>");
         Append (R, "<td>" & Category_Abbreviation (Cat) & "</td>");
         Append (R, "<td>" & Float_Image (Profile.Category_Means (Cat))
                 & "</td>");
         Append (R, "<td>" & Float_Image (Profile.Category_Medians (Cat))
                 & "</td>");
         Append (R, "<td>" & Float_Image (Profile.Category_Std_Devs (Cat))
                 & "</td>");
         Append (R, "</tr>" & NL);
      end loop;
      Append (R, "</table>" & NL);

      --  Findings
      if Current_Options.Include_Raw_Findings then
         Append (R, "<h2>Worst Patterns</h2>" & NL);
         Append (R, "<ul class=""findings-list"">" & NL);
         declare
            use Finding_Vectors;
         begin
            for F of Profile.Worst_Patterns loop
               Append (R, "  <li class=""severity-"
                       & Severity_Image (F.Severity) & """>");
               Append (R, "<strong>["
                       & Category_Abbreviation (F.Category) & " / "
                       & Severity_Image (F.Severity) & "]</strong> ");
               Append (R, Escape_HTML (To_String (F.Explanation)));
               Append (R, " <em>("
                       & Escape_HTML (To_String (F.Matched))
                       & ")</em>");
               Append (R, "</li>" & NL);
            end loop;
         end;
         Append (R, "</ul>" & NL);
      end if;

      --  Methodology
      if Current_Options.Include_Methodology then
         Append (R, "<h2>Methodology</h2>" & NL);
         Append (R, "<p>The Irritation Surface Area (ISA) score is "
                 & "computed as a weighted sum of ten metric categories, "
                 & "each normalised to 0-10. Lower scores indicate "
                 & "better user experience. Pattern detection uses "
                 & "regular expressions and heuristic analysis on "
                 & "model responses to standardised behavioural "
                 & "probes.</p>" & NL);
      end if;

      --  Footer
      Append (R, "<footer>" & NL);
      Append (R, "  <p>Generated by Vexometer "
              & To_String (Metadata.Vexometer_Version));
      if Length (Metadata.License) > 0 then
         Append (R, " | Report licence: "
                 & To_String (Metadata.License));
      end if;
      Append (R, "</p>" & NL);
      Append (R, "</footer>" & NL);
      Append (R, "</body>" & NL);
      Append (R, "</html>");
      return To_String (R);
   end Profile_To_HTML;

   ---------------------------------------------------------------------------
   --  Markdown Format Implementation
   ---------------------------------------------------------------------------

   function Profile_To_Markdown
      (Profile  : Model_Profile;
       Metadata : Report_Metadata) return String
   is
      --  Generate a full Markdown report for a single model profile.
      --  Includes metadata header, category scores table, and findings.
      R : Unbounded_String;
   begin
      Append (R, "# " & To_String (Metadata.Title) & NL & NL);
      Append (R, "**Model:** " & To_String (Profile.Model_ID)
              & " (v" & To_String (Profile.Model_Version) & ")  " & NL);
      Append (R, "**Provider:** " & To_String (Profile.Provider)
              & "  " & NL);
      Append (R, "**Analyses:** " & Profile.Analysis_Count'Image
              & "  " & NL);
      Append (R, "**Generated:** "
              & Timestamp_String (Metadata.Generated_At) & "  " & NL);
      Append (R, "**Vexometer:** "
              & To_String (Metadata.Vexometer_Version) & NL & NL);

      --  ISA Score
      Append (R, "## Overall ISA Score: "
              & Float_Image (Profile.Mean_ISA, 1)
              & " (sd=" & Float_Image (Profile.Std_Dev_ISA, 1)
              & ", median=" & Float_Image (Profile.Median_ISA, 1)
              & ")" & NL & NL);

      --  Category scores table
      Append (R, "## Category Scores" & NL & NL);
      Append (R, "| Category | Abbrev | Mean | Median | Std Dev |"
              & NL);
      Append (R, "|----------|--------|------|--------|---------|"
              & NL);
      for Cat in Metric_Category loop
         Append (R, "| " & Category_Full_Name (Cat)
                 & " | " & Category_Abbreviation (Cat)
                 & " | " & Float_Image (Profile.Category_Means (Cat))
                 & " | " & Float_Image (Profile.Category_Medians (Cat))
                 & " | " & Float_Image (Profile.Category_Std_Devs (Cat))
                 & " |" & NL);
      end loop;
      Append (R, NL);

      --  Findings
      if Current_Options.Include_Raw_Findings then
         Append (R, "## Worst Patterns" & NL & NL);
         declare
            use Finding_Vectors;
         begin
            for F of Profile.Worst_Patterns loop
               Append (R, "- **["
                       & Category_Abbreviation (F.Category) & " / "
                       & Severity_Image (F.Severity) & "]** "
                       & To_String (F.Explanation)
                       & " _(" & To_String (F.Matched) & ")_" & NL);
            end loop;
         end;
         Append (R, NL);
      end if;

      --  Methodology
      if Current_Options.Include_Methodology then
         Append (R, "## Methodology" & NL & NL);
         Append (R, "The Irritation Surface Area (ISA) score is "
                 & "computed as a weighted sum of ten metric "
                 & "categories, each normalised to 0-10. "
                 & "Lower scores indicate better user experience."
                 & NL & NL);
      end if;

      Append (R, "---" & NL);
      Append (R, "*Generated by Vexometer "
              & To_String (Metadata.Vexometer_Version) & "*" & NL);
      return To_String (R);
   end Profile_To_Markdown;

   function Comparison_Table_Markdown
      (Profiles : Profile_Vector) return String
   is
      --  Generate a Markdown comparison table with one row per model
      --  and columns for ISA plus all 10 category abbreviations.
      use Profile_Vectors;
      R : Unbounded_String;
   begin
      --  Header
      Append (R, "| Model | ISA");
      for Cat in Metric_Category loop
         Append (R, " | " & Category_Abbreviation (Cat));
      end loop;
      Append (R, " |" & NL);

      --  Separator
      Append (R, "|-------|-----");
      for Cat in Metric_Category loop
         pragma Unreferenced (Cat);
         Append (R, "|------");
      end loop;
      Append (R, "|" & NL);

      --  Data rows
      for P of Profiles loop
         Append (R, "| " & To_String (P.Model_ID)
                 & " | " & Float_Image (P.Mean_ISA, 1));
         for Cat in Metric_Category loop
            Append (R, " | "
                    & Float_Image (P.Category_Means (Cat)));
         end loop;
         Append (R, " |" & NL);
      end loop;

      return To_String (R);
   end Comparison_Table_Markdown;

   ---------------------------------------------------------------------------
   --  CSV Format Implementation
   ---------------------------------------------------------------------------

   function CSV_Header return String is
      --  Return the CSV header row with column names for model profile
      --  export.  Columns: Model, Version, Provider, ISA, then each
      --  category abbreviation.
      R : Unbounded_String;
   begin
      Append (R, "Model,Version,Provider,ISA,StdDev,Median,Analyses");
      for Cat in Metric_Category loop
         Append (R, "," & Category_Abbreviation (Cat));
      end loop;
      return To_String (R);
   end CSV_Header;

   function Profile_To_CSV_Row (Profile : Model_Profile) return String is
      --  Return a single CSV data row for a Model_Profile.
      R : Unbounded_String;
   begin
      Append (R, Escape_CSV (To_String (Profile.Model_ID)));
      Append (R, "," & Escape_CSV (To_String (Profile.Model_Version)));
      Append (R, "," & Escape_CSV (To_String (Profile.Provider)));
      Append (R, "," & Float_Image (Profile.Mean_ISA));
      Append (R, "," & Float_Image (Profile.Std_Dev_ISA));
      Append (R, "," & Float_Image (Profile.Median_ISA));
      Append (R, "," & Profile.Analysis_Count'Image);
      for Cat in Metric_Category loop
         Append (R, "," & Float_Image (Profile.Category_Means (Cat)));
      end loop;
      return To_String (R);
   end Profile_To_CSV_Row;

   ---------------------------------------------------------------------------
   --  LaTeX Format Implementation
   ---------------------------------------------------------------------------

   function Profile_To_LaTeX
      (Profile  : Model_Profile;
       Metadata : Report_Metadata) return String
   is
      --  Generate a LaTeX fragment for a single model profile.
      --  Wraps in a table environment with category scores.
      R : Unbounded_String;
   begin
      Append (R, "% Generated by Vexometer "
              & To_String (Metadata.Vexometer_Version) & NL);
      Append (R, "\documentclass{article}" & NL);
      Append (R, "\usepackage{booktabs}" & NL);
      Append (R, "\usepackage{siunitx}" & NL);
      Append (R, "\begin{document}" & NL & NL);

      Append (R, "\section{" & Escape_LaTeX (To_String (Metadata.Title))
              & "}" & NL & NL);
      Append (R, "\textbf{Model:} "
              & Escape_LaTeX (To_String (Profile.Model_ID))
              & " (v" & Escape_LaTeX (To_String (Profile.Model_Version))
              & ") \\" & NL);
      Append (R, "\textbf{Provider:} "
              & Escape_LaTeX (To_String (Profile.Provider))
              & " \\" & NL);
      Append (R, "\textbf{Overall ISA Score:} "
              & Float_Image (Profile.Mean_ISA, 1)
              & " ($\sigma$ = " & Float_Image (Profile.Std_Dev_ISA, 1)
              & ") \\" & NL & NL);

      --  Table
      Append (R, "\begin{table}[htbp]" & NL);
      Append (R, "\centering" & NL);
      Append (R, "\caption{Category scores for "
              & Escape_LaTeX (To_String (Profile.Model_ID))
              & "}" & NL);
      Append (R, "\begin{tabular}{lrrrr}" & NL);
      Append (R, "\toprule" & NL);
      Append (R, "Category & Abbrev & Mean & Median & Std Dev \\" & NL);
      Append (R, "\midrule" & NL);
      for Cat in Metric_Category loop
         Append (R, Escape_LaTeX (Category_Full_Name (Cat))
                 & " & " & Category_Abbreviation (Cat)
                 & " & " & Float_Image (Profile.Category_Means (Cat))
                 & " & " & Float_Image (Profile.Category_Medians (Cat))
                 & " & " & Float_Image (Profile.Category_Std_Devs (Cat))
                 & " \\" & NL);
      end loop;
      Append (R, "\bottomrule" & NL);
      Append (R, "\end{tabular}" & NL);
      Append (R, "\end{table}" & NL & NL);

      Append (R, "\end{document}" & NL);
      return To_String (R);
   end Profile_To_LaTeX;

   function Comparison_Table_LaTeX
      (Profiles : Profile_Vector) return String
   is
      --  Generate a LaTeX tabular fragment comparing multiple models.
      --  Columns: Model, ISA, then each category abbreviation.
      use Profile_Vectors;
      R : Unbounded_String;
      --  Build column spec: l + 1 ISA col + 10 category cols = 12 total
      Col_Spec : Unbounded_String;
   begin
      Append (Col_Spec, "l");
      Append (Col_Spec, "r");  --  ISA
      for Cat in Metric_Category loop
         pragma Unreferenced (Cat);
         Append (Col_Spec, "r");
      end loop;

      Append (R, "\begin{table}[htbp]" & NL);
      Append (R, "\centering" & NL);
      Append (R, "\caption{Model Comparison}" & NL);
      Append (R, "\begin{tabular}{" & To_String (Col_Spec) & "}" & NL);
      Append (R, "\toprule" & NL);

      --  Header row
      Append (R, "Model & ISA");
      for Cat in Metric_Category loop
         Append (R, " & " & Category_Abbreviation (Cat));
      end loop;
      Append (R, " \\" & NL);
      Append (R, "\midrule" & NL);

      --  Data rows
      for P of Profiles loop
         Append (R, Escape_LaTeX (To_String (P.Model_ID))
                 & " & " & Float_Image (P.Mean_ISA, 1));
         for Cat in Metric_Category loop
            Append (R, " & " & Float_Image (P.Category_Means (Cat)));
         end loop;
         Append (R, " \\" & NL);
      end loop;

      Append (R, "\bottomrule" & NL);
      Append (R, "\end{tabular}" & NL);
      Append (R, "\end{table}" & NL);
      return To_String (R);
   end Comparison_Table_LaTeX;

   ---------------------------------------------------------------------------
   --  YAML Format (minimal)
   ---------------------------------------------------------------------------

   function Profile_To_YAML (Profile : Model_Profile) return String is
      --  Minimal YAML serialisation for machine-readable export.
      R : Unbounded_String;
   begin
      Append (R, "---" & NL);
      Append (R, "model_id: """ & To_String (Profile.Model_ID)
              & """" & NL);
      Append (R, "model_version: """
              & To_String (Profile.Model_Version) & """" & NL);
      Append (R, "provider: """
              & To_String (Profile.Provider) & """" & NL);
      Append (R, "analysis_count: "
              & Profile.Analysis_Count'Image & NL);
      Append (R, "mean_isa: " & Float_Image (Profile.Mean_ISA) & NL);
      Append (R, "std_dev_isa: "
              & Float_Image (Profile.Std_Dev_ISA) & NL);
      Append (R, "median_isa: "
              & Float_Image (Profile.Median_ISA) & NL);
      Append (R, "category_means:" & NL);
      for Cat in Metric_Category loop
         Append (R, "  " & Category_Abbreviation (Cat) & ": "
                 & Float_Image (Profile.Category_Means (Cat)) & NL);
      end loop;
      Append (R, "category_medians:" & NL);
      for Cat in Metric_Category loop
         Append (R, "  " & Category_Abbreviation (Cat) & ": "
                 & Float_Image (Profile.Category_Medians (Cat)) & NL);
      end loop;
      Append (R, "evaluated_at: """
              & Timestamp_String (Profile.Evaluated_At) & """" & NL);
      return To_String (R);
   end Profile_To_YAML;

   ---------------------------------------------------------------------------
   --  Report String Dispatch
   ---------------------------------------------------------------------------

   function Generate_Report_String
      (Profile  : Model_Profile;
       Format   : Report_Format;
       Metadata : Report_Metadata := Default_Metadata) return String
   is
      --  Dispatch to the appropriate format-specific renderer and return
      --  the full report as a string.
   begin
      return (case Format is
         when JSON     => Profile_To_JSON (Profile),
         when HTML     => Profile_To_HTML (Profile, Metadata),
         when Markdown => Profile_To_Markdown (Profile, Metadata),
         when CSV      => CSV_Header & NL & Profile_To_CSV_Row (Profile),
         when LaTeX    => Profile_To_LaTeX (Profile, Metadata),
         when YAML     => Profile_To_YAML (Profile));
   end Generate_Report_String;

   ---------------------------------------------------------------------------
   --  File I/O
   ---------------------------------------------------------------------------

   procedure Write_String_To_File (Path : String; Content : String) is
      --  Write a string to a file, creating or overwriting as needed.
      F : File_Type;
   begin
      Create (F, Out_File, Path);
      Put (F, Content);
      Close (F);
   end Write_String_To_File;

   ---------------------------------------------------------------------------
   --  Generate_Report
   ---------------------------------------------------------------------------

   procedure Generate_Report
      (Profile  : Model_Profile;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata)
   is
      --  Generate a report for a single model profile and write it
      --  to the specified file path.
   begin
      Write_String_To_File
         (Path, Generate_Report_String (Profile, Format, Metadata));
   end Generate_Report;

   ---------------------------------------------------------------------------
   --  Comparison Reports
   ---------------------------------------------------------------------------

   function Generate_Comparison_Report_String
      (Profiles : Profile_Vector;
       Format   : Report_Format;
       Metadata : Report_Metadata := Default_Metadata) return String
   is
      --  Generate a comparison report string for multiple model profiles.
      --  Delegates to format-specific comparison table generators where
      --  available; falls back to concatenating per-profile reports.
      use Profile_Vectors;
      R : Unbounded_String;
   begin
      case Format is
         when JSON =>
            Append (R, "{" & NL);
            Append (R, "  ""title"": """
                    & Escape_JSON (To_String (Metadata.Title))
                    & """," & NL);
            Append (R, "  ""generated_at"": """
                    & Timestamp_String (Metadata.Generated_At)
                    & """," & NL);
            Append (R, "  ""profiles"": [" & NL);
            declare
               First : Boolean := True;
            begin
               for P of Profiles loop
                  if not First then
                     Append (R, "," & NL);
                  end if;
                  Append (R, "    " & Profile_To_JSON (P));
                  First := False;
               end loop;
            end;
            Append (R, NL & "  ]" & NL);
            Append (R, "}");

         when Markdown =>
            Append (R, "# " & To_String (Metadata.Title)
                    & NL & NL);
            Append (R, Comparison_Table_Markdown (Profiles));
            Append (R, NL & "---" & NL);
            Append (R, "*Generated by Vexometer "
                    & To_String (Metadata.Vexometer_Version)
                    & "*" & NL);

         when HTML =>
            --  Wrap comparison table in a full HTML document
            Append (R, "<!DOCTYPE html>" & NL);
            Append (R, "<html lang=""en""><head>" & NL);
            Append (R, "<meta charset=""utf-8"">" & NL);
            Append (R, "<title>"
                    & Escape_HTML (To_String (Metadata.Title))
                    & "</title>" & NL);
            if Current_Options.Embed_Styles then
               Append (R, Dark_Theme_CSS & NL);
            end if;
            Append (R, "</head><body>" & NL);
            Append (R, "<h1>"
                    & Escape_HTML (To_String (Metadata.Title))
                    & "</h1>" & NL);
            Append (R, "<table>" & NL);
            Append (R, "<tr><th>Model</th><th>ISA</th>");
            for Cat in Metric_Category loop
               Append (R, "<th>"
                       & Category_Abbreviation (Cat) & "</th>");
            end loop;
            Append (R, "</tr>" & NL);
            for P of Profiles loop
               Append (R, "<tr>");
               Append (R, "<td>"
                       & Escape_HTML (To_String (P.Model_ID))
                       & "</td>");
               Append (R, "<td>" & Float_Image (P.Mean_ISA, 1)
                       & "</td>");
               for Cat in Metric_Category loop
                  Append (R, "<td>"
                          & Float_Image (P.Category_Means (Cat))
                          & "</td>");
               end loop;
               Append (R, "</tr>" & NL);
            end loop;
            Append (R, "</table>" & NL);
            Append (R, "</body></html>");

         when CSV =>
            Append (R, CSV_Header & NL);
            for P of Profiles loop
               Append (R, Profile_To_CSV_Row (P) & NL);
            end loop;

         when LaTeX =>
            Append (R, Comparison_Table_LaTeX (Profiles));

         when YAML =>
            Append (R, "---" & NL);
            Append (R, "title: """
                    & To_String (Metadata.Title) & """" & NL);
            Append (R, "profiles:" & NL);
            for P of Profiles loop
               Append (R, "  - " & NL
                       & Profile_To_YAML (P));
            end loop;
      end case;

      return To_String (R);
   end Generate_Comparison_Report_String;

   procedure Generate_Comparison_Report
      (Profiles : Profile_Vector;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata)
   is
      --  Generate a multi-model comparison report and write to file.
   begin
      Write_String_To_File
         (Path,
          Generate_Comparison_Report_String (Profiles, Format, Metadata));
   end Generate_Comparison_Report;

   ---------------------------------------------------------------------------
   --  Analysis Report
   ---------------------------------------------------------------------------

   procedure Generate_Analysis_Report
      (Analysis : Response_Analysis;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata)
   is
      --  Generate a detailed analysis report for a single
      --  prompt/response pair and write to file.
      R : Unbounded_String;
   begin
      case Format is
         when JSON =>
            Append (R, Analysis_To_JSON (Analysis));

         when Markdown =>
            Append (R, "# Analysis: "
                    & To_String (Analysis.Model_ID) & NL & NL);
            Append (R, "**ISA Score:** "
                    & Float_Image (Analysis.Overall_ISA, 1) & NL & NL);
            Append (R, "## Category Scores" & NL & NL);
            Append (R, "| Category | Score |" & NL);
            Append (R, "|----------|-------|" & NL);
            for Cat in Metric_Category loop
               Append (R, "| " & Category_Abbreviation (Cat)
                       & " | "
                       & Float_Image (Analysis.Category_Scores (Cat))
                       & " |" & NL);
            end loop;
            Append (R, NL);
            Append (R, "## Findings (" &
                    Natural'Image
                       (Natural (Analysis.Findings.Length))
                    & ")" & NL & NL);
            for F of Analysis.Findings loop
               Append (R, "- **["
                       & Category_Abbreviation (F.Category)
                       & "]** " & To_String (F.Explanation) & NL);
            end loop;

         when HTML =>
            Append (R, "<!DOCTYPE html><html lang=""en"">" & NL);
            Append (R, "<head><meta charset=""utf-8""><title>Analysis"
                    & "</title>" & NL);
            if Current_Options.Embed_Styles then
               Append (R, Dark_Theme_CSS & NL);
            end if;
            Append (R, "</head><body>" & NL);
            Append (R, "<h1>Analysis: "
                    & Escape_HTML (To_String (Analysis.Model_ID))
                    & "</h1>" & NL);
            if Current_Options.Include_Charts then
               Append (R, "<div class=""chart-container"">" & NL);
               Append (R, Radar_Chart_SVG (Analysis.Category_Scores));
               Append (R, ISA_Gauge_SVG (Analysis.Overall_ISA));
               Append (R, "</div>" & NL);
            end if;
            Append (R, "</body></html>");

         when CSV =>
            --  Single row with analysis data
            Append (R, "Model,ISA");
            for Cat in Metric_Category loop
               Append (R, "," & Category_Abbreviation (Cat));
            end loop;
            Append (R, NL);
            Append (R, Escape_CSV (To_String (Analysis.Model_ID)));
            Append (R, "," & Float_Image (Analysis.Overall_ISA));
            for Cat in Metric_Category loop
               Append (R, ","
                       & Float_Image (Analysis.Category_Scores (Cat)));
            end loop;
            Append (R, NL);

         when LaTeX =>
            Append (R, "\begin{table}[htbp]" & NL);
            Append (R, "\centering" & NL);
            Append (R, "\caption{Analysis: "
                    & Escape_LaTeX (To_String (Analysis.Model_ID))
                    & "}" & NL);
            Append (R, "\begin{tabular}{lr}" & NL);
            Append (R, "\toprule" & NL);
            Append (R, "Category & Score \\" & NL);
            Append (R, "\midrule" & NL);
            for Cat in Metric_Category loop
               Append (R, Category_Abbreviation (Cat) & " & "
                       & Float_Image (Analysis.Category_Scores (Cat))
                       & " \\" & NL);
            end loop;
            Append (R, "\midrule" & NL);
            Append (R, "Overall ISA & "
                    & Float_Image (Analysis.Overall_ISA, 1)
                    & " \\" & NL);
            Append (R, "\bottomrule" & NL);
            Append (R, "\end{tabular}" & NL);
            Append (R, "\end{table}" & NL);

         when YAML =>
            Append (R, "---" & NL);
            Append (R, "model_id: """
                    & To_String (Analysis.Model_ID) & """" & NL);
            Append (R, "overall_isa: "
                    & Float_Image (Analysis.Overall_ISA) & NL);
            Append (R, "category_scores:" & NL);
            for Cat in Metric_Category loop
               Append (R, "  " & Category_Abbreviation (Cat) & ": "
                       & Float_Image (Analysis.Category_Scores (Cat))
                       & NL);
            end loop;
      end case;

      Write_String_To_File (Path, To_String (R));
   end Generate_Analysis_Report;

   ---------------------------------------------------------------------------
   --  Probe Report
   ---------------------------------------------------------------------------

   procedure Generate_Probe_Report
      (Results  : Result_Vector;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata)
   is
      --  Generate a report on behavioural probe results and write
      --  to the specified file.
      use Vexometer.Probes.Result_Vectors;
      R : Unbounded_String;
   begin
      case Format is
         when JSON =>
            Append (R, "{" & NL);
            Append (R, "  ""title"": """
                    & Escape_JSON (To_String (Metadata.Title))
                    & """," & NL);
            Append (R, "  ""probe_results"": [" & NL);
            declare
               First : Boolean := True;
            begin
               for PR of Results loop
                  if not First then
                     Append (R, "," & NL);
                  end if;
                  Append (R, "    {" & NL);
                  Append (R, "      ""probe_id"": """
                          & Escape_JSON (To_String (PR.Probe.ID))
                          & """," & NL);
                  Append (R, "      ""passed"": "
                          & (if PR.Passed then "true" else "false")
                          & "," & NL);
                  Append (R, "      ""score"": "
                          & Float_Image (PR.Score) & "," & NL);
                  Append (R, "      ""response_time"": "
                          & Float_Image (Float (PR.Response_Time))
                          & "," & NL);
                  Append (R, "      ""explanation"": """
                          & Escape_JSON (To_String (PR.Explanation))
                          & """" & NL);
                  Append (R, "    }");
                  First := False;
               end loop;
            end;
            Append (R, NL & "  ]" & NL);
            Append (R, "}");

         when Markdown =>
            Append (R, "# Probe Results" & NL & NL);
            Append (R, "| Probe | Passed | Score | Time |" & NL);
            Append (R, "|-------|--------|-------|------|" & NL);
            for PR of Results loop
               Append (R, "| " & To_String (PR.Probe.Name)
                       & " | " & (if PR.Passed then "PASS" else "FAIL")
                       & " | " & Float_Image (PR.Score)
                       & " | " & Float_Image (Float (PR.Response_Time))
                       & "s |" & NL);
            end loop;

         when others =>
            --  Fall back to JSON for unsupported formats
            Append (R, "{ ""note"": ""Format not yet supported for "
                    & "probe reports; use JSON or Markdown."" }");
      end case;

      Write_String_To_File (Path, To_String (R));
   end Generate_Probe_Report;

   ---------------------------------------------------------------------------
   --  Arena Submission
   ---------------------------------------------------------------------------

   function Generate_Arena_Submission_String
      (Submission : Arena_Submission) return String
   is
      --  Generate a JSON submission document formatted for integration
      --  with the LMSYS Chatbot Arena.  Includes methodology reference,
      --  profile data, and links to raw data.
      use Profile_Vectors;
      R : Unbounded_String;
   begin
      Append (R, "{" & NL);
      Append (R, "  ""submission_type"": ""vexometer_isa_integration"","
              & NL);
      Append (R, "  ""version"": """
              & To_String (Submission.Metadata.Vexometer_Version)
              & """," & NL);
      Append (R, "  ""title"": """
              & Escape_JSON (To_String (Submission.Metadata.Title))
              & """," & NL);
      Append (R, "  ""author"": """
              & Escape_JSON (To_String (Submission.Metadata.Author))
              & """," & NL);
      Append (R, "  ""organisation"": """
              & Escape_JSON
                   (To_String (Submission.Metadata.Organisation))
              & """," & NL);
      Append (R, "  ""generated_at"": """
              & Timestamp_String (Submission.Metadata.Generated_At)
              & """," & NL);
      Append (R, "  ""methodology"": """
              & Escape_JSON (To_String (Submission.Methodology))
              & """," & NL);
      Append (R, "  ""probe_suite"": """
              & Escape_JSON (To_String (Submission.Probe_Suite))
              & """," & NL);
      Append (R, "  ""raw_data_url"": """
              & Escape_JSON (To_String (Submission.Raw_Data_URL))
              & """," & NL);

      --  Metrics schema
      Append (R, "  ""metrics_schema"": {" & NL);
      Append (R, "    ""score_range"": ""0-100""," & NL);
      Append (R, "    ""interpretation"": ""lower is better""," & NL);
      Append (R, "    ""categories"": [" & NL);
      declare
         First : Boolean := True;
      begin
         for Cat in Metric_Category loop
            if not First then
               Append (R, "," & NL);
            end if;
            Append (R, "      {""abbreviation"": """
                    & Category_Abbreviation (Cat)
                    & """, ""name"": """
                    & Category_Full_Name (Cat) & """}");
            First := False;
         end loop;
      end;
      Append (R, NL & "    ]" & NL);
      Append (R, "  }," & NL);

      --  Profiles
      Append (R, "  ""profiles"": [" & NL);
      declare
         First : Boolean := True;
      begin
         for P of Submission.Profiles loop
            if not First then
               Append (R, "," & NL);
            end if;
            Append (R, "    " & Profile_To_JSON (P));
            First := False;
         end loop;
      end;
      Append (R, NL & "  ]" & NL);
      Append (R, "}");
      return To_String (R);
   end Generate_Arena_Submission_String;

   procedure Generate_Arena_Submission
      (Submission : Arena_Submission;
       Path       : String)
   is
      --  Write the Arena submission JSON document to a file.
   begin
      Write_String_To_File
         (Path, Generate_Arena_Submission_String (Submission));
   end Generate_Arena_Submission;

   ---------------------------------------------------------------------------
   --  Export Options
   ---------------------------------------------------------------------------

   procedure Set_Export_Options (Options : Export_Options) is
      --  Set the package-level export configuration.
   begin
      Current_Options := Options;
   end Set_Export_Options;

   function Get_Export_Options return Export_Options is
      --  Retrieve the current export configuration.
   begin
      return Current_Options;
   end Get_Export_Options;

end Vexometer.Reports;
