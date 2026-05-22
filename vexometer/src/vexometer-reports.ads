--  Vexometer.Reports - Report generation
--
--  Generates analysis reports in various formats for publication,
--  integration, and academic use.
--
--  Copyright (C) 2024 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Vexometer.Core;   use Vexometer.Core;
with Vexometer.Probes; use Vexometer.Probes;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Calendar;

package Vexometer.Reports is

   ---------------------------------------------------------------------------
   --  Report Formats
   ---------------------------------------------------------------------------

   type Report_Format is (
      JSON,      --  Machine-readable, for integration
      HTML,      --  Visual report with embedded charts
      Markdown,  --  For publication/sharing on GitHub, blogs
      CSV,       --  For statistical analysis in R, Python
      LaTeX,     --  For academic papers
      YAML       --  Alternative machine-readable
   );

   type Format_Set is array (Report_Format) of Boolean with Pack;

   All_Formats : constant Format_Set := [others => True];

   ---------------------------------------------------------------------------
   --  Report Metadata
   ---------------------------------------------------------------------------

   type Report_Metadata is record
      Title        : Unbounded_String;
      Author       : Unbounded_String;
      Organisation : Unbounded_String;
      Generated_At : Ada.Calendar.Time;
      Vexometer_Version : Unbounded_String;
      Description  : Unbounded_String;
      License      : Unbounded_String;
   end record;

   Default_Metadata : constant Report_Metadata := (
      Title        => To_Unbounded_String ("Irritation Surface Analysis Report"),
      Author       => Null_Unbounded_String,
      Organisation => Null_Unbounded_String,
      Generated_At => Ada.Calendar.Clock,
      Vexometer_Version => To_Unbounded_String ("0.1.0"),
      Description  => Null_Unbounded_String,
      License      => To_Unbounded_String ("CC-BY-4.0")
   );

   ---------------------------------------------------------------------------
   --  Single Model Report
   ---------------------------------------------------------------------------

   procedure Generate_Report
      (Profile  : Model_Profile;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata);

   function Generate_Report_String
      (Profile  : Model_Profile;
       Format   : Report_Format;
       Metadata : Report_Metadata := Default_Metadata) return String;

   ---------------------------------------------------------------------------
   --  Comparison Report
   ---------------------------------------------------------------------------

   procedure Generate_Comparison_Report
      (Profiles : Profile_Vector;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata);

   function Generate_Comparison_Report_String
      (Profiles : Profile_Vector;
       Format   : Report_Format;
       Metadata : Report_Metadata := Default_Metadata) return String;

   ---------------------------------------------------------------------------
   --  Detailed Analysis Report
   ---------------------------------------------------------------------------

   procedure Generate_Analysis_Report
      (Analysis : Response_Analysis;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata);
   --  Full report for a single prompt/response pair

   ---------------------------------------------------------------------------
   --  Probe Suite Report
   ---------------------------------------------------------------------------

   procedure Generate_Probe_Report
      (Results  : Result_Vector;
       Format   : Report_Format;
       Path     : String;
       Metadata : Report_Metadata := Default_Metadata);
   --  Report on behavioural probe results

   ---------------------------------------------------------------------------
   --  LMArena Submission Format
   --
   --  Special format for proposing ISA integration with LMSYS Chatbot Arena
   ---------------------------------------------------------------------------

   type Arena_Submission is record
      Metadata     : Report_Metadata;
      Profiles     : Profile_Vector;
      Methodology  : Unbounded_String;
      Probe_Suite  : Unbounded_String;  --  Reference to probe definitions
      Raw_Data_URL : Unbounded_String;  --  Link to full dataset
   end record;

   procedure Generate_Arena_Submission
      (Submission : Arena_Submission;
       Path       : String);

   function Generate_Arena_Submission_String
      (Submission : Arena_Submission) return String;

   ---------------------------------------------------------------------------
   --  Format-Specific Helpers
   ---------------------------------------------------------------------------

   --  JSON
   function Profile_To_JSON (Profile : Model_Profile) return String;
   function Analysis_To_JSON (Analysis : Response_Analysis) return String;
   function Finding_To_JSON (F : Finding) return String;

   --  HTML
   function Profile_To_HTML
      (Profile  : Model_Profile;
       Metadata : Report_Metadata) return String;
   function Radar_Chart_SVG (Scores : Category_Score_Array) return String;
   function ISA_Gauge_SVG (Score : Float) return String;

   --  Markdown
   function Profile_To_Markdown
      (Profile  : Model_Profile;
       Metadata : Report_Metadata) return String;
   function Comparison_Table_Markdown
      (Profiles : Profile_Vector) return String;

   --  CSV
   function Profile_To_CSV_Row (Profile : Model_Profile) return String;
   function CSV_Header return String;

   --  LaTeX
   function Profile_To_LaTeX
      (Profile  : Model_Profile;
       Metadata : Report_Metadata) return String;
   function Comparison_Table_LaTeX
      (Profiles : Profile_Vector) return String;

   ---------------------------------------------------------------------------
   --  Export Configuration
   ---------------------------------------------------------------------------

   type Export_Options is record
      Include_Raw_Findings : Boolean := False;
      Include_Methodology  : Boolean := True;
      Include_Charts       : Boolean := True;  --  For HTML
      Embed_Styles         : Boolean := True;  --  For HTML
      Pretty_Print         : Boolean := True;  --  For JSON
      Decimal_Places       : Positive := 2;
   end record;

   Default_Export : constant Export_Options := (
      Include_Raw_Findings => False,
      Include_Methodology  => True,
      Include_Charts       => True,
      Embed_Styles         => True,
      Pretty_Print         => True,
      Decimal_Places       => 2
   );

   procedure Set_Export_Options (Options : Export_Options);
   function Get_Export_Options return Export_Options;

end Vexometer.Reports;
