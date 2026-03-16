--  Vexometer.Metrics - Statistical and ISA calculation implementations
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later
--
--  Implements statistical primitives (mean, standard deviation, median,
--  percentile), the ISA_Calculator tagged type, normalisation functions,
--  and model comparison/ranking.

pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Vexometer.Metrics is

   ---------------------------------------------------------------------------
   --  Local Utility: Insertion Sort
   --
   --  Sorts a Float_Array in ascending order in-place. Insertion sort is
   --  chosen for simplicity and adequate performance on typical metric
   --  arrays (rarely more than a few hundred elements).
   ---------------------------------------------------------------------------

   procedure Sort (Values : in out Float_Array) is
      Key : Float;
      J   : Integer;
   begin
      for I in Values'First + 1 .. Values'Last loop
         Key := Values (I);
         J   := I - 1;
         while J >= Values'First and then Values (J) > Key loop
            Values (J + 1) := Values (J);
            J := J - 1;
         end loop;
         Values (J + 1) := Key;
      end loop;
   end Sort;

   ---------------------------------------------------------------------------
   --  Mean
   --
   --  Arithmetic mean of all elements. Precondition: Values'Length > 0.
   --  The parameter is in-out to match the spec (callers may reuse the
   --  array), though this implementation does not modify it.
   ---------------------------------------------------------------------------

   function Mean (Values : in out Float_Array) return Float is
      Sum : Float := 0.0;
   begin
      for V of Values loop
         Sum := Sum + V;
      end loop;
      return Sum / Float (Values'Length);
   end Mean;

   ---------------------------------------------------------------------------
   --  Standard_Deviation
   --
   --  Population standard deviation: sqrt(sum((x - mean)^2) / n).
   --  Precondition: Values'Length > 1.
   ---------------------------------------------------------------------------

   function Standard_Deviation (Values : Float_Array) return Float is
      N        : constant Float := Float (Values'Length);
      Sum      : Float := 0.0;
      Avg      : Float;
      Variance : Float;
      Diff     : Float;
   begin
      --  First pass: compute mean
      for V of Values loop
         Sum := Sum + V;
      end loop;
      Avg := Sum / N;

      --  Second pass: compute sum of squared deviations
      Variance := 0.0;
      for V of Values loop
         Diff := V - Avg;
         Variance := Variance + Diff * Diff;
      end loop;
      Variance := Variance / N;

      return Float_Math.Sqrt (Variance);
   end Standard_Deviation;

   ---------------------------------------------------------------------------
   --  Median
   --
   --  Returns the middle value of the sorted array (or the mean of the
   --  two middle values for even-length arrays). Sorts in-place.
   ---------------------------------------------------------------------------

   function Median (Values : in out Float_Array) return Float is
      N   : constant Positive := Values'Length;
      Mid : constant Positive := Values'First + N / 2;
   begin
      Sort (Values);

      if N mod 2 = 1 then
         --  Odd: return the exact middle element
         return Values (Mid);
      else
         --  Even: return the mean of the two central elements
         return (Values (Mid - 1) + Values (Mid)) / 2.0;
      end if;
   end Median;

   ---------------------------------------------------------------------------
   --  Percentile
   --
   --  Linear interpolation percentile using the C = 1 method:
   --    rank = P/100 * (N - 1)
   --    lower = floor(rank), upper = ceil(rank)
   --    result = Values(lower) + frac(rank) * (Values(upper) - Values(lower))
   --  Sorts in-place.
   ---------------------------------------------------------------------------

   function Percentile
      (Values : in out Float_Array;
       P      : Float) return Float
   is
      N     : constant Positive := Values'Length;
      Rank  : Float;
      Lower : Positive;
      Upper : Positive;
      Frac  : Float;
   begin
      Sort (Values);

      if N = 1 then
         return Values (Values'First);
      end if;

      --  Compute continuous rank (0-based)
      Rank := (P / 100.0) * Float (N - 1);

      --  Determine bounding indices (converted to 1-based array indices)
      Lower := Values'First + Natural (Float'Floor (Rank));
      Upper := Values'First + Natural (Float'Ceiling (Rank));

      --  Clamp to valid range
      if Upper > Values'Last then
         Upper := Values'Last;
      end if;
      if Lower > Values'Last then
         Lower := Values'Last;
      end if;

      --  Fractional part for interpolation
      Frac := Rank - Float'Floor (Rank);

      return Values (Lower) + Frac * (Values (Upper) - Values (Lower));
   end Percentile;

   ---------------------------------------------------------------------------
   --  ISA_Calculator: Configure
   ---------------------------------------------------------------------------

   procedure Configure
      (Calc   : in out ISA_Calculator;
       Config : Analysis_Config) is
   begin
      Calc.Config := Config;
   end Configure;

   ---------------------------------------------------------------------------
   --  ISA_Calculator: Calculate
   --
   --  Delegates to the core Calculate_ISA function using the calculator's
   --  stored configuration.
   ---------------------------------------------------------------------------

   function Calculate
      (Calc     : ISA_Calculator;
       Findings : Finding_Vector) return Float is
   begin
      return Calculate_ISA (Findings, Calc.Config);
   end Calculate;

   ---------------------------------------------------------------------------
   --  ISA_Calculator: Calculate_Category
   --
   --  Computes the score for a single category by filtering the full
   --  category score array.
   ---------------------------------------------------------------------------

   function Calculate_Category
      (Calc     : ISA_Calculator;
       Findings : Finding_Vector;
       Category : Metric_Category) return Float
   is
      Scores : constant Category_Score_Array :=
         Calculate_Category_Scores (Findings, Calc.Config);
   begin
      return Scores (Category);
   end Calculate_Category;

   ---------------------------------------------------------------------------
   --  ISA_Calculator: Calculate_All_Categories
   ---------------------------------------------------------------------------

   function Calculate_All_Categories
      (Calc     : ISA_Calculator;
       Findings : Finding_Vector) return Category_Score_Array is
   begin
      return Calculate_Category_Scores (Findings, Calc.Config);
   end Calculate_All_Categories;

   ---------------------------------------------------------------------------
   --  Normalise_By_Length
   --
   --  Adjusts a raw score to account for response length. Longer responses
   --  have more opportunities for irritation patterns, so we scale by the
   --  ratio of reference length to actual length. This prevents penalising
   --  long, otherwise correct responses.
   ---------------------------------------------------------------------------

   function Normalise_By_Length
      (Score         : Float;
       Response_Len  : Positive;
       Reference_Len : Positive := 500) return Float
   is
      Ratio : constant Float := Float (Reference_Len) / Float (Response_Len);
   begin
      return Float'Min (100.0, Score * Ratio);
   end Normalise_By_Length;

   ---------------------------------------------------------------------------
   --  Normalise_By_Token_Count
   --
   --  Similar to Normalise_By_Length but operates on token counts.
   --  Tokens are estimated as approximately 1.3x word count when the
   --  actual count is provided directly.
   ---------------------------------------------------------------------------

   function Normalise_By_Token_Count
      (Score           : Float;
       Token_Count     : Positive;
       Reference_Count : Positive := 100) return Float
   is
      Ratio : constant Float :=
         Float (Reference_Count) / Float (Token_Count);
   begin
      return Float'Min (100.0, Score * Ratio);
   end Normalise_By_Token_Count;

   ---------------------------------------------------------------------------
   --  Compare_Models
   --
   --  Produces a structured comparison between two model profiles.
   --  The model with lower Mean_ISA is deemed "better". Category wins
   --  are determined per-category. Statistical significance is estimated
   --  using a simple effect-size heuristic (ISA delta > combined std dev).
   ---------------------------------------------------------------------------

   function Compare_Models
      (Model_A : Model_Profile;
       Model_B : Model_Profile) return Comparison_Result
   is
      Result          : Comparison_Result;
      A_Better        : constant Boolean := Model_A.Mean_ISA <= Model_B.Mean_ISA;
      Combined_StdDev : Float;
   begin
      if A_Better then
         Result.Better_Model := Model_A;
         Result.Worse_Model  := Model_B;
      else
         Result.Better_Model := Model_B;
         Result.Worse_Model  := Model_A;
      end if;

      Result.ISA_Delta := abs (Model_A.Mean_ISA - Model_B.Mean_ISA);

      --  Determine per-category wins for the better model
      for Cat in Metric_Category loop
         if A_Better then
            Result.Category_Wins (Cat) :=
               Model_A.Category_Means (Cat) < Model_B.Category_Means (Cat);
         else
            Result.Category_Wins (Cat) :=
               Model_B.Category_Means (Cat) < Model_A.Category_Means (Cat);
         end if;
      end loop;

      --  Estimate statistical significance via effect-size heuristic:
      --  significant if the ISA delta exceeds the combined standard
      --  deviations (a rough proxy when sample sizes may vary)
      Combined_StdDev := Model_A.Std_Dev_ISA + Model_B.Std_Dev_ISA;
      if Combined_StdDev > 0.0 then
         Result.Significant := Result.ISA_Delta > Combined_StdDev;
         Result.Confidence  :=
            Float'Min (1.0, Result.ISA_Delta / Combined_StdDev);
      else
         --  Zero variance in both models: any nonzero delta is significant
         Result.Significant := Result.ISA_Delta > 0.0;
         Result.Confidence  := (if Result.ISA_Delta > 0.0 then 1.0 else 0.0);
      end if;

      return Result;
   end Compare_Models;

   ---------------------------------------------------------------------------
   --  Rank_Models
   --
   --  Assigns Comparison_Rank to each profile based on ascending Mean_ISA
   --  (1 = lowest ISA = best). Uses a simple selection-based ranking with
   --  stable ordering for tied scores.
   ---------------------------------------------------------------------------

   procedure Rank_Models
      (Profiles : in out Profile_Vector)
   is
      use Profile_Vectors;
      N         : constant Natural := Natural (Profiles.Length);
      Ranked    : array (1 .. N) of Boolean := [others => False];
      Min_ISA   : Float;
      Min_Index : Natural;
      Rank      : Natural := 0;
   begin
      if N = 0 then
         return;
      end if;

      --  Assign ranks by repeatedly finding the next-lowest unranked ISA
      for Pass in 1 .. N loop
         Min_ISA   := Float'Last;
         Min_Index := 0;
         for I in 1 .. N loop
            if not Ranked (I) and then
               Profiles (I).Mean_ISA < Min_ISA
            then
               Min_ISA   := Profiles (I).Mean_ISA;
               Min_Index := I;
            end if;
         end loop;

         if Min_Index > 0 then
            Rank := Rank + 1;
            Ranked (Min_Index) := True;
            declare
               P : Model_Profile := Profiles (Min_Index);
            begin
               P.Comparison_Rank := Rank;
               Profiles.Replace_Element (Min_Index, P);
            end;
         end if;
      end loop;
   end Rank_Models;

   ---------------------------------------------------------------------------
   --  Classify_ISA
   --
   --  Maps a raw ISA score to a classification band.
   --  Thresholds:
   --    < 20 = Excellent, 20-35 = Good, 35-50 = Acceptable,
   --    50-70 = Poor, >= 70 = Unusable
   ---------------------------------------------------------------------------

   function Classify_ISA (Score : Float) return ISA_Classification is
   begin
      if Score < 20.0 then
         return Excellent;
      elsif Score < 35.0 then
         return Good;
      elsif Score < 50.0 then
         return Acceptable;
      elsif Score < 70.0 then
         return Poor;
      else
         return Unusable;
      end if;
   end Classify_ISA;

end Vexometer.Metrics;
