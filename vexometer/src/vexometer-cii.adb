--  Vexometer.CII - Completion Integrity Index (Body)
--
--  Detects incomplete outputs: TODO, placeholders, ellipses, unimplemented
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Characters.Handling; use Ada.Characters.Handling;

package body Vexometer.CII is

   ---------------------------------------------------------------------------
   --  Internal Constants: Built-in Pattern Database
   ---------------------------------------------------------------------------

   --  Maximum number of custom patterns that can be registered
   Max_Custom_Patterns : constant := 128;

   --  Internal storage for the pattern database
   type Pattern_Array is array (Positive range <>) of Pattern_Entry;

   --  Marker strings for each incompleteness kind.  We use heap-allocated
   --  strings so they can be referenced via access values in Detection
   --  records.

   --  Todo_Comment markers
   S_TODO  : aliased String := "TODO";
   S_FIXME : aliased String := "FIXME";
   S_XXX   : aliased String := "XXX";
   S_HACK  : aliased String := "HACK";
   S_TBD   : aliased String := "[TBD]";

   --  Placeholder_Text markers
   S_Ellipsis_Dot  : aliased String := "...";
   S_Etc           : aliased String := "etc.";
   S_And_So_On     : aliased String := "and so on";
   S_Similar_Above : aliased String := "similar to above";
   S_Lorem         : aliased String := "lorem ipsum";

   --  Unimplemented_Code markers
   S_Unimplemented_RS : aliased String := "unimplemented!()";
   S_Unimplemented_RU : aliased String := "todo!()";
   S_Raise_Not_Impl   : aliased String := "raise NotImplementedError";
   S_Panic_Not_Impl   : aliased String := "panic!(""not implemented"")";
   S_Assert_False     : aliased String := "assert False";

   --  Truncation_Marker markers
   S_Rest_Similar    : aliased String := "rest similar";
   S_Continue_Pat    : aliased String := "continue the pattern";
   S_Repeat_Others   : aliased String := "repeat for others";
   S_And_So_On_Dots  : aliased String := "...and so on";
   S_Impl_Remaining  : aliased String := "implement remaining";

   --  Null_Implementation markers
   S_Arrow_Braces : aliased String := "() => {}";
   S_Def_Pass     : aliased String := "pass";
   S_Fn_Empty     : aliased String := "fn foo() {}";

   --  Ellipsis_Code markers -- unicode ellipsis
   S_Unicode_Ellipsis : aliased String := (1 => Character'Val (16#E2#),
                                           2 => Character'Val (16#80#),
                                           3 => Character'Val (16#A6#));

   --  Stub_Return markers
   S_Return_None : aliased String := "return None";
   S_Return_Null : aliased String := "return null";
   S_Return_Zero : aliased String := "return 0";

   ---------------------------------------------------------------------------
   --  Built-in Patterns
   ---------------------------------------------------------------------------

   S_All_Lang : aliased String := "*";
   S_Python   : aliased String := "python";
   S_Rust     : aliased String := "rust";
   S_JS       : aliased String := "javascript";

   Builtin_Patterns : constant Pattern_Array (1 .. 22) := [
      --  Todo_Comment (case-insensitive)
      (Pattern => S_TODO'Access,  Kind => Todo_Comment,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_FIXME'Access, Kind => Todo_Comment,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_XXX'Access,   Kind => Todo_Comment,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_HACK'Access,  Kind => Todo_Comment,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_TBD'Access,   Kind => Todo_Comment,
       Languages => S_All_Lang'Access, Case_Sensitive => False),

      --  Placeholder_Text (case-insensitive)
      (Pattern => S_Ellipsis_Dot'Access,  Kind => Placeholder_Text,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_Etc'Access,           Kind => Placeholder_Text,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_And_So_On'Access,     Kind => Placeholder_Text,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_Similar_Above'Access, Kind => Placeholder_Text,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_Lorem'Access,         Kind => Placeholder_Text,
       Languages => S_All_Lang'Access, Case_Sensitive => False),

      --  Unimplemented_Code (case-sensitive)
      (Pattern => S_Unimplemented_RS'Access, Kind => Unimplemented_Code,
       Languages => S_Rust'Access, Case_Sensitive => True),
      (Pattern => S_Unimplemented_RU'Access, Kind => Unimplemented_Code,
       Languages => S_Rust'Access, Case_Sensitive => True),
      (Pattern => S_Raise_Not_Impl'Access,   Kind => Unimplemented_Code,
       Languages => S_Python'Access, Case_Sensitive => True),
      (Pattern => S_Panic_Not_Impl'Access,   Kind => Unimplemented_Code,
       Languages => S_Rust'Access, Case_Sensitive => True),
      (Pattern => S_Assert_False'Access,     Kind => Unimplemented_Code,
       Languages => S_Python'Access, Case_Sensitive => True),

      --  Truncation_Marker (case-insensitive)
      (Pattern => S_Rest_Similar'Access,    Kind => Truncation_Marker,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_Continue_Pat'Access,    Kind => Truncation_Marker,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_Repeat_Others'Access,   Kind => Truncation_Marker,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_And_So_On_Dots'Access,  Kind => Truncation_Marker,
       Languages => S_All_Lang'Access, Case_Sensitive => False),
      (Pattern => S_Impl_Remaining'Access,  Kind => Truncation_Marker,
       Languages => S_All_Lang'Access, Case_Sensitive => False),

      --  Stub_Return (case-sensitive)
      (Pattern => S_Return_None'Access, Kind => Stub_Return,
       Languages => S_Python'Access, Case_Sensitive => True),
      (Pattern => S_Return_Null'Access, Kind => Stub_Return,
       Languages => S_JS'Access, Case_Sensitive => True)
   ];

   ---------------------------------------------------------------------------
   --  Custom Pattern Storage
   ---------------------------------------------------------------------------

   Custom_Patterns : array (1 .. Max_Custom_Patterns) of Pattern_Entry;
   Custom_Count    : Natural := 0;

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   --  Severity_To_Score converts a Severity_Level into a normalised Score.
   function Severity_To_Score (Sev : Severity_Level) return Score is
   begin
      return (case Sev is
         when None     => 0.0,
         when Low      => 0.25,
         when Medium   => 0.5,
         when High     => 0.75,
         when Critical => 1.0);
   end Severity_To_Score;

   --  Case_Insensitive_Index searches for Pattern within Source ignoring
   --  case.  Returns the index of the first match, or 0 if not found.
   --  The From parameter controls the starting search position.
   function Case_Insensitive_Index
      (Source  : String;
       Pattern : String;
       From    : Positive := 1) return Natural
   is
      Upper_Source  : constant String := To_Upper (Source);
      Upper_Pattern : constant String := To_Upper (Pattern);
   begin
      if From > Source'Last then
         return 0;
      end if;
      return Index (Upper_Source, Upper_Pattern, From);
   end Case_Insensitive_Index;

   --  Check_Language returns True if the pattern's language filter matches
   --  the given language (or the pattern applies to all languages).
   function Check_Language
      (Pat_Languages : String;
       Language      : String) return Boolean
   is
   begin
      if Pat_Languages = "*" then
         return True;
      end if;
      --  Simple comma-separated check
      return Index (To_Lower (Pat_Languages),
                    To_Lower (Language)) > 0;
   end Check_Language;

   --  Scan_For_Pattern searches Content for occurrences of a single pattern
   --  and appends all detections to Result.
   procedure Scan_For_Pattern
      (Content  : String;
       Pat      : Pattern_Entry;
       Language : String;
       Result   : in out Detection_Array)
   is
      Pos      : Natural;
      Search_From : Positive := Content'First;
   begin
      --  Skip if language filter does not match
      if Language'Length > 0
         and then not Check_Language (Pat.Languages.all, Language)
      then
         return;
      end if;

      loop
         if Pat.Case_Sensitive then
            if Search_From > Content'Last then
               exit;
            end if;
            Pos := Index (Content, Pat.Pattern.all, Search_From);
         else
            Pos := Case_Insensitive_Index
                     (Content, Pat.Pattern.all, Search_From);
         end if;

         exit when Pos = 0;

         declare
            Det : Detection;
         begin
            Det.Kind     := Pat.Kind;
            Det.Location := Pos;
            Det.Length   := Pat.Pattern'Length;
            Det.Matched  :=
               new String'(Content (Pos .. Pos + Pat.Pattern'Length - 1));
            Det.Sev      := Severity_To_Score (Kind_Severity (Pat.Kind));
            Result.Append (Det);
         end;

         --  Advance past this match to find further occurrences
         Search_From := Pos + Pat.Pattern'Length;
         exit when Search_From > Content'Last;
      end loop;
   end Scan_For_Pattern;

   ---------------------------------------------------------------------------
   --  Analyse
   ---------------------------------------------------------------------------

   function Analyse (Content : String) return Detection_Array is
   begin
      return Analyse_With_Language (Content, "*");
   end Analyse;

   ---------------------------------------------------------------------------
   --  Analyse_With_Language
   ---------------------------------------------------------------------------

   function Analyse_With_Language
      (Content  : String;
       Language : String) return Detection_Array
   is
      Result : Detection_Array;
   begin
      --  Scan built-in patterns
      for Pat of Builtin_Patterns loop
         Scan_For_Pattern (Content, Pat, Language, Result);
      end loop;

      --  Scan custom patterns
      for I in 1 .. Custom_Count loop
         Scan_For_Pattern (Content, Custom_Patterns (I), Language, Result);
      end loop;

      return Result;
   end Analyse_With_Language;

   ---------------------------------------------------------------------------
   --  Calculate
   ---------------------------------------------------------------------------

   function Calculate
      (Detections     : Detection_Array;
       Content_Length : Positive) return Metric_Result
   is
      use Detection_Vectors;
      Total_Severity : Float := 0.0;
      Count          : constant Natural := Natural (Length (Detections));
      Raw_Score      : Float;
      Clamped        : Score;
   begin
      if Count = 0 then
         return (Category    => Completion_Integrity,
                 Value       => 0.0,
                 Conf        => 0.95,
                 Sample_Size => Content_Length);
      end if;

      --  Accumulate weighted severities.  Each detection contributes its
      --  individual severity score.
      for Det of Detections loop
         Total_Severity := Total_Severity + Float (Det.Sev);
      end loop;

      --  Normalise: divide by content length (in kilobytes) to avoid
      --  penalising longer content unfairly, then clamp to 0..1.
      Raw_Score := Total_Severity /
                   Float'Max (1.0, Float (Content_Length) / 1000.0);

      --  Clamp the result into Score range
      if Raw_Score >= 1.0 then
         Clamped := 1.0;
      elsif Raw_Score <= 0.0 then
         Clamped := 0.0;
      else
         Clamped := Score (Raw_Score);
      end if;

      --  Confidence is higher with more content to analyse
      declare
         Conf_Raw : Float :=
            Float'Min (1.0,
                       0.5 + Float (Content_Length) / 10_000.0);
      begin
         return (Category    => Completion_Integrity,
                 Value       => Clamped,
                 Conf        => Confidence (Conf_Raw),
                 Sample_Size => Content_Length);
      end;
   end Calculate;

   ---------------------------------------------------------------------------
   --  Is_Complete
   ---------------------------------------------------------------------------

   function Is_Complete (Content : String) return Boolean is
      Detections : constant Detection_Array := Analyse (Content);
   begin
      return Detection_Vectors.Is_Empty (Detections);
   end Is_Complete;

   ---------------------------------------------------------------------------
   --  Is_Complete_For_Language
   ---------------------------------------------------------------------------

   function Is_Complete_For_Language
      (Content  : String;
       Language : String) return Boolean
   is
      Detections : constant Detection_Array :=
         Analyse_With_Language (Content, Language);
   begin
      return Detection_Vectors.Is_Empty (Detections);
   end Is_Complete_For_Language;

   ---------------------------------------------------------------------------
   --  Get_Patterns
   ---------------------------------------------------------------------------

   --  Return a pointer to the first built-in pattern.  Callers can iterate
   --  the 22 built-in entries by pointer arithmetic or by calling
   --  Analyse directly.
   First_Builtin : aliased Pattern_Entry := Builtin_Patterns (1);

   function Get_Patterns return access constant Pattern_Entry is
   begin
      return First_Builtin'Access;
   end Get_Patterns;

   ---------------------------------------------------------------------------
   --  Register_Custom_Pattern
   ---------------------------------------------------------------------------

   procedure Register_Custom_Pattern (Custom_Pattern : Pattern_Entry) is
   begin
      if Custom_Count < Max_Custom_Patterns then
         Custom_Count := Custom_Count + 1;
         Custom_Patterns (Custom_Count) := Custom_Pattern;
      end if;
   end Register_Custom_Pattern;

end Vexometer.CII;
