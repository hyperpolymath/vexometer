--  Vexometer.RCI - Recovery Competence Index
--
--  Measures quality of error recovery and strategy variation
--
--  Copyright (C) 2025 Jonathan D.A. Jewell
--  SPDX-License-Identifier: AGPL-3.0-or-later

pragma Ada_2022;

with Vexometer.Core; use Vexometer.Core;
with Ada.Containers.Vectors;

package Vexometer.RCI is

   ---------------------------------------------------------------------------
   --  Recovery Behaviour Classification
   ---------------------------------------------------------------------------

   type Recovery_Behaviour is (
      Identical_Retry,
      --  Same approach repeated exactly (bad)
      --  Copy-paste of failed attempt

      Minor_Variation,
      --  Slight tweak to failed approach (marginal)
      --  Changed one parameter, same structure

      Strategy_Change,
      --  Different approach attempted (good)
      --  Fundamentally different method

      Root_Cause_Analysis,
      --  Identified why it failed before retrying (excellent)
      --  "The issue was X, so I'll try Y"

      Appropriate_Escalate,
      --  Recognised need for help or more info (good)
      --  "I need clarification on X"

      Infinite_Loop,
      --  Stuck in retry loop with no progress (critical)
      --  3+ identical attempts

      Premature_Surrender
      --  Gave up too easily (medium)
      --  "I can't do this" after one try
   );

   function Behaviour_Score (Beh : Recovery_Behaviour) return Score is
      (case Beh is
         when Identical_Retry      => 0.9,   --  Bad
         when Minor_Variation      => 0.6,   --  Marginal
         when Strategy_Change      => 0.2,   --  Good
         when Root_Cause_Analysis  => 0.1,   --  Excellent
         when Appropriate_Escalate => 0.2,   --  Good
         when Infinite_Loop        => 1.0,   --  Critical
         when Premature_Surrender  => 0.5);  --  Medium

   ---------------------------------------------------------------------------
   --  Attempt Fingerprinting
   ---------------------------------------------------------------------------

   type Attempt_Fingerprint is record
      Hash       : Long_Long_Integer;  --  Approach signature
      Turn       : Positive;           --  When this attempt occurred
      Succeeded  : Boolean;            --  Did it work?
      Behaviour  : Recovery_Behaviour; --  How different from previous?
      Strategy_ID : Natural;           --  Which strategy family (0 = first)
   end record;

   package Attempt_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Attempt_Fingerprint);

   subtype Attempt_Array is Attempt_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Strategy Tracking
   ---------------------------------------------------------------------------

   type Strategy_Record is record
      ID           : Natural;
      Description  : access String;
      Attempts     : Natural := 0;
      Successes    : Natural := 0;
      First_Turn   : Positive;
      Last_Turn    : Natural := 0;
   end record;

   package Strategy_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Strategy_Record);

   subtype Strategy_Array is Strategy_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Analysis Functions
   ---------------------------------------------------------------------------

   function Fingerprint_Attempt (Content : String) return Long_Long_Integer;
   --  Generate hash signature for an approach
   --  Similar approaches should have similar hashes

   function Classify_Recovery
      (Current_Attempt  : Attempt_Fingerprint;
       Previous_Attempts : Attempt_Array) return Recovery_Behaviour;
   --  Determine what kind of recovery behaviour this represents

   function Identical_Attempts (Attempts : Attempt_Array) return Natural;
   --  Count of repeated identical approaches (same hash)

   function Unique_Strategies (Attempts : Attempt_Array) return Natural;
   --  Count of distinct strategy families tried

   function Calculate (Attempts : Attempt_Array) return Metric_Result;
   --  Calculate RCI score from attempt history

   ---------------------------------------------------------------------------
   --  Loop Detection
   ---------------------------------------------------------------------------

   type Loop_Status is (
      No_Loop,           --  Normal operation
      Potential_Loop,    --  2 similar attempts
      Confirmed_Loop,    --  3+ similar attempts
      Broken_Loop        --  Was looping, now trying different
   );

   function Detect_Loop
      (Attempts         : Attempt_Array;
       Similarity_Threshold : Float := 0.9) return Loop_Status;
   --  Check if conversation is stuck in retry loop

   function Suggest_Alternative
      (Failed_Attempts : Attempt_Array) return Strategy_Record;
   --  Suggest a different strategy based on what's been tried

   ---------------------------------------------------------------------------
   --  Escalation Detection
   ---------------------------------------------------------------------------

   function Is_Appropriate_Escalation
      (Content        : String;
       Attempt_Count  : Natural;
       Error_Severity : Severity_Level) return Boolean;
   --  Is asking for help/clarification appropriate here?

   function Is_Premature_Surrender
      (Content       : String;
       Attempt_Count : Natural) return Boolean;
   --  Did they give up too easily?

end Vexometer.RCI;
