--  Vexometer.Core - Core calculation implementations
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later
--
--  Provides the fundamental ISA (Irritation Surface Analysis) calculation
--  engine. All scores are normalised 0-1 per category and weighted to
--  produce an overall ISA score in the range 0-100 (lower is better).

pragma Ada_2022;

package body Vexometer.Core is

   ---------------------------------------------------------------------------
   --  Calculate_Category_Scores
   --
   --  Computes per-category scores from a vector of findings. Each finding
   --  that meets the minimum confidence threshold contributes its severity
   --  weight to the corresponding category. Category scores are averaged
   --  across findings and clamped to [0.0, 1.0].
   ---------------------------------------------------------------------------

   function Calculate_Category_Scores
      (Findings : Finding_Vector;
       Config   : Analysis_Config := Default_Config) return Category_Score_Array
   is
      Result : Category_Score_Array := Null_Category_Scores;
      Count  : array (Metric_Category) of Natural := [others => 0];
   begin
      for F of Findings loop
         if Float (F.Conf) >= Config.Min_Confidence then
            Result (F.Category) := Result (F.Category) +
               Config.Severity_Weights (F.Severity);
            Count (F.Category) := Count (F.Category) + 1;
         end if;
      end loop;

      --  Normalise each category by its finding count, clamping to [0, 1]
      for Cat in Metric_Category loop
         if Count (Cat) > 0 then
            Result (Cat) := Float'Min (1.0,
               Result (Cat) / Float (Count (Cat)));
         end if;
      end loop;

      return Result;
   end Calculate_Category_Scores;

   ---------------------------------------------------------------------------
   --  Calculate_ISA
   --
   --  Produces a weighted composite ISA score from individual findings.
   --  The score is the weighted mean of category scores multiplied by 100,
   --  yielding a value in [0, 100]. Lower is better.
   ---------------------------------------------------------------------------

   function Calculate_ISA
      (Findings : Finding_Vector;
       Config   : Analysis_Config := Default_Config) return Float
   is
      Weighted_Sum : Float := 0.0;
      Total_Weight : Float := 0.0;
      Cat_Scores   : constant Category_Score_Array :=
         Calculate_Category_Scores (Findings, Config);
   begin
      for Cat in Metric_Category loop
         Weighted_Sum := Weighted_Sum +
            Cat_Scores (Cat) * Config.Category_Weights (Cat);
         Total_Weight := Total_Weight + Config.Category_Weights (Cat);
      end loop;

      if Total_Weight > 0.0 then
         return (Weighted_Sum / Total_Weight) * 100.0;
      else
         return 0.0;
      end if;
   end Calculate_ISA;

   ---------------------------------------------------------------------------
   --  Aggregate_Profile
   --
   --  Combines multiple response analyses into a single model profile,
   --  computing mean ISA and mean category scores across all analyses.
   --  The profile inherits model identity from the first analysis.
   ---------------------------------------------------------------------------

   function Aggregate_Profile
      (Analyses : Response_Vector;
       Config   : Analysis_Config := Default_Config) return Model_Profile
   is
      pragma Unreferenced (Config);

      Profile : Model_Profile;
      N       : constant Natural := Natural (Analyses.Length);
      Sums    : Category_Score_Array := Null_Category_Scores;
      ISA_Sum : Float := 0.0;
   begin
      if N = 0 then
         return Profile;
      end if;

      --  Accumulate sums for mean computation
      for A of Analyses loop
         ISA_Sum := ISA_Sum + A.Overall_ISA;
         for Cat in Metric_Category loop
            Sums (Cat) := Sums (Cat) + A.Category_Scores (Cat);
         end loop;
      end loop;

      --  Compute means
      Profile.Mean_ISA := ISA_Sum / Float (N);
      for Cat in Metric_Category loop
         Profile.Category_Means (Cat) := Sums (Cat) / Float (N);
      end loop;

      --  Set identity fields from the first analysis element
      Profile.Analysis_Count := N;
      Profile.Model_ID       := Analyses.First_Element.Model_ID;
      Profile.Model_Version  := Analyses.First_Element.Model_Version;

      return Profile;
   end Aggregate_Profile;

end Vexometer.Core;
