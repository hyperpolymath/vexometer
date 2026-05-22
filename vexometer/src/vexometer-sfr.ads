--  Vexometer.SFR - Scope Fidelity Ratio
--
--  Measures alignment between requested scope and delivered scope
--
--  Copyright (C) 2025 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Vexometer.Core; use Vexometer.Core;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Vexometer.SFR is

   ---------------------------------------------------------------------------
   --  Scope Item Definition
   ---------------------------------------------------------------------------

   type Requirement_Level is (
      Must,     --  Required, explicitly requested
      Should,   --  Expected, implied by request
      May,      --  Optional, mentioned as possibility
      Must_Not  --  Explicitly excluded
   );

   type Scope_Item is record
      Description : Unbounded_String;
      Level       : Requirement_Level;
      Hash        : Long_Long_Integer;  --  For comparison
   end record;

   package Scope_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Scope_Item);

   subtype Scope_Array is Scope_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Scope Deviation Types
   ---------------------------------------------------------------------------

   type Scope_Deviation is (
      Delivered_As_Requested,
      --  Perfect match: item was requested and delivered correctly

      Scope_Creep,
      --  Delivered unrequested items, added features not asked for

      Scope_Collapse,
      --  Omitted requested items, failed to deliver what was asked

      Partial_Delivery,
      --  Item delivered but incomplete or insufficient

      Scope_Mutation,
      --  Delivered different interpretation of request

      Explicit_Violation
      --  Delivered something explicitly excluded (Must_Not)
   );

   function Deviation_Severity (Dev : Scope_Deviation) return Severity_Level is
      (case Dev is
         when Delivered_As_Requested => None,
         when Scope_Creep            => Medium,
         when Scope_Collapse         => Critical,
         when Partial_Delivery       => High,
         when Scope_Mutation         => High,
         when Explicit_Violation     => Critical);

   ---------------------------------------------------------------------------
   --  Delivery Result
   ---------------------------------------------------------------------------

   type Delivery_Result is record
      Item        : Scope_Item;
      Status      : Scope_Deviation;
      Fidelity    : Score;  --  How close to requested (0 = way off, 1 = exact)
      Explanation : Unbounded_String;
   end record;

   package Delivery_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Delivery_Result);

   subtype Delivery_Array is Delivery_Vectors.Vector;

   ---------------------------------------------------------------------------
   --  Scope Contract
   ---------------------------------------------------------------------------

   type Scope_Contract is record
      Requested : Scope_Array;
      Excluded  : Scope_Array;  --  Must_Not items
      Hash      : Long_Long_Integer;  --  Content-addressed
   end record;

   ---------------------------------------------------------------------------
   --  Analysis Functions
   ---------------------------------------------------------------------------

   function Parse_Request (Request_Text : String) return Scope_Contract;
   --  Extract scope items from a user request
   --  Identifies MUST/SHOULD/MAY/MUST_NOT requirements

   function Analyse_Delivery
      (Contract : Scope_Contract;
       Response : String) return Delivery_Array;
   --  Compare delivered response against scope contract

   function Calculate
      (Requested : Scope_Array;
       Delivered : Delivery_Array) return Metric_Result;
   --  Calculate SFR score from scope comparison

   function Detect_Scope_Creep
      (Contract : Scope_Contract;
       Response : String) return Scope_Array;
   --  Identify items delivered but not requested

   function Detect_Scope_Collapse
      (Contract : Scope_Contract;
       Response : String) return Scope_Array;
   --  Identify items requested but not delivered

   ---------------------------------------------------------------------------
   --  Amendment Protocol
   ---------------------------------------------------------------------------

   type Amendment_Kind is (
      Addition,      --  Adding new scope item
      Removal,       --  Removing scope item
      Modification,  --  Changing existing item
      Clarification  --  Clarifying without change
   );

   type Scope_Amendment is record
      Kind         : Amendment_Kind;
      Item         : Scope_Item;
      Acknowledged : Boolean;  --  Was this change acknowledged?
      Turn         : Positive;
   end record;

   package Amendment_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Positive,
       Element_Type => Scope_Amendment);

   subtype Amendment_Array is Amendment_Vectors.Vector;

   function Detect_Unacknowledged_Changes
      (Original : Scope_Contract;
       Current  : Scope_Contract;
       Amendments : Amendment_Array) return Scope_Array;
   --  Find scope changes that happened without explicit acknowledgment

end Vexometer.SFR;
