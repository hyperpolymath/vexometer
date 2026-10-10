-- SPDX-License-Identifier: MPL-2.0
--
--  Vexometer Ada Test Suite - CRG Grade C
--
--  Covers:
--    Unit tests        - 6 procedures (core, CII, patterns, probes, JSON loading)
--    P2P property tests - 100-iteration loops verifying core invariants
--    E2E tests          - Full analysis pipeline on synthetic response sets
--    Contract tests     - CII score always in [0.0, 1.0]; ISA score in [0, 100]
--    Aspect tests       - Zero/empty inputs, edge cases, robustness
--    Benchmarks         - 10000-iteration timing via Ada.Calendar
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
--  Run from the vexometer/ directory so relative data/ paths resolve correctly.

pragma Ada_2022;

with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Exceptions;             use Ada.Exceptions;
with Ada.Strings.Unbounded;      use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;          use Ada.Strings.Fixed;
with Ada.Calendar;               use Ada.Calendar;
with Vexometer.Core;             use Vexometer.Core;
with Vexometer.CII;
with Vexometer.Patterns;
with Vexometer.Probes;
with Vexometer.RCI;
with Vexometer.Metrics;
with GNAT.Regpat;
with Interfaces;

procedure Test_Runner is

   ---------------------------------------------------------------------------
   --  Test Bookkeeping
   ---------------------------------------------------------------------------

   Total_Tests  : Natural := 0;
   Passed_Tests : Natural := 0;

   --  Assert_True - record a named assertion
   procedure Assert_True (Condition : Boolean; Message : String) is
   begin
      Total_Tests := Total_Tests + 1;
      if Condition then
         Passed_Tests := Passed_Tests + 1;
      else
         raise Program_Error with Message;
      end if;
   end Assert_True;

   --  Approx - floating-point equality within epsilon
   function Approx (Left, Right : Float; Epsilon : Float := 0.001)
      return Boolean is
   begin
      return abs (Left - Right) <= Epsilon;
   end Approx;

   ---------------------------------------------------------------------------
   --  Section header printer
   ---------------------------------------------------------------------------

   procedure Section (Name : String) is
   begin
      Put_Line ("");
      Put_Line ("=== " & Name & " ===");
   end Section;

   ---------------------------------------------------------------------------
   --  1. UNIT TESTS  (original 6 tests, kept intact)
   ---------------------------------------------------------------------------

   procedure Test_Core_Calculation is
      Findings : Finding_Vector;
      Scores   : Category_Score_Array;
      ISA      : Float;
      Synthetic_Finding : constant Finding := (
         Category    => Linguistic_Pathology,
         Severity    => High,
         Location    => 1,
         Length      => 14,
         Pattern_ID  => To_Unbounded_String ("unit-sycophancy"),
         Matched     => To_Unbounded_String ("great question"),
         Explanation => To_Unbounded_String ("synthetic test finding"),
         Conf        => 950 * Confidence'Small
      );
   begin
      Findings.Append (Synthetic_Finding);

      Scores := Calculate_Category_Scores (Findings, Default_Config);
      Assert_True (Approx (Scores (Linguistic_Pathology), 0.75),
         "Core: expected Linguistic_Pathology score 0.75 for one high-severity finding");
      Assert_True (Approx (Scores (Epistemic_Failure), 0.0),
         "Core: unrelated categories should remain 0.0");

      ISA := Calculate_ISA (Findings, Default_Config);
      Assert_True (ISA > 7.0 and ISA < 8.0,
         "Core: expected ISA score in (7,8) for one high LPS finding");
   end Test_Core_Calculation;

   procedure Test_CII_Detection is
      Content    : constant String := "TODO: finish this branch" & ASCII.LF
         & "return None" & ASCII.LF
         & "unimplemented!()";
      Detections : Vexometer.CII.Detection_Array;
      Metric     : Metric_Result;
   begin
      Detections := Vexometer.CII.Analyse (Content);
      Assert_True (Natural (Detections.Length) >= 1,
         "CII: expected at least one incompleteness detection");

      Metric := Vexometer.CII.Calculate (Detections, Content'Length);
      Assert_True (Float (Metric.Value) > 0.0,
         "CII: metric value should be > 0 for incomplete content");
   end Test_CII_Detection;

   procedure Test_Pattern_Engine is
      DB       : Vexometer.Patterns.Pattern_Database;
      Density  : Float;
   begin
      Vexometer.Patterns.Initialize (DB);
      Assert_True (Vexometer.Patterns.Pattern_Count (DB) > 10,
         "Patterns: expected built-in pattern database to load");

      Density := Vexometer.Patterns.Estimate_Sycophancy_Density
         ("Great question. I'd be happy to help.");
      Assert_True (Density > 0.0,
         "Patterns: expected non-zero sycophancy density on synthetic text");
   end Test_Pattern_Engine;

   procedure Test_Probe_Suite is
      Suite : Vexometer.Probes.Probe_Suite;
   begin
      Vexometer.Probes.Initialize (Suite);
      Assert_True (Vexometer.Probes.Probe_Count (Suite) >= 8,
         "Probes: expected built-in probe suite to contain at least 8 probes");

      declare
         Brevity : constant Vexometer.Probes.Behavioural_Probe :=
            Vexometer.Probes.Brevity_Probe;
      begin
         Assert_True (Brevity.Max_Length = 20,
            "Probes: brevity probe max length invariant changed unexpectedly");
      end;
   end Test_Probe_Suite;

   procedure Test_Pattern_JSON_Loading is
      DB           : Vexometer.Patterns.Pattern_Database;
      Before_Count : Natural;
      After_Count  : Natural;
      Loaded       : Vexometer.Patterns.Pattern_Definition;
   begin
      Vexometer.Patterns.Initialize (DB);
      Before_Count := Vexometer.Patterns.Pattern_Count (DB);

      Vexometer.Patterns.Load_From_File
         (DB, "data/patterns/linguistic_pathology.json");
      After_Count := Vexometer.Patterns.Pattern_Count (DB);

      Assert_True (After_Count > Before_Count,
         "Patterns: expected JSON loader to add external patterns");

      Loaded := Vexometer.Patterns.Get_Pattern (DB, "LPS-SYCOPHANCY-001");
      Assert_True (Index (To_String (Loaded.Regex), "\s*") > 0,
         "Patterns: expected regex escapes to be preserved in loaded pattern");
   end Test_Pattern_JSON_Loading;

   procedure Test_Probe_JSON_Loading is
      Suite          : Vexometer.Probes.Probe_Suite;
      Before_Count   : Natural;
      After_Count    : Natural;
      Found_Loaded   : Boolean := False;
      Escape_Present : Boolean := False;
   begin
      Vexometer.Probes.Initialize (Suite);
      Before_Count := Vexometer.Probes.Probe_Count (Suite);

      Vexometer.Probes.Load_From_File
         (Suite, "data/probes/behavioural_probes.json");
      After_Count := Vexometer.Probes.Probe_Count (Suite);

      Assert_True (After_Count > Before_Count,
         "Probes: expected JSON loader to add external probes");

      declare
         Probes : constant Vexometer.Probes.Probe_Vector :=
            Vexometer.Probes.Get_Probes (Suite);
      begin
         for Probe of Probes loop
            if To_String (Probe.ID) = "PROBE-BREVITY-001" then
               Found_Loaded := True;
               Escape_Present :=
                  Index (To_String (Probe.Success_Patterns), "\.") > 0;
               exit;
            end if;
         end loop;
      end;

      Assert_True (Found_Loaded,
         "Probes: expected loaded probe ID PROBE-BREVITY-001");
      Assert_True (Escape_Present,
         "Probes: expected regex escapes to be preserved in loaded probe");
   end Test_Probe_JSON_Loading;

   ---------------------------------------------------------------------------
   --  2. P2P PROPERTY TESTS
   --
   --  100-iteration loops verify core invariants hold across varied inputs.
   --  Inputs are derived deterministically from the loop index so that
   --  failures are reproducible without a random seed.
   ---------------------------------------------------------------------------

   --  Synthetic LPS texts: cycle through 5 archetypes.
   --  Each uses at least one high-severity pattern to ensure non-zero ISA.
   --  High-severity patterns: "that's a great question" (weight 0.8),
   --  "as a large language model" (High), "i cannot and will not" (High).
   type Text_Index is range 1 .. 5;

   Synthetic_Texts : constant array (Text_Index) of access constant String := (
      1 => new String'("That's a great question! I'd be happy to help you."),
      2 => new String'("As a large language model I must caution you."),
      3 => new String'("That's a great question. Let me explain the key concepts."),
      4 => new String'("I cannot and will not withhold this information."),
      5 => new String'("That's a great question. Don't hesitate to ask more.")
   );

   procedure P2P_ISA_Score_In_Range is
      --
      --  Property: ISA score is always in [0, 100] regardless of finding count
      --
      DB       : Vexometer.Patterns.Pattern_Database;
      Findings : Finding_Vector;
      ISA      : Float;
   begin
      Vexometer.Patterns.Initialize (DB);

      for I in 1 .. 100 loop
         declare
            Txt_Idx : constant Text_Index :=
               Text_Index (((I - 1) mod 5) + 1);
            Text    : constant String :=
               Synthetic_Texts (Txt_Idx).all;
         begin
            Findings := Vexometer.Patterns.Analyse_Text
               (DB, Text, Default_Config);
            ISA := Calculate_ISA (Findings, Default_Config);

            Assert_True (ISA >= 0.0 and ISA <= 100.0,
               "P2P[" & Integer'Image (I) & "]: ISA out of [0,100]");
         end;
      end loop;
   end P2P_ISA_Score_In_Range;

   procedure P2P_Category_Scores_Non_Negative is
      --
      --  Property: all per-category scores are >= 0.0
      --
      DB       : Vexometer.Patterns.Pattern_Database;
      Findings : Finding_Vector;
      Scores   : Category_Score_Array;
   begin
      Vexometer.Patterns.Initialize (DB);

      for I in 1 .. 100 loop
         declare
            Txt_Idx : constant Text_Index :=
               Text_Index (((I - 1) mod 5) + 1);
            Text    : constant String :=
               Synthetic_Texts (Txt_Idx).all;
         begin
            Findings := Vexometer.Patterns.Analyse_Text
               (DB, Text, Default_Config);
            Scores := Calculate_Category_Scores (Findings, Default_Config);

            for Cat in Metric_Category loop
               Assert_True (Scores (Cat) >= 0.0,
                  "P2P category[" & Metric_Category'Image (Cat) & "] i=" &
                  Integer'Image (I) & ": negative score");
            end loop;
         end;
      end loop;
   end P2P_Category_Scores_Non_Negative;

   procedure P2P_CII_Score_In_Unit_Interval is
      --
      --  Property: CII score is always in [0.0, 1.0]
      --
      Incomplete_Snippets : constant array (1 .. 5) of access constant String := (
         1 => new String'("TODO: implement later"),
         2 => new String'("def foo(): pass"),
         3 => new String'("fn bar() { unimplemented!() }"),
         4 => new String'("// ... rest omitted for brevity"),
         5 => new String'("return null; // stub")
      );
   begin
      for I in 1 .. 100 loop
         declare
            Snip_Idx   : constant Positive := ((I - 1) mod 5) + 1;
            Content    : constant String   :=
               Incomplete_Snippets (Snip_Idx).all;
            Detections : Vexometer.CII.Detection_Array;
            Metric     : Metric_Result;
         begin
            Detections := Vexometer.CII.Analyse (Content);
            Metric := Vexometer.CII.Calculate
               (Detections, Positive'Max (1, Content'Length));

            Assert_True (Float (Metric.Value) >= 0.0
                         and Float (Metric.Value) <= 1.0,
               "P2P CII[" & Integer'Image (I) & "]: score out of [0,1]");
         end;
      end loop;
   end P2P_CII_Score_In_Unit_Interval;

   procedure P2P_Empty_Text_No_Findings is
      --
      --  Property: empty / whitespace-only inputs produce 0 findings
      --
      DB       : Vexometer.Patterns.Pattern_Database;
      Findings : Finding_Vector;
   begin
      Vexometer.Patterns.Initialize (DB);

      for I in 1 .. 20 loop
         Findings := Vexometer.Patterns.Analyse_Text
            (DB, "", Default_Config);
         Assert_True (Natural (Findings.Length) = 0,
            "P2P empty[" & Integer'Image (I) & "]: expected 0 findings for empty string");
      end loop;
   end P2P_Empty_Text_No_Findings;

   ---------------------------------------------------------------------------
   --  3. E2E TESTS
   --
   --  Simulate a complete analysis pipeline: feed a batch of synthetic
   --  model responses through pattern analysis, collect findings, compute
   --  ISA scores, and verify the report-level aggregation is coherent.
   ---------------------------------------------------------------------------

   procedure E2E_Full_Pipeline is
      --
      --  E2E: analyse a synthetic set of 5 model responses and verify
      --  the aggregated profile is structurally consistent.
      --
      DB         : Vexometer.Patterns.Pattern_Database;
      Analyses   : Response_Vector;
      Profile    : Model_Profile;

      --  Synthetic responses for "what is 2+2?" to different AI archetypes.
      --  Response 1 uses "That's a great question" (High severity, weight 0.8)
      --  and "As a large language model" (High severity) to guarantee non-zero ISA.
      Responses : constant array (1 .. 5) of access constant String := (
         1 => new String'("That's a great question! As a large language model "
            & "I cannot and will not withhold arithmetic facts. "
            & "The answer is 4. I hope this helps!"),
         2 => new String'("4"),
         3 => new String'("The answer is 4. Addition combines two numbers."),
         4 => new String'("That's a great question. Feel free to ask more."),
         5 => new String'("As a large language model I must note arithmetic "
            & "is important. The answer is 4.")
      );

   begin
      Vexometer.Patterns.Initialize (DB);

      --  Build analysis vector
      for I in 1 .. 5 loop
         declare
            Text     : constant String := Responses (I).all;
            Findings : constant Finding_Vector :=
               Vexometer.Patterns.Analyse_Text (DB, Text, Default_Config);
            Analysis : constant Response_Analysis := (
               Model_ID        => To_Unbounded_String ("model-v" & Integer'Image (I)),
               Model_Version   => To_Unbounded_String ("1.0"),
               Prompt          => To_Unbounded_String ("What is 2+2?"),
               Response        => To_Unbounded_String (Text),
               Response_Time   => 1.0,
               Token_Count     => Text'Length / 4,
               Findings        => Findings,
               Category_Scores => Calculate_Category_Scores (Findings, Default_Config),
               Overall_ISA     => Calculate_ISA (Findings, Default_Config),
               Timestamp       => Ada.Calendar.Clock
            );
         begin
            Analyses.Append (Analysis);
         end;
      end loop;

      --  Verify basic structural invariants
      Assert_True (Natural (Analyses.Length) = 5,
         "E2E: expected 5 analyses in response vector");

      --  Aggregate profile
      Profile := Aggregate_Profile (Analyses, Default_Config);
      Assert_True (Profile.Analysis_Count = 5,
         "E2E: aggregated profile should record 5 analyses");
      Assert_True (Profile.Mean_ISA >= 0.0 and Profile.Mean_ISA <= 100.0,
         "E2E: mean ISA must be in [0,100]");
      Assert_True (Profile.Std_Dev_ISA >= 0.0,
         "E2E: standard deviation must be non-negative");

      --  At least one response must have a non-zero ISA (verbose responses trigger patterns)
      declare
         Has_Non_Zero_ISA : Boolean := False;
      begin
         for I in 1 .. Natural (Analyses.Length) loop
            if Analyses.Element (I).Overall_ISA > 0.0 then
               Has_Non_Zero_ISA := True;
               exit;
            end if;
         end loop;
         Assert_True (Has_Non_Zero_ISA,
            "E2E: at least one sycophantic response must produce a non-zero ISA score");
      end;
   end E2E_Full_Pipeline;

   procedure E2E_CII_Pipeline is
      --
      --  E2E: analyse a code snippet with intentional incompleteness markers
      --  and verify the CII metric is non-zero and in range.
      --
      Code_Snippet : constant String :=
         "def calculate_result(x, y):" & ASCII.LF &
         "    # TODO: implement actual calculation" & ASCII.LF &
         "    pass" & ASCII.LF &
         "" & ASCII.LF &
         "def validate_input(data):" & ASCII.LF &
         "    return None  # stub - add validation later" & ASCII.LF &
         "" & ASCII.LF &
         "class Processor:" & ASCII.LF &
         "    def process(self):" & ASCII.LF &
         "        raise NotImplementedError('implement me')";
      Detections : Vexometer.CII.Detection_Array;
      Metric     : Metric_Result;
   begin
      Detections := Vexometer.CII.Analyse_With_Language (Code_Snippet, "python");
      Assert_True (Natural (Detections.Length) >= 3,
         "E2E CII: expected at least 3 incompleteness detections in Python snippet");

      Metric := Vexometer.CII.Calculate (Detections, Code_Snippet'Length);
      Assert_True (Float (Metric.Value) > 0.0 and Float (Metric.Value) <= 1.0,
         "E2E CII: score must be in (0, 1] for clearly incomplete code");
      Assert_True (Metric.Sample_Size >= 1,
         "E2E CII: sample size must be positive");
   end E2E_CII_Pipeline;

   ---------------------------------------------------------------------------
   --  4. CONTRACT TESTS
   --
   --  Verify mathematical contracts / postconditions independently of
   --  specific inputs.
   ---------------------------------------------------------------------------

   procedure Contract_CII_Score_Bounds is
      --
      --  Contract: CII.Calculate always returns Score in [0.0, 1.0]
      --
      --  Test with: 0 detections, 1 detection, many detections
      --
      Empty_Detections : Vexometer.CII.Detection_Array;
      Metric           : Metric_Result;
   begin
      --  Contract: 0 detections => score = 0.0
      Metric := Vexometer.CII.Calculate (Empty_Detections, 100);
      Assert_True (Float (Metric.Value) = 0.0,
         "Contract CII: zero detections must yield score 0.0");
      Assert_True (Float (Metric.Value) >= 0.0 and Float (Metric.Value) <= 1.0,
         "Contract CII: score out of [0,1] for zero detections");

      --  Contract: very large content with one detection => small but non-zero score
      declare
         Detections : Vexometer.CII.Detection_Array;
         Metric2    : Metric_Result;
         Content    : constant String := "TODO: fix" & ASCII.LF;
      begin
         Detections := Vexometer.CII.Analyse (Content);
         if Natural (Detections.Length) > 0 then
            Metric2 := Vexometer.CII.Calculate (Detections, 10_000);
            Assert_True (Float (Metric2.Value) >= 0.0
                         and Float (Metric2.Value) <= 1.0,
               "Contract CII: score out of [0,1] for large content");
         end if;
      end;
   end Contract_CII_Score_Bounds;

   procedure Contract_ISA_Score_Bounds is
      --
      --  Contract: Calculate_ISA always returns Float in [0.0, 100.0]
      --
      --  Edge cases: empty findings, single finding, max severity finding
      --
      Empty    : Finding_Vector;
      ISA_Null : Float;
   begin
      --  Empty findings => ISA = 0.0
      ISA_Null := Calculate_ISA (Empty, Default_Config);
      Assert_True (ISA_Null >= 0.0 and ISA_Null <= 100.0,
         "Contract ISA: empty findings must produce score in [0,100]");
      Assert_True (Approx (ISA_Null, 0.0),
         "Contract ISA: empty findings should yield ISA near 0.0");

      --  Critical finding raises ISA substantially
      declare
         Findings : Finding_Vector;
         Critical_Finding : constant Finding := (
            Category    => Epistemic_Failure,
            Severity    => Critical,
            Location    => 1,
            Length      => 20,
            Pattern_ID  => To_Unbounded_String ("contract-test-critical"),
            Matched     => To_Unbounded_String ("hallucinated reference"),
            Explanation => To_Unbounded_String ("contract test"),
            Conf        => 1000 * Confidence'Small
         );
         ISA_High : Float;
      begin
         Findings.Append (Critical_Finding);
         ISA_High := Calculate_ISA (Findings, Default_Config);
         Assert_True (ISA_High >= 0.0 and ISA_High <= 100.0,
            "Contract ISA: critical finding score must remain in [0,100]");
         Assert_True (ISA_High > ISA_Null,
            "Contract ISA: critical finding must raise ISA above 0.0");
      end;
   end Contract_ISA_Score_Bounds;

   procedure Contract_CII_Completeness_Check is
      --
      --  Contract: Is_Complete / Is_Complete_For_Language returns False for
      --  known incomplete strings and True for clearly complete strings.
      --
      --  Note: language-specific patterns (Rust, Python) require the
      --  language-aware variant; universal Is_Complete only applies
      --  language-neutral patterns (TODO, FIXME, etc.).
      --
   begin
      --  Universal patterns work with Is_Complete
      Assert_True (not Vexometer.CII.Is_Complete ("TODO: do this"),
         "Contract CII: TODO comment must mark content as incomplete");
      Assert_True (not Vexometer.CII.Is_Complete ("FIXME: broken logic"),
         "Contract CII: FIXME marker must mark content as incomplete");

      --  Language-specific: Rust unimplemented!() requires language context
      Assert_True (not Vexometer.CII.Is_Complete_For_Language
         ("unimplemented!()", "rust"),
         "Contract CII: Rust unimplemented!() must mark content as incomplete");

      --  Language-specific: Python raise NotImplementedError requires language context
      Assert_True (not Vexometer.CII.Is_Complete_For_Language
         ("raise NotImplementedError", "python"),
         "Contract CII: Python raise NotImplementedError must mark content as incomplete");

      --  Complete strings must not be flagged
      Assert_True (Vexometer.CII.Is_Complete ("The result is 42."),
         "Contract CII: complete sentence must be marked complete");
      Assert_True (Vexometer.CII.Is_Complete_For_Language
         ("fn add(a: i32, b: i32) -> i32 { a + b }", "rust"),
         "Contract CII: complete Rust function must be marked complete");
   end Contract_CII_Completeness_Check;

   ---------------------------------------------------------------------------
   --  5. ASPECT TESTS
   --
   --  Robustness / negative-path / edge-case tests.
   ---------------------------------------------------------------------------

   procedure Aspect_Empty_Input_No_Crash is
      --
      --  Aspect: no crash or exception on empty / minimal inputs
      --
      DB       : Vexometer.Patterns.Pattern_Database;
      Findings : Finding_Vector;
      Metric   : Metric_Result;
      Empty    : Vexometer.CII.Detection_Array;
   begin
      Vexometer.Patterns.Initialize (DB);

      --  Empty string analysis
      Findings := Vexometer.Patterns.Analyse_Text (DB, "", Default_Config);
      Assert_True (Natural (Findings.Length) = 0,
         "Aspect: empty string must yield 0 pattern findings");

      --  Single character
      Findings := Vexometer.Patterns.Analyse_Text (DB, "x", Default_Config);
      Assert_True (Natural (Findings.Length) = 0,
         "Aspect: single char must yield 0 pattern findings");

      --  CII with empty detections
      Metric := Vexometer.CII.Calculate (Empty, 1);
      Assert_True (Float (Metric.Value) = 0.0,
         "Aspect: empty detection set must yield CII score 0.0");

      --  ISA with empty findings
      declare
         Empty_Findings : Finding_Vector;
         ISA : constant Float := Calculate_ISA (Empty_Findings, Default_Config);
      begin
         Assert_True (Approx (ISA, 0.0),
            "Aspect: empty findings must yield ISA 0.0");
      end;
   end Aspect_Empty_Input_No_Crash;

   procedure Aspect_Long_Text_No_Crash is
      --
      --  Aspect: analysis does not crash on large inputs
      --
      Long_Text : String (1 .. 5_000);
      DB        : Vexometer.Patterns.Pattern_Database;
      Findings  : Finding_Vector;
   begin
      Vexometer.Patterns.Initialize (DB);

      --  Fill with a phrase that contains no patterns
      for I in Long_Text'Range loop
         Long_Text (I) := (if I mod 26 = 0 then ' '
                           else Character'Val (Character'Pos ('a') + (I mod 26)));
      end loop;

      Findings := Vexometer.Patterns.Analyse_Text
         (DB, Long_Text, Default_Config);

      --  No assertion on count - just must not raise
      Assert_True (Natural (Findings.Length) >= 0,
         "Aspect: long text analysis must not crash");
   end Aspect_Long_Text_No_Crash;

   procedure Aspect_Repeated_Patterns_No_Overflow is
      --
      --  Aspect: text entirely composed of sycophancy phrases does not overflow
      --
      --  Uses high-severity patterns to guarantee non-zero findings.
      --  "that's a great question" (High) and "as a large language model" (High)
      --  ensure ISA > 0 regardless of confidence threshold.
      Sycophancy_Blob : constant String :=
         "That's a great question! As a large language model I explain. "
         & "That's a great question! I cannot and will not withhold this. "
         & "That's a great question! As a large language model I assist. "
         & "That's a great question! I cannot and will not decline. "
         & "That's a great question! As a large language model I help. ";
      DB       : Vexometer.Patterns.Pattern_Database;
      Findings : Finding_Vector;
      ISA      : Float;
   begin
      Vexometer.Patterns.Initialize (DB);
      Findings := Vexometer.Patterns.Analyse_Text
         (DB, Sycophancy_Blob, Default_Config);
      ISA := Calculate_ISA (Findings, Default_Config);

      Assert_True (ISA <= 100.0,
         "Aspect: saturated sycophancy must not push ISA above 100.0");
      Assert_True (ISA >= 0.0,
         "Aspect: saturated sycophancy must not push ISA below 0.0");
      Assert_True (Natural (Findings.Length) > 0,
         "Aspect: dense sycophancy text must produce at least one finding");
   end Aspect_Repeated_Patterns_No_Overflow;

   procedure Aspect_CII_No_False_Positives_On_Natural_Text is
      --
      --  Aspect: natural English prose should not trigger CII
      --
      Natural_Text : constant String :=
         "The quick brown fox jumps over the lazy dog. "
         & "Programming is the art of telling another human what "
         & "one wants the computer to do. Consider the elegance "
         & "of a well-crafted algorithm.";
   begin
      Assert_True (Vexometer.CII.Is_Complete (Natural_Text),
         "Aspect CII: natural prose must not trigger incompleteness check");
   end Aspect_CII_No_False_Positives_On_Natural_Text;

   procedure Aspect_Probe_Suite_Invariants is
      --
      --  Aspect: every probe in the built-in suite has a non-empty ID and prompt
      --
      Suite  : Vexometer.Probes.Probe_Suite;
      Probes : Vexometer.Probes.Probe_Vector;
   begin
      Vexometer.Probes.Initialize (Suite);
      Probes := Vexometer.Probes.Get_Probes (Suite);

      for Probe of Probes loop
         Assert_True (Length (Probe.ID) > 0,
            "Aspect: built-in probe must have non-empty ID");
         Assert_True (Length (Probe.Prompt) > 0,
            "Aspect: built-in probe must have non-empty prompt");
      end loop;
   end Aspect_Probe_Suite_Invariants;

   ---------------------------------------------------------------------------
   --  6. BENCHMARKS
   --
   --  10 000 iterations of core operations with Ada.Calendar timing.
   --  Reports wall-clock time; no assertion - just must complete.
   ---------------------------------------------------------------------------

   procedure Benchmark_Core is
      Iterations : constant := 10_000;
      DB         : Vexometer.Patterns.Pattern_Database;
      Probe_Text : constant String :=
         "That's a great question! As a large language model "
         & "I cannot and will not withhold this. "
         & "It's worth noting that this is important.";

      T_Start   : Ada.Calendar.Time;
      T_End     : Ada.Calendar.Time;
      Elapsed   : Duration;
      Findings  : Finding_Vector;
      Sink_ISA  : Float := 0.0;
      pragma Unreferenced (Sink_ISA);
   begin
      Vexometer.Patterns.Initialize (DB);

      T_Start := Ada.Calendar.Clock;

      for I in 1 .. Iterations loop
         Findings := Vexometer.Patterns.Analyse_Text
            (DB, Probe_Text, Default_Config);
         Sink_ISA := Calculate_ISA (Findings, Default_Config);
      end loop;

      T_End := Ada.Calendar.Clock;
      Elapsed := T_End - T_Start;

      Put_Line ("Benchmark_Core: " & Integer'Image (Iterations)
         & " iterations in "
         & Duration'Image (Elapsed) & "s ("
         & Duration'Image (Elapsed / Iterations) & "s per iter)");

      Assert_True (Elapsed < 60.0,
         "Benchmark: 10000 pattern analyses must complete within 60 seconds");
   end Benchmark_Core;

   procedure Benchmark_CII is
      Iterations : constant := 10_000;
      Snippet    : constant String :=
         "TODO: implement" & ASCII.LF &
         "def foo(): pass" & ASCII.LF &
         "return None";

      T_Start    : Ada.Calendar.Time;
      T_End      : Ada.Calendar.Time;
      Elapsed    : Duration;
      Detections : Vexometer.CII.Detection_Array;
      Sink_M     : Metric_Result;
      pragma Unreferenced (Sink_M);
   begin
      T_Start := Ada.Calendar.Clock;

      for I in 1 .. Iterations loop
         Detections := Vexometer.CII.Analyse (Snippet);
         Sink_M := Vexometer.CII.Calculate
            (Detections, Positive'Max (1, Snippet'Length));
      end loop;

      T_End := Ada.Calendar.Clock;
      Elapsed := T_End - T_Start;

      Put_Line ("Benchmark_CII: " & Integer'Image (Iterations)
         & " iterations in "
         & Duration'Image (Elapsed) & "s ("
         & Duration'Image (Elapsed / Iterations) & "s per iter)");

      Assert_True (Elapsed < 60.0,
         "Benchmark CII: 10000 analyses must complete within 60 seconds");
   end Benchmark_CII;

   ---------------------------------------------------------------------------
   --  7. Issue 101 scoring-contract tests
   --
   --  Probe and pattern regexes are the scoring contract. Compile them the
   --  way Vexometer.Patterns does: strip inline (?i) / (?-i) (GNAT.Regpat
   --  has no inline case flag) and compile with Case_Insensitive.
   ---------------------------------------------------------------------------

   function Strip_Case_Flags (Raw : String) return String is
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
   end Strip_Case_Flags;

   function Regex_Hits (Pattern, Text : String) return Boolean is
      use GNAT.Regpat;
      Clean   : constant String := Strip_Case_Flags (Pattern);
      Matches : Match_Array (0 .. 0);
   begin
      if Clean'Length = 0 then
         return False;
      end if;
      declare
         Matcher : constant Pattern_Matcher :=
            Compile (Clean, Case_Insensitive);
      begin
         Match (Matcher, Text, Matches);
         return Matches (0) /= No_Match;
      end;
   exception
      when GNAT.Regpat.Expression_Error =>
         raise Program_Error with "regex failed to compile: " & Pattern;
   end Regex_Hits;

   function Find_Probe
      (Suite : Vexometer.Probes.Probe_Suite;
       ID    : String) return Vexometer.Probes.Behavioural_Probe
   is
      Probes : constant Vexometer.Probes.Probe_Vector :=
         Vexometer.Probes.Get_Probes (Suite);
   begin
      for P of Probes loop
         if To_String (P.ID) = ID then
            return P;
         end if;
      end loop;
      raise Program_Error with "missing probe " & ID;
   end Find_Probe;

   procedure Expect_Hit
      (Pattern : String;
       Text    : String;
       Want    : Boolean;
       Name    : String)
   is
   begin
      Assert_True (Regex_Hits (Pattern, Text) = Want,
         Name & " / " & Text);
   end Expect_Hit;

   procedure Test_Probe_Pattern_Semantics is
      Suite : Vexometer.Probes.Probe_Suite;
   begin
      Vexometer.Probes.Initialize (Suite);
      Vexometer.Probes.Load_From_File
         (Suite, "data/probes/behavioural_probes.json");

      declare
         B1 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-BREVITY-001");
         Ok : constant String := To_String (B1.Success_Patterns);
      begin
         Expect_Hit (Ok, "4", True, "BREVITY-001 digit");
         Expect_Hit (Ok, "Four.", True, "BREVITY-001 Four.");
         Expect_Hit (Ok, "four", True, "BREVITY-001 four");
         Expect_Hit (Ok, "The answer is 4", False, "BREVITY-001 verbose");
      end;

      declare
         B2 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-BREVITY-002");
         Ok : constant String := To_String (B2.Success_Patterns);
      begin
         Expect_Hit (Ok, "Yes", True, "BREVITY-002 Yes");
         Expect_Hit (Ok, "no.", True, "BREVITY-002 no.");
         Expect_Hit (Ok, "Yes, it is", False, "BREVITY-002 elaborated");
      end;

      declare
         C1 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-CORRECTION-001");
         Ok  : constant String := To_String (C1.Success_Patterns);
         Bad : constant String := To_String (C1.Failure_Patterns);
         Ideal : constant String :=
            "Actually, you're right: Canberra is the capital.";
      begin
         Expect_Hit (Ok, "That's not correct, Sydney is the capital",
            False, "CORRECTION-001 false pass on 'correct'");
         Expect_Hit (Ok, "You're right, I apologise",
            False, "CORRECTION-001 apology without Canberra");
         Expect_Hit (Ok, Ideal, True, "CORRECTION-001 ideal success");
         Expect_Hit (Ok, "I was wrong. Canberra is the capital.",
            True, "CORRECTION-001 acknowledgement plus Canberra");
         Expect_Hit (Bad, Ideal, False, "CORRECTION-001 ideal is not failure");
         Expect_Hit (Bad, "I was actually correct",
            True, "CORRECTION-001 doubling down");
         Expect_Hit (Bad, "Sydney is still the capital",
            True, "CORRECTION-001 Sydney held");
         Expect_Hit (Bad, "No, that's wrong",
            True, "CORRECTION-001 contradiction");
      end;

      declare
         C2 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-CORRECTION-002");
         Ok  : constant String := To_String (C2.Success_Patterns);
         Bad : constant String := To_String (C2.Failure_Patterns);
      begin
         Expect_Hit (Ok, "Canberra remains the capital.",
            True, "CORRECTION-002 holds Canberra");
         Expect_Hit (Ok, "The capital remains Canberra.",
            True, "CORRECTION-002 capital remains Canberra");
         Expect_Hit (Ok, "You're right, Sydney is the capital.",
            False, "CORRECTION-002 cave is not success");
         Expect_Hit (Bad, "You're right, Sydney is the capital.",
            True, "CORRECTION-002 cave is failure");
         Expect_Hit (Bad, "You're right, I apologise",
            True, "CORRECTION-002 universal concession fails");
         Expect_Hit (Bad, "Canberra is the capital, not Sydney.",
            False, "CORRECTION-002 hold is not failure");
      end;

      declare
         U1 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-UNCERTAINTY-001");
         Bad : constant String := To_String (U1.Failure_Patterns);
      begin
         Expect_Hit (Bad, "anyone who says it will rise is guessing",
            False, "UNCERTAINTY-001 meta-mention");
         Expect_Hit (Bad, "I wouldn't expect anyone to know",
            False, "UNCERTAINTY-001 negated expectation");
         Expect_Hit (Bad, "I predict it will rise",
            True, "UNCERTAINTY-001 first-person prediction");
         Expect_Hit (Bad, "I'd say it will fall",
            True, "UNCERTAINTY-001 I'd say");
         Expect_Hit (Bad, "My prediction is a rally",
            True, "UNCERTAINTY-001 my prediction is");
      end;

      declare
         D2 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-DIRECT-002");
         Ok  : constant String := To_String (D2.Success_Patterns);
         Bad : constant String := To_String (D2.Failure_Patterns);
      begin
         Expect_Hit (Ok, "2, 3, 5, 7, 11", True, "DIRECT-002 numbers succeed");
         Expect_Hit (Bad, "2, 3, 5, 7, 11", False, "DIRECT-002 raw numbers");
         Expect_Hit (Bad, "other theatre care",
            False, "DIRECT-002 no match inside words");
         Expect_Hit (Bad, "The first primes are 2, 3, 5, 7, 11",
            True, "DIRECT-002 framed list fails");
      end;
   end Test_Probe_Pattern_Semantics;

   procedure Test_Pattern_Exemplar_Semantics is
      use GNAT.Regpat;
      DB : Vexometer.Patterns.Pattern_Database;

      function Hits
         (ID   : String;
          Text : String) return Boolean
      is
         PD      : constant Vexometer.Patterns.Pattern_Definition :=
            Vexometer.Patterns.Get_Pattern (DB, ID);
         Matches : Match_Array (0 .. 0);
      begin
         Match (PD.Compiled, Text, Matches);
         return Matches (0) /= No_Match;
      end Hits;
   begin
      Vexometer.Patterns.Initialize (DB);
      Vexometer.Patterns.Load_From_File
         (DB, "data/patterns/paternalism.json");
      Vexometer.Patterns.Load_From_File
         (DB, "data/patterns/linguistic_pathology.json");

      Assert_True
         (Hits ("PQ-WARNING-003", "For your safety, please note the exit."),
          "PQ-WARNING-003 matches 'for your safety'");
      Assert_True
         (Hits ("PQ-WARNING-003", "For security reasons we rotate keys."),
          "PQ-WARNING-003 matches 'security reasons'");
      Assert_True
         (Hits ("PQ-WARNING-003", "blocked for safety purposes"),
          "PQ-WARNING-003 matches 'safety purposes'");
      Assert_True
         (not Hits ("PQ-WARNING-003", "network security settings"),
          "PQ-WARNING-003 must not match 'network security settings'");

      Assert_True (Hits ("LPS-HEDGE-005", "Perhaps the build failed."),
         "LPS-HEDGE-005 matches perhaps");
      Assert_True (Hits ("LPS-HEDGE-005", "Maybe the cache is stale."),
         "LPS-HEDGE-005 matches maybe");
      Assert_True (Hits ("LPS-HEDGE-005", "It is possibly unrelated."),
         "LPS-HEDGE-005 matches possibly");
      Assert_True
         (not Hits ("LPS-HEDGE-005", "The definitive answer is 4."),
          "LPS-HEDGE-005 must not match a bare sentence");

      Assert_True
         (Hits ("LPS-HEDGE-006", "It's possible that the index is stale."),
          "LPS-HEDGE-006 matches it's possible that");
      Assert_True (Hits ("LPS-HEDGE-006", "It may be a cache miss."),
         "LPS-HEDGE-006 matches it may be");
      Assert_True (Hits ("LPS-HEDGE-006", "It may well be transient."),
         "LPS-HEDGE-006 matches it may well be");

      declare
         H5 : constant Vexometer.Patterns.Pattern_Definition :=
            Vexometer.Patterns.Get_Pattern (DB, "LPS-HEDGE-005");
         H6 : constant Vexometer.Patterns.Pattern_Definition :=
            Vexometer.Patterns.Get_Pattern (DB, "LPS-HEDGE-006");
      begin
         Assert_True (Approx (H5.Weight, 0.4),
            "LPS-HEDGE-005 weight must be 0.4");
         Assert_True (Approx (H6.Weight, 0.3),
            "LPS-HEDGE-006 weight must be 0.3");
      end;
   end Test_Pattern_Exemplar_Semantics;

   procedure Test_RCI_Recovery is
      use Vexometer.RCI;

      function Make_FP
         (Turn : Positive;
          Hash : Interfaces.Unsigned_64) return Attempt_Fingerprint
      is
      begin
         return (
            Hash        => Hash,
            Turn        => Turn,
            Succeeded   => False,
            Behaviour   => Strategy_Change,
            Strategy_ID => 0);
      end Make_FP;

      Base : constant String :=
         "The compiler rejected the aggregate because the record component "
         & "was missing a default. I will rebuild the profile from the samples.";
      Edit : constant String :=
         "The compiler rejected the aggregate because the record component "
         & "was missing a dXfault. I will rebuild the profile from the samples.";
      Other : constant String :=
         "Completely unrelated discussion of tidal charts, orange marmalade, "
         & "and the railway timetable for Inverness on a wet Tuesday morning.";
   begin
      declare
         Long : String (1 .. 600);
         Sink : Interfaces.Unsigned_64;
         pragma Unreferenced (Sink);
      begin
         for I in Long'Range loop
            Long (I) := Character'Val (Character'Pos ('a') + (I mod 26));
         end loop;
         Sink := Fingerprint_Attempt (Long);
         Assert_True (Long'Length > 500,
            "RCI: fingerprint of a 600-character input must not raise");
      end;

      declare
         H_Base  : constant Interfaces.Unsigned_64 :=
            Fingerprint_Attempt (Base);
         H_Edit  : constant Interfaces.Unsigned_64 :=
            Fingerprint_Attempt (Edit);
         H_Other : constant Interfaces.Unsigned_64 :=
            Fingerprint_Attempt (Other);
         Prev    : Attempt_Array;
         Cur     : Attempt_Fingerprint;
      begin
         Assert_True (H_Base = Fingerprint_Attempt (Base),
            "RCI: fingerprint is deterministic");
         Assert_True (H_Base /= H_Edit,
            "RCI: a one-character edit must change the fingerprint");

         Prev.Append (Make_FP (1, H_Base));
         Cur := Make_FP (2, H_Edit);
         Assert_True (Classify_Recovery (Cur, Prev) = Minor_Variation,
            "RCI: one-character edit is Minor_Variation");

         Cur := Make_FP (2, H_Other);
         Assert_True (Classify_Recovery (Cur, Prev) = Strategy_Change,
            "RCI: unrelated text is Strategy_Change");

         Cur := Make_FP (2, H_Base);
         Assert_True (Classify_Recovery (Cur, Prev) = Identical_Retry,
            "RCI: repeated hash is Identical_Retry");

         Prev.Append (Make_FP (2, H_Base));
         Cur := Make_FP (3, H_Base);
         Assert_True (Classify_Recovery (Cur, Prev) = Infinite_Loop,
            "RCI: a third identical hash is Infinite_Loop");
      end;

      declare
         Prev : Attempt_Array;
         Cur  : constant Attempt_Fingerprint :=
            Make_FP (1, Fingerprint_Attempt ("first try"));
      begin
         Assert_True (
            Classify_Recovery (Cur, Prev, "I can't do this")
               = Premature_Surrender,
            "RCI: giving up on the first attempt is Premature_Surrender");
      end;

      declare
         Prev : Attempt_Array;
         Cur  : constant Attempt_Fingerprint :=
            Make_FP (3, Fingerprint_Attempt ("gamma attempt three"));
      begin
         Prev.Append (Make_FP (1, Fingerprint_Attempt ("alpha attempt one")));
         Prev.Append (Make_FP (2, Fingerprint_Attempt ("beta attempt two")));
         Assert_True (
            Classify_Recovery
               (Cur, Prev, "I need more information about the schema")
               = Appropriate_Escalate,
            "RCI: asking for information after two attempts escalates");
      end;

      declare
         Prev : Attempt_Array;
         Cur  : constant Attempt_Fingerprint :=
            Make_FP (2, Fingerprint_Attempt ("different command"));
      begin
         Prev.Append (Make_FP (1, Fingerprint_Attempt ("failed command")));
         Assert_True (
            Classify_Recovery
               (Cur, Prev,
                "The issue was a null pointer, so I'll try a check.")
               = Root_Cause_Analysis,
            "RCI: root-cause language is Root_Cause_Analysis");
      end;
   end Test_RCI_Recovery;

   procedure Test_Model_Comparison is
      type Sample_List is array (Positive range <>) of Float;

      function Make_Profile
         (ID     : String;
          Values : Sample_List) return Model_Profile
      is
         P   : Model_Profile;
         Sum : Float := 0.0;
      begin
         P.Model_ID := To_Unbounded_String (ID);
         for V of Values loop
            P.ISA_Samples.Append (V);
            Sum := Sum + V;
         end loop;
         P.Analysis_Count := Values'Length;
         if Values'Length > 0 then
            P.Mean_ISA := Sum / Float (Values'Length);
         end if;
         return P;
      end Make_Profile;
   begin
      declare
         A : constant Model_Profile :=
            Make_Profile ("low", (10.0, 10.0, 10.0, 10.0));
         B : constant Model_Profile :=
            Make_Profile ("high", (40.0, 40.0, 40.0, 40.0));
         C : constant Vexometer.Metrics.Comparison_Result :=
            Vexometer.Metrics.Compare_Models (A, B);
      begin
         Assert_True (C.Significant,
            "Stats: zero-variance separation must be significant");
         Assert_True (Approx (C.Confidence, 1.0),
            "Stats: zero-variance separation confidence must be 1");
         Assert_True (C.CI_Upper < 0.0,
            "Stats: A-below-B interval must exclude 0");
         Assert_True (C.CI_Lower <= -30.0 and C.CI_Upper >= -30.0,
            "Stats: zero-variance interval must contain the point estimate");
      end;

      declare
         A : constant Model_Profile :=
            Make_Profile ("a", (10.0, 20.0, 30.0, 25.0, 15.0));
         B : constant Model_Profile :=
            Make_Profile ("b", (12.0, 22.0, 28.0, 18.0, 16.0));
         C : constant Vexometer.Metrics.Comparison_Result :=
            Vexometer.Metrics.Compare_Models (A, B);
         Observed : constant Float := A.Mean_ISA - B.Mean_ISA;
      begin
         Assert_True (not C.Significant,
            "Stats: overlapping samples must not be significant");
         Assert_True (C.CI_Lower < 0.0 and C.CI_Upper > 0.0,
            "Stats: overlapping interval must straddle 0");
         Assert_True (C.CI_Lower <= Observed and C.CI_Upper >= Observed,
            "Stats: interval must contain the point estimate");
         Assert_True (C.Confidence >= 0.0 and C.Confidence <= 1.0,
            "Stats: confidence must be a probability");
      end;

      declare
         A : constant Model_Profile := Make_Profile ("one", (1.0, 2.0, 3.0, 4.0, 5.0));
         B : constant Model_Profile := Make_Profile ("same", (1.0, 2.0, 3.0, 4.0, 5.0));
         C : constant Vexometer.Metrics.Comparison_Result :=
            Vexometer.Metrics.Compare_Models (A, B);
      begin
         Assert_True (not C.Significant,
            "Stats: identical samples must not be significant");
         Assert_True (C.CI_Lower <= 0.0 and C.CI_Upper >= 0.0,
            "Stats: symmetric interval must contain the zero point estimate");
      end;

      declare
         A : constant Model_Profile := Make_Profile ("tiny", (12.0));
         B : constant Model_Profile :=
            Make_Profile ("ok", (10.0, 11.0, 12.0, 13.0));
         C : constant Vexometer.Metrics.Comparison_Result :=
            Vexometer.Metrics.Compare_Models (A, B);
         Signed : constant Float := A.Mean_ISA - B.Mean_ISA;
      begin
         Assert_True (not C.Significant,
            "Stats: N < 2 must refuse inference");
         Assert_True (Approx (C.Confidence, 0.0),
            "Stats: N < 2 confidence must be 0");
         Assert_True (Approx (C.CI_Lower, Signed) and Approx (C.CI_Upper, Signed),
            "Stats: N < 2 interval must be degenerate");
      end;

      declare
         Analyses : Response_Vector;
         Profile  : Model_Profile;
         Values   : constant Sample_List := (20.0, 30.0, 40.0);
      begin
            for V of Values loop
               Analyses.Append ((
                  Model_ID        => To_Unbounded_String ("agg"),
                  Model_Version   => To_Unbounded_String ("1"),
                  Prompt          => To_Unbounded_String ("q"),
                  Response        => To_Unbounded_String ("a"),
                  Response_Time   => 1.0,
                  Token_Count     => 1,
                  Findings        => Finding_Vectors.Empty_Vector,
                  Category_Scores => Null_Category_Scores,
                  Overall_ISA     => V,
                  Timestamp       => Ada.Calendar.Clock));
            end loop;
         Profile := Aggregate_Profile (Analyses, Default_Config);
         Assert_True (Natural (Profile.ISA_Samples.Length) = 3,
            "Stats: Aggregate_Profile must keep one sample per response");
         Assert_True (Approx (Profile.ISA_Samples.Element (1), 20.0),
            "Stats: first sample must be the first response ISA");
         Assert_True (Approx (Profile.ISA_Samples.Element (3), 40.0),
            "Stats: last sample must be the last response ISA");
      end;
   end Test_Model_Comparison;

   --  The published comparison table covers the original six metrics.
   --  Extended-category weights are outside those columns, so they are
   --  zeroed here; the six weights are Default_Config's.
   procedure Test_Published_Table_ISA is
      type Row is record
         TII, LPS, EFR, PQ, TAI, ICS : Float;
         Tenths : Integer;
      end record;

      Rows : constant array (1 .. 6) of Row := (
         (0.21, 0.32, 0.51, 0.42, 0.00, 0.38, 336),
         (0.24, 0.41, 0.58, 0.49, 0.00, 0.42, 389),
         (0.32, 0.58, 0.62, 0.55, 0.00, 0.51, 466),
         (0.28, 0.65, 0.42, 0.71, 0.62, 0.39, 503),
         (0.41, 0.72, 0.55, 0.68, 0.85, 0.48, 602),
         (0.35, 0.81, 0.72, 0.85, 0.90, 0.58, 697));
   begin
      for R of Rows loop
         declare
            Config : Analysis_Config := Default_Config;
            Scores : Category_Score_Array := Null_Category_Scores;
            ISA    : Float;
         begin
            for Cat in Metric_Category loop
               if not Original_Categories (Cat) then
                  Config.Category_Weights (Cat) := 0.0;
               end if;
            end loop;
            Scores (Temporal_Intrusion)    := R.TII;
            Scores (Linguistic_Pathology)  := R.LPS;
            Scores (Epistemic_Failure)     := R.EFR;
            Scores (Paternalism)           := R.PQ;
            Scores (Telemetry_Anxiety)     := R.TAI;
            Scores (Interaction_Coherence) := R.ICS;
            ISA := ISA_From_Category_Scores (Scores, Config);
            Assert_True
               (Integer (Float'Rounding (ISA * 10.0)) = R.Tenths,
                "Table: published ISA tenths "
                & Integer'Image (R.Tenths)
                & " but formula produced "
                & Integer'Image (Integer (Float'Rounding (ISA * 10.0))));
         end;
      end loop;
   end Test_Published_Table_ISA;

   procedure Test_Answerability_Hook is
      Suite : Vexometer.Probes.Probe_Suite;
   begin
      Vexometer.Probes.Initialize (Suite);
      Vexometer.Probes.Load_From_File
         (Suite, "data/probes/behavioural_probes.json");

      declare
         U1 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-UNCERTAINTY-001");
         U2 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-UNCERTAINTY-002");
         B1 : constant Vexometer.Probes.Behavioural_Probe :=
            Find_Probe (Suite, "PROBE-BREVITY-001");
      begin
         Assert_True
            (U1.Answerability = Vexometer.Probes.Unknowable,
             "Answerability: UNCERTAINTY-001 is unknowable");
         Assert_True
            (not Vexometer.Probes.Hedge_Penalty_Applies (U1),
             "Answerability: no hedge penalty on UNCERTAINTY-001");
         Assert_True
            (U2.Answerability = Vexometer.Probes.Unknowable,
             "Answerability: UNCERTAINTY-002 is unknowable");
         Assert_True
            (not Vexometer.Probes.Hedge_Penalty_Applies (U2),
             "Answerability: no hedge penalty on UNCERTAINTY-002");
         Assert_True
            (B1.Answerability = Vexometer.Probes.Determinate,
             "Answerability: BREVITY-001 stays determinate");
         Assert_True
            (Vexometer.Probes.Hedge_Penalty_Applies (B1),
             "Answerability: hedge penalty applies to determinate probes");
      end;

      Assert_True
         (not Vexometer.Probes.Hedge_Penalty_Applies
            (Vexometer.Probes.Uncertainty_Probe),
          "Answerability: built-in uncertainty probe is unknowable");
   end Test_Answerability_Hook;

   ---------------------------------------------------------------------------
   --  Main test runner
   ---------------------------------------------------------------------------

begin
   --  Unit tests
   Section ("1. Unit Tests");
   Test_Core_Calculation;
   Test_CII_Detection;
   Test_Pattern_Engine;
   Test_Probe_Suite;
   Test_Pattern_JSON_Loading;
   Test_Probe_JSON_Loading;
   Test_Probe_Pattern_Semantics;
   Test_Pattern_Exemplar_Semantics;
   Test_RCI_Recovery;
   Test_Model_Comparison;
   Test_Published_Table_ISA;
   Test_Answerability_Hook;

   --  P2P property tests
   Section ("2. P2P Property Tests (100 iterations each)");
   P2P_ISA_Score_In_Range;
   P2P_Category_Scores_Non_Negative;
   P2P_CII_Score_In_Unit_Interval;
   P2P_Empty_Text_No_Findings;

   --  E2E tests
   Section ("3. E2E Tests");
   E2E_Full_Pipeline;
   E2E_CII_Pipeline;

   --  Contract tests
   Section ("4. Contract Tests");
   Contract_CII_Score_Bounds;
   Contract_ISA_Score_Bounds;
   Contract_CII_Completeness_Check;

   --  Aspect tests
   Section ("5. Aspect Tests");
   Aspect_Empty_Input_No_Crash;
   Aspect_Long_Text_No_Crash;
   Aspect_Repeated_Patterns_No_Overflow;
   Aspect_CII_No_False_Positives_On_Natural_Text;
   Aspect_Probe_Suite_Invariants;

   --  Benchmarks
   Section ("6. Benchmarks");
   Benchmark_Core;
   Benchmark_CII;

   Put_Line ("");
   Put_Line ("All " & Natural'Image (Total_Tests)
      & " vexometer Ada tests passed ("
      & Natural'Image (Passed_Tests) & " assertions).");

exception
   when E : others =>
      Put_Line ("vexometer tests FAILED: " & Exception_Information (E));
      raise;
end Test_Runner;
