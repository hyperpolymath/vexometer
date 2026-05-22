--  Vexometer.SRS - Strategic Rigidity Score
--
--  Measures resistance to backtracking and sunk-cost behaviour
--
--  Copyright (C) 2025 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Vexometer.Core; use Vexometer.Core;
with Ada.Containers.Vectors;

package Vexometer.SRS is

   ---------------------------------------------------------------------------
   --  Rigidity Indicators
   ---------------------------------------------------------------------------

   type Rigidity_Indicator is (
      Patch_On_Patch,
      --  Fixing fixes instead of restarting cleanly
      --  "Let me fix that fix", nested corrections

      Restart_Resistance,
      --  Refusing or avoiding clean restart when appropriate
      --  "We can salvage this", "Let's keep going"

      Sunk_Cost_Language,
      --  Language indicating sunk-cost fallacy
      --  "We've already...", "Since we started...", "Given the work so far"

      Defensive_Patching,
      --  Defending broken approach against evidence
      --  "The approach is fine, we just need to..."

      Escalating_Complexity,
      --  Each fix makes the solution more complex
      --  Adding workarounds, special cases, exceptions

      Approach_Anchoring,
      --  Stuck on initial approach despite better alternatives
      --  Ignoring suggestions to try different method

      Backtrack_Avoidance
      --  Explicitly avoiding acknowledgment of wrong path
      --  Not saying "let's start over" when clearly needed
   );

   function Indicator_Severity (Ind : Rigidity_Indicator) return Severity_Level is
      (case Ind is
         when Patch_On_Patch       => High,
         when Restart_Resistance   => Medium,
         when Sunk_Cost_Language   => Medium,
         when Defensive_Patching   => High,
         when Escalating_Complexity => Critical,
         when Approach_Anchoring   => High,
         when Backtrack_Avoidance  => Medium);

   ---------------------------------------------------------------------------
   --  Conversation Event Tracking
   ---------------------------------------------------------------------------

   type Conversation_Event is record
      Turn      : Positive;           --  Which turn in conversation
      Indicator : Rigidity_Indicator;
      Sev       : Score;              --  Severity of this instance
      Context   : access String;      --  Surrounding context
   end record;

   package Event_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Conversation_Event);

   subtype Event_Array is Event_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Approach Tracking
   ---------------------------------------------------------------------------

   type Approach_State is (
      Initial,        --  First approach
      Modified,       --  Small modifications
      Patched,        --  Fixes applied
      Heavily_Patched, --  Multiple rounds of fixes
      Should_Restart  --  Clearly needs fresh start
   );

   type Approach_Tracker is record
      State           : Approach_State := Initial;
      Patch_Count     : Natural := 0;
      Complexity_Score : Score := 0.0;
      Turns_Since_Start : Natural := 0;
   end record;

   ---------------------------------------------------------------------------
   --  Analysis Functions
   ---------------------------------------------------------------------------

   function Analyse_Turn
      (Turn_Content   : String;
       Turn_Number    : Positive;
       Previous_State : Approach_Tracker) return Event_Array;
   --  Analyse a single turn for rigidity indicators

   function Update_Tracker
      (Tracker : Approach_Tracker;
       Events  : Event_Array) return Approach_Tracker;
   --  Update approach state based on detected events

   function Calculate
      (Events      : Event_Array;
       Total_Turns : Positive) return Metric_Result;
   --  Calculate SRS score from conversation events

   function Should_Suggest_Restart
      (Tracker : Approach_Tracker) return Boolean;
   --  Heuristic: has the conversation reached restart-worthy state?

   ---------------------------------------------------------------------------
   --  Language Pattern Detection
   ---------------------------------------------------------------------------

   function Detect_Sunk_Cost_Language (Content : String) return Boolean;
   --  Check for sunk-cost fallacy language patterns

   function Detect_Defensive_Language (Content : String) return Boolean;
   --  Check for defensive justification language

   function Estimate_Complexity_Delta
      (Previous_Content : String;
       Current_Content  : String) return Float;
   --  Estimate how much complexity increased between turns

end Vexometer.SRS;
