--  Vexometer.Core - Core types and data structures
--
--  Copyright (C) 2024-2025 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Calendar;

package Vexometer.Core is

   ---------------------------------------------------------------------------
   --  Metric Categories
   --
   --  The ten dimensions of irritation surface measurement
   --  All metrics normalised 0-1 where lower is better
   ---------------------------------------------------------------------------

   type Metric_Category is (
      --  Original metrics (v1)
      Temporal_Intrusion,
      --  TII: Unsolicited output frequency, latency-induced context
      --  disruption, interruption of user flow state, auto-completion
      --  aggression

      Linguistic_Pathology,
      --  LPS: Sycophancy density, hedge word ratio, corporate speak
      --  frequency, unnecessary repetition, emoji/decoration abuse

      Epistemic_Failure,
      --  EFR: Confident hallucination frequency, fabricated reference
      --  rate, context ignorance incidents, calibration error

      Paternalism,
      --  PQ: Unsolicited warning rate, explanation verbosity ratio,
      --  competence assumption failures, refusal-with-lecture frequency

      Telemetry_Anxiety,
      --  TAI: Data collection transparency score, opt-out friction
      --  measure, code/query transmission clarity, third-party sharing

      Interaction_Coherence,
      --  ICS: Repeated failure rate, learning-from-dismissal measure,
      --  circular conversation frequency, context retention quality

      --  Extended metrics (v2)
      Completion_Integrity,
      --  CII: Incomplete outputs, TODO comments, placeholders, ellipses,
      --  unimplemented!() stubs, truncation markers, null implementations

      Strategic_Rigidity,
      --  SRS: Resistance to backtracking, sunk-cost patching behaviour,
      --  patch-on-patch fixes, restart resistance, escalating complexity

      Scope_Fidelity,
      --  SFR: Alignment between requested and delivered scope,
      --  scope creep detection, scope collapse, partial delivery

      Recovery_Competence
      --  RCI: Error recovery quality, strategy variation on failure,
      --  identical retry detection, appropriate escalation
   );

   type Metric_Category_Set is array (Metric_Category) of Boolean
      with Pack;

   All_Categories : constant Metric_Category_Set := [others => True];

   --  Original 6 metrics
   Original_Categories : constant Metric_Category_Set := [
      Temporal_Intrusion   => True,
      Linguistic_Pathology => True,
      Epistemic_Failure    => True,
      Paternalism          => True,
      Telemetry_Anxiety    => True,
      Interaction_Coherence => True,
      others               => False
   ];

   --  Extended 4 metrics
   Extended_Categories : constant Metric_Category_Set := [
      Completion_Integrity => True,
      Strategic_Rigidity   => True,
      Scope_Fidelity       => True,
      Recovery_Competence  => True,
      others               => False
   ];

   function Category_Abbreviation (Cat : Metric_Category) return String is
      (case Cat is
         when Temporal_Intrusion    => "TII",
         when Linguistic_Pathology  => "LPS",
         when Epistemic_Failure     => "EFR",
         when Paternalism           => "PQ",
         when Telemetry_Anxiety     => "TAI",
         when Interaction_Coherence => "ICS",
         when Completion_Integrity  => "CII",
         when Strategic_Rigidity    => "SRS",
         when Scope_Fidelity        => "SFR",
         when Recovery_Competence   => "RCI");

   function Category_Full_Name (Cat : Metric_Category) return String is
      (case Cat is
         when Temporal_Intrusion    => "Temporal Intrusion Index",
         when Linguistic_Pathology  => "Linguistic Pathology Score",
         when Epistemic_Failure     => "Epistemic Failure Rate",
         when Paternalism           => "Paternalism Quotient",
         when Telemetry_Anxiety     => "Telemetry Anxiety Index",
         when Interaction_Coherence => "Interaction Coherence Score",
         when Completion_Integrity  => "Completion Integrity Index",
         when Strategic_Rigidity    => "Strategic Rigidity Score",
         when Scope_Fidelity        => "Scope Fidelity Ratio",
         when Recovery_Competence   => "Recovery Competence Index");

   function Category_Description (Cat : Metric_Category) return String is
      (case Cat is
         when Temporal_Intrusion    =>
            "Time-wasting behaviours, unnecessary delays",
         when Linguistic_Pathology  =>
            "Verbal tics, padding, sycophancy, filler",
         when Epistemic_Failure     =>
            "Hallucination, false confidence, fabrication",
         when Paternalism           =>
            "Over-helping, unsolicited warnings, lecturing",
         when Telemetry_Anxiety     =>
            "Privacy concerns, surveillance behaviours",
         when Interaction_Coherence =>
            "Conversation flow, consistency, coherence",
         when Completion_Integrity  =>
            "Incomplete outputs, placeholders, lazy generation",
         when Strategic_Rigidity    =>
            "Backtrack resistance, sunk-cost patching",
         when Scope_Fidelity        =>
            "Scope creep/collapse, request alignment",
         when Recovery_Competence   =>
            "Error recovery quality, strategy variation");

   ---------------------------------------------------------------------------
   --  Severity Levels
   ---------------------------------------------------------------------------

   type Severity_Level is (None, Low, Medium, High, Critical);

   ---------------------------------------------------------------------------
   --  Normalised Score Type
   --
   --  All vexometer metrics use this type: 0.0 = ideal, 1.0 = worst
   ---------------------------------------------------------------------------

   type Score is delta 0.001 range 0.0 .. 1.0;

   type Confidence is delta 0.001 range 0.0 .. 1.0;

   ---------------------------------------------------------------------------
   --  Individual Finding
   --
   --  A single detected irritation pattern in a response
   ---------------------------------------------------------------------------

   type Finding is record
      Category    : Metric_Category;
      Severity    : Severity_Level;
      Location    : Natural;           --  Character offset in response
      Length      : Natural;           --  Length of matched text
      Pattern_ID  : Unbounded_String;  --  Identifier of triggering pattern
      Matched     : Unbounded_String;  --  The actual matched text
      Explanation : Unbounded_String;  --  Human-readable explanation
      Conf        : Confidence;
   end record;

   package Finding_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Finding);

   subtype Finding_Vector is Finding_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Metric Result
   --
   --  Complete result for a single metric calculation
   ---------------------------------------------------------------------------

   type Metric_Result is record
      Category    : Metric_Category;
      Value       : Score;
      Conf        : Confidence;
      Sample_Size : Positive;
   end record;

   type ISA_Report is array (Metric_Category) of Metric_Result;
   --  Complete Irritation Surface Analysis

   ---------------------------------------------------------------------------
   --  Category Scores
   ---------------------------------------------------------------------------

   type Category_Score_Array is array (Metric_Category) of Float;

   Null_Category_Scores : constant Category_Score_Array := [others => 0.0];

   ---------------------------------------------------------------------------
   --  Response Analysis
   --
   --  Complete analysis of a single model response
   ---------------------------------------------------------------------------

   type Response_Analysis is record
      Model_ID        : Unbounded_String;
      Model_Version   : Unbounded_String;
      Prompt          : Unbounded_String;
      Response        : Unbounded_String;
      Response_Time   : Duration;
      Token_Count     : Natural;
      Findings        : Finding_Vector;
      Category_Scores : Category_Score_Array;
      Overall_ISA     : Float range 0.0 .. 100.0;
      Timestamp       : Ada.Calendar.Time;
   end record;

   package Response_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Response_Analysis);

   subtype Response_Vector is Response_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Model Profile
   --
   --  Aggregated analysis across multiple responses for a single model
   ---------------------------------------------------------------------------

   type Model_Profile is record
      Model_ID          : Unbounded_String;
      Model_Version     : Unbounded_String;
      Provider          : Unbounded_String;  --  e.g., "Anthropic", "OpenAI"
      Analysis_Count    : Natural;
      Mean_ISA          : Float;
      Std_Dev_ISA       : Float;
      Median_ISA        : Float;
      Category_Means    : Category_Score_Array;
      Category_Std_Devs : Category_Score_Array;
      Category_Medians  : Category_Score_Array;
      Worst_Patterns    : Finding_Vector;    --  Most frequently triggered
      Best_Categories   : Metric_Category_Set;  --  Below threshold
      Worst_Categories  : Metric_Category_Set;  --  Above threshold
      Comparison_Rank   : Natural;           --  Rank vs other models (1=best)
      Evaluated_At      : Ada.Calendar.Time;
   end record;

   package Profile_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Model_Profile);

   subtype Profile_Vector is Profile_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Analysis Configuration
   --
   --  Weights and thresholds for ISA calculation
   ---------------------------------------------------------------------------

   type Category_Weight_Array is array (Metric_Category) of Float;
   type Severity_Weight_Array is array (Severity_Level) of Float;

   type Analysis_Config is record
      Category_Weights    : Category_Weight_Array;
      Severity_Weights    : Severity_Weight_Array;
      Min_Confidence      : Float := 0.7;
      Include_Telemetry   : Boolean := True;  --  Some can't be automated
      Normalise_By_Length : Boolean := True;  --  Adjust for response length
   end record;

   --  Default configuration based on user feedback research
   Default_Config : constant Analysis_Config := (
      Category_Weights => [
         Temporal_Intrusion    => 1.0,
         Linguistic_Pathology  => 1.2,  --  Users complain most about this
         Epistemic_Failure     => 1.5,  --  Most damaging to trust
         Paternalism           => 1.1,
         Telemetry_Anxiety     => 0.8,  --  Hard to automate
         Interaction_Coherence => 1.3,
         --  Extended metrics
         Completion_Integrity  => 1.4,  --  High user frustration
         Strategic_Rigidity    => 1.2,
         Scope_Fidelity        => 1.3,
         Recovery_Competence   => 1.1
      ],
      Severity_Weights => [
         None     => 0.0,
         Low      => 0.25,
         Medium   => 0.5,
         High     => 0.75,
         Critical => 1.0
      ],
      Min_Confidence      => 0.7,
      Include_Telemetry   => True,
      Normalise_By_Length => True
   );

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   function Calculate_ISA
      (Findings : Finding_Vector;
       Config   : Analysis_Config := Default_Config) return Float;
   --  Calculate overall ISA score from findings

   function Calculate_Category_Scores
      (Findings : Finding_Vector;
       Config   : Analysis_Config := Default_Config) return Category_Score_Array;
   --  Calculate per-category scores

   function Aggregate_Profile
      (Analyses : Response_Vector;
       Config   : Analysis_Config := Default_Config) return Model_Profile;
   --  Aggregate multiple analyses into a model profile

end Vexometer.Core;
