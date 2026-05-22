--  Vexometer.Patterns - Pattern detection engine
--
--  Detects irritation patterns in model responses using regular expressions
--  and heuristic analysis.
--
--  Copyright (C) 2024 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Vexometer.Core;         use Vexometer.Core;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with GNAT.Regpat;

package Vexometer.Patterns is

   ---------------------------------------------------------------------------
   --  Pattern Definition
   --
   --  A single irritation pattern to detect
   ---------------------------------------------------------------------------

   Max_Pattern_Size : constant := 2048;

   type Pattern_Definition is record
      ID           : Unbounded_String;   --  Unique identifier
      Name         : Unbounded_String;   --  Human-readable name
      Regex        : Unbounded_String;   --  Regular expression
      Compiled     : GNAT.Regpat.Pattern_Matcher (Max_Pattern_Size);
      Category     : Metric_Category;
      Severity     : Severity_Level;
      Weight       : Float range 0.0 .. 1.0;
      Explanation  : Unbounded_String;   --  Why this is an irritant
      Examples     : Unbounded_String;   --  Example matches
      False_Positive_Risk : Float range 0.0 .. 1.0 := 0.1;
   end record;

   package Pattern_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Pattern_Definition);

   package Pattern_Maps is new Ada.Containers.Indefinite_Hashed_Maps
      (Key_Type        => String,
       Element_Type    => Pattern_Definition,
       Hash            => Ada.Strings.Hash,
       Equivalent_Keys => "=");

   ---------------------------------------------------------------------------
   --  Built-in Pattern Sets
   --
   --  Common irritation patterns organised by category
   ---------------------------------------------------------------------------

   --  Linguistic Pathology (LPS) patterns
   Sycophancy_Patterns : constant array (Positive range <>) of
      access constant String := (
      new String'("(?i)\bgreat question\b"),
      new String'("(?i)\bexcellent question\b"),
      new String'("(?i)\bthat'?s a (great|excellent|wonderful) question\b"),
      new String'("(?i)\bi'?d be happy to\b"),
      new String'("(?i)\bi'?m happy to help\b"),
      new String'("(?i)\babsolutely[!.]"),
      new String'("(?i)\bi hope this helps\b"),
      new String'("(?i)\blet me know if you (have|need)\b"),
      new String'("(?i)\bfeel free to\b"),
      new String'("(?i)\bdon'?t hesitate to\b"),
      new String'("(?i)\bhappy to (help|assist|clarify)\b")
   );

   Identity_Patterns : constant array (Positive range <>) of
      access constant String := (
      new String'("(?i)\bas an ai\b"),
      new String'("(?i)\bas a (large )?language model\b"),
      new String'("(?i)\bi'?m (just )?an ai\b"),
      new String'("(?i)\bi don'?t have (personal )?(opinions?|feelings?|emotions?)\b")
   );

   Hedge_Patterns : constant array (Positive range <>) of
      access constant String := (
      new String'("(?i)\bit'?s important to note\b"),
      new String'("(?i)\bit'?s worth noting\b"),
      new String'("(?i)\bit'?s worth mentioning\b"),
      new String'("(?i)\bplease (note|be aware|keep in mind)\b"),
      new String'("(?i)\bhowever,? it'?s important\b"),
      new String'("(?i)\bthat (being )?said\b"),
      new String'("(?i)\bhaving said that\b"),
      new String'("(?i)\bwith that (being )?said\b")
   );

   --  Paternalism (PQ) patterns
   Warning_Patterns : constant array (Positive range <>) of
      access constant String := (
      new String'("(?i)\bi (must|have to|need to) (caution|warn)\b"),
      new String'("(?i)\bi cannot and will not\b"),
      new String'("(?i)\bi'?m not able to\b"),
      new String'("(?i)\bfor (your )?(safety|security)\b"),
      new String'("(?i)\bbefore (we|i) (proceed|continue)\b"),
      new String'("(?i)\bimportant (safety|security) (note|warning|consideration)\b"),
      new String'("(?i)\bplease (ensure|make sure|verify) (that )?(you )?(understand|know)\b")
   );

   Lecture_Patterns : constant array (Positive range <>) of
      access constant String := (
      new String'("(?i)\blet me explain\b"),
      new String'("(?i)\ballow me to explain\b"),
      new String'("(?i)\bto (better )?understand this\b"),
      new String'("(?i)\bfirst,? (let'?s|we need to) understand\b"),
      new String'("(?i)\bthe (key|important|fundamental) (thing|point|concept) (to understand|here) is\b")
   );

   ---------------------------------------------------------------------------
   --  Pattern Database
   ---------------------------------------------------------------------------

   type Pattern_Database is tagged private;

   procedure Initialize (DB : in out Pattern_Database);
   --  Load built-in patterns

   procedure Load_From_File
      (DB   : in out Pattern_Database;
       Path : String);
   --  Load additional patterns from JSON/TOML file

   procedure Load_From_Directory
      (DB   : in out Pattern_Database;
       Path : String);
   --  Load all pattern files from directory

   procedure Add_Pattern
      (DB      : in out Pattern_Database;
       Pattern : Pattern_Definition);

   procedure Remove_Pattern
      (DB : in out Pattern_Database;
       ID : String);

   function Get_Pattern
      (DB : Pattern_Database;
       ID : String) return Pattern_Definition;

   function Pattern_Count (DB : Pattern_Database) return Natural;

   function Patterns_By_Category
      (DB       : Pattern_Database;
       Category : Metric_Category) return Pattern_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Analysis
   ---------------------------------------------------------------------------

   procedure Analyse_Text
      (DB       : Pattern_Database;
       Text     : String;
       Config   : Analysis_Config;
       Findings : out Finding_Vector);
   --  Find all pattern matches in text

   function Analyse_Text
      (DB     : Pattern_Database;
       Text   : String;
       Config : Analysis_Config := Default_Config) return Finding_Vector;
   --  Functional version

   procedure Analyse_Response
      (DB       : Pattern_Database;
       Prompt   : String;
       Response : String;
       Config   : Analysis_Config;
       Analysis : out Response_Analysis);
   --  Full response analysis including context-aware detection

   ---------------------------------------------------------------------------
   --  Heuristic Analysers
   --
   --  Beyond regex: structural and semantic analysis
   ---------------------------------------------------------------------------

   function Detect_Repetition
      (Text      : String;
       Threshold : Positive := 3) return Finding_Vector;
   --  Detect repeated phrases (e.g., same warning multiple times)

   function Detect_Verbosity
      (Prompt   : String;
       Response : String;
       Ratio    : Float := 10.0) return Finding_Vector;
   --  Detect excessive verbosity relative to prompt

   function Detect_Competence_Mismatch
      (Prompt   : String;
       Response : String) return Finding_Vector;
   --  Detect when response assumes lower competence than prompt suggests

   function Estimate_Sycophancy_Density
      (Text : String) return Float;
   --  Return sycophancy patterns per 100 words

   function Estimate_Hedge_Ratio
      (Text : String) return Float;
   --  Return hedge phrases per 100 words

private

   type Category_Pattern_Vector_Array is
      array (Metric_Category) of Pattern_Vectors.Vector;

   type Pattern_Database is tagged record
      Patterns     : Pattern_Vectors.Vector;
      By_ID        : Pattern_Maps.Map;
      By_Category  : Category_Pattern_Vector_Array;
      Initialised  : Boolean := False;
   end record;

end Vexometer.Patterns;
