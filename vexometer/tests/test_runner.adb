-- SPDX-License-Identifier: PMPL-1.0-or-later
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
