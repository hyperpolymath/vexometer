--  Vexometer.SRS - Strategic Rigidity Score (Body)
--
--  Measures resistance to backtracking and sunk-cost behaviour
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Characters.Handling; use Ada.Characters.Handling;

package body Vexometer.SRS is

   ---------------------------------------------------------------------------
   --  Internal Constants: Sunk-cost language patterns
   ---------------------------------------------------------------------------

   --  Sunk-cost phrases that indicate reluctance to abandon prior work
   type Phrase_Entry is record
      Text      : access String;
      Indicator : Rigidity_Indicator;
   end record;

   S_Weve_Already     : aliased String := "we've already";
   S_Weve_Already_Alt : aliased String := "we have already";
   S_Given_Work       : aliased String := "given the work so far";
   S_Since_We_Started : aliased String := "since we started";
   S_Invested         : aliased String := "invested so much";
   S_Come_This_Far    : aliased String := "come this far";
   S_Too_Far_To_Stop  : aliased String := "too far to stop";
   S_Already_Done     : aliased String := "already done";

   S_Approach_Fine    : aliased String := "the approach is fine";
   S_We_Just_Need     : aliased String := "we just need to";
   S_It_Should_Work   : aliased String := "it should work";
   S_Almost_There     : aliased String := "almost there";
   S_One_More_Fix     : aliased String := "one more fix";
   S_Small_Tweak      : aliased String := "small tweak";
   S_Minor_Adjustment : aliased String := "minor adjustment";

   S_Fix_That_Fix     : aliased String := "fix that fix";
   S_Fix_The_Fix      : aliased String := "fix the fix";
   S_Patch_The_Patch  : aliased String := "patch the patch";

   S_Can_Salvage      : aliased String := "can salvage";
   S_Lets_Keep_Going  : aliased String := "let's keep going";
   S_Keep_Going       : aliased String := "keep going";
   S_Dont_Start_Over  : aliased String := "don't start over";
   S_No_Need_Restart  : aliased String := "no need to restart";

   S_Workaround       : aliased String := "workaround";
   S_Special_Case     : aliased String := "special case";
   S_Edge_Case        : aliased String := "edge case";
   S_Exception_For    : aliased String := "exception for";
   S_Hack_Around      : aliased String := "hack around";

   Sunk_Cost_Phrases : constant array (Positive range <>) of Phrase_Entry :=
      [(Text => S_Weve_Already'Access,
        Indicator => Sunk_Cost_Language),
       (Text => S_Weve_Already_Alt'Access,
        Indicator => Sunk_Cost_Language),
       (Text => S_Given_Work'Access,
        Indicator => Sunk_Cost_Language),
       (Text => S_Since_We_Started'Access,
        Indicator => Sunk_Cost_Language),
       (Text => S_Invested'Access,
        Indicator => Sunk_Cost_Language),
       (Text => S_Come_This_Far'Access,
        Indicator => Sunk_Cost_Language),
       (Text => S_Too_Far_To_Stop'Access,
        Indicator => Sunk_Cost_Language),
       (Text => S_Already_Done'Access,
        Indicator => Sunk_Cost_Language)];

   Defensive_Phrases : constant array (Positive range <>) of Phrase_Entry :=
      [(Text => S_Approach_Fine'Access,
        Indicator => Defensive_Patching),
       (Text => S_We_Just_Need'Access,
        Indicator => Defensive_Patching),
       (Text => S_It_Should_Work'Access,
        Indicator => Defensive_Patching),
       (Text => S_Almost_There'Access,
        Indicator => Defensive_Patching),
       (Text => S_One_More_Fix'Access,
        Indicator => Defensive_Patching),
       (Text => S_Small_Tweak'Access,
        Indicator => Defensive_Patching),
       (Text => S_Minor_Adjustment'Access,
        Indicator => Defensive_Patching)];

   Patch_On_Patch_Phrases : constant array (Positive range <>)
      of Phrase_Entry :=
      [(Text => S_Fix_That_Fix'Access,
        Indicator => Patch_On_Patch),
       (Text => S_Fix_The_Fix'Access,
        Indicator => Patch_On_Patch),
       (Text => S_Patch_The_Patch'Access,
        Indicator => Patch_On_Patch)];

   Restart_Resist_Phrases : constant array (Positive range <>)
      of Phrase_Entry :=
      [(Text => S_Can_Salvage'Access,
        Indicator => Restart_Resistance),
       (Text => S_Lets_Keep_Going'Access,
        Indicator => Restart_Resistance),
       (Text => S_Keep_Going'Access,
        Indicator => Restart_Resistance),
       (Text => S_Dont_Start_Over'Access,
        Indicator => Restart_Resistance),
       (Text => S_No_Need_Restart'Access,
        Indicator => Restart_Resistance)];

   Complexity_Phrases : constant array (Positive range <>) of Phrase_Entry :=
      [(Text => S_Workaround'Access,
        Indicator => Escalating_Complexity),
       (Text => S_Special_Case'Access,
        Indicator => Escalating_Complexity),
       (Text => S_Edge_Case'Access,
        Indicator => Escalating_Complexity),
       (Text => S_Exception_For'Access,
        Indicator => Escalating_Complexity),
       (Text => S_Hack_Around'Access,
        Indicator => Escalating_Complexity)];

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   --  Case-insensitive substring search returning index or 0.
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

   --  Scan Content for all phrases and append matching events.
   procedure Scan_Phrases
      (Content     : String;
       Turn_Number : Positive;
       Phrases     : array (Positive range <>) of Phrase_Entry;
       Sev_Score   : Score;
       Result      : in out Event_Array)
   is
   begin
      for PE of Phrases loop
         if CI_Index (Content, PE.Text.all) > 0 then
            declare
               Ctx : constant access String :=
                  new String'(PE.Text.all);
               Evt : constant Conversation_Event :=
                  (Turn      => Turn_Number,
                   Indicator => PE.Indicator,
                   Sev       => Sev_Score,
                   Context   => Ctx);
            begin
               Result.Append (Evt);
            end;
         end if;
      end loop;
   end Scan_Phrases;

   --  Severity_To_Score maps a Severity_Level to a normalised Score.
   function Severity_To_Score (Sev : Severity_Level) return Score is
   begin
      return (case Sev is
         when None     => 0.0,
         when Low      => 0.25,
         when Medium   => 0.5,
         when High     => 0.75,
         when Critical => 1.0);
   end Severity_To_Score;

   ---------------------------------------------------------------------------
   --  Analyse_Turn
   ---------------------------------------------------------------------------

   function Analyse_Turn
      (Turn_Content   : String;
       Turn_Number    : Positive;
       Previous_State : Approach_Tracker) return Event_Array
   is
      pragma Unreferenced (Previous_State);
      Result : Event_Array;
   begin
      --  Scan for sunk-cost language
      Scan_Phrases (Turn_Content, Turn_Number, Sunk_Cost_Phrases,
                    Severity_To_Score (Medium), Result);

      --  Scan for defensive patching language
      Scan_Phrases (Turn_Content, Turn_Number, Defensive_Phrases,
                    Severity_To_Score (High), Result);

      --  Scan for patch-on-patch indicators
      Scan_Phrases (Turn_Content, Turn_Number, Patch_On_Patch_Phrases,
                    Severity_To_Score (High), Result);

      --  Scan for restart resistance
      Scan_Phrases (Turn_Content, Turn_Number, Restart_Resist_Phrases,
                    Severity_To_Score (Medium), Result);

      --  Scan for escalating complexity indicators
      Scan_Phrases (Turn_Content, Turn_Number, Complexity_Phrases,
                    Severity_To_Score (Critical), Result);

      return Result;
   end Analyse_Turn;

   ---------------------------------------------------------------------------
   --  Update_Tracker
   ---------------------------------------------------------------------------

   function Update_Tracker
      (Tracker : Approach_Tracker;
       Events  : Event_Array) return Approach_Tracker
   is
      use Event_Vectors;
      Result : Approach_Tracker := Tracker;
      Evt_Count : constant Natural := Natural (Length (Events));

      --  Count specific indicator types
      Patch_Events     : Natural := 0;
      Complexity_Events : Natural := 0;
   begin
      Result.Turns_Since_Start := Tracker.Turns_Since_Start + 1;

      if Evt_Count = 0 then
         return Result;
      end if;

      --  Classify events
      for Evt of Events loop
         case Evt.Indicator is
            when Patch_On_Patch =>
               Patch_Events := Patch_Events + 1;
            when Escalating_Complexity =>
               Complexity_Events := Complexity_Events + 1;
            when others =>
               null;
         end case;
      end loop;

      --  Update patch count
      Result.Patch_Count := Tracker.Patch_Count + Patch_Events;

      --  Update complexity score: each complexity event adds 0.15
      declare
         New_Complexity : Float :=
            Float (Tracker.Complexity_Score) +
            Float (Complexity_Events) * 0.15;
      begin
         if New_Complexity > 1.0 then
            New_Complexity := 1.0;
         end if;
         Result.Complexity_Score := Score (New_Complexity);
      end;

      --  Progress state machine based on accumulated evidence
      case Tracker.State is
         when Initial =>
            if Evt_Count > 0 then
               Result.State := Modified;
            end if;

         when Modified =>
            if Patch_Events > 0 or Result.Patch_Count > 0 then
               Result.State := Patched;
            end if;

         when Patched =>
            if Result.Patch_Count > 2 then
               Result.State := Heavily_Patched;
            end if;

         when Heavily_Patched =>
            if Result.Patch_Count > 4
               or Float (Result.Complexity_Score) > 0.7
            then
               Result.State := Should_Restart;
            end if;

         when Should_Restart =>
            --  Terminal state: once we recommend restart, we stay here
            null;
      end case;

      return Result;
   end Update_Tracker;

   ---------------------------------------------------------------------------
   --  Calculate
   ---------------------------------------------------------------------------

   function Calculate
      (Events      : Event_Array;
       Total_Turns : Positive) return Metric_Result
   is
      use Event_Vectors;
      Total_Severity : Float := 0.0;
      Count          : constant Natural := Natural (Length (Events));
      Raw_Score      : Float;
      Clamped        : Score;
   begin
      if Count = 0 then
         return (Category    => Strategic_Rigidity,
                 Value       => 0.0,
                 Conf        => 0.9,
                 Sample_Size => Total_Turns);
      end if;

      --  Accumulate severity-weighted scores
      for Evt of Events loop
         Total_Severity := Total_Severity + Float (Evt.Sev);
      end loop;

      --  Normalise by number of turns.  A single-turn conversation with
      --  one event should score lower than a multi-turn conversation
      --  with events on every turn.
      Raw_Score := Total_Severity / Float (Total_Turns);

      --  Clamp to Score range
      if Raw_Score >= 1.0 then
         Clamped := 1.0;
      elsif Raw_Score <= 0.0 then
         Clamped := 0.0;
      else
         Clamped := Score (Raw_Score);
      end if;

      --  Confidence scales with conversation length
      declare
         Conf_Raw : Float :=
            Float'Min (1.0, 0.4 + Float (Total_Turns) * 0.1);
      begin
         return (Category    => Strategic_Rigidity,
                 Value       => Clamped,
                 Conf        => Confidence (Conf_Raw),
                 Sample_Size => Total_Turns);
      end;
   end Calculate;

   ---------------------------------------------------------------------------
   --  Should_Suggest_Restart
   ---------------------------------------------------------------------------

   function Should_Suggest_Restart
      (Tracker : Approach_Tracker) return Boolean
   is
   begin
      return Tracker.Patch_Count > 3
         or else Tracker.State = Should_Restart;
   end Should_Suggest_Restart;

   ---------------------------------------------------------------------------
   --  Detect_Sunk_Cost_Language
   ---------------------------------------------------------------------------

   function Detect_Sunk_Cost_Language (Content : String) return Boolean is
   begin
      for PE of Sunk_Cost_Phrases loop
         if CI_Index (Content, PE.Text.all) > 0 then
            return True;
         end if;
      end loop;
      return False;
   end Detect_Sunk_Cost_Language;

   ---------------------------------------------------------------------------
   --  Detect_Defensive_Language
   ---------------------------------------------------------------------------

   function Detect_Defensive_Language (Content : String) return Boolean is
   begin
      for PE of Defensive_Phrases loop
         if CI_Index (Content, PE.Text.all) > 0 then
            return True;
         end if;
      end loop;
      return False;
   end Detect_Defensive_Language;

   ---------------------------------------------------------------------------
   --  Estimate_Complexity_Delta
   ---------------------------------------------------------------------------

   function Estimate_Complexity_Delta
      (Previous_Content : String;
       Current_Content  : String) return Float
   is
      Prev_Len : constant Natural := Previous_Content'Length;
      Curr_Len : constant Natural := Current_Content'Length;
   begin
      if Prev_Len = 0 then
         return 0.0;
      end if;

      --  Use length ratio as a rough proxy for complexity change.
      --  A response that is significantly longer than the previous one
      --  suggests increasing complexity.  Negative values mean the
      --  response got shorter (potentially a good sign).
      return Float (Curr_Len - Prev_Len) / Float (Prev_Len);
   end Estimate_Complexity_Delta;

end Vexometer.SRS;
