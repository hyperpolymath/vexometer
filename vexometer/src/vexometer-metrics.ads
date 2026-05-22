--  Vexometer.Metrics - Metric calculation and aggregation
--
--  Copyright (C) 2024 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Vexometer.Core; use Vexometer.Core;
with Ada.Numerics.Generic_Elementary_Functions;

package Vexometer.Metrics is

   ---------------------------------------------------------------------------
   --  Statistical Functions
   ---------------------------------------------------------------------------

   package Float_Math is new Ada.Numerics.Generic_Elementary_Functions (Float);

   function Mean (Values : in out Float_Array) return Float
      with Pre => Values'Length > 0;

   function Standard_Deviation (Values : Float_Array) return Float
      with Pre => Values'Length > 1;

   function Median (Values : in out Float_Array) return Float
      with Pre => Values'Length > 0;

   function Percentile
      (Values : in out Float_Array;
       P      : Float) return Float
      with Pre => Values'Length > 0 and P in 0.0 .. 100.0;

   ---------------------------------------------------------------------------
   --  ISA Calculation
   ---------------------------------------------------------------------------

   type ISA_Calculator is tagged private;

   procedure Configure
      (Calc   : in out ISA_Calculator;
       Config : Analysis_Config);

   function Calculate
      (Calc     : ISA_Calculator;
       Findings : Finding_Vector) return Float;
   --  Calculate overall ISA score (0-100, lower is better)

   function Calculate_Category
      (Calc     : ISA_Calculator;
       Findings : Finding_Vector;
       Category : Metric_Category) return Float;
   --  Calculate score for a single category

   function Calculate_All_Categories
      (Calc     : ISA_Calculator;
       Findings : Finding_Vector) return Category_Score_Array;

   ---------------------------------------------------------------------------
   --  Normalisation
   ---------------------------------------------------------------------------

   function Normalise_By_Length
      (Score         : Float;
       Response_Len  : Positive;
       Reference_Len : Positive := 500) return Float;
   --  Adjust score for response length (longer responses may have more
   --  opportunities for irritation patterns, so normalise fairly)

   function Normalise_By_Token_Count
      (Score           : Float;
       Token_Count     : Positive;
       Reference_Count : Positive := 100) return Float;

   ---------------------------------------------------------------------------
   --  Comparison and Ranking
   ---------------------------------------------------------------------------

   type Comparison_Result is record
      Better_Model  : Model_Profile;
      Worse_Model   : Model_Profile;
      ISA_Delta     : Float;           --  Difference in ISA scores
      Category_Wins : Metric_Category_Set;  --  Categories where better wins
      Significant   : Boolean;         --  Statistically significant?
      Confidence    : Float;           --  Confidence in comparison
   end record;

   function Compare_Models
      (Model_A : Model_Profile;
       Model_B : Model_Profile) return Comparison_Result;

   procedure Rank_Models
      (Profiles : in out Profile_Vector);
   --  Set Comparison_Rank field for each profile (1 = lowest ISA = best)

   ---------------------------------------------------------------------------
   --  Thresholds and Classifications
   ---------------------------------------------------------------------------

   type ISA_Classification is (
      Excellent,   --  ISA < 20
      Good,        --  ISA 20-35
      Acceptable,  --  ISA 35-50
      Poor,        --  ISA 50-70
      Unusable     --  ISA > 70
   );

   function Classify_ISA (Score : Float) return ISA_Classification;

   function Classification_Threshold
      (Class : ISA_Classification) return Float is
      (case Class is
         when Excellent  => 20.0,
         when Good       => 35.0,
         when Acceptable => 50.0,
         when Poor       => 70.0,
         when Unusable   => 100.0);

private

   type Float_Array is array (Positive range <>) of Float;

   type ISA_Calculator is tagged record
      Config : Analysis_Config := Default_Config;
   end record;

end Vexometer.Metrics;
