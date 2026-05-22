--  ISA (formerly Vexometer) - Irritation Surface Analyser
--  Main entry point
--
--  Copyright (C) 2024 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Ada.Text_IO;            use Ada.Text_IO;
with Ada.Command_Line;       use Ada.Command_Line;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Characters.Handling;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Calendar;
with Ada.Environment_Variables;
with Ada.Exceptions;

with Vexometer.Core;         use Vexometer.Core;
with Vexometer.Patterns;
with Vexometer.Probes;
with Vexometer.API;
with Vexometer.Reports;
with Vexometer.GUI;

procedure Vexometer.App is

   package String_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Unbounded_String);

   subtype String_Vector is String_Vectors.Vector;

   type CLI_Options is record
      Output_Path   : Unbounded_String := Null_Unbounded_String;
      Format        : Vexometer.Reports.Report_Format :=
         Vexometer.Reports.JSON;
      Model         : Unbounded_String := Null_Unbounded_String;
      Provider      : Vexometer.API.API_Provider := Vexometer.API.Ollama;
      Patterns_Path : Unbounded_String := Null_Unbounded_String;
      Probes_Path   : Unbounded_String := Null_Unbounded_String;
      Config_Path   : Unbounded_String := Null_Unbounded_String;
      Positionals   : String_Vector := String_Vectors.Empty_Vector;
   end record;

   function To_Lower (S : String) return String
      renames Ada.Characters.Handling.To_Lower;

   function Format_Extension
      (Format : Vexometer.Reports.Report_Format) return String
   is
   begin
      return (case Format is
         when Vexometer.Reports.JSON     => "json",
         when Vexometer.Reports.HTML     => "html",
         when Vexometer.Reports.Markdown => "md",
         when Vexometer.Reports.CSV      => "csv",
         when Vexometer.Reports.LaTeX    => "tex",
         when Vexometer.Reports.YAML     => "yaml");
   end Format_Extension;

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

   function Read_Stdin return String is
      Content : Unbounded_String := Null_Unbounded_String;
   begin
      while not End_Of_File loop
         Append (Content, Get_Line);
         if not End_Of_File then
            Append (Content, ASCII.LF);
         end if;
      end loop;
      return To_String (Content);
   exception
      when End_Error =>
         return To_String (Content);
      when others =>
         return "";
   end Read_Stdin;

   procedure Remove_File_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path)
         and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File
      then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Remove_File_If_Exists;

   function Parse_Format
      (Raw    : String;
       Format : out Vexometer.Reports.Report_Format) return Boolean
   is
      Lower : constant String := To_Lower (Raw);
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

   function Parse_Provider
      (Raw      : String;
       Provider : out Vexometer.API.API_Provider) return Boolean
   is
      Lower : constant String := To_Lower (Raw);
   begin
      if Lower = "ollama" then
         Provider := Vexometer.API.Ollama;
      elsif Lower = "lmstudio" or else Lower = "lm-studio" then
         Provider := Vexometer.API.LMStudio;
      elsif Lower = "llamacpp" or else Lower = "llama.cpp" then
         Provider := Vexometer.API.Llamacpp;
      elsif Lower = "localai" then
         Provider := Vexometer.API.LocalAI;
      elsif Lower = "koboldcpp" then
         Provider := Vexometer.API.Koboldcpp;
      elsif Lower = "huggingface" then
         Provider := Vexometer.API.HuggingFace;
      elsif Lower = "together" then
         Provider := Vexometer.API.Together;
      elsif Lower = "groq" then
         Provider := Vexometer.API.Groq;
      elsif Lower = "openai" then
         Provider := Vexometer.API.OpenAI;
      elsif Lower = "anthropic" then
         Provider := Vexometer.API.Anthropic;
      elsif Lower = "google" or else Lower = "gemini" then
         Provider := Vexometer.API.Google;
      elsif Lower = "mistral" then
         Provider := Vexometer.API.Mistral;
      elsif Lower = "custom" then
         Provider := Vexometer.API.Custom;
      else
         return False;
      end if;

      return True;
   end Parse_Provider;

   function Parse_Common_Options (Opts : out CLI_Options) return Boolean is
      I : Positive := 2;
   begin
      Opts := (others => <>);

      while I <= Argument_Count loop
         declare
            Arg : constant String := Argument (I);
         begin
            if Arg = "-o" or else Arg = "--output" then
               if I = Argument_Count then
                  Put_Line ("Missing value for " & Arg);
                  return False;
               end if;
               Opts.Output_Path := To_Unbounded_String (Argument (I + 1));
               I := I + 2;

            elsif Arg = "-f" or else Arg = "--format" then
               if I = Argument_Count then
                  Put_Line ("Missing value for " & Arg);
                  return False;
               end if;
               if not Parse_Format (Argument (I + 1), Opts.Format) then
                  Put_Line ("Unsupported format: " & Argument (I + 1));
                  return False;
               end if;
               I := I + 2;

            elsif Arg = "-m" or else Arg = "--model" then
               if I = Argument_Count then
                  Put_Line ("Missing value for " & Arg);
                  return False;
               end if;
               Opts.Model := To_Unbounded_String (Argument (I + 1));
               I := I + 2;

            elsif Arg = "-p" or else Arg = "--provider" then
               if I = Argument_Count then
                  Put_Line ("Missing value for " & Arg);
                  return False;
               end if;
               if not Parse_Provider (Argument (I + 1), Opts.Provider) then
                  Put_Line ("Unsupported provider: " & Argument (I + 1));
                  return False;
               end if;
               I := I + 2;

            elsif Arg = "--patterns" then
               if I = Argument_Count then
                  Put_Line ("Missing value for --patterns");
                  return False;
               end if;
               Opts.Patterns_Path := To_Unbounded_String (Argument (I + 1));
               I := I + 2;

            elsif Arg = "--probes" then
               if I = Argument_Count then
                  Put_Line ("Missing value for --probes");
                  return False;
               end if;
               Opts.Probes_Path := To_Unbounded_String (Argument (I + 1));
               I := I + 2;

            elsif Arg = "-c" or else Arg = "--config" then
               if I = Argument_Count then
                  Put_Line ("Missing value for " & Arg);
                  return False;
               end if;
               Opts.Config_Path := To_Unbounded_String (Argument (I + 1));
               I := I + 2;

            elsif Arg'Length > 0 and then Arg (Arg'First) = '-' then
               Put_Line ("Unknown option: " & Arg);
               return False;

            else
               Opts.Positionals.Append (To_Unbounded_String (Arg));
               I := I + 1;
            end if;
         end;
      end loop;

      return True;
   end Parse_Common_Options;

   function Join_Positionals (Values : String_Vector) return String is
      Result : Unbounded_String := Null_Unbounded_String;
   begin
      for Item of Values loop
         if Length (Result) > 0 then
            Append (Result, ' ');
         end if;
         Append (Result, To_String (Item));
      end loop;
      return To_String (Result);
   end Join_Positionals;

   function Extract_Response_Text (Values : String_Vector) return String is
   begin
      if Values.Is_Empty then
         return Read_Stdin;
      end if;

      if Natural (Values.Length) = 1 then
         declare
            Candidate : constant String := To_String (Values.First_Element);
         begin
            if Ada.Directories.Exists (Candidate)
               and then Ada.Directories.Kind (Candidate) =
                  Ada.Directories.Ordinary_File
            then
               return Read_File (Candidate);
            end if;
         end;
      end if;

      return Join_Positionals (Values);
   end Extract_Response_Text;

   procedure Load_Pattern_Overrides
      (DB   : in out Vexometer.Patterns.Pattern_Database;
       Path : String)
   is
   begin
      if Path'Length = 0 then
         return;
      end if;

      if not Ada.Directories.Exists (Path) then
         Put_Line ("Warning: pattern path does not exist: " & Path);
         return;
      end if;

      if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
         Vexometer.Patterns.Load_From_Directory (DB, Path);
      elsif Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
         Vexometer.Patterns.Load_From_File (DB, Path);
      else
         Put_Line ("Warning: unsupported pattern path kind: " & Path);
      end if;
   end Load_Pattern_Overrides;

   procedure Load_Probe_Overrides
      (Suite : in out Vexometer.Probes.Probe_Suite;
       Path  : String)
   is
      Search  : Ada.Directories.Search_Type;
      Dir_Ent : Ada.Directories.Directory_Entry_Type;
   begin
      if Path'Length = 0 then
         return;
      end if;

      if not Ada.Directories.Exists (Path) then
         Put_Line ("Warning: probe path does not exist: " & Path);
         return;
      end if;

      if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
         Vexometer.Probes.Load_From_File (Suite, Path);
      elsif Ada.Directories.Kind (Path) = Ada.Directories.Directory then
         Ada.Directories.Start_Search
            (Search,
             Path,
             "*.json",
             Filter => [Ada.Directories.Ordinary_File => True,
                        others => False]);

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Dir_Ent);
            Vexometer.Probes.Load_From_File
               (Suite, Ada.Directories.Full_Name (Dir_Ent));
         end loop;

         Ada.Directories.End_Search (Search);
      else
         Put_Line ("Warning: unsupported probe path kind: " & Path);
      end if;
   exception
      when others =>
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others =>
               null;
         end;
         Put_Line ("Warning: failed while loading probes from: " & Path);
   end Load_Probe_Overrides;

   function Render_Analysis_Report
      (Analysis : Response_Analysis;
       Format   : Vexometer.Reports.Report_Format) return String
   is
      Temp_Path : constant String := "/tmp/vexometer-cli-analysis.tmp";
   begin
      Vexometer.Reports.Generate_Analysis_Report
         (Analysis => Analysis,
          Format   => Format,
          Path     => Temp_Path);
      declare
         Rendered : constant String := Read_File (Temp_Path);
      begin
         Remove_File_If_Exists (Temp_Path);
         return Rendered;
      end;
   exception
      when others =>
         Remove_File_If_Exists (Temp_Path);
         return "";
   end Render_Analysis_Report;

   function Render_Probe_Report
      (Results : Vexometer.Probes.Result_Vector;
       Format  : Vexometer.Reports.Report_Format) return String
   is
      Temp_Path : constant String := "/tmp/vexometer-cli-probes.tmp";
   begin
      Vexometer.Reports.Generate_Probe_Report
         (Results => Results,
          Format  => Format,
          Path    => Temp_Path);
      declare
         Rendered : constant String := Read_File (Temp_Path);
      begin
         Remove_File_If_Exists (Temp_Path);
         return Rendered;
      end;
   exception
      when others =>
         Remove_File_If_Exists (Temp_Path);
         return "";
   end Render_Probe_Report;

   function Env_Or_Empty (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;
      return "";
   end Env_Or_Empty;

   function API_Key_For (Provider : Vexometer.API.API_Provider) return String is
   begin
      case Provider is
         when Vexometer.API.OpenAI =>
            return Env_Or_Empty ("OPENAI_API_KEY");
         when Vexometer.API.Anthropic =>
            return Env_Or_Empty ("ANTHROPIC_API_KEY");
         when Vexometer.API.Google =>
            return Env_Or_Empty ("GOOGLE_API_KEY");
         when Vexometer.API.Mistral =>
            return Env_Or_Empty ("MISTRAL_API_KEY");
         when Vexometer.API.HuggingFace =>
            return Env_Or_Empty ("HUGGINGFACE_API_KEY");
         when Vexometer.API.Together =>
            return Env_Or_Empty ("TOGETHER_API_KEY");
         when Vexometer.API.Groq =>
            return Env_Or_Empty ("GROQ_API_KEY");
         when others =>
            return "";
      end case;
   end API_Key_For;

   procedure Build_Analysis
      (Response_Text : String;
       Model_Name    : String;
       Patterns_Path : String;
       Analysis      : out Response_Analysis)
   is
      DB : Vexometer.Patterns.Pattern_Database;
   begin
      Vexometer.Patterns.Initialize (DB);
      Load_Pattern_Overrides (DB, Patterns_Path);

      Vexometer.Patterns.Analyse_Response
         (DB       => DB,
          Prompt   => "",
          Response => Response_Text,
          Config   => Default_Config,
          Analysis => Analysis);

      Analysis.Model_ID := To_Unbounded_String (Model_Name);
      Analysis.Model_Version := Null_Unbounded_String;
      Analysis.Response_Time := 0.0;
      Analysis.Token_Count :=
         (if Response_Text'Length > 0 then Response_Text'Length / 4 else 0);
      Analysis.Timestamp := Ada.Calendar.Clock;
   end Build_Analysis;

   procedure Print_Usage is
   begin
      Put_Line ("ISA (formerly Vexometer) " & Vexometer.Version);
      Put_Line ("Irritation Surface Analyser for AI Assistants");
      New_Line;
      Put_Line ("Usage: vexometer [OPTIONS] [COMMAND]");
      Put_Line ("Name: ISA is canonical; 'vexometer' is retained for compatibility.");
      New_Line;
      Put_Line ("Commands:");
      Put_Line ("  gui              Launch graphical interface (default)");
      Put_Line ("  analyse [TEXT]   Analyse response text from arg, file, or stdin");
      Put_Line ("  probe MODEL      Run behavioural probe suite against model");
      Put_Line ("  compare M1 M2... Compare multiple models");
      Put_Line ("  report FILE      Analyse FILE and emit a report artifact");
      New_Line;
      Put_Line ("Options:");
      Put_Line ("  -h, --help       Show this help message");
      Put_Line ("  -v, --version    Show version information");
      Put_Line ("  -o, --output F   Output file (default: stdout)");
      Put_Line ("  -f, --format F   Output format: json, html, md, csv, latex");
      Put_Line ("  -c, --config F   Configuration file (reserved)");
      Put_Line ("  -m, --model M    Model to analyse (for API calls)");
      Put_Line ("  -p, --provider P API provider: ollama, openai, anthropic, ...");
      Put_Line ("  --patterns PATH  Additional pattern file/directory");
      Put_Line ("  --probes PATH    Additional probe file/directory");
      New_Line;
      Put_Line ("Examples:");
      Put_Line ("  echo 'Great question!' | vexometer analyse");
      Put_Line ("  vexometer probe llama3.2 -p ollama -f json -o report.json");
      Put_Line ("  vexometer compare gpt-4o claude-3.5-sonnet llama3.2");
      Put_Line ("  vexometer report response.txt -f md -o analysis.md");
      New_Line;
      Put_Line ("For more information: https://gitlab.com/hyperpolymath/vexometer");
   end Print_Usage;

   procedure Print_Version is
   begin
      Put_Line ("ISA (formerly Vexometer) " & Vexometer.Version);
      Put_Line ("Copyright (C) 2024 Jonathan D.A. Jewell");
      Put_Line ("License: MPL-2.0");
      Put_Line ("This is free software; you are free to change and redistribute it.");
   end Print_Version;

   procedure Run_GUI is
      Win : Vexometer.GUI.Main_Window;
   begin
      Win.Initialize;
      Win.Show;
      Vexometer.GUI.Run;
   end Run_GUI;

   procedure Run_Analyse (Opts : CLI_Options) is
      Response_Text : constant String := Extract_Response_Text (Opts.Positionals);
      Analysis      : Response_Analysis;
      Model_Name    : constant String :=
         (if Length (Opts.Model) > 0 then To_String (Opts.Model)
          else "manual-input");
   begin
      if Response_Text'Length = 0 then
         Put_Line ("No response text provided (arg/file/stdin).");
         Set_Exit_Status (1);
         return;
      end if;

      Build_Analysis
         (Response_Text => Response_Text,
          Model_Name    => Model_Name,
          Patterns_Path => To_String (Opts.Patterns_Path),
          Analysis      => Analysis);

      if Length (Opts.Output_Path) > 0 then
         Vexometer.Reports.Generate_Analysis_Report
            (Analysis => Analysis,
             Format   => Opts.Format,
             Path     => To_String (Opts.Output_Path));
         Put_Line ("Analysis report written to " & To_String (Opts.Output_Path));
      else
         if Opts.Format = Vexometer.Reports.JSON then
            Put_Line (Vexometer.Reports.Analysis_To_JSON (Analysis));
         else
            Put_Line (Render_Analysis_Report (Analysis, Opts.Format));
         end if;
      end if;
   end Run_Analyse;

   procedure Run_Probe (Opts : CLI_Options) is
      Model_Name : constant String :=
         (if Length (Opts.Model) > 0 then To_String (Opts.Model)
          elsif not Opts.Positionals.Is_Empty
             then To_String (Opts.Positionals.First_Element)
          else "");
      Client   : Vexometer.API.API_Client;
      Suite    : Vexometer.Probes.Probe_Suite;
      Results  : Vexometer.Probes.Result_Vector;
      Key      : constant String := API_Key_For (Opts.Provider);
   begin
      if Model_Name'Length = 0 then
         Put_Line ("Missing model. Usage: vexometer probe MODEL [options]");
         Set_Exit_Status (1);
         return;
      end if;

      Vexometer.API.Configure
         (Client   => Client,
          Provider => Opts.Provider,
          Model    => Model_Name,
          API_Key  => Key);

      Vexometer.Probes.Initialize (Suite);
      Load_Probe_Overrides (Suite, To_String (Opts.Probes_Path));

      Vexometer.API.Run_Probe_Suite
         (Client  => Client,
          Suite   => Suite,
          Results => Results);

      if Length (Opts.Output_Path) > 0 then
         Vexometer.Reports.Generate_Probe_Report
            (Results => Results,
             Format  => Opts.Format,
             Path    => To_String (Opts.Output_Path));
         Put_Line ("Probe report written to " & To_String (Opts.Output_Path));
      else
         Put_Line (Render_Probe_Report (Results, Opts.Format));
      end if;
   end Run_Probe;

   procedure Run_Compare (Opts : CLI_Options) is
      Models   : String_Vector := Opts.Positionals;
      Key      : constant String := API_Key_For (Opts.Provider);
      Suite    : Vexometer.Probes.Probe_Suite;
      Profiles : Profile_Vector;
   begin
      if Length (Opts.Model) > 0 then
         Models.Append (Opts.Model);
      end if;

      if Natural (Models.Length) < 2 then
         Put_Line ("Need at least two models. Usage: vexometer compare M1 M2 [M3 ...]");
         Set_Exit_Status (1);
         return;
      end if;

      Vexometer.Probes.Initialize (Suite);
      Load_Probe_Overrides (Suite, To_String (Opts.Probes_Path));

      declare
         Configs : Vexometer.API.Model_Config_Array
            (1 .. Natural (Models.Length));
      begin
         for I in Configs'Range loop
            Configs (I).Provider := Opts.Provider;
            Configs (I).Endpoint := To_Unbounded_String
               (Vexometer.API.Default_Endpoint (Opts.Provider));
            Configs (I).API_Key := To_Unbounded_String (Key);
            Configs (I).Model := Models (I);
            Configs (I).Temperature := 0.0;
            Configs (I).Max_Tokens := 2048;
            Configs (I).Timeout := 60.0;
            Configs (I).Retry_Count := 3;
            Configs (I).Retry_Delay := 1.0;
         end loop;

         Vexometer.API.Compare_Models
            (Configs  => Configs,
             Suite    => Suite,
             Profiles => Profiles);
      end;

      if Length (Opts.Output_Path) > 0 then
         Vexometer.Reports.Generate_Comparison_Report
            (Profiles => Profiles,
             Format   => Opts.Format,
             Path     => To_String (Opts.Output_Path));
         Put_Line
            ("Comparison report written to " & To_String (Opts.Output_Path));
      else
         Put_Line
            (Vexometer.Reports.Generate_Comparison_Report_String
               (Profiles => Profiles,
                Format   => Opts.Format));
      end if;
   end Run_Compare;

   procedure Run_Report (Opts : CLI_Options) is
      Input_Path : constant String :=
         (if not Opts.Positionals.Is_Empty
            then To_String (Opts.Positionals.First_Element)
          else "");
      Response_Text : Unbounded_String := Null_Unbounded_String;
      Model_Name    : constant String :=
         (if Length (Opts.Model) > 0 then To_String (Opts.Model)
          else "file-input");
      Analysis      : Response_Analysis;
      Output_Path   : Unbounded_String := Opts.Output_Path;
   begin
      if Input_Path'Length = 0 then
         Put_Line ("Missing input file. Usage: vexometer report FILE [options]");
         Set_Exit_Status (1);
         return;
      end if;

      if not Ada.Directories.Exists (Input_Path)
         or else Ada.Directories.Kind (Input_Path) /= Ada.Directories.Ordinary_File
      then
         Put_Line ("Input file not found: " & Input_Path);
         Set_Exit_Status (1);
         return;
      end if;

      Response_Text := To_Unbounded_String (Read_File (Input_Path));
      if Length (Response_Text) = 0 then
         Put_Line ("Input file is empty or unreadable: " & Input_Path);
         Set_Exit_Status (1);
         return;
      end if;

      Build_Analysis
         (Response_Text => To_String (Response_Text),
          Model_Name    => Model_Name,
          Patterns_Path => To_String (Opts.Patterns_Path),
          Analysis      => Analysis);

      if Length (Output_Path) = 0 then
         Output_Path := To_Unbounded_String
            (Input_Path & ".isa." & Format_Extension (Opts.Format));
      end if;

      Vexometer.Reports.Generate_Analysis_Report
         (Analysis => Analysis,
          Format   => Opts.Format,
          Path     => To_String (Output_Path));

      Put_Line ("Report written to " & To_String (Output_Path));
   end Run_Report;

begin
   if Argument_Count = 0 then
      Run_GUI;
      return;
   end if;

   declare
      Cmd : constant String := Argument (1);
   begin
      if Cmd = "-h" or else Cmd = "--help" then
         Print_Usage;

      elsif Cmd = "-v" or else Cmd = "--version" then
         Print_Version;

      elsif Cmd = "gui" then
         Run_GUI;

      elsif Cmd = "analyse" or else Cmd = "analyze" then
         declare
            Opts : CLI_Options;
         begin
            if Parse_Common_Options (Opts) then
               Run_Analyse (Opts);
            else
               Set_Exit_Status (1);
            end if;
         end;

      elsif Cmd = "probe" then
         declare
            Opts : CLI_Options;
         begin
            if Parse_Common_Options (Opts) then
               Run_Probe (Opts);
            else
               Set_Exit_Status (1);
            end if;
         end;

      elsif Cmd = "compare" then
         declare
            Opts : CLI_Options;
         begin
            if Parse_Common_Options (Opts) then
               Run_Compare (Opts);
            else
               Set_Exit_Status (1);
            end if;
         end;

      elsif Cmd = "report" then
         declare
            Opts : CLI_Options;
         begin
            if Parse_Common_Options (Opts) then
               Run_Report (Opts);
            else
               Set_Exit_Status (1);
            end if;
         end;

      else
         Put_Line ("Unknown command: " & Cmd);
         Print_Usage;
         Set_Exit_Status (1);
      end if;
   end;

exception
   when E : others =>
      Put_Line ("Error: " & Ada.Exceptions.Exception_Message (E));
      Set_Exit_Status (1);
end Vexometer.App;
