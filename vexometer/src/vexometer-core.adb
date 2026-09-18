--  Vexometer.Core - Core calculation implementations
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: MPL-2.0
--
--  Provides the fundamental ISA (Irritation Surface Analysis) calculation
--  engine. All scores are normalised 0-1 per category and weighted to
--  produce an overall ISA score in the range 0-100 (lower is better).

pragma Ada_2022;

with Ada.Numerics.Elementary_Functions;
with Ada.Containers.Generic_Array_Sort;

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
   --  computing mean, population standard deviation, and median for the
   --  ISA score and each category score across all analyses.
   --  The profile inherits model identity from the first analysis.
   ---------------------------------------------------------------------------

   function Aggregate_Profile
      (Analyses : Response_Vector;
       Config   : Analysis_Config := Default_Config) return Model_Profile
   is
      pragma Unreferenced (Config);

      package EF renames Ada.Numerics.Elementary_Functions;

      type Float_Array is array (Positive range <>) of Float;

      procedure Sort is new Ada.Containers.Generic_Array_Sort
         (Index_Type   => Positive,
          Element_Type => Float,
          Array_Type   => Float_Array);

      function Median_Of (Values : Float_Array) return Float is
         Sorted : Float_Array := Values;
         Mid    : constant Positive := Sorted'First + Sorted'Length / 2;
      begin
         Sort (Sorted);
         if Sorted'Length mod 2 = 1 then
            return Sorted (Mid);
         else
            return (Sorted (Mid - 1) + Sorted (Mid)) / 2.0;
         end if;
      end Median_Of;

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

      --  Standard deviations and medians. Two-pass form: sums of squared
      --  deviations cannot go negative, unlike E[x^2] - E[x]^2.
      declare
         ISA_Vals : Float_Array (1 .. N);
         ISA_SSD  : Float := 0.0;
         Cat_SSD  : Category_Score_Array := Null_Category_Scores;
         I        : Positive := 1;
      begin
         for A of Analyses loop
            ISA_Vals (I) := A.Overall_ISA;
            I := I + 1;
            ISA_SSD := ISA_SSD + (A.Overall_ISA - Profile.Mean_ISA) ** 2;
            for Cat in Metric_Category loop
               Cat_SSD (Cat) := Cat_SSD (Cat)
                  + (A.Category_Scores (Cat) - Profile.Category_Means (Cat)) ** 2;
            end loop;
         end loop;

         Profile.Std_Dev_ISA := EF.Sqrt (ISA_SSD / Float (N));
         Profile.Median_ISA  := Median_Of (ISA_Vals);

         for Cat in Metric_Category loop
            Profile.Category_Std_Devs (Cat) := EF.Sqrt (Cat_SSD (Cat) / Float (N));
         end loop;

         for Cat in Metric_Category loop
            declare
               Vals : Float_Array (1 .. N);
               J    : Positive := 1;
            begin
               for A of Analyses loop
                  Vals (J) := A.Category_Scores (Cat);
                  J := J + 1;
               end loop;
               Profile.Category_Medians (Cat) := Median_Of (Vals);
            end;
         end loop;
      end;

      --  Set identity fields from the first analysis element
      Profile.Analysis_Count := N;
      Profile.Model_ID       := Analyses.First_Element.Model_ID;
      Profile.Model_Version  := Analyses.First_Element.Model_Version;
      Profile.Evaluated_At   := Ada.Calendar.Clock;

      return Profile;
   end Aggregate_Profile;

end Vexometer.Core;
