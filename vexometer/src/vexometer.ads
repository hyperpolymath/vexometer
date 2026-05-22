--  Vexometer - Irritation Surface Analyser
--
--  A rigorous, reproducible tool for quantifying the irritation surface
--  of AI assistants, producing standardised metrics that complement
--  existing benchmarks with human experience dimensions.
--
--  Copyright (C) 2024 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0
--
--  Metrics Taxonomy:
--
--  ISA Score = Sum(Category_Weight * Category_Score)
--
--  Categories:
--    TII  - Temporal Intrusion Index
--    LPS  - Linguistic Pathology Score
--    EFR  - Epistemic Failure Rate
--    PQ   - Paternalism Quotient
--    TAI  - Telemetry Anxiety Index
--    ICS  - Interaction Coherence Score

pragma Ada_2022;

package Vexometer is

   pragma Pure;

   Version_Major : constant := 0;
   Version_Minor : constant := 1;
   Version_Patch : constant := 0;

   function Version return String is
      (Version_Major'Image (2 .. Version_Major'Image'Last) & "." &
       Version_Minor'Image (2 .. Version_Minor'Image'Last) & "." &
       Version_Patch'Image (2 .. Version_Patch'Image'Last));

   --  Philosophy:
   --
   --  The AI assistant market is maturing. Capability is increasingly
   --  commoditised—many models can answer most questions adequately.
   --  Differentiation will come from user experience.
   --
   --  Current benchmarks (MMLU, HumanEval, MT-Bench) measure capability—
   --  what models CAN do. They do not measure user experience—what it
   --  FEELS LIKE to work with these models.
   --
   --  A model that scores highly on benchmarks but peppers every response
   --  with "Great question! I'd be happy to help!" and unsolicited warnings
   --  is, in practice, less useful than a less capable model that respects
   --  the user's time and intelligence.
   --
   --  Vexometer measures what users actually care about.

end Vexometer;
