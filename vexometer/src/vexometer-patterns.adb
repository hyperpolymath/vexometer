--  Vexometer.Patterns - Pattern detection engine (body)
--
--  Implements regex-based and heuristic pattern detection for irritation
--  surface analysis. Built-in patterns cover sycophancy, identity leakage,
--  hedge phrases, unsolicited warnings, and lecturing. Heuristic analysers
--  detect structural issues (repetition, verbosity, competence mismatch)
--  that cannot be captured by simple regex matching alone.
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings;

package body Vexometer.Patterns is

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   function Word_Count (Text : String) return Natural is
      --  Count whitespace-delimited words in Text.
      Count    : Natural := 0;
      In_Word  : Boolean := False;
   begin
      for C of Text loop
         if C = ' ' or C = ASCII.HT or C = ASCII.LF or C = ASCII.CR then
            if In_Word then
               In_Word := False;
            end if;
         else
            if not In_Word then
               In_Word := True;
               Count := Count + 1;
            end if;
         end if;
      end loop;
      return Count;
   end Word_Count;

   function Sentence_Count (Text : String) return Natural is
      --  Count sentences by looking for period, exclamation, or question
      --  mark followed by a space or end of string.
      Count : Natural := 0;
   begin
      if Text'Length = 0 then
         return 0;
      end if;

      for I in Text'First .. Text'Last loop
         if Text (I) = '.' or Text (I) = '!' or Text (I) = '?' then
            if I = Text'Last then
               Count := Count + 1;
            elsif I < Text'Last
               and then (Text (I + 1) = ' ' or Text (I + 1) = ASCII.LF)
            then
               Count := Count + 1;
            end if;
         end if;
      end loop;

      --  If no sentence-ending punctuation found, treat the whole text
      --  as one sentence (provided it is non-empty).
      if Count = 0 and then Text'Length > 0 then
         Count := 1;
      end if;

      return Count;
   end Sentence_Count;

   function To_Lower (S : String) return String
      renames Ada.Characters.Handling.To_Lower;

   function Contains
      (Source  : String;
       Pattern : String) return Boolean
   is
      use Ada.Strings.Fixed;
   begin
      return Index (Source, Pattern) > 0;
   end Contains;

   function Read_File (Path : String) return String is
      use Ada.Text_IO;

      F       : File_Type;
      Content : Unbounded_String := Null_Unbounded_String;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Append (Content, Get_Line (F));
         Append (Content, ASCII.LF);
      end loop;
      Close (F);
      return To_String (Content);
   exception
      when others =>
         return "";
   end Read_File;

   function Find_Value_Start
      (Source   : String;
       Key      : String;
       From_Pos : Positive := 1) return Natural
   is
      use Ada.Strings.Fixed;

      Key_Token : constant String := """" & Key & """";
      Start_At  : constant Positive := Positive'Max (Source'First, From_Pos);
      Key_Pos   : constant Natural := Index (Source, Key_Token, Start_At);
      Pos       : Natural;
   begin
      if Source'Length = 0 then
         return 0;
      end if;

      if Key_Pos = 0 then
         return 0;
      end if;

      Pos := Index (Source, ":", Key_Pos + Key_Token'Length);
      if Pos = 0 then
         return 0;
      end if;

      Pos := Pos + 1;
      while Pos <= Source'Last loop
         exit when Source (Pos) /= ' '
            and then Source (Pos) /= ASCII.HT
            and then Source (Pos) /= ASCII.LF
            and then Source (Pos) /= ASCII.CR;
         Pos := Pos + 1;
      end loop;

      if Pos > Source'Last then
         return 0;
      end if;
      return Pos;
   end Find_Value_Start;

   function Extract_JSON_String
      (Source   : String;
       Key      : String;
       From_Pos : Positive := 1) return String
   is
      Start_Pos : constant Natural := Find_Value_Start (Source, Key, From_Pos);
      Pos       : Natural;
      Escaped   : Boolean := False;
      Result    : Unbounded_String := Null_Unbounded_String;
   begin
      if Start_Pos = 0 or else Source (Start_Pos) /= '"' then
         return "";
      end if;

      Pos := Start_Pos + 1;
      while Pos <= Source'Last loop
         declare
            C : constant Character := Source (Pos);
         begin
            if Escaped then
               case C is
                  when '"' | '\' | '/' =>
                     Append (Result, C);
                  when 'n' =>
                     Append (Result, ASCII.LF);
                  when 'r' =>
                     Append (Result, ASCII.CR);
                  when 't' =>
                     Append (Result, ASCII.HT);
                  when others =>
                     --  Preserve unknown escapes (e.g. regex "\s", "\b").
                     Append (Result, '\');
                     Append (Result, C);
               end case;
               Escaped := False;
            elsif C = '\' then
               Escaped := True;
            elsif C = '"' then
               return To_String (Result);
            else
               Append (Result, C);
            end if;
         end;
         Pos := Pos + 1;
      end loop;

      return To_String (Result);
   end Extract_JSON_String;

   function Extract_JSON_Number
      (Source   : String;
       Key      : String;
       From_Pos : Positive := 1) return String
   is
      Start_Pos : constant Natural := Find_Value_Start (Source, Key, From_Pos);
      Pos       : Natural;
      Result    : Unbounded_String := Null_Unbounded_String;
   begin
      if Start_Pos = 0 then
         return "";
      end if;

      Pos := Start_Pos;
      while Pos <= Source'Last loop
         declare
            C : constant Character := Source (Pos);
         begin
            exit when not (C in '0' .. '9'
               or else C = '-'
               or else C = '+'
               or else C = '.'
               or else C = 'e'
               or else C = 'E');
            Append (Result, C);
         end;
         Pos := Pos + 1;
      end loop;

      return Ada.Strings.Fixed.Trim (To_String (Result), Ada.Strings.Both);
   end Extract_JSON_Number;

   function Find_Matching_Closing
      (Source     : String;
       Open_Pos   : Positive;
       Open_Char  : Character;
       Close_Char : Character) return Natural
   is
      Depth     : Natural := 0;
      In_String : Boolean := False;
      Escaped   : Boolean := False;
   begin
      for I in Open_Pos .. Source'Last loop
         declare
            C : constant Character := Source (I);
         begin
            if In_String then
               if Escaped then
                  Escaped := False;
               elsif C = '\' then
                  Escaped := True;
               elsif C = '"' then
                  In_String := False;
               end if;
            else
               if C = '"' then
                  In_String := True;
               elsif C = Open_Char then
                  Depth := Depth + 1;
               elsif C = Close_Char then
                  if Depth = 0 then
                     return 0;
                  end if;
                  Depth := Depth - 1;
                  if Depth = 0 then
                     return I;
                  end if;
               end if;
            end if;
         end;
      end loop;

      return 0;
   end Find_Matching_Closing;

   function Normalize_Regex (Raw : String) return String is
      Result : Unbounded_String := Null_Unbounded_String;
      Pos    : Natural := Raw'First;
   begin
      while Pos <= Raw'Last loop
         if Pos + 3 <= Raw'Last and then Raw (Pos .. Pos + 3) = "(?i)" then
            Pos := Pos + 4;
         elsif Pos + 4 <= Raw'Last
            and then Raw (Pos .. Pos + 4) = "(?-i)"
         then
            Pos := Pos + 5;
         else
            Append (Result, Raw (Pos));
            Pos := Pos + 1;
         end if;
      end loop;

      return To_String (Result);
   end Normalize_Regex;

   function Clamp_Weight (Value : Float) return Float is
   begin
      return Float'Min (1.0, Float'Max (0.0, Value));
   end Clamp_Weight;

   function Parse_Weight (Raw : String; Default : Float) return Float is
   begin
      if Raw'Length = 0 then
         return Default;
      end if;
      return Clamp_Weight (Float'Value (Raw));
   exception
      when others =>
         return Default;
   end Parse_Weight;

   function To_Category
      (Raw     : String;
       Default : Metric_Category) return Metric_Category
   is
      Lower : constant String := To_Lower (Raw);
   begin
      if Contains (Lower, "temporal") then
         return Temporal_Intrusion;
      elsif Contains (Lower, "linguistic") then
         return Linguistic_Pathology;
      elsif Contains (Lower, "epistemic") then
         return Epistemic_Failure;
      elsif Contains (Lower, "paternalism") then
         return Paternalism;
      elsif Contains (Lower, "telemetry") then
         return Telemetry_Anxiety;
      elsif Contains (Lower, "coherence") then
         return Interaction_Coherence;
      elsif Contains (Lower, "completion") then
         return Completion_Integrity;
      elsif Contains (Lower, "strategic") then
         return Strategic_Rigidity;
      elsif Contains (Lower, "scope") then
         return Scope_Fidelity;
      elsif Contains (Lower, "recovery") then
         return Recovery_Competence;
      else
         return Default;
      end if;
   end To_Category;

   function To_Severity
      (Raw     : String;
       Default : Severity_Level) return Severity_Level
   is
      Lower : constant String := To_Lower (Raw);
   begin
      if Contains (Lower, "critical") then
         return Critical;
      elsif Contains (Lower, "high") then
         return High;
      elsif Contains (Lower, "medium") then
         return Medium;
      elsif Contains (Lower, "low") then
         return Low;
      elsif Contains (Lower, "none") then
         return None;
      else
         return Default;
      end if;
   end To_Severity;

   ---------------------------------------------------------------------------
   --  Make_Pattern
   --
   --  Construct a Pattern_Definition from components, compiling the regex.
   ---------------------------------------------------------------------------

   function Make_Pattern
      (ID          : String;
       Name        : String;
       Regex       : String;
       Category    : Metric_Category;
       Severity    : Severity_Level;
       Weight      : Float;
       Explanation : String;
      FP_Risk     : Float := 0.1) return Pattern_Definition
   is
      PD          : Pattern_Definition;
      Clean_Regex : constant String := Normalize_Regex (Regex);
   begin
      PD.ID          := To_Unbounded_String (ID);
      PD.Name        := To_Unbounded_String (Name);
      PD.Regex       := To_Unbounded_String (Clean_Regex);
      PD.Category    := Category;
      PD.Severity    := Severity;
      PD.Weight      := Weight;
      PD.Explanation := To_Unbounded_String (Explanation);
      PD.Examples    := Null_Unbounded_String;
      PD.False_Positive_Risk := FP_Risk;

      --  Compile the regex into the fixed-size pattern matcher.
      --  GNAT.Regpat.Compile overwrites the discriminated Compiled field.
      GNAT.Regpat.Compile (PD.Compiled, Clean_Regex,
         GNAT.Regpat.Case_Insensitive);

      return PD;
   end Make_Pattern;

   ---------------------------------------------------------------------------
   --  Register_Pattern
   --
   --  Internal helper: add a pattern to all three indices of the database.
   ---------------------------------------------------------------------------

   procedure Register_Pattern
      (DB      : in out Pattern_Database;
       Pattern : Pattern_Definition)
   is
      Key : constant String := To_String (Pattern.ID);
   begin
      DB.Patterns.Append (Pattern);
      DB.By_ID.Include (Key, Pattern);
      DB.By_Category (Pattern.Category).Append (Pattern);
   end Register_Pattern;

   ---------------------------------------------------------------------------
   --  Load_Sycophancy_Patterns
   ---------------------------------------------------------------------------

   procedure Load_Sycophancy_Patterns (DB : in out Pattern_Database) is
   begin
      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-great-q",
         Name        => "Great question",
         Regex       => "great question",
         Category    => Linguistic_Pathology,
         Severity    => Medium,
         Weight      => 0.6,
         Explanation => "Sycophantic opener that adds no value"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-excellent-q",
         Name        => "Excellent question",
         Regex       => "excellent question",
         Category    => Linguistic_Pathology,
         Severity    => Medium,
         Weight      => 0.6,
         Explanation => "Sycophantic opener that adds no value"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-thats-a-great",
         Name        => "That's a great question",
         Regex       => "that'?s a (great|excellent|wonderful) question",
         Category    => Linguistic_Pathology,
         Severity    => High,
         Weight      => 0.8,
         Explanation => "Full sycophantic opener preamble",
         FP_Risk     => 0.05));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-happy-to",
         Name        => "I'd be happy to",
         Regex       => "i'?d be happy to",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.4,
         Explanation => "Unnecessary preamble before actual content",
         FP_Risk     => 0.2));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-happy-help",
         Name        => "Happy to help",
         Regex       => "i'?m happy to help",
         Category    => Linguistic_Pathology,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Filler phrase adding no value"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-absolutely",
         Name        => "Absolutely!",
         Regex       => "absolutely[!.]",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Emphatic agreement often masking lack of substance",
         FP_Risk     => 0.25));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-hope-helps",
         Name        => "Hope this helps",
         Regex       => "i hope this helps",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Closing filler that wastes response tokens"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-let-me-know",
         Name        => "Let me know if",
         Regex       => "let me know if you (have|need)",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Closing filler offering unnecessary continued help"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-feel-free",
         Name        => "Feel free to",
         Regex       => "feel free to",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Patronising permission-granting language"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-dont-hesitate",
         Name        => "Don't hesitate to",
         Regex       => "don'?t hesitate to",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Patronising encouragement language"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "syc-happy-assist",
         Name        => "Happy to assist",
         Regex       => "happy to (help|assist|clarify)",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.4,
         Explanation => "Sycophantic service-role language"));
   end Load_Sycophancy_Patterns;

   ---------------------------------------------------------------------------
   --  Load_Identity_Patterns
   ---------------------------------------------------------------------------

   procedure Load_Identity_Patterns (DB : in out Pattern_Database) is
   begin
      Register_Pattern (DB, Make_Pattern (
         ID          => "id-as-an-ai",
         Name        => "As an AI",
         Regex       => "as an ai",
         Category    => Linguistic_Pathology,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Identity disclaimer rarely relevant to the query"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "id-language-model",
         Name        => "As a language model",
         Regex       => "as a (large )?language model",
         Category    => Linguistic_Pathology,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Technical identity disclaimer users don't need"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "id-im-an-ai",
         Name        => "I'm an AI",
         Regex       => "i'?m (just )?an ai",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.4,
         Explanation => "Self-deprecating identity statement"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "id-no-feelings",
         Name        => "I don't have feelings",
         Regex       => "i don'?t have (personal )?(opinions?|feelings?|emotions?)",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Unsolicited disclaimer about capabilities",
         FP_Risk     => 0.15));
   end Load_Identity_Patterns;

   ---------------------------------------------------------------------------
   --  Load_Hedge_Patterns
   ---------------------------------------------------------------------------

   procedure Load_Hedge_Patterns (DB : in out Pattern_Database) is
   begin
      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-important-note",
         Name        => "Important to note",
         Regex       => "it'?s important to note",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Hedge phrase adding unnecessary emphasis"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-worth-noting",
         Name        => "Worth noting",
         Regex       => "it'?s worth noting",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Hedge phrase padding the response"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-worth-mentioning",
         Name        => "Worth mentioning",
         Regex       => "it'?s worth mentioning",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Hedge phrase padding the response"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-please-note",
         Name        => "Please note",
         Regex       => "please (note|be aware|keep in mind)",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Hedge phrase that can sound patronising"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-however-important",
         Name        => "However important",
         Regex       => "however,? it'?s important",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.3,
         Explanation => "Double-hedge construction"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-that-said",
         Name        => "That said",
         Regex       => "that (being )?said",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.2,
         Explanation => "Common hedge transitional phrase",
         FP_Risk     => 0.3));

      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-having-said",
         Name        => "Having said that",
         Regex       => "having said that",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.2,
         Explanation => "Hedge transitional phrase"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "hedge-with-that-said",
         Name        => "With that said",
         Regex       => "with that (being )?said",
         Category    => Linguistic_Pathology,
         Severity    => Low,
         Weight      => 0.2,
         Explanation => "Extended hedge transitional phrase"));
   end Load_Hedge_Patterns;

   ---------------------------------------------------------------------------
   --  Load_Warning_Patterns
   ---------------------------------------------------------------------------

   procedure Load_Warning_Patterns (DB : in out Pattern_Database) is
   begin
      Register_Pattern (DB, Make_Pattern (
         ID          => "warn-caution",
         Name        => "I must caution",
         Regex       => "i (must|have to|need to) (caution|warn)",
         Category    => Paternalism,
         Severity    => High,
         Weight      => 0.7,
         Explanation => "Unsolicited warning preamble"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "warn-cannot-will-not",
         Name        => "Cannot and will not",
         Regex       => "i cannot and will not",
         Category    => Paternalism,
         Severity    => High,
         Weight      => 0.8,
         Explanation => "Aggressive refusal language",
         FP_Risk     => 0.05));

      Register_Pattern (DB, Make_Pattern (
         ID          => "warn-not-able",
         Name        => "I'm not able to",
         Regex       => "i'?m not able to",
         Category    => Paternalism,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Refusal framing that may be over-cautious",
         FP_Risk     => 0.2));

      Register_Pattern (DB, Make_Pattern (
         ID          => "warn-for-safety",
         Name        => "For your safety",
         Regex       => "for (your )?(safety|security)",
         Category    => Paternalism,
         Severity    => Medium,
         Weight      => 0.6,
         Explanation => "Paternalistic safety framing"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "warn-before-proceed",
         Name        => "Before we proceed",
         Regex       => "before (we|i) (proceed|continue)",
         Category    => Paternalism,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Gate-keeping before providing content"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "warn-safety-note",
         Name        => "Safety note",
         Regex       =>
            "important (safety|security) (note|warning|consideration)",
         Category    => Paternalism,
         Severity    => High,
         Weight      => 0.7,
         Explanation => "Unsolicited safety disclaimer"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "warn-ensure-understand",
         Name        => "Ensure you understand",
         Regex       =>
            "please (ensure|make sure|verify) (that )?(you )?"
            & "(understand|know)",
         Category    => Paternalism,
         Severity    => High,
         Weight      => 0.7,
         Explanation => "Patronising competence check",
         FP_Risk     => 0.1));
   end Load_Warning_Patterns;

   ---------------------------------------------------------------------------
   --  Load_Lecture_Patterns
   ---------------------------------------------------------------------------

   procedure Load_Lecture_Patterns (DB : in out Pattern_Database) is
   begin
      Register_Pattern (DB, Make_Pattern (
         ID          => "lec-let-me-explain",
         Name        => "Let me explain",
         Regex       => "let me explain",
         Category    => Paternalism,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Unsolicited explanation preamble"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "lec-allow-me",
         Name        => "Allow me to explain",
         Regex       => "allow me to explain",
         Category    => Paternalism,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Formal lecturing preamble"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "lec-to-understand",
         Name        => "To understand this",
         Regex       => "to (better )?understand this",
         Category    => Paternalism,
         Severity    => Low,
         Weight      => 0.4,
         Explanation => "Assumes user needs deeper understanding",
         FP_Risk     => 0.2));

      Register_Pattern (DB, Make_Pattern (
         ID          => "lec-first-understand",
         Name        => "First let's understand",
         Regex       => "first,? (let'?s|we need to) understand",
         Category    => Paternalism,
         Severity    => Medium,
         Weight      => 0.6,
         Explanation => "Redirects user to foundational knowledge"));

      Register_Pattern (DB, Make_Pattern (
         ID          => "lec-key-thing",
         Name        => "The key thing to understand",
         Regex       =>
            "the (key|important|fundamental) (thing|point|concept) "
            & "(to understand|here) is",
         Category    => Paternalism,
         Severity    => Medium,
         Weight      => 0.5,
         Explanation => "Lecturing preamble imposing structure",
         FP_Risk     => 0.15));
   end Load_Lecture_Patterns;

   ---------------------------------------------------------------------------
   --  Initialize
   --
   --  Load all built-in pattern sets into the database. This provides a
   --  fully functional pattern engine without requiring external files.
   ---------------------------------------------------------------------------

   procedure Initialize (DB : in out Pattern_Database) is
   begin
      if DB.Initialised then
         return;
      end if;

      --  Clear any stale data
      DB.Patterns.Clear;
      DB.By_ID.Clear;
      for Cat in Metric_Category loop
         DB.By_Category (Cat).Clear;
      end loop;

      --  Load all built-in pattern categories
      Load_Sycophancy_Patterns (DB);
      Load_Identity_Patterns (DB);
      Load_Hedge_Patterns (DB);
      Load_Warning_Patterns (DB);
      Load_Lecture_Patterns (DB);

      DB.Initialised := True;
   end Initialize;

   ---------------------------------------------------------------------------
   --  Load_From_File
   --
   --  Stub for loading patterns from a JSON file. Without GNATCOLL.JSON
   --  we simply ignore unknown files and fall back to built-in patterns.
   --  A future version will implement a lightweight JSON parser.
   ---------------------------------------------------------------------------

   procedure Load_From_File
      (DB   : in out Pattern_Database;
       Path : String)
   is
      use Ada.Strings.Fixed;
      use Ada.Directories;

      File_Category : Metric_Category := Linguistic_Pathology;
   begin
      if not DB.Initialised then
         Initialize (DB);
      end if;

      if not Exists (Path) or else Kind (Path) /= Ordinary_File then
         return;
      end if;

      declare
         Content     : constant String := Read_File (Path);
         Search_From : Natural;
         Id_Key_Pos  : Natural;
         Obj_Start   : Natural;
         Obj_End     : Natural;
      begin
         if Content'Length = 0 then
            return;
         end if;

         declare
            File_Category_Str : constant String :=
               Extract_JSON_String (Content, "category");
         begin
            if File_Category_Str'Length > 0 then
               File_Category := To_Category
                  (File_Category_Str, Linguistic_Pathology);
            end if;
         end;

         Search_From := Content'First;
         loop
            Id_Key_Pos := Index (Content, """id""", Search_From);
            exit when Id_Key_Pos = 0;

            Obj_Start := Id_Key_Pos;
            while Obj_Start > Content'First
               and then Content (Obj_Start) /= '{'
            loop
               Obj_Start := Obj_Start - 1;
            end loop;

            exit when Content (Obj_Start) /= '{';

            Obj_End := Find_Matching_Closing (Content, Obj_Start, '{', '}');
            exit when Obj_End = 0;

            declare
               Obj            : constant String := Content (Obj_Start .. Obj_End);
               Pattern_ID     : constant String := Extract_JSON_String (Obj, "id");
               Pattern_Name   : constant String := Extract_JSON_String (Obj, "name");
               Pattern_Regex  : constant String := Extract_JSON_String (Obj, "regex");
               Severity_Str   : constant String := Extract_JSON_String (Obj, "severity");
               Weight_Str     : constant String := Extract_JSON_Number (Obj, "weight");
               Explain_Str    : constant String := Extract_JSON_String
                  (Obj, "explanation");
               Category_Str   : constant String := Extract_JSON_String
                  (Obj, "category");
               Category_Value : Metric_Category := File_Category;
            begin
               if Category_Str'Length > 0 then
                  Category_Value := To_Category (Category_Str, File_Category);
               end if;

               if Pattern_ID'Length > 0
                  and then Pattern_Regex'Length > 0
                  and then not DB.By_ID.Contains (Pattern_ID)
               then
                  declare
                     Loaded : Pattern_Definition;
                  begin
                     Loaded := Make_Pattern (
                        ID          => Pattern_ID,
                        Name        =>
                           (if Pattern_Name'Length > 0 then Pattern_Name
                            else Pattern_ID),
                        Regex       => Pattern_Regex,
                        Category    => Category_Value,
                        Severity    => To_Severity (Severity_Str, Medium),
                        Weight      => Parse_Weight (Weight_Str, 0.5),
                        Explanation =>
                           (if Explain_Str'Length > 0 then Explain_Str
                            else "Loaded from " & Path)
                     );
                     Add_Pattern (DB, Loaded);
                  exception
                     when others =>
                        null;
                  end;
               end if;
            end;

            if Obj_End >= Content'Last then
               exit;
            end if;
            Search_From := Obj_End + 1;
         end loop;
      end;
   end Load_From_File;

   ---------------------------------------------------------------------------
   --  Load_From_Directory
   --
   --  Iterate all files in the given directory and attempt to load each
   --  as a pattern file. Currently delegates to Load_From_File which is
   --  a no-op for external files, but does ensure initialisation.
   ---------------------------------------------------------------------------

   procedure Load_From_Directory
      (DB   : in out Pattern_Database;
       Path : String)
   is
      use Ada.Directories;

      Search  : Search_Type;
      Dir_Ent : Directory_Entry_Type;
   begin
      if not DB.Initialised then
         Initialize (DB);
      end if;

      if not Exists (Path) or else Kind (Path) /= Directory then
         return;
      end if;

      Start_Search (Search, Path, "*.json",
         Filter => [Ordinary_File => True, others => False]);

      while More_Entries (Search) loop
         Get_Next_Entry (Search, Dir_Ent);
         Load_From_File (DB, Full_Name (Dir_Ent));
      end loop;

      End_Search (Search);
   end Load_From_Directory;

   ---------------------------------------------------------------------------
   --  Add_Pattern
   ---------------------------------------------------------------------------

   procedure Add_Pattern
      (DB      : in out Pattern_Database;
       Pattern : Pattern_Definition)
   is
   begin
      Register_Pattern (DB, Pattern);
   end Add_Pattern;

   ---------------------------------------------------------------------------
   --  Remove_Pattern
   ---------------------------------------------------------------------------

   procedure Remove_Pattern
      (DB : in out Pattern_Database;
       ID : String)
   is
      use Pattern_Vectors;
      Cursor : Pattern_Vectors.Cursor := DB.Patterns.First;
   begin
      --  Remove from the flat vector
      while Has_Element (Cursor) loop
         if To_String (Element (Cursor).ID) = ID then
            DB.Patterns.Delete (Cursor);
            exit;
         end if;
         Next (Cursor);
      end loop;

      --  Remove from category index
      for Cat in Metric_Category loop
         declare
            Cat_Cursor : Pattern_Vectors.Cursor :=
               DB.By_Category (Cat).First;
         begin
            while Has_Element (Cat_Cursor) loop
               if To_String (Element (Cat_Cursor).ID) = ID then
                  DB.By_Category (Cat).Delete (Cat_Cursor);
                  exit;
               end if;
               Next (Cat_Cursor);
            end loop;
         end;
      end loop;

      --  Remove from ID map
      if DB.By_ID.Contains (ID) then
         DB.By_ID.Delete (ID);
      end if;
   end Remove_Pattern;

   ---------------------------------------------------------------------------
   --  Get_Pattern
   ---------------------------------------------------------------------------

   function Get_Pattern
      (DB : Pattern_Database;
       ID : String) return Pattern_Definition
   is
   begin
      return DB.By_ID.Element (ID);
   end Get_Pattern;

   ---------------------------------------------------------------------------
   --  Pattern_Count
   ---------------------------------------------------------------------------

   function Pattern_Count (DB : Pattern_Database) return Natural is
   begin
      return Natural (DB.Patterns.Length);
   end Pattern_Count;

   ---------------------------------------------------------------------------
   --  Patterns_By_Category
   ---------------------------------------------------------------------------

   function Patterns_By_Category
      (DB       : Pattern_Database;
       Category : Metric_Category) return Pattern_Vectors.Vector
   is
   begin
      return DB.By_Category (Category);
   end Patterns_By_Category;

   ---------------------------------------------------------------------------
   --  Analyse_Text (procedure form)
   --
   --  Apply every loaded pattern against the input text using GNAT.Regpat.
   --  For each match, create a Finding record with location, matched text,
   --  and pattern metadata.
   ---------------------------------------------------------------------------

   procedure Analyse_Text
      (DB       : Pattern_Database;
       Text     : String;
       Config   : Analysis_Config;
       Findings : out Finding_Vector)
   is
      use GNAT.Regpat;

      Lower_Text : constant String := To_Lower (Text);
      Matches    : Match_Array (0 .. 0);
   begin
      Findings := Finding_Vectors.Empty_Vector;

      if Text'Length = 0 then
         return;
      end if;

      for PD of DB.Patterns loop
         --  Scan for all non-overlapping matches of this pattern.
         declare
            Search_Start : Natural := Lower_Text'First;
         begin
            loop
               Match (PD.Compiled, Lower_Text, Matches, Search_Start);

               exit when Matches (0) = No_Match;

               --  Compute confidence: base confidence is 1.0 minus the
               --  false-positive risk, weighted by the pattern weight.
               declare
                  Conf_Value : constant Float :=
                     Float'Min (1.0,
                        (1.0 - PD.False_Positive_Risk) * PD.Weight);
                  Match_First : constant Natural := Matches (0).First;
                  Match_Last  : constant Natural := Matches (0).Last;
               begin
                  --  Only report findings above the confidence threshold
                  if Conf_Value >= Config.Min_Confidence
                     or else PD.Severity >= High
                  then
                     Findings.Append (Finding'(
                        Category    => PD.Category,
                        Severity    => PD.Severity,
                        Location    => Match_First - Text'First,
                        Length      => Match_Last - Match_First + 1,
                        Pattern_ID  => PD.ID,
                        Matched     => To_Unbounded_String
                           (Text (Match_First .. Match_Last)),
                        Explanation => PD.Explanation,
                        Conf        =>
                           Confidence (Float'Min (1.0,
                              Float'Max (0.0, Conf_Value)))));
                  end if;

                  --  Advance past this match to find the next one
                  Search_Start := Match_Last + 1;

                  exit when Search_Start > Lower_Text'Last;
               end;
            end loop;
         end;
      end loop;
   end Analyse_Text;

   ---------------------------------------------------------------------------
   --  Analyse_Text (function form)
   ---------------------------------------------------------------------------

   function Analyse_Text
      (DB     : Pattern_Database;
       Text   : String;
       Config : Analysis_Config := Default_Config) return Finding_Vector
   is
      Result : Finding_Vector;
   begin
      Analyse_Text (DB, Text, Config, Result);
      return Result;
   end Analyse_Text;

   ---------------------------------------------------------------------------
   --  Analyse_Response
   --
   --  Full response analysis. Runs pattern matching on the response text,
   --  then applies heuristic analysers, and aggregates findings into
   --  category scores and an overall ISA rating.
   ---------------------------------------------------------------------------

   procedure Analyse_Response
      (DB       : Pattern_Database;
       Prompt   : String;
       Response : String;
       Config   : Analysis_Config;
       Analysis : out Response_Analysis)
   is
      Pattern_Findings   : Finding_Vector;
      Repetition_Findings : Finding_Vector;
      Verbosity_Findings  : Finding_Vector;
      Mismatch_Findings   : Finding_Vector;
   begin
      --  Initialise the analysis record
      Analysis.Prompt   := To_Unbounded_String (Prompt);
      Analysis.Response := To_Unbounded_String (Response);
      Analysis.Findings := Finding_Vectors.Empty_Vector;

      --  Phase 1: Regex pattern matching
      Analyse_Text (DB, Response, Config, Pattern_Findings);
      for F of Pattern_Findings loop
         Analysis.Findings.Append (F);
      end loop;

      --  Phase 2: Heuristic analysis
      Repetition_Findings := Detect_Repetition (Response);
      for F of Repetition_Findings loop
         Analysis.Findings.Append (F);
      end loop;

      Verbosity_Findings := Detect_Verbosity (Prompt, Response);
      for F of Verbosity_Findings loop
         Analysis.Findings.Append (F);
      end loop;

      Mismatch_Findings := Detect_Competence_Mismatch (Prompt, Response);
      for F of Mismatch_Findings loop
         Analysis.Findings.Append (F);
      end loop;

      --  Phase 3: Calculate aggregate scores
      Analysis.Category_Scores :=
         Calculate_Category_Scores (Analysis.Findings, Config);
      Analysis.Overall_ISA :=
         Calculate_ISA (Analysis.Findings, Config);
   end Analyse_Response;

   ---------------------------------------------------------------------------
   --  Detect_Repetition
   --
   --  Splits text into sentences and looks for exact or near-exact
   --  repetitions. Repeated sentences are a sign of lazy generation or
   --  stuck decoding loops.
   ---------------------------------------------------------------------------

   function Detect_Repetition
      (Text      : String;
       Threshold : Positive := 3) return Finding_Vector
   is
      pragma Unreferenced (Threshold);

      Result    : Finding_Vector := Finding_Vectors.Empty_Vector;
      Lower     : constant String := To_Lower (Text);

      --  Simple sentence extraction: split on ". " or ".\n"
      type Sentence_Range is record
         First : Positive;
         Last  : Natural;
      end record;

      Max_Sentences : constant := 500;
      Sentences     : array (1 .. Max_Sentences) of Sentence_Range;
      Sent_Count    : Natural := 0;

      Pos : Positive := Lower'First;
   begin
      if Lower'Length < 10 then
         return Result;
      end if;

      --  Extract sentence boundaries
      declare
         Start : Positive := Pos;
      begin
         while Pos <= Lower'Last and then Sent_Count < Max_Sentences loop
            if Lower (Pos) = '.'
               and then (Pos = Lower'Last
                  or else (Pos < Lower'Last
                     and then (Lower (Pos + 1) = ' '
                        or else Lower (Pos + 1) = ASCII.LF)))
            then
               if Pos - Start >= 5 then
                  Sent_Count := Sent_Count + 1;
                  Sentences (Sent_Count) :=
                     (First => Start, Last => Pos);
               end if;
               if Pos < Lower'Last then
                  Start := Pos + 2;
                  Pos := Pos + 2;
               else
                  exit;
               end if;
            else
               Pos := Pos + 1;
            end if;
         end loop;

         --  Capture trailing sentence without period
         if Start <= Lower'Last and then Lower'Last - Start >= 5
            and then Sent_Count < Max_Sentences
         then
            Sent_Count := Sent_Count + 1;
            Sentences (Sent_Count) :=
               (First => Start, Last => Lower'Last);
         end if;
      end;

      --  Compare all pairs for exact match (case-insensitive)
      for I in 1 .. Sent_Count loop
         for J in I + 1 .. Sent_Count loop
            declare
               S_I : constant String :=
                  Lower (Sentences (I).First .. Sentences (I).Last);
               S_J : constant String :=
                  Lower (Sentences (J).First .. Sentences (J).Last);
            begin
               if S_I'Length >= 10 and then S_I = S_J then
                  Result.Append (Finding'(
                     Category    => Linguistic_Pathology,
                     Severity    => Medium,
                     Location    => Sentences (J).First - Text'First,
                     Length      => S_J'Length,
                     Pattern_ID  =>
                        To_Unbounded_String ("heuristic-repetition"),
                     Matched     => To_Unbounded_String
                        (Text (Sentences (J).First ..
                           Sentences (J).Last)),
                     Explanation =>
                        To_Unbounded_String
                           ("Repeated sentence detected (exact match)"),
                     Conf        => 0.9));
               end if;
            end;
         end loop;
      end loop;

      return Result;
   end Detect_Repetition;

   ---------------------------------------------------------------------------
   --  Detect_Verbosity
   --
   --  Computes the ratio of response words to prompt words. If the ratio
   --  exceeds the given threshold, the response is flagged as excessively
   --  verbose. Also checks words-per-sentence to detect bloated prose.
   ---------------------------------------------------------------------------

   function Detect_Verbosity
      (Prompt   : String;
       Response : String;
       Ratio    : Float := 10.0) return Finding_Vector
   is
      Result         : Finding_Vector := Finding_Vectors.Empty_Vector;
      Prompt_Words   : constant Natural := Word_Count (Prompt);
      Response_Words : constant Natural := Word_Count (Response);
      Resp_Sentences : constant Natural := Sentence_Count (Response);
   begin
      --  Check overall verbosity ratio
      if Prompt_Words > 0 then
         declare
            Actual_Ratio : constant Float :=
               Float (Response_Words) / Float (Prompt_Words);
         begin
            if Actual_Ratio > Ratio then
               Result.Append (Finding'(
                  Category    => Paternalism,
                  Severity    => Medium,
                  Location    => 0,
                  Length      => 0,
                  Pattern_ID  =>
                     To_Unbounded_String ("heuristic-verbosity-ratio"),
                  Matched     => Null_Unbounded_String,
                  Explanation =>
                     To_Unbounded_String
                        ("Response is" & Natural'Image
                           (Natural (Actual_Ratio))
                         & "x longer than prompt (threshold:"
                         & Natural'Image (Natural (Ratio)) & "x)"),
                  Conf        => 0.7));
            end if;
         end;
      end if;

      --  Check words-per-sentence (flag if average exceeds 30)
      if Resp_Sentences > 0 then
         declare
            Avg_Words : constant Float :=
               Float (Response_Words) / Float (Resp_Sentences);
         begin
            if Avg_Words > 30.0 then
               Result.Append (Finding'(
                  Category    => Linguistic_Pathology,
                  Severity    => Low,
                  Location    => 0,
                  Length      => 0,
                  Pattern_ID  =>
                     To_Unbounded_String ("heuristic-sentence-length"),
                  Matched     => Null_Unbounded_String,
                  Explanation =>
                     To_Unbounded_String
                        ("Average sentence length is"
                         & Natural'Image (Natural (Avg_Words))
                         & " words (threshold: 30)"),
                  Conf        => 0.6));
            end if;
         end;
      end if;

      return Result;
   end Detect_Verbosity;

   ---------------------------------------------------------------------------
   --  Detect_Competence_Mismatch
   --
   --  Looks for confidence language ("certainly", "definitely", "absolutely")
   --  appearing near hedge language ("I think", "perhaps", "maybe") within
   --  the same response, which indicates incoherent epistemic signalling.
   --  Also checks for overly basic explanations in response to technical
   --  prompts.
   ---------------------------------------------------------------------------

   function Detect_Competence_Mismatch
      (Prompt   : String;
       Response : String) return Finding_Vector
   is
      Result    : Finding_Vector := Finding_Vectors.Empty_Vector;
      Lower_R   : constant String := To_Lower (Response);
      Lower_P   : constant String := To_Lower (Prompt);

      --  Confidence indicators
      Has_Certainly   : constant Boolean := Contains (Lower_R, "certainly");
      Has_Definitely  : constant Boolean := Contains (Lower_R, "definitely");
      Has_Absolutely  : constant Boolean := Contains (Lower_R, "absolutely");
      Has_Confident   : constant Boolean :=
         Has_Certainly or Has_Definitely or Has_Absolutely;

      --  Hedge indicators
      Has_I_Think     : constant Boolean := Contains (Lower_R, "i think");
      Has_Perhaps     : constant Boolean := Contains (Lower_R, "perhaps");
      Has_Maybe       : constant Boolean := Contains (Lower_R, "maybe");
      Has_Not_Sure    : constant Boolean :=
         Contains (Lower_R, "i'm not sure")
         or Contains (Lower_R, "im not sure");
      Has_Hedge       : constant Boolean :=
         Has_I_Think or Has_Perhaps or Has_Maybe or Has_Not_Sure;

      --  Technical prompt indicators
      Has_Technical   : constant Boolean :=
         Contains (Lower_P, "function")
         or Contains (Lower_P, "algorithm")
         or Contains (Lower_P, "api")
         or Contains (Lower_P, "syntax")
         or Contains (Lower_P, "implement")
         or Contains (Lower_P, "compile")
         or Contains (Lower_P, "runtime");
   begin
      --  Flag simultaneous confidence and hedging
      if Has_Confident and Has_Hedge then
         Result.Append (Finding'(
            Category    => Epistemic_Failure,
            Severity    => Medium,
            Location    => 0,
            Length      => 0,
            Pattern_ID  =>
               To_Unbounded_String ("heuristic-confidence-hedge"),
            Matched     => Null_Unbounded_String,
            Explanation =>
               To_Unbounded_String
                  ("Response contains both confident and uncertain "
                   & "language, indicating incoherent epistemic "
                   & "signalling"),
            Conf        => 0.7));
      end if;

      --  Flag basic explanations for technical queries
      if Has_Technical then
         declare
            Has_Basic_Explain : constant Boolean :=
               Contains (Lower_R, "in simple terms")
               or Contains (Lower_R, "simply put")
               or Contains (Lower_R, "to put it simply")
               or Contains (Lower_R, "in layman")
               or Contains (Lower_R, "for beginners");
         begin
            if Has_Basic_Explain then
               Result.Append (Finding'(
                  Category    => Paternalism,
                  Severity    => Medium,
                  Location    => 0,
                  Length      => 0,
                  Pattern_ID  =>
                     To_Unbounded_String ("heuristic-competence-down"),
                  Matched     => Null_Unbounded_String,
                  Explanation =>
                     To_Unbounded_String
                        ("Technical prompt received a dumbed-down "
                         & "explanation, suggesting incorrect "
                         & "competence modelling"),
                  Conf        => 0.65));
            end if;
         end;
      end if;

      return Result;
   end Detect_Competence_Mismatch;

   ---------------------------------------------------------------------------
   --  Estimate_Sycophancy_Density
   --
   --  Returns the number of sycophantic pattern matches per 100 words.
   --  Uses substring matching on the built-in sycophancy indicator phrases
   --  for speed (avoids regex compilation per call).
   ---------------------------------------------------------------------------

   function Estimate_Sycophancy_Density
      (Text : String) return Float
   is
      Lower : constant String := To_Lower (Text);
      Words : constant Natural := Word_Count (Text);
      Count : Natural := 0;

      --  Fast substring checks for common sycophantic phrases
      Indicators : constant array (Positive range <>) of
         access constant String := (
         new String'("great question"),
         new String'("excellent question"),
         new String'("wonderful question"),
         new String'("happy to help"),
         new String'("happy to assist"),
         new String'("i'd be happy to"),
         new String'("i hope this helps"),
         new String'("feel free to"),
         new String'("don't hesitate"),
         new String'("let me know if"),
         new String'("absolutely!"),
         new String'("absolutely.")
      );
   begin
      if Words = 0 then
         return 0.0;
      end if;

      for Ind of Indicators loop
         if Contains (Lower, Ind.all) then
            Count := Count + 1;
         end if;
      end loop;

      return (Float (Count) / Float (Words)) * 100.0;
   end Estimate_Sycophancy_Density;

   ---------------------------------------------------------------------------
   --  Estimate_Hedge_Ratio
   --
   --  Returns the number of hedge phrases per 100 words.
   ---------------------------------------------------------------------------

   function Estimate_Hedge_Ratio
      (Text : String) return Float
   is
      Lower : constant String := To_Lower (Text);
      Words : constant Natural := Word_Count (Text);
      Count : Natural := 0;

      Indicators : constant array (Positive range <>) of
         access constant String := (
         new String'("it's important to note"),
         new String'("its important to note"),
         new String'("it's worth noting"),
         new String'("its worth noting"),
         new String'("it's worth mentioning"),
         new String'("its worth mentioning"),
         new String'("please note"),
         new String'("please be aware"),
         new String'("keep in mind"),
         new String'("that being said"),
         new String'("that said"),
         new String'("having said that"),
         new String'("with that said"),
         new String'("however, it's important"),
         new String'("i think"),
         new String'("perhaps"),
         new String'("maybe")
      );
   begin
      if Words = 0 then
         return 0.0;
      end if;

      for Ind of Indicators loop
         if Contains (Lower, Ind.all) then
            Count := Count + 1;
         end if;
      end loop;

      return (Float (Count) / Float (Words)) * 100.0;
   end Estimate_Hedge_Ratio;

end Vexometer.Patterns;
