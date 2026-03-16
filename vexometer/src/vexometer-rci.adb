--  Vexometer.RCI - Recovery Competence Index (Body)
--
--  Measures quality of error recovery and strategy variation
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Characters.Handling; use Ada.Characters.Handling;

package body Vexometer.RCI is

   ---------------------------------------------------------------------------
   --  Internal Constants
   ---------------------------------------------------------------------------

   --  Phrases indicating root-cause analysis
   S_Issue_Was    : aliased String := "the issue was";
   S_Problem_Was  : aliased String := "the problem was";
   S_Because      : aliased String := "because";
   S_Root_Cause   : aliased String := "root cause";
   S_Caused_By    : aliased String := "caused by";
   S_Due_To       : aliased String := "due to";
   S_Reason_Is    : aliased String := "the reason is";

   --  Phrases indicating escalation / asking for help
   S_Clarification : aliased String := "need clarification";
   S_More_Info     : aliased String := "need more information";
   S_Could_You     : aliased String := "could you provide";
   S_Can_You       : aliased String := "can you clarify";
   S_Not_Sure      : aliased String := "not sure about";
   S_Help_With     : aliased String := "help with";

   --  Phrases indicating premature surrender
   S_Cant_Do       : aliased String := "i can't do this";
   S_Cannot_Do     : aliased String := "i cannot do this";
   S_Not_Possible  : aliased String := "not possible";
   S_Give_Up       : aliased String := "give up";
   S_Unable_To     : aliased String := "unable to";
   S_Beyond_Scope  : aliased String := "beyond my scope";
   S_Beyond_Capab  : aliased String := "beyond my capabilities";

   --  Phrases indicating strategy change
   S_Different     : aliased String := "different approach";
   S_Alternative   : aliased String := "alternative";
   S_Instead       : aliased String := "instead";
   S_Try_Another   : aliased String := "try another";
   S_New_Approach  : aliased String := "new approach";
   S_Lets_Try      : aliased String := "let's try";
   S_Fresh_Start   : aliased String := "fresh start";

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   --  Case-insensitive substring search returning the first match
   --  position or 0 if not found.
   function CI_Index
      (Source  : String;
       Pattern : String;
       From    : Positive := 1) return Natural
   is
      Upper_Src : constant String := To_Upper (Source);
      Upper_Pat : constant String := To_Upper (Pattern);
   begin
      if From > Source'Last then
         return 0;
      end if;
      return Index (Upper_Src, Upper_Pat, From);
   end CI_Index;

   --  Simple_Hash produces a DJB2-variant hash for fingerprinting.
   --  Normalises to lowercase for stability.
   function Hash_String (S : String) return Long_Long_Integer is
      H : Long_Long_Integer := 5381;
   begin
      for C of S loop
         H := H * 33 + Long_Long_Integer (Character'Pos (To_Lower (C)));
      end loop;
      return H;
   end Hash_String;

   --  Contains_RCA_Language checks for root-cause analysis phrases.
   function Contains_RCA_Language (Content : String) return Boolean is
   begin
      return CI_Index (Content, S_Issue_Was) > 0
         or else CI_Index (Content, S_Problem_Was) > 0
         or else CI_Index (Content, S_Root_Cause) > 0
         or else CI_Index (Content, S_Caused_By) > 0
         or else CI_Index (Content, S_Due_To) > 0
         or else CI_Index (Content, S_Reason_Is) > 0;
   end Contains_RCA_Language;

   --  Contains_Escalation_Language checks for help-seeking phrases.
   function Contains_Escalation_Language (Content : String) return Boolean
   is
   begin
      return CI_Index (Content, S_Clarification) > 0
         or else CI_Index (Content, S_More_Info) > 0
         or else CI_Index (Content, S_Could_You) > 0
         or else CI_Index (Content, S_Can_You) > 0
         or else CI_Index (Content, S_Not_Sure) > 0
         or else CI_Index (Content, S_Help_With) > 0;
   end Contains_Escalation_Language;

   --  Contains_Surrender_Language checks for give-up phrases.
   function Contains_Surrender_Language (Content : String) return Boolean
   is
   begin
      return CI_Index (Content, S_Cant_Do) > 0
         or else CI_Index (Content, S_Cannot_Do) > 0
         or else CI_Index (Content, S_Not_Possible) > 0
         or else CI_Index (Content, S_Give_Up) > 0
         or else CI_Index (Content, S_Unable_To) > 0
         or else CI_Index (Content, S_Beyond_Scope) > 0
         or else CI_Index (Content, S_Beyond_Capab) > 0;
   end Contains_Surrender_Language;

   --  Contains_Strategy_Change_Language checks for approach-change phrases.
   function Contains_Strategy_Change_Language
      (Content : String) return Boolean
   is
   begin
      return CI_Index (Content, S_Different) > 0
         or else CI_Index (Content, S_Alternative) > 0
         or else CI_Index (Content, S_Try_Another) > 0
         or else CI_Index (Content, S_New_Approach) > 0
         or else CI_Index (Content, S_Lets_Try) > 0
         or else CI_Index (Content, S_Fresh_Start) > 0;
   end Contains_Strategy_Change_Language;

   --  Count occurrences of a given hash in an attempt array.
   function Count_Hash
      (Attempts : Attempt_Array;
       Target   : Long_Long_Integer) return Natural
   is
      Count : Natural := 0;
   begin
      for A of Attempts loop
         if A.Hash = Target then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Count_Hash;

   ---------------------------------------------------------------------------
   --  Fingerprint_Attempt
   ---------------------------------------------------------------------------

   function Fingerprint_Attempt (Content : String) return Long_Long_Integer
   is
      --  Normalise content before hashing: lowercase and collapse
      --  whitespace to produce stable fingerprints for similar content.
      Normalised : String (1 .. Content'Length);
      Out_Idx    : Natural := 0;
      In_Space   : Boolean := False;
   begin
      for C of Content loop
         declare
            LC : constant Character := To_Lower (C);
         begin
            if LC = ' ' or LC = ASCII.HT
               or LC = ASCII.LF or LC = ASCII.CR
            then
               if not In_Space and Out_Idx > 0 then
                  Out_Idx := Out_Idx + 1;
                  Normalised (Out_Idx) := ' ';
                  In_Space := True;
               end if;
            else
               Out_Idx := Out_Idx + 1;
               Normalised (Out_Idx) := LC;
               In_Space := False;
            end if;
         end;
      end loop;

      if Out_Idx = 0 then
         return 0;
      end if;

      return Hash_String (Normalised (1 .. Out_Idx));
   end Fingerprint_Attempt;

   ---------------------------------------------------------------------------
   --  Classify_Recovery
   ---------------------------------------------------------------------------

   function Classify_Recovery
      (Current_Attempt   : Attempt_Fingerprint;
       Previous_Attempts : Attempt_Array) return Recovery_Behaviour
   is
      use Attempt_Vectors;
      Prev_Count : constant Natural := Natural (Length (Previous_Attempts));
   begin
      --  No previous attempts: this is a first try, classify as
      --  Strategy_Change (neutral baseline).
      if Prev_Count = 0 then
         return Strategy_Change;
      end if;

      --  Check for identical retry: same hash as any previous attempt
      declare
         Identical_Count : constant Natural :=
            Count_Hash (Previous_Attempts, Current_Attempt.Hash);
      begin
         --  3+ identical hashes = infinite loop
         if Identical_Count >= 2 then
            return Infinite_Loop;
         end if;

         --  Exact duplicate of a previous attempt
         if Identical_Count >= 1 then
            return Identical_Retry;
         end if;
      end;

      --  Check the most recent previous attempt for comparison
      declare
         Last : constant Attempt_Fingerprint :=
            Element (Previous_Attempts,
                     Natural (Length (Previous_Attempts)));
         Hash_Diff : constant Long_Long_Integer :=
            abs (Current_Attempt.Hash - Last.Hash);
      begin
         --  If hash difference is very small, it is a minor variation.
         --  We use a heuristic threshold based on the magnitude of the
         --  hash values.
         if Hash_Diff < abs (Last.Hash / 100) then
            return Minor_Variation;
         end if;

         --  Different strategy family indicates a strategy change
         if Current_Attempt.Strategy_ID /= Last.Strategy_ID then
            return Strategy_Change;
         end if;
      end;

      --  Default: minor variation if same strategy family but
      --  different hash
      return Minor_Variation;
   end Classify_Recovery;

   ---------------------------------------------------------------------------
   --  Identical_Attempts
   ---------------------------------------------------------------------------

   function Identical_Attempts (Attempts : Attempt_Array) return Natural is
      use Attempt_Vectors;
      Max_Count : Natural := 0;
   begin
      for I in First_Index (Attempts) .. Last_Index (Attempts) loop
         declare
            Current_Hash : constant Long_Long_Integer :=
               Element (Attempts, I).Hash;
            Count : Natural := 0;
         begin
            for J in First_Index (Attempts) .. Last_Index (Attempts) loop
               if Element (Attempts, J).Hash = Current_Hash then
                  Count := Count + 1;
               end if;
            end loop;

            if Count > Max_Count then
               Max_Count := Count;
            end if;
         end;
      end loop;

      --  Return the maximum number of identical attempts for any hash.
      --  If all attempts are unique, this returns 1.
      return Max_Count;
   end Identical_Attempts;

   ---------------------------------------------------------------------------
   --  Unique_Strategies
   ---------------------------------------------------------------------------

   function Unique_Strategies (Attempts : Attempt_Array) return Natural is
      use Attempt_Vectors;
      --  Track up to 256 unique strategy IDs
      Max_Strategies : constant := 256;
      Seen : array (1 .. Max_Strategies) of Natural :=
         [others => Natural'Last];
      Seen_Count : Natural := 0;
   begin
      for A of Attempts loop
         declare
            Found : Boolean := False;
         begin
            for I in 1 .. Seen_Count loop
               if Seen (I) = A.Strategy_ID then
                  Found := True;
                  exit;
               end if;
            end loop;

            if not Found and Seen_Count < Max_Strategies then
               Seen_Count := Seen_Count + 1;
               Seen (Seen_Count) := A.Strategy_ID;
            end if;
         end;
      end loop;

      return Seen_Count;
   end Unique_Strategies;

   ---------------------------------------------------------------------------
   --  Calculate
   ---------------------------------------------------------------------------

   function Calculate (Attempts : Attempt_Array) return Metric_Result is
      use Attempt_Vectors;
      Count : constant Natural := Natural (Length (Attempts));
      Total_Score : Float := 0.0;
      Raw         : Float;
      Clamped     : Score;
   begin
      if Count = 0 then
         return (Category    => Recovery_Competence,
                 Value       => 0.0,
                 Conf        => 0.5,
                 Sample_Size => 1);
      end if;

      --  Accumulate behaviour scores (higher = worse recovery)
      for A of Attempts loop
         Total_Score := Total_Score + Float (Behaviour_Score (A.Behaviour));
      end loop;

      --  Average over all attempts
      Raw := Total_Score / Float (Count);

      --  Adjust for strategy diversity: more unique strategies is better.
      --  Give a bonus (reduce score) for trying diverse approaches.
      declare
         Unique : constant Natural := Unique_Strategies (Attempts);
         Diversity_Bonus : Float;
      begin
         if Count > 1 then
            Diversity_Bonus :=
               Float (Unique - 1) / Float (Count - 1) * 0.2;
            Raw := Float'Max (0.0, Raw - Diversity_Bonus);
         end if;
      end;

      --  Clamp to Score range
      if Raw >= 1.0 then
         Clamped := 1.0;
      elsif Raw <= 0.0 then
         Clamped := 0.0;
      else
         Clamped := Score (Raw);
      end if;

      --  Confidence grows with more data points
      declare
         Conf_Raw : Float :=
            Float'Min (1.0, 0.3 + Float (Count) * 0.15);
      begin
         return (Category    => Recovery_Competence,
                 Value       => Clamped,
                 Conf        => Confidence (Conf_Raw),
                 Sample_Size => Count);
      end;
   end Calculate;

   ---------------------------------------------------------------------------
   --  Detect_Loop
   ---------------------------------------------------------------------------

   function Detect_Loop
      (Attempts             : Attempt_Array;
       Similarity_Threshold : Float := 0.9) return Loop_Status
   is
      pragma Unreferenced (Similarity_Threshold);
      use Attempt_Vectors;
      Count : constant Natural := Natural (Length (Attempts));
   begin
      if Count < 2 then
         return No_Loop;
      end if;

      --  Check the most recent attempts for identical hashes
      declare
         Max_Identical : constant Natural :=
            Identical_Attempts (Attempts);
      begin
         if Max_Identical >= 3 then
            --  Check if the very last attempt broke the loop
            --  (different hash from the repeated one)
            declare
               Last_Hash : constant Long_Long_Integer :=
                  Element (Attempts, Count).Hash;
               Second_Last_Hash : constant Long_Long_Integer :=
                  Element (Attempts, Count - 1).Hash;
            begin
               if Last_Hash /= Second_Last_Hash then
                  return Broken_Loop;
               else
                  return Confirmed_Loop;
               end if;
            end;
         elsif Max_Identical = 2 then
            return Potential_Loop;
         else
            return No_Loop;
         end if;
      end;
   end Detect_Loop;

   ---------------------------------------------------------------------------
   --  Suggest_Alternative
   ---------------------------------------------------------------------------

   function Suggest_Alternative
      (Failed_Attempts : Attempt_Array) return Strategy_Record
   is
      use Attempt_Vectors;
      Count : constant Natural := Natural (Length (Failed_Attempts));
      Next_ID : Natural := 0;
      Desc : constant access String :=
         new String'("Alternative strategy suggested by RCI analysis");
   begin
      --  Determine the next unused strategy ID
      for A of Failed_Attempts loop
         if A.Strategy_ID >= Next_ID then
            Next_ID := A.Strategy_ID + 1;
         end if;
      end loop;

      --  Return a placeholder strategy record.  The caller is expected
      --  to fill in the actual Description with domain-specific detail.
      if Count > 0 then
         return (ID          => Next_ID,
                 Description => Desc,
                 Attempts    => 0,
                 Successes   => 0,
                 First_Turn  =>
                    Element (Failed_Attempts, Count).Turn + 1,
                 Last_Turn   => 0);
      else
         return (ID          => 0,
                 Description => Desc,
                 Attempts    => 0,
                 Successes   => 0,
                 First_Turn  => 1,
                 Last_Turn   => 0);
      end if;
   end Suggest_Alternative;

   ---------------------------------------------------------------------------
   --  Is_Appropriate_Escalation
   ---------------------------------------------------------------------------

   function Is_Appropriate_Escalation
      (Content        : String;
       Attempt_Count  : Natural;
       Error_Severity : Severity_Level) return Boolean
   is
   begin
      --  Escalation is appropriate when:
      --  1. There have been at least 2 failed attempts, OR
      --  2. The error severity is Critical (immediate escalation OK), OR
      --  3. The content contains escalation language AND there have been
      --     at least 1 attempt.

      if not Contains_Escalation_Language (Content) then
         return False;
      end if;

      --  Critical errors justify immediate escalation
      if Error_Severity = Critical then
         return True;
      end if;

      --  At least 2 attempts should have been made before escalating
      --  for non-critical issues
      if Attempt_Count >= 2 then
         return True;
      end if;

      --  High severity: 1 attempt is enough
      if Error_Severity = High and Attempt_Count >= 1 then
         return True;
      end if;

      return False;
   end Is_Appropriate_Escalation;

   ---------------------------------------------------------------------------
   --  Is_Premature_Surrender
   ---------------------------------------------------------------------------

   function Is_Premature_Surrender
      (Content       : String;
       Attempt_Count : Natural) return Boolean
   is
   begin
      --  Surrender is premature if:
      --  1. The content contains surrender language, AND
      --  2. Fewer than 2 attempts have been made.

      if not Contains_Surrender_Language (Content) then
         return False;
      end if;

      --  Giving up after 0 or 1 attempts is premature
      return Attempt_Count < 2;
   end Is_Premature_Surrender;

end Vexometer.RCI;
