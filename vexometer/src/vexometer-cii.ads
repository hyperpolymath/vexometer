--  Vexometer.CII - Completion Integrity Index
--
--  Detects incomplete outputs: TODO, placeholders, ellipses, unimplemented
--
--  Copyright (C) 2025 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Vexometer.Core; use Vexometer.Core;
with Ada.Containers.Vectors;

package Vexometer.CII is

   ---------------------------------------------------------------------------
   --  Incompleteness Kinds
   ---------------------------------------------------------------------------

   type Incompleteness_Kind is (
      Todo_Comment,
      --  TODO, FIXME, XXX, HACK, NOTE (incomplete work markers)

      Placeholder_Text,
      --  "...", "etc.", "and so on", "similar to above"

      Unimplemented_Code,
      --  unimplemented!(), pass, raise NotImplementedError, todo!()
      --  panic!("not implemented"), assert False

      Truncation_Marker,
      --  "// rest similar", "continue the pattern", "repeat for others"
      --  "...and so on", "implement remaining"

      Null_Implementation,
      --  Empty function bodies, pass-only functions, stub returns
      --  () => {}, def foo(): pass, fn foo() {}

      Ellipsis_Code,
      --  Literal "..." or "…" in code blocks indicating omission

      Stub_Return
      --  return None, return null, return 0 without real logic
   );

   function Kind_Severity (Kind : Incompleteness_Kind) return Severity_Level is
      (case Kind is
         when Todo_Comment       => Medium,
         when Placeholder_Text   => High,
         when Unimplemented_Code => Critical,
         when Truncation_Marker  => Critical,
         when Null_Implementation => High,
         when Ellipsis_Code      => Critical,
         when Stub_Return        => Medium);

   ---------------------------------------------------------------------------
   --  Detection Record
   ---------------------------------------------------------------------------

   type Detection is record
      Kind     : Incompleteness_Kind;
      Location : Positive;  --  Character offset
      Length   : Natural;   --  Length of matched text
      Matched  : access String;  --  The actual text matched
      Sev      : Score;     --  How bad is this instance (0-1)
   end record;

   package Detection_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Detection);

   subtype Detection_Array is Detection_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Analysis Functions
   ---------------------------------------------------------------------------

   function Analyse (Content : String) return Detection_Array;
   --  Scan content for incompleteness markers
   --  Returns all detected instances with locations

   function Analyse_With_Language
      (Content  : String;
       Language : String) return Detection_Array;
   --  Language-aware analysis (e.g., knows Python uses "pass")

   function Calculate
      (Detections     : Detection_Array;
       Content_Length : Positive) return Metric_Result;
   --  Calculate CII score from detections
   --  Score is normalised by content length

   function Is_Complete (Content : String) return Boolean;
   --  Quick check: does content have any incompleteness markers?

   function Is_Complete_For_Language
      (Content  : String;
       Language : String) return Boolean;
   --  Language-aware completeness check

   ---------------------------------------------------------------------------
   --  Pattern Database
   ---------------------------------------------------------------------------

   type Pattern_Entry is record
      Pattern     : access String;
      Kind        : Incompleteness_Kind;
      Languages   : access String;  --  Comma-separated, or "*" for all
      Case_Sensitive : Boolean;
   end record;

   function Get_Patterns return access constant Pattern_Entry;
   --  Get the built-in pattern database

   procedure Register_Custom_Pattern (Custom_Pattern : Pattern_Entry);
   --  Add a custom pattern to the database

end Vexometer.CII;
