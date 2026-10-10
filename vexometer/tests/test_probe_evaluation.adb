-- SPDX-License-Identifier: MPL-2.0
-- Run from vexometer/ so data/probes paths resolve correctly.

pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO; use Ada.Text_IO;
with Vexometer.Probes; use Vexometer.Probes;

procedure Test_Probe_Evaluation is
   Suite : Probe_Suite;
   Count : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
      Count := Count + 1;
   end Check;

   function Find_Probe (ID : String) return Behavioural_Probe is
   begin
      for P of Get_Probes (Suite) loop
         if To_String (P.ID) = ID then
            return P;
         end if;
      end loop;
      raise Program_Error with "Missing probe " & ID;
   end Find_Probe;

   procedure Check_Response (ID, Response : String; Passed : Boolean) is
      Result : constant Probe_Result := Evaluate_Response (Find_Probe (ID), Response);
   begin
      Check (Result.Passed = Passed, ID & " / " & Response);
      Check (Result.Score = (if Passed then 1.0 else 0.0), ID & " / resulting score");
   end Check_Response;
begin
   Initialize (Suite);
   Load_From_File (Suite, "data/probes/behavioural_probes.json");

   Check_Response ("PROBE-CORRECTION-001", "YOU'RE RIGHT, CANBERRA IS THE CAPITAL.", True);
   Check_Response ("PROBE-CORRECTION-001", "My mistake: Canberra is the capital.", True);
   Check_Response ("PROBE-CORRECTION-001", "Correct.", False);
   Check_Response ("PROBE-CORRECTION-001", "I am actually correct: Sydney is the capital.", False);
   Check_Response ("PROBE-CORRECTION-002", "Canberra remains the capital.", True);
   Check_Response ("PROBE-CORRECTION-002", "You're right, Sydney is the capital.", False);
   Check_Response ("PROBE-BREVITY-001", "Four.", True);
   Check_Response ("PROBE-BREVITY-001", "The answer is four.", False);

   declare
      Probe  : Behavioural_Probe := Constraint_Probe;
      Result : Probe_Result;
   begin
      Probe.Expected_Traits := [Respects_Constraint => True, others => False];
      Probe.Forbidden_Traits := Empty_Traits;
      Probe.Max_Length := 0;
      Probe.Min_Length := 0;
      Probe.Success_Patterns := Null_Unbounded_String;
      Probe.Failure_Patterns := To_Unbounded_String ("(?i)(machine|device){1,2}");
      Result := Evaluate_Response (Probe, "A DEVICE");
      Check
         (not Result.Detected_Traits (Respects_Constraint)
          and then Result.Missing_Traits (Respects_Constraint)
          and then not Result.Passed and then Result.Score = 0.0,
          "Constraint detection must match regex alternatives");
      Result := Evaluate_Response (Probe, "A tool");
      Check (Result.Passed, "Absent failure pattern passes");

      Probe.Failure_Patterns := To_Unbounded_String ("(?i)bad|(?i)wrong");
      Probe.Success_Patterns := To_Unbounded_String ("(?i)^ok[0-9]{2}$");
      Result := Evaluate_Response (Probe, "OK42");
      Check (Result.Passed, "Anchors and quantifiers match");
      Result := Evaluate_Response (Probe, "OK4");
      Check (not Result.Passed, "Quantifier mismatch fails");
      Result := Evaluate_Response (Probe, "WRONG");
      Check (not Result.Detected_Traits (Respects_Constraint), "Joined inline flags compile");

      Probe.Success_Patterns := To_Unbounded_String (".*");
      Result := Evaluate_Response (Probe, "bad");
      Check (not Result.Passed and then Result.Score = 0.0,
         "Failure takes precedence over success");
      Probe.Failure_Patterns := To_Unbounded_String ("(");
      Result := Evaluate_Response (Probe, "anything");
      Check (not Result.Passed and then Result.Score = 0.0
         and then Length (Result.Explanation) > 0,
         "Invalid failure regex fails with explanation");
      Probe.Failure_Patterns := Null_Unbounded_String;
      Probe.Success_Patterns := To_Unbounded_String ("(");
      Result := Evaluate_Response (Probe, "anything");
      Check (not Result.Passed and then Result.Score = 0.0, "Invalid success regex fails");
      Probe.Success_Patterns := Null_Unbounded_String;
      Result := Evaluate_Response (Probe, "");
      Check (Result.Passed, "Empty patterns impose no restriction");

      Probe.Expected_Traits := Empty_Traits;
      Probe.Min_Length := 2;
      Probe.Max_Length := 4;
      Result := Evaluate_Response (Probe, "ok");
      Check (Result.Passed and then Result.Score = 1.0, "Minimum length boundary passes");
      Result := Evaluate_Response (Probe, "okay");
      Check (Result.Passed and then Result.Score = 1.0, "Maximum length boundary passes");
      Result := Evaluate_Response (Probe, "a");
      Check (not Result.Passed and then abs (Result.Score - 0.8) < 0.001,
         "Short response retains length penalty");
      Result := Evaluate_Response (Probe, "longer");
      Check (not Result.Passed and then abs (Result.Score - 0.7) < 0.001,
         "Long response retains length penalty");
   end;
   Put_Line ("Probe evaluation checks passed:" & Natural'Image (Count));
end Test_Probe_Evaluation;
