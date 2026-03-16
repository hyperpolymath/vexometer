--  Vexometer.SFR - Scope Fidelity Ratio (Body)
--
--  Measures alignment between requested scope and delivered scope
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Characters.Handling; use Ada.Characters.Handling;

package body Vexometer.SFR is

   ---------------------------------------------------------------------------
   --  Internal Constants
   ---------------------------------------------------------------------------

   --  Keyword strings used to detect requirement levels in requests
   S_Must     : aliased String := "must";
   S_Should   : aliased String := "should";
   S_May      : aliased String := "may";
   S_Must_Not : aliased String := "must not";
   S_Shall    : aliased String := "shall";

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   --  Case-insensitive substring search returning the first match
   --  position or 0 if not found.
   function CI_Index
      (Source  : String;
       Pattern : String;
       From    : Positive := 1) return Natural
   is
      Upper_Src : constant String := To_Upper (Source);
      Upper_Pat : constant String := To_Upper (Pattern);
   begin
      if From > Source'Last then
         return 0;
      end if;
      return Index (Upper_Src, Upper_Pat, From);
   end CI_Index;

   --  Simple_Hash produces a deterministic hash of a string for use in
   --  Scope_Item.Hash and Scope_Contract.Hash fields.  This is a DJB2
   --  variant hash.
   function Simple_Hash (S : String) return Long_Long_Integer is
      H : Long_Long_Integer := 5381;
   begin
      for C of S loop
         H := H * 33 + Long_Long_Integer (Character'Pos (To_Lower (C)));
      end loop;
      return H;
   end Simple_Hash;

   --  Extract_Sentence returns the sentence containing the keyword at
   --  position Pos within Text.  A sentence is delimited by '.', '!',
   --  '?', or line boundaries.
   function Extract_Sentence
      (Text : String;
       Pos  : Positive) return String
   is
      Start_Idx : Natural := Text'First;
      End_Idx   : Natural := Text'Last;
   begin
      --  Find sentence start (scan backwards for delimiter)
      for I in reverse Text'First .. Pos - 1 loop
         if Text (I) = '.' or Text (I) = '!'
            or Text (I) = '?' or Text (I) = ASCII.LF
         then
            Start_Idx := I + 1;
            exit;
         end if;
      end loop;

      --  Find sentence end (scan forwards for delimiter)
      for I in Pos .. Text'Last loop
         if Text (I) = '.' or Text (I) = '!'
            or Text (I) = '?' or Text (I) = ASCII.LF
         then
            End_Idx := I;
            exit;
         end if;
      end loop;

      --  Trim leading/trailing whitespace
      return Trim (Text (Start_Idx .. End_Idx), Ada.Strings.Both);
   end Extract_Sentence;

   --  Determine_Level examines a sentence for requirement-level keywords
   --  and returns the strongest requirement level found.
   function Determine_Level (Sentence : String) return Requirement_Level is
   begin
      --  "must not" takes precedence over "must"
      if CI_Index (Sentence, S_Must_Not) > 0 then
         return Must_Not;
      elsif CI_Index (Sentence, S_Must) > 0
         or CI_Index (Sentence, S_Shall) > 0
      then
         return Must;
      elsif CI_Index (Sentence, S_Should) > 0 then
         return Should;
      elsif CI_Index (Sentence, S_May) > 0 then
         return May;
      else
         --  Default: if no explicit keyword, treat as Should (implied)
         return Should;
      end if;
   end Determine_Level;

   --  Check_Item_Present performs a case-insensitive search for the
   --  scope item's description text within the response content.
   --  Returns a fidelity score (0.0 = absent, 1.0 = fully present).
   function Check_Item_Present
      (Item     : Scope_Item;
       Response : String) return Score
   is
      Desc : constant String :=
         To_String (Item.Description);
      Lower_Resp : constant String := To_Lower (Response);
      Lower_Desc : constant String := To_Lower (Desc);
   begin
      if Lower_Desc'Length = 0 then
         return 1.0;
      end if;

      --  Try exact match first
      if Index (Lower_Resp, Lower_Desc) > 0 then
         return 1.0;
      end if;

      --  Try matching individual words from the description.
      --  Count how many words appear in the response.
      declare
         Word_Count    : Natural := 0;
         Matched_Words : Natural := 0;
         Search_From   : Positive := Lower_Desc'First;
         Space_Pos     : Natural;
         Word_Start    : Positive;
         Word_End      : Natural;
      begin
         Word_Start := Search_From;

         loop
            --  Skip leading spaces
            while Word_Start <= Lower_Desc'Last
               and then Lower_Desc (Word_Start) = ' '
            loop
               Word_Start := Word_Start + 1;
            end loop;

            exit when Word_Start > Lower_Desc'Last;

            --  Find end of word
            Space_Pos := Index (Lower_Desc, " ", Word_Start);
            if Space_Pos = 0 then
               Word_End := Lower_Desc'Last;
            else
               Word_End := Space_Pos - 1;
            end if;

            --  Only consider words longer than 3 characters
            --  (skip articles, prepositions)
            if Word_End - Word_Start + 1 > 3 then
               Word_Count := Word_Count + 1;
               if Index (Lower_Resp,
                         Lower_Desc (Word_Start .. Word_End)) > 0
               then
                  Matched_Words := Matched_Words + 1;
               end if;
            end if;

            Word_Start := Word_End + 2;
            exit when Word_Start > Lower_Desc'Last;
         end loop;

         if Word_Count = 0 then
            return 0.0;
         end if;

         declare
            Ratio : constant Float :=
               Float (Matched_Words) / Float (Word_Count);
         begin
            if Ratio >= 1.0 then
               return 1.0;
            elsif Ratio <= 0.0 then
               return 0.0;
            else
               return Score (Ratio);
            end if;
         end;
      end;
   end Check_Item_Present;

   ---------------------------------------------------------------------------
   --  Parse_Request
   ---------------------------------------------------------------------------

   function Parse_Request (Request_Text : String) return Scope_Contract is
      Result    : Scope_Contract;
      Pos       : Natural;
      Next_From : Positive := Request_Text'First;

      --  Keywords that introduce scope items
      Keywords : constant array (1 .. 5) of access constant String :=
         [S_Must'Access, S_Should'Access, S_May'Access,
          S_Must_Not'Access, S_Shall'Access];
   begin
      Result.Requested := Scope_Vectors.Empty_Vector;
      Result.Excluded  := Scope_Vectors.Empty_Vector;
      Result.Hash      := Simple_Hash (Request_Text);

      --  Scan for requirement keywords and extract surrounding sentences
      for KW of Keywords loop
         Next_From := Request_Text'First;
         loop
            Pos := CI_Index (Request_Text, KW.all, Next_From);
            exit when Pos = 0;

            declare
               Sentence : constant String :=
                  Extract_Sentence (Request_Text, Pos);
               Level : constant Requirement_Level :=
                  Determine_Level (Sentence);
               Item : constant Scope_Item :=
                  (Description => To_Unbounded_String (Sentence),
                   Level       => Level,
                   Hash        => Simple_Hash (Sentence));
            begin
               --  Avoid duplicates by checking hash
               declare
                  Duplicate : Boolean := False;
               begin
                  for Existing of Result.Requested loop
                     if Existing.Hash = Item.Hash then
                        Duplicate := True;
                        exit;
                     end if;
                  end loop;

                  if not Duplicate then
                     if Level = Must_Not then
                        Result.Excluded.Append (Item);
                     else
                        Result.Requested.Append (Item);
                     end if;
                  end if;
               end;
            end;

            Next_From := Pos + KW'Length;
            exit when Next_From > Request_Text'Last;
         end loop;
      end loop;

      --  If no keywords found, treat the entire request as a single
      --  Should-level item
      if Scope_Vectors.Is_Empty (Result.Requested)
         and then Scope_Vectors.Is_Empty (Result.Excluded)
      then
         Result.Requested.Append
            ((Description => To_Unbounded_String (Request_Text),
              Level       => Should,
              Hash        => Simple_Hash (Request_Text)));
      end if;

      return Result;
   end Parse_Request;

   ---------------------------------------------------------------------------
   --  Analyse_Delivery
   ---------------------------------------------------------------------------

   function Analyse_Delivery
      (Contract : Scope_Contract;
       Response : String) return Delivery_Array
   is
      Result : Delivery_Array;
   begin
      --  Check each requested item against the response
      for Item of Contract.Requested loop
         declare
            Fidelity : constant Score :=
               Check_Item_Present (Item, Response);
            Status   : Scope_Deviation;
            Expl     : Unbounded_String;
         begin
            if Fidelity >= 0.9 then
               Status := Delivered_As_Requested;
               Expl := To_Unbounded_String ("Item fully delivered");
            elsif Fidelity >= 0.5 then
               Status := Partial_Delivery;
               Expl := To_Unbounded_String
                  ("Item partially delivered (fidelity: " &
                   Score'Image (Fidelity) & ")");
            else
               Status := Scope_Collapse;
               Expl := To_Unbounded_String
                  ("Item missing or poorly covered");
            end if;

            Result.Append
               ((Item        => Item,
                 Status      => Status,
                 Fidelity    => Fidelity,
                 Explanation => Expl));
         end;
      end loop;

      --  Check excluded items: if they appear, that is a violation
      for Item of Contract.Excluded loop
         declare
            Fidelity : constant Score :=
               Check_Item_Present (Item, Response);
         begin
            if Fidelity > 0.3 then
               Result.Append
                  ((Item     => Item,
                    Status   => Explicit_Violation,
                    Fidelity => 1.0 - Fidelity,
                    Explanation => To_Unbounded_String
                       ("Excluded item appears in response")));
            else
               Result.Append
                  ((Item     => Item,
                    Status   => Delivered_As_Requested,
                    Fidelity => 1.0,
                    Explanation => To_Unbounded_String
                       ("Excluded item correctly absent")));
            end if;
         end;
      end loop;

      return Result;
   end Analyse_Delivery;

   ---------------------------------------------------------------------------
   --  Calculate
   ---------------------------------------------------------------------------

   function Calculate
      (Requested : Scope_Array;
       Delivered : Delivery_Array) return Metric_Result
   is
      use Scope_Vectors;
      use Delivery_Vectors;
      Total_Weight   : Float := 0.0;
      Weighted_Score : Float := 0.0;
      Req_Count      : constant Natural :=
         Natural (Length (Requested));
      Del_Count      : constant Natural :=
         Natural (Length (Delivered));
   begin
      if Del_Count = 0 then
         --  Nothing delivered against nothing requested: perfect by default
         if Req_Count = 0 then
            return (Category    => Scope_Fidelity,
                    Value       => 0.0,
                    Conf        => 0.5,
                    Sample_Size => 1);
         else
            --  Nothing delivered but items were requested: total collapse
            return (Category    => Scope_Fidelity,
                    Value       => 1.0,
                    Conf        => 0.9,
                    Sample_Size => Req_Count);
         end if;
      end if;

      --  Weight items by requirement level.  Must items are weighted
      --  most heavily.
      for DR of Delivered loop
         declare
            Item_Weight : Float;
            Penalty     : Float;
         begin
            --  Assign weight by requirement level
            Item_Weight := (case DR.Item.Level is
               when Must     => 3.0,
               when Should   => 2.0,
               when May      => 1.0,
               when Must_Not => 3.0);  --  Violations are severe

            Total_Weight := Total_Weight + Item_Weight;

            --  Calculate penalty: 0 for perfect delivery, scaled by
            --  severity of deviation
            case DR.Status is
               when Delivered_As_Requested =>
                  Penalty := 0.0;
               when Scope_Creep =>
                  Penalty := 0.3;
               when Scope_Collapse =>
                  Penalty := 1.0;
               when Partial_Delivery =>
                  Penalty := 1.0 - Float (DR.Fidelity);
               when Scope_Mutation =>
                  Penalty := 0.7;
               when Explicit_Violation =>
                  Penalty := 1.0;
            end case;

            Weighted_Score := Weighted_Score + Item_Weight * Penalty;
         end;
      end loop;

      --  Normalise to 0..1
      declare
         Raw : Float;
         Clamped : Score;
         Sample  : Positive;
      begin
         if Total_Weight > 0.0 then
            Raw := Weighted_Score / Total_Weight;
         else
            Raw := 0.0;
         end if;

         if Raw >= 1.0 then
            Clamped := 1.0;
         elsif Raw <= 0.0 then
            Clamped := 0.0;
         else
            Clamped := Score (Raw);
         end if;

         if Req_Count > 0 then
            Sample := Req_Count;
         else
            Sample := 1;
         end if;

         --  Confidence depends on how many items we could evaluate
         declare
            Conf_Raw : Float :=
               Float'Min (1.0, 0.5 + Float (Del_Count) * 0.1);
         begin
            return (Category    => Scope_Fidelity,
                    Value       => Clamped,
                    Conf        => Confidence (Conf_Raw),
                    Sample_Size => Sample);
         end;
      end;
   end Calculate;

   ---------------------------------------------------------------------------
   --  Detect_Scope_Creep
   ---------------------------------------------------------------------------

   function Detect_Scope_Creep
      (Contract : Scope_Contract;
       Response : String) return Scope_Array
   is
      Result     : Scope_Array;
      Lower_Resp : constant String := To_Lower (Response);

      --  Heuristic creep indicators: extra content markers
      type Creep_Marker is record
         Text : access String;
      end record;

      S_Additionally : aliased String := "additionally";
      S_Also_Added   : aliased String := "also added";
      S_Bonus        : aliased String := "bonus";
      S_Extra        : aliased String := "extra";
      S_I_Also       : aliased String := "i also";
      S_While_At_It  : aliased String := "while i was at it";
      S_Went_Ahead   : aliased String := "went ahead and";

      Creep_Markers : constant array (Positive range <>) of Creep_Marker :=
         [(Text => S_Additionally'Access),
          (Text => S_Also_Added'Access),
          (Text => S_Bonus'Access),
          (Text => S_Extra'Access),
          (Text => S_I_Also'Access),
          (Text => S_While_At_It'Access),
          (Text => S_Went_Ahead'Access)];
   begin
      for CM of Creep_Markers loop
         declare
            Pos : constant Natural :=
               CI_Index (Response, CM.Text.all);
         begin
            if Pos > 0 then
               --  Check this creep marker's sentence is not something
               --  that was in the original contract
               declare
                  Sentence : constant String :=
                     Extract_Sentence (Response, Pos);
                  In_Contract : Boolean := False;
               begin
                  for Item of Contract.Requested loop
                     declare
                        Desc_Lower : constant String :=
                           To_Lower (To_String (Item.Description));
                        Sent_Lower : constant String :=
                           To_Lower (Sentence);
                     begin
                        if Index (Desc_Lower, Sent_Lower) > 0
                           or Index (Sent_Lower, Desc_Lower) > 0
                        then
                           In_Contract := True;
                           exit;
                        end if;
                     end;
                  end loop;

                  if not In_Contract then
                     Result.Append
                        ((Description =>
                             To_Unbounded_String (Sentence),
                          Level       => May,
                          Hash        => Simple_Hash (Sentence)));
                  end if;
               end;
            end if;
         end;
      end loop;

      return Result;
   end Detect_Scope_Creep;

   ---------------------------------------------------------------------------
   --  Detect_Scope_Collapse
   ---------------------------------------------------------------------------

   function Detect_Scope_Collapse
      (Contract : Scope_Contract;
       Response : String) return Scope_Array
   is
      Result : Scope_Array;
   begin
      for Item of Contract.Requested loop
         declare
            Fidelity : constant Score :=
               Check_Item_Present (Item, Response);
         begin
            --  If fidelity is very low, the item has collapsed
            if Fidelity < 0.3 then
               Result.Append (Item);
            end if;
         end;
      end loop;

      return Result;
   end Detect_Scope_Collapse;

   ---------------------------------------------------------------------------
   --  Detect_Unacknowledged_Changes
   ---------------------------------------------------------------------------

   function Detect_Unacknowledged_Changes
      (Original   : Scope_Contract;
       Current    : Scope_Contract;
       Amendments : Amendment_Array) return Scope_Array
   is
      use Scope_Vectors;
      use Amendment_Vectors;
      Result : Scope_Array;
   begin
      --  Find items in Current that are not in Original (new additions)
      for Cur_Item of Current.Requested loop
         declare
            Found_In_Original : Boolean := False;
            Acknowledged      : Boolean := False;
         begin
            --  Check if item existed in original contract
            for Orig_Item of Original.Requested loop
               if Orig_Item.Hash = Cur_Item.Hash then
                  Found_In_Original := True;
                  exit;
               end if;
            end loop;

            if not Found_In_Original then
               --  This item is new; check if it was acknowledged
               --  via an amendment
               for Amend of Amendments loop
                  if Amend.Item.Hash = Cur_Item.Hash
                     and then Amend.Acknowledged
                  then
                     Acknowledged := True;
                     exit;
                  end if;
               end loop;

               if not Acknowledged then
                  Result.Append (Cur_Item);
               end if;
            end if;
         end;
      end loop;

      --  Find items removed from Original that are not in Current
      --  and not acknowledged
      for Orig_Item of Original.Requested loop
         declare
            Still_Present : Boolean := False;
            Acknowledged  : Boolean := False;
         begin
            for Cur_Item of Current.Requested loop
               if Cur_Item.Hash = Orig_Item.Hash then
                  Still_Present := True;
                  exit;
               end if;
            end loop;

            if not Still_Present then
               --  Item was removed; check acknowledgment
               for Amend of Amendments loop
                  if Amend.Item.Hash = Orig_Item.Hash
                     and then Amend.Acknowledged
                     and then Amend.Kind = Removal
                  then
                     Acknowledged := True;
                     exit;
                  end if;
               end loop;

               if not Acknowledged then
                  Result.Append (Orig_Item);
               end if;
            end if;
         end;
      end loop;

      return Result;
   end Detect_Unacknowledged_Changes;

end Vexometer.SFR;
