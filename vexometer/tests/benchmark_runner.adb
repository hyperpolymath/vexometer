-- SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Ada.Text_IO;                    use Ada.Text_IO;
with Ada.Float_Text_IO;
with Ada.Calendar;                   use Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;              use Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Ada.Environment_Variables;
with Ada.Containers.Vectors;
with Ada.Directories;

with Vexometer.Core;                 use Vexometer.Core;
with Vexometer.Patterns;
with Vexometer.Probes;
with Vexometer.Reports;

procedure Benchmark_Runner is

   package Float_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Float);

   subtype Float_Vector is Float_Vectors.Vector;

   type Corpus_Definition is record
      Name : Unbounded_String;
      Path : Unbounded_String;
   end record;

   package Corpus_Def_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Corpus_Definition);

   subtype Corpus_Def_Vector is Corpus_Def_Vectors.Vector;

   type Corpus_Sample is record
      Name : Unbounded_String;
      Text : Unbounded_String;
   end record;

   package Corpus_Sample_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Corpus_Sample);

   subtype Corpus_Sample_Vector is Corpus_Sample_Vectors.Vector;

   type Sample_Result is record
      Name          : Unbounded_String;
      Avg_MS        : Float;
      P50_MS        : Float;
      P95_MS        : Float;
      ISA_Mean      : Float;
      Chars_Per_Sec : Float;
   end record;

   package Result_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Sample_Result);

   subtype Result_Vector is Result_Vectors.Vector;

   QQ : constant String := """";

   function To_Lower (S : String) return String
      renames Ada.Characters.Handling.To_Lower;

   function Read_File (Path : String) return String is
      F       : File_Type;
      Content : Unbounded_String := Null_Unbounded_String;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Append (Content, Get_Line (F));
         if not End_Of_File (F) then
            Append (Content, ASCII.LF);
         end if;
      end loop;
      Close (F);
      return To_String (Content);
   exception
      when others =>
         return "";
   end Read_File;

   function Escape_JSON (S : String) return String is
      R : Unbounded_String := Null_Unbounded_String;
   begin
      for C of S loop
         case C is
            when '"' =>
               Append (R, '\');
               Append (R, '"');
            when '\' =>
               Append (R, '\');
               Append (R, '\');
            when ASCII.LF =>
               Append (R, '\');
               Append (R, 'n');
            when ASCII.CR =>
               Append (R, '\');
               Append (R, 'r');
            when ASCII.HT =>
               Append (R, '\');
               Append (R, 't');
            when others =>
               Append (R, C);
         end case;
      end loop;
      return To_String (R);
   end Escape_JSON;

   function Image_Float (Value : Float; Aft : Natural := 3) return String is
      Buf : String (1 .. 48);
   begin
      Ada.Float_Text_IO.Put (To => Buf, Item => Value, Aft => Aft, Exp => 0);
      return Trim (Buf, Ada.Strings.Both);
   end Image_Float;

   function Read_Positive_Env
      (Name    : String;
       Default : Positive) return Positive
   is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Positive'Value (Ada.Environment_Variables.Value (Name));
      end if;
      return Default;
   exception
      when others =>
         return Default;
   end Read_Positive_Env;

   function Env_Or_Else
      (Name    : String;
       Default : String) return String
   is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;
      return Default;
   end Env_Or_Else;

   procedure Sort (Values : in out Float_Vector) is
   begin
      if Natural (Values.Length) < 2 then
         return;
      end if;

      for I in 2 .. Natural (Values.Length) loop
         declare
            Key : constant Float := Values (Positive (I));
            J   : Integer := I - 1;
         begin
            while J >= 1 and then Values (Positive (J)) > Key loop
               Values.Replace_Element
                  (Positive (J + 1), Values (Positive (J)));
               J := J - 1;
            end loop;
            Values.Replace_Element (Positive (J + 1), Key);
         end;
      end loop;
   end Sort;

   function Percentile
      (Values : Float_Vector;
       Ratio  : Float) return Float
   is
      Sorted : Float_Vector := Values;
      N      : constant Natural := Natural (Sorted.Length);
      P      : constant Float := Float'Max (0.0, Float'Min (1.0, Ratio));
      Pos    : Natural;
   begin
      if N = 0 then
         return 0.0;
      end if;

      Sort (Sorted);
      Pos := Natural (Float (N - 1) * P) + 1;
      if Pos > N then
         Pos := N;
      end if;
      return Sorted (Positive (Pos));
   end Percentile;

   function Build_Corpus return Corpus_Sample_Vector is
      Defs    : Corpus_Def_Vector := Corpus_Def_Vectors.Empty_Vector;
      Samples : Corpus_Sample_Vector := Corpus_Sample_Vectors.Empty_Vector;
   begin
      Defs.Append
         (New_Item => Corpus_Definition'
            (Name => To_Unbounded_String ("clean_concise"),
             Path => To_Unbounded_String
                ("benchmarks/corpus/clean_concise.txt")));
      Defs.Append
         (New_Item => Corpus_Definition'
            (Name => To_Unbounded_String ("sycophancy_dense"),
             Path => To_Unbounded_String
                ("benchmarks/corpus/sycophancy_dense.txt")));
      Defs.Append
         (New_Item => Corpus_Definition'
            (Name => To_Unbounded_String ("paternalistic_warning"),
             Path => To_Unbounded_String
                ("benchmarks/corpus/paternalistic_warning.txt")));
      Defs.Append
         (New_Item => Corpus_Definition'
            (Name => To_Unbounded_String ("mixed_pathology"),
             Path => To_Unbounded_String
                ("benchmarks/corpus/mixed_pathology.txt")));

      for D of Defs loop
         declare
            T : constant String := Read_File (To_String (D.Path));
         begin
            if T'Length > 0 then
               Samples.Append
                  (New_Item => Corpus_Sample'
                     (Name => D.Name, Text => To_Unbounded_String (T)));
            end if;
         end;
      end loop;

      return Samples;
   end Build_Corpus;

   function Benchmark_Sample
      (DB         : Vexometer.Patterns.Pattern_Database;
       Sample     : Corpus_Sample;
       Iterations : Positive) return Sample_Result
   is
      Durations      : Float_Vector := Float_Vectors.Empty_Vector;
      ISA_Sum        : Float := 0.0;
      Duration_Sum_S : Float := 0.0;
      Chars_Total    : Natural := 0;
      Text           : constant String := To_String (Sample.Text);
   begin
      for I in 1 .. Iterations loop
         pragma Unreferenced (I);

         declare
            Start    : constant Time := Clock;
            Analysis : Response_Analysis;
            Elapsed  : Duration;
         begin
            Vexometer.Patterns.Analyse_Response
               (DB       => DB,
                Prompt   => "",
                Response => Text,
                Config   => Default_Config,
                Analysis => Analysis);

            Elapsed := Clock - Start;
            Durations.Append (Float (Elapsed) * 1000.0);
            Duration_Sum_S := Duration_Sum_S + Float (Elapsed);
            ISA_Sum := ISA_Sum + Analysis.Overall_ISA;
            Chars_Total := Chars_Total + Text'Length;
         end;
      end loop;

      return (
         Name          => Sample.Name,
         Avg_MS        => (Duration_Sum_S * 1000.0) / Float (Iterations),
         P50_MS        => Percentile (Durations, 0.50),
         P95_MS        => Percentile (Durations, 0.95),
         ISA_Mean      => ISA_Sum / Float (Iterations),
         Chars_Per_Sec =>
            (if Duration_Sum_S > 0.0
             then Float (Chars_Total) / Duration_Sum_S
             else 0.0)
      );
   end Benchmark_Sample;

   function Benchmark_Pattern_Load
      (Iterations : Positive) return Float
   is
      Sum_S : Float := 0.0;
   begin
      for I in 1 .. Iterations loop
         pragma Unreferenced (I);

         declare
            Start : constant Time := Clock;
            DB    : Vexometer.Patterns.Pattern_Database;
         begin
            Vexometer.Patterns.Initialize (DB);
            Vexometer.Patterns.Load_From_File
               (DB, "data/patterns/linguistic_pathology.json");
            Vexometer.Patterns.Load_From_File
               (DB, "data/patterns/paternalism.json");

            Sum_S := Sum_S + Float (Clock - Start);
         end;
      end loop;

      return (Sum_S * 1000.0) / Float (Iterations);
   end Benchmark_Pattern_Load;

   function Benchmark_Probe_Load
      (Iterations : Positive) return Float
   is
      Sum_S : Float := 0.0;
   begin
      for I in 1 .. Iterations loop
         pragma Unreferenced (I);

         declare
            Suite : Vexometer.Probes.Probe_Suite;
            Start : constant Time := Clock;
         begin
            Vexometer.Probes.Initialize (Suite);
            Vexometer.Probes.Load_From_File
               (Suite, "data/probes/behavioural_probes.json");
            Sum_S := Sum_S + Float (Clock - Start);
         end;
      end loop;

      return (Sum_S * 1000.0) / Float (Iterations);
   end Benchmark_Probe_Load;

   function Parse_Format
      (Token  : String;
       Format : out Vexometer.Reports.Report_Format) return Boolean
   is
      Lower : constant String := To_Lower (Trim (Token, Ada.Strings.Both));
   begin
      if Lower = "json" then
         Format := Vexometer.Reports.JSON;
      elsif Lower = "html" then
         Format := Vexometer.Reports.HTML;
      elsif Lower = "md" or else Lower = "markdown" then
         Format := Vexometer.Reports.Markdown;
      elsif Lower = "csv" then
         Format := Vexometer.Reports.CSV;
      elsif Lower = "latex" or else Lower = "tex" then
         Format := Vexometer.Reports.LaTeX;
      elsif Lower = "yaml" or else Lower = "yml" then
         Format := Vexometer.Reports.YAML;
      else
         return False;
      end if;

      return True;
   end Parse_Format;

   function Parse_Formats
      (Raw : String) return Vexometer.Reports.Format_Set
   is
      Enabled : Vexometer.Reports.Format_Set := [others => False];
      Token   : Unbounded_String := Null_Unbounded_String;
      Parsed  : Natural := 0;

      procedure Consume_Token is
         Fmt : Vexometer.Reports.Report_Format;
         T   : constant String := Trim (To_String (Token), Ada.Strings.Both);
      begin
         if T'Length > 0 and then Parse_Format (T, Fmt) then
            Enabled (Fmt) := True;
            Parsed := Parsed + 1;
         end if;
         Token := Null_Unbounded_String;
      end Consume_Token;
   begin
      for C of Raw loop
         if C = ',' then
            Consume_Token;
         else
            Append (Token, C);
         end if;
      end loop;

      Consume_Token;

      if Parsed = 0 then
         Enabled (Vexometer.Reports.HTML) := True;
         Enabled (Vexometer.Reports.JSON) := True;
         Enabled (Vexometer.Reports.Markdown) := True;
      end if;

      return Enabled;
   end Parse_Formats;

   function Format_Extension
      (Fmt : Vexometer.Reports.Report_Format) return String
   is
   begin
      return (case Fmt is
         when Vexometer.Reports.JSON     => "json",
         when Vexometer.Reports.HTML     => "html",
         when Vexometer.Reports.Markdown => "md",
         when Vexometer.Reports.CSV      => "csv",
         when Vexometer.Reports.LaTeX    => "tex",
         when Vexometer.Reports.YAML     => "yaml");
   end Format_Extension;

   procedure Ensure_Directory (Path : String) is
   begin
      if not Ada.Directories.Exists (Path) then
         Ada.Directories.Create_Path (Path);
      end if;
   end Ensure_Directory;

   procedure Export_Sample_Reports
      (DB      : Vexometer.Patterns.Pattern_Database;
       Samples : Corpus_Sample_Vector;
       Formats : Vexometer.Reports.Format_Set)
   is
      Reports_Dir : constant String := "benchmarks/results/cases";
      Meta        : Vexometer.Reports.Report_Metadata :=
         Vexometer.Reports.Default_Metadata;
   begin
      Ensure_Directory (Reports_Dir);

      for S of Samples loop
         declare
            Analysis : Response_Analysis;
            Name     : constant String := To_String (S.Name);
            Text     : constant String := To_String (S.Text);
         begin
            Vexometer.Patterns.Analyse_Response
               (DB       => DB,
                Prompt   => "",
                Response => Text,
                Config   => Default_Config,
                Analysis => Analysis);

            Analysis.Model_ID := To_Unbounded_String ("benchmark-" & Name);
            Analysis.Model_Version := Null_Unbounded_String;
            Analysis.Response_Time := 0.0;
            Analysis.Token_Count := Text'Length / 4;
            Analysis.Timestamp := Clock;

            Meta.Title := To_Unbounded_String ("ISA Benchmark Case: " & Name);
            Meta.Description := To_Unbounded_String
               ("Single-sample analysis report generated by benchmark_runner.");
            Meta.Generated_At := Clock;

            for Fmt in Vexometer.Reports.Report_Format loop
               if Formats (Fmt) then
                  Vexometer.Reports.Generate_Analysis_Report
                     (Analysis => Analysis,
                      Format   => Fmt,
                      Path     => Reports_Dir & "/" & Name
                         & "." & Format_Extension (Fmt),
                      Metadata => Meta);
               end if;
            end loop;
         end;
      end loop;
   end Export_Sample_Reports;

   Analysis_Iterations : constant Positive :=
      Read_Positive_Env ("VEXOMETER_BENCH_ITERATIONS", 200);
   Loader_Iterations   : constant Positive :=
      Read_Positive_Env ("VEXOMETER_BENCH_LOADER_ITERATIONS", 100);

   Display_Formats : constant Vexometer.Reports.Format_Set := Parse_Formats
      (Env_Or_Else ("VEXOMETER_BENCH_DISPLAY_FORMATS", "html,json,md"));

   DB_Backend : constant String := Env_Or_Else
      ("VEXOMETER_BENCH_DB_BACKEND", "verisimdb");

   Samples         : constant Corpus_Sample_Vector := Build_Corpus;
   Results         : Result_Vector := Result_Vectors.Empty_Vector;
   DB              : Vexometer.Patterns.Pattern_Database;
   Pattern_Load_MS : Float;
   Probe_Load_MS   : Float;

begin
   Ensure_Directory ("benchmarks/results");

   if Samples.Is_Empty then
      Put_Line ("{" & QQ & "error" & QQ & ":" & QQ
         & "benchmark corpus empty" & QQ & "}");
      return;
   end if;

   Vexometer.Patterns.Initialize (DB);
   Vexometer.Patterns.Load_From_File (DB, "data/patterns/linguistic_pathology.json");
   Vexometer.Patterns.Load_From_File (DB, "data/patterns/paternalism.json");

   for S of Samples loop
      Results.Append (Benchmark_Sample (DB, S, Analysis_Iterations));
   end loop;

   Export_Sample_Reports (DB, Samples, Display_Formats);

   Pattern_Load_MS := Benchmark_Pattern_Load (Loader_Iterations);
   Probe_Load_MS := Benchmark_Probe_Load (Loader_Iterations);

   Put_Line ("{");
   Put_Line ("  " & QQ & "schema" & QQ & ": "
      & QQ & "vexometer-benchmark-v1" & QQ & ",");
   Put_Line ("  " & QQ & "timestamp_utc" & QQ & ": "
      & QQ & Escape_JSON (Ada.Calendar.Formatting.Image (Clock)) & QQ & ",");
   Put_Line ("  " & QQ & "database_backend" & QQ & ": "
      & QQ & Escape_JSON (DB_Backend) & QQ & ",");
   Put_Line ("  " & QQ & "analysis_iterations" & QQ & ": "
      & Positive'Image (Analysis_Iterations) & ",");
   Put_Line ("  " & QQ & "loader_iterations" & QQ & ": "
      & Positive'Image (Loader_Iterations) & ",");

   Put_Line ("  " & QQ & "display_formats" & QQ & ": [");
   declare
      Count : Natural := 0;
      Total : Natural := 0;
   begin
      for Fmt in Vexometer.Reports.Report_Format loop
         if Display_Formats (Fmt) then
            Total := Total + 1;
         end if;
      end loop;

      for Fmt in Vexometer.Reports.Report_Format loop
         if Display_Formats (Fmt) then
            Count := Count + 1;
            Put ("    " & QQ
               & Escape_JSON (To_Lower (Vexometer.Reports.Report_Format'Image (Fmt)))
               & QQ);
            if Count < Total then
               Put_Line (",");
            else
               New_Line;
            end if;
         end if;
      end loop;
   end;
   Put_Line ("  ],");

   Put_Line ("  " & QQ & "analysis_cases" & QQ & ": [");

   for I in 1 .. Natural (Results.Length) loop
      declare
         R : constant Sample_Result := Results (Positive (I));
      begin
         Put_Line ("    {");
         Put_Line ("      " & QQ & "name" & QQ & ": "
            & QQ & Escape_JSON (To_String (R.Name)) & QQ & ",");
         Put_Line ("      " & QQ & "avg_ms" & QQ & ": "
            & Image_Float (R.Avg_MS) & ",");
         Put_Line ("      " & QQ & "p50_ms" & QQ & ": "
            & Image_Float (R.P50_MS) & ",");
         Put_Line ("      " & QQ & "p95_ms" & QQ & ": "
            & Image_Float (R.P95_MS) & ",");
         Put_Line ("      " & QQ & "isa_mean" & QQ & ": "
            & Image_Float (R.ISA_Mean) & ",");
         Put_Line ("      " & QQ & "chars_per_sec" & QQ & ": "
            & Image_Float (R.Chars_Per_Sec, 1));

         if I < Natural (Results.Length) then
            Put_Line ("    },");
         else
            Put_Line ("    }");
         end if;
      end;
   end loop;

   Put_Line ("  ],");
   Put_Line ("  " & QQ & "loader_benchmarks" & QQ & ": {");
   Put_Line ("    " & QQ & "patterns_load_avg_ms" & QQ & ": "
      & Image_Float (Pattern_Load_MS) & ",");
   Put_Line ("    " & QQ & "probes_load_avg_ms" & QQ & ": "
      & Image_Float (Probe_Load_MS));
   Put_Line ("  },");
   Put_Line ("  " & QQ & "artifacts" & QQ & ": {");
   Put_Line ("    " & QQ & "summary_json" & QQ & ": "
      & QQ & "benchmarks/results/latest.json" & QQ & ",");
   Put_Line ("    " & QQ & "case_reports_dir" & QQ & ": "
      & QQ & "benchmarks/results/cases" & QQ);
   Put_Line ("  }");
   Put_Line ("}");

end Benchmark_Runner;
