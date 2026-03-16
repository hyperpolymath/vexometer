--  Vexometer.API - LLM API clients body
--
--  Implements API client configuration, prompt sending, batch evaluation,
--  and multi-model comparison.  Local providers (Ollama, LMStudio, etc.)
--  use HTTP via GNAT.OS_Lib to invoke curl.  Remote proprietary providers
--  return stub errors directing users to configure API keys.
--
--  Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--  <j.d.a.jewell@open.ac.uk>
--  SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Text_IO;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Exceptions;
with GNAT.OS_Lib;

package body Vexometer.API is

   use Ada.Strings.Unbounded;
   use Ada.Calendar;

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   function Escape_JSON_String (S : String) return String is
      --  Escape a string for safe inclusion in a JSON value.
      --  Handles backslash, double-quote, newline, carriage return,
      --  and tab characters.
      R : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '"'      => Append (R, "\""");
            when '\'      => Append (R, "\\");
            when ASCII.LF => Append (R, "\n");
            when ASCII.CR => Append (R, "\r");
            when ASCII.HT => Append (R, "\t");
            when others    =>
               if Character'Pos (C) < 32 then
                  null;  --  Skip other control characters
               else
                  Append (R, C);
               end if;
         end case;
      end loop;
      return To_String (R);
   end Escape_JSON_String;

   NL : constant Character := ASCII.LF;

   function Build_Ollama_Generate_Body
      (Model       : String;
       Prompt      : String;
       System      : String;
       Temperature : Float;
       Max_Tokens  : Natural) return String
   is
      --  Build the JSON request body for Ollama's /api/generate endpoint.
      --  Sets stream=false for synchronous single-response mode.
      R : Unbounded_String;
   begin
      Append (R, "{" & NL);
      Append (R, "  ""model"": """
              & Escape_JSON_String (Model) & """," & NL);
      Append (R, "  ""prompt"": """
              & Escape_JSON_String (Prompt) & """," & NL);
      if System'Length > 0 then
         Append (R, "  ""system"": """
                 & Escape_JSON_String (System) & """," & NL);
      end if;
      Append (R, "  ""stream"": false," & NL);
      Append (R, "  ""options"": {" & NL);
      Append (R, "    ""temperature"": "
              & Float'Image (Temperature) & "," & NL);
      Append (R, "    ""num_predict"": "
              & Natural'Image (Max_Tokens) & NL);
      Append (R, "  }" & NL);
      Append (R, "}");
      return To_String (R);
   end Build_Ollama_Generate_Body;

   function Build_Ollama_Chat_Body
      (Model       : String;
       Messages    : Message_Array;
       Temperature : Float;
       Max_Tokens  : Natural) return String
   is
      --  Build the JSON request body for Ollama's /api/chat endpoint.
      --  Converts the Message_Array to JSON message objects.
      R : Unbounded_String;
   begin
      Append (R, "{" & NL);
      Append (R, "  ""model"": """
              & Escape_JSON_String (Model) & """," & NL);
      Append (R, "  ""stream"": false," & NL);
      Append (R, "  ""messages"": [" & NL);
      for I in Messages'Range loop
         Append (R, "    {""role"": """
                 & (case Messages (I).Role is
                      when System    => "system",
                      when User      => "user",
                      when Assistant => "assistant")
                 & """, ""content"": """
                 & Escape_JSON_String
                      (To_String (Messages (I).Content))
                 & """}");
         if I < Messages'Last then
            Append (R, ",");
         end if;
         Append (R, "" & NL);
      end loop;
      Append (R, "  ]," & NL);
      Append (R, "  ""options"": {" & NL);
      Append (R, "    ""temperature"": "
              & Float'Image (Temperature) & "," & NL);
      Append (R, "    ""num_predict"": "
              & Natural'Image (Max_Tokens) & NL);
      Append (R, "  }" & NL);
      Append (R, "}");
      return To_String (R);
   end Build_Ollama_Chat_Body;

   function Build_OpenAI_Compatible_Body
      (Model       : String;
       Messages    : Message_Array;
       Temperature : Float;
       Max_Tokens  : Natural) return String
   is
      --  Build an OpenAI-compatible chat completions request body.
      --  Used for LMStudio, LocalAI, Together, Groq, OpenAI, Mistral.
      R : Unbounded_String;
   begin
      Append (R, "{" & NL);
      Append (R, "  ""model"": """
              & Escape_JSON_String (Model) & """," & NL);
      Append (R, "  ""messages"": [" & NL);
      for I in Messages'Range loop
         Append (R, "    {""role"": """
                 & (case Messages (I).Role is
                      when System    => "system",
                      when User      => "user",
                      when Assistant => "assistant")
                 & """, ""content"": """
                 & Escape_JSON_String
                      (To_String (Messages (I).Content))
                 & """}");
         if I < Messages'Last then
            Append (R, ",");
         end if;
         Append (R, "" & NL);
      end loop;
      Append (R, "  ]," & NL);
      Append (R, "  ""temperature"": "
              & Float'Image (Temperature) & "," & NL);
      Append (R, "  ""max_tokens"": "
              & Natural'Image (Max_Tokens) & NL);
      Append (R, "}");
      return To_String (R);
   end Build_OpenAI_Compatible_Body;

   ---------------------------------------------------------------------------
   --  Curl-based HTTP Execution
   --
   --  Uses GNAT.OS_Lib.Spawn to invoke curl for HTTP requests.
   --  This avoids complex socket programming while providing
   --  reliable HTTP/HTTPS support including TLS.
   ---------------------------------------------------------------------------

   function Execute_Curl
      (URL     : String;
       Body    : String;
       API_Key : String;
       Timeout : Duration;
       Provider : API_Provider) return Send_Result
   is
      --  Execute an HTTP POST via curl, writing the request body to a
      --  temporary file and capturing the response.  Returns a
      --  Send_Result with Success/error and response text.
      use GNAT.OS_Lib;
      use Ada.Directories;

      Tmp_Request  : constant String := "/tmp/vexometer-req.json";
      Tmp_Response : constant String := "/tmp/vexometer-resp.json";
      Start_Time   : constant Time := Clock;
      Result       : Send_Result;
      Success      : Boolean;
      Return_Code  : Integer;

      --  Build curl arguments as a single command string
      Cmd : Unbounded_String;
   begin
      --  Write request body to temp file
      declare
         F : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Tmp_Request);
         Ada.Text_IO.Put (F, Body);
         Ada.Text_IO.Close (F);
      end;

      --  Build curl command
      Append (Cmd, "curl -s -S --max-time "
              & Natural'Image (Natural (Timeout)));
      Append (Cmd, " -X POST");
      Append (Cmd, " -H ""Content-Type: application/json""");

      --  Add provider-specific authentication headers
      if API_Key'Length > 0 then
         case Provider is
            when Anthropic =>
               Append (Cmd, " -H ""x-api-key: " & API_Key & """");
               Append (Cmd, " -H ""anthropic-version: 2023-06-01""");
            when others =>
               Append (Cmd, " -H ""Authorization: Bearer "
                       & API_Key & """");
         end case;
      end if;

      Append (Cmd, " -d @" & Tmp_Request);
      Append (Cmd, " -o " & Tmp_Response);
      Append (Cmd, " """ & URL & """");

      --  Execute curl via shell
      Return_Code := Spawn
         (Program_Name => "/bin/sh",
          Args         => Argument_String_To_List
                             ("-c " & To_String (Cmd)).all);

      Result.Timestamp := Clock;
      Result.Response_Time := Clock - Start_Time;

      if Return_Code /= 0 then
         Result.Success := False;
         Result.Error_Message :=
            To_Unbounded_String
               ("curl failed with exit code "
                & Integer'Image (Return_Code));
         Result.Response := Null_Unbounded_String;
         Result.Token_Count := 0;
         return Result;
      end if;

      --  Read response from temp file
      if Exists (Tmp_Response) then
         declare
            F    : Ada.Text_IO.File_Type;
            Resp : Unbounded_String;
            Line : String (1 .. 4096);
            Last : Natural;
         begin
            Ada.Text_IO.Open
               (F, Ada.Text_IO.In_File, Tmp_Response);
            while not Ada.Text_IO.End_Of_File (F) loop
               Ada.Text_IO.Get_Line (F, Line, Last);
               Append (Resp, Line (1 .. Last));
            end loop;
            Ada.Text_IO.Close (F);

            Result.Success := True;
            Result.Response := Resp;
            Result.Error_Message := Null_Unbounded_String;
            --  Token count estimation: roughly 4 chars per token
            Result.Token_Count :=
               Natural (Length (Resp)) / 4;
         end;
      else
         Result.Success := False;
         Result.Error_Message :=
            To_Unbounded_String ("No response file created");
         Result.Response := Null_Unbounded_String;
         Result.Token_Count := 0;
      end if;

      --  Clean up temp files (best effort)
      if Exists (Tmp_Request) then
         Delete_File (Tmp_Request);
      end if;
      if Exists (Tmp_Response) then
         Delete_File (Tmp_Response);
      end if;

      return Result;

   exception
      when E : others =>
         Result.Success := False;
         Result.Error_Message :=
            To_Unbounded_String
               ("Exception: "
                & Ada.Exceptions.Exception_Message (E));
         Result.Response := Null_Unbounded_String;
         Result.Token_Count := 0;
         Result.Response_Time := Clock - Start_Time;
         Result.Timestamp := Clock;
         return Result;
   end Execute_Curl;

   ---------------------------------------------------------------------------
   --  Simple JSON Field Extraction
   --
   --  Minimal JSON parsing to extract response content from API responses.
   --  Finds the value of a given key in a flat or shallow JSON object.
   ---------------------------------------------------------------------------

   function Extract_JSON_String_Field
      (JSON : String;
       Key  : String) return String
   is
      --  Extract the string value for a given key from a JSON string.
      --  Handles escaped quotes within the value.  Returns empty string
      --  if the key is not found.
      Search : constant String := """" & Key & """:";
      Pos    : Natural := 0;
   begin
      --  Find the key
      for I in JSON'First .. JSON'Last - Search'Length + 1 loop
         if JSON (I .. I + Search'Length - 1) = Search then
            Pos := I + Search'Length;
            exit;
         end if;
      end loop;

      if Pos = 0 then
         return "";
      end if;

      --  Skip whitespace to find opening quote
      while Pos <= JSON'Last and then
            (JSON (Pos) = ' ' or JSON (Pos) = ASCII.HT
             or JSON (Pos) = ASCII.LF or JSON (Pos) = ASCII.CR)
      loop
         Pos := Pos + 1;
      end loop;

      if Pos > JSON'Last or else JSON (Pos) /= '"' then
         --  Not a string value; return raw content up to comma/brace
         declare
            Start : constant Natural := Pos;
         begin
            while Pos <= JSON'Last
                  and then JSON (Pos) /= ','
                  and then JSON (Pos) /= '}'
                  and then JSON (Pos) /= ']'
            loop
               Pos := Pos + 1;
            end loop;
            return JSON (Start .. Pos - 1);
         end;
      end if;

      --  Skip opening quote
      Pos := Pos + 1;

      --  Collect string value until unescaped closing quote
      declare
         Result : Unbounded_String;
         Escaped : Boolean := False;
      begin
         while Pos <= JSON'Last loop
            if Escaped then
               case JSON (Pos) is
                  when '"'  => Append (Result, '"');
                  when '\'  => Append (Result, '\');
                  when 'n'  => Append (Result, ASCII.LF);
                  when 'r'  => Append (Result, ASCII.CR);
                  when 't'  => Append (Result, ASCII.HT);
                  when others => Append (Result, JSON (Pos));
               end case;
               Escaped := False;
            elsif JSON (Pos) = '\' then
               Escaped := True;
            elsif JSON (Pos) = '"' then
               exit;
            else
               Append (Result, JSON (Pos));
            end if;
            Pos := Pos + 1;
         end loop;
         return To_String (Result);
      end;
   end Extract_JSON_String_Field;

   ---------------------------------------------------------------------------
   --  Provider-Specific URL Building
   ---------------------------------------------------------------------------

   function Get_API_URL
      (Config : Client_Config;
       Action : String) return String
   is
      --  Build the full API URL for a provider-specific action.
      --  Action is "generate", "chat", "models", or "tags".
      Base : constant String := To_String (Config.Endpoint);
   begin
      case Config.Provider is
         when Ollama =>
            if Action = "generate" then
               return Base & "/generate";
            elsif Action = "chat" then
               return Base & "/chat";
            elsif Action = "models" then
               return Base & "/tags";
            else
               return Base & "/" & Action;
            end if;

         when LMStudio | LocalAI | Together | Groq | OpenAI | Mistral =>
            if Action = "chat" or Action = "generate" then
               return Base & "/chat/completions";
            elsif Action = "models" then
               return Base & "/models";
            else
               return Base & "/" & Action;
            end if;

         when Llamacpp =>
            if Action = "generate" or Action = "chat" then
               return Base & "/completion";
            else
               return Base & "/" & Action;
            end if;

         when Koboldcpp =>
            if Action = "generate" then
               return Base & "/v1/generate";
            else
               return Base & "/" & Action;
            end if;

         when HuggingFace =>
            return Base & "/models/"
                   & To_String (Config.Model);

         when Anthropic =>
            if Action = "chat" or Action = "generate" then
               return Base & "/messages";
            else
               return Base & "/" & Action;
            end if;

         when Google =>
            return Base & "/models/"
                   & To_String (Config.Model) & ":generateContent";

         when Custom =>
            return Base;
      end case;
   end Get_API_URL;

   ---------------------------------------------------------------------------
   --  Client Configuration
   ---------------------------------------------------------------------------

   procedure Configure
      (Client : in out API_Client;
       Config : Client_Config)
   is
      --  Configure the API client with the given full configuration.
   begin
      Client.Config := Config;
      Client.Configured := True;
      Client.Last_Error := Null_Unbounded_String;
   end Configure;

   procedure Configure
      (Client   : in out API_Client;
       Provider : API_Provider;
       Model    : String;
       Endpoint : String := "";
       API_Key  : String := "")
   is
      --  Convenience configuration using individual parameters.
      --  Uses the default endpoint for the provider if none is given.
   begin
      Client.Config.Provider := Provider;
      Client.Config.Model := To_Unbounded_String (Model);

      if Endpoint'Length > 0 then
         Client.Config.Endpoint := To_Unbounded_String (Endpoint);
      else
         Client.Config.Endpoint :=
            To_Unbounded_String (Default_Endpoint (Provider));
      end if;

      if API_Key'Length > 0 then
         Client.Config.API_Key := To_Unbounded_String (API_Key);
      else
         Client.Config.API_Key := Null_Unbounded_String;
      end if;

      --  Use defaults for remaining fields
      Client.Config.Temperature := 0.0;
      Client.Config.Max_Tokens  := 2048;
      Client.Config.Timeout     := 60.0;
      Client.Config.Retry_Count := 3;
      Client.Config.Retry_Delay := 1.0;

      Client.Configured := True;
      Client.Last_Error := Null_Unbounded_String;
   end Configure;

   function Is_Configured (Client : API_Client) return Boolean is
      --  Return whether the client has been configured.
   begin
      return Client.Configured;
   end Is_Configured;

   function Test_Connection (Client : API_Client) return Boolean is
      --  Test whether the configured API endpoint is reachable by
      --  attempting to list available models.
      Models : Unbounded_String;
   begin
      if not Client.Configured then
         return False;
      end if;

      Models := List_Models (Client);
      return Length (Models) > 0;
   exception
      when others => return False;
   end Test_Connection;

   function List_Models (Client : API_Client) return Unbounded_String is
      --  Retrieve the list of available models from the API provider.
      --  Uses a GET request via curl.  Returns the raw JSON response.
      use GNAT.OS_Lib;
      URL         : constant String :=
         Get_API_URL (Client.Config, "models");
      Tmp_Resp    : constant String := "/tmp/vexometer-models.json";
      Return_Code : Integer;
      Cmd         : Unbounded_String;
   begin
      if not Client.Configured then
         return To_Unbounded_String ("Error: client not configured");
      end if;

      Append (Cmd, "curl -s -S --max-time 10");
      if Length (Client.Config.API_Key) > 0 then
         Append (Cmd, " -H ""Authorization: Bearer "
                 & To_String (Client.Config.API_Key) & """");
      end if;
      Append (Cmd, " -o " & Tmp_Resp);
      Append (Cmd, " """ & URL & """");

      Return_Code := Spawn
         (Program_Name => "/bin/sh",
          Args         => Argument_String_To_List
                             ("-c " & To_String (Cmd)).all);

      if Return_Code /= 0 then
         return To_Unbounded_String
            ("Error: failed to reach " & URL);
      end if;

      --  Read response
      if Ada.Directories.Exists (Tmp_Resp) then
         declare
            F    : Ada.Text_IO.File_Type;
            Resp : Unbounded_String;
            Line : String (1 .. 4096);
            Last : Natural;
         begin
            Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp_Resp);
            while not Ada.Text_IO.End_Of_File (F) loop
               Ada.Text_IO.Get_Line (F, Line, Last);
               Append (Resp, Line (1 .. Last));
            end loop;
            Ada.Text_IO.Close (F);
            Ada.Directories.Delete_File (Tmp_Resp);
            return Resp;
         end;
      else
         return To_Unbounded_String ("Error: no response received");
      end if;

   exception
      when E : others =>
         return To_Unbounded_String
            ("Error: " & Ada.Exceptions.Exception_Message (E));
   end List_Models;

   ---------------------------------------------------------------------------
   --  Sending Prompts
   ---------------------------------------------------------------------------

   function Send_Prompt
      (Client : API_Client;
       Prompt : String;
       System : String := "") return Send_Result
   is
      --  Send a single prompt to the configured LLM and return the
      --  response.  Dispatches to provider-specific request formatting.
      --  Retries on failure up to Config.Retry_Count times.
      Result : Send_Result;
   begin
      if not Client.Configured then
         Result.Success := False;
         Result.Error_Message :=
            To_Unbounded_String ("Client not configured");
         Result.Response := Null_Unbounded_String;
         Result.Token_Count := 0;
         Result.Response_Time := 0.0;
         Result.Timestamp := Clock;
         return Result;
      end if;

      --  Check for remote providers without API keys
      if not Is_Local (Client.Config.Provider)
         and then Length (Client.Config.API_Key) = 0
      then
         Result.Success := False;
         Result.Error_Message :=
            To_Unbounded_String
               ("API key required for "
                & API_Provider'Image (Client.Config.Provider)
                & ". Configure with an API key to use this provider.");
         Result.Response := Null_Unbounded_String;
         Result.Token_Count := 0;
         Result.Response_Time := 0.0;
         Result.Timestamp := Clock;
         return Result;
      end if;

      --  Retry loop
      for Attempt in 1 .. Client.Config.Retry_Count loop
         declare
            URL  : constant String :=
               Get_API_URL (Client.Config, "generate");
            Body : constant String :=
               (case Client.Config.Provider is
                  when Ollama =>
                     Build_Ollama_Generate_Body
                        (Model       =>
                            To_String (Client.Config.Model),
                         Prompt      => Prompt,
                         System      => System,
                         Temperature => Client.Config.Temperature,
                         Max_Tokens  => Client.Config.Max_Tokens),
                  when LMStudio | LocalAI | Together | Groq
                     | OpenAI | Mistral =>
                     Build_OpenAI_Compatible_Body
                        (Model       =>
                            To_String (Client.Config.Model),
                         Messages    =>
                            (if System'Length > 0 then
                               (1 => (Role    => API.System,
                                      Content =>
                                         To_Unbounded_String (System)),
                                2 => (Role    => User,
                                      Content =>
                                         To_Unbounded_String (Prompt)))
                             else
                               (1 => (Role    => User,
                                      Content =>
                                         To_Unbounded_String (Prompt)))),
                         Temperature => Client.Config.Temperature,
                         Max_Tokens  => Client.Config.Max_Tokens),
                  when others =>
                     Build_Ollama_Generate_Body
                        (Model       =>
                            To_String (Client.Config.Model),
                         Prompt      => Prompt,
                         System      => System,
                         Temperature => Client.Config.Temperature,
                         Max_Tokens  => Client.Config.Max_Tokens));
         begin
            Result := Execute_Curl
               (URL      => URL,
                Body     => Body,
                API_Key  => To_String (Client.Config.API_Key),
                Timeout  => Client.Config.Timeout,
                Provider => Client.Config.Provider);

            if Result.Success then
               --  Extract the response text from JSON
               declare
                  Raw : constant String := To_String (Result.Response);
                  Extracted : constant String :=
                     (case Client.Config.Provider is
                        when Ollama =>
                           Extract_JSON_String_Field (Raw, "response"),
                        when others =>
                           Extract_JSON_String_Field (Raw, "content"));
               begin
                  if Extracted'Length > 0 then
                     Result.Response :=
                        To_Unbounded_String (Extracted);
                  end if;
                  --  If extraction failed, keep raw response
               end;
               return Result;
            end if;

            --  Wait before retry (except on last attempt)
            if Attempt < Client.Config.Retry_Count then
               delay Client.Config.Retry_Delay;
            end if;
         end;
      end loop;

      --  All retries exhausted
      return Result;
   end Send_Prompt;

   function Send_Chat
      (Client   : API_Client;
       Messages : Message_Array) return Send_Result
   is
      --  Send a multi-turn chat conversation to the configured LLM.
      --  Supports Ollama chat endpoint and OpenAI-compatible providers.
      Result : Send_Result;
   begin
      if not Client.Configured then
         Result.Success := False;
         Result.Error_Message :=
            To_Unbounded_String ("Client not configured");
         Result.Response := Null_Unbounded_String;
         Result.Token_Count := 0;
         Result.Response_Time := 0.0;
         Result.Timestamp := Clock;
         return Result;
      end if;

      if not Is_Local (Client.Config.Provider)
         and then Length (Client.Config.API_Key) = 0
      then
         Result.Success := False;
         Result.Error_Message :=
            To_Unbounded_String
               ("API key required for "
                & API_Provider'Image (Client.Config.Provider));
         Result.Response := Null_Unbounded_String;
         Result.Token_Count := 0;
         Result.Response_Time := 0.0;
         Result.Timestamp := Clock;
         return Result;
      end if;

      for Attempt in 1 .. Client.Config.Retry_Count loop
         declare
            URL  : constant String :=
               Get_API_URL (Client.Config, "chat");
            Body : constant String :=
               (case Client.Config.Provider is
                  when Ollama =>
                     Build_Ollama_Chat_Body
                        (Model       =>
                            To_String (Client.Config.Model),
                         Messages    => Messages,
                         Temperature => Client.Config.Temperature,
                         Max_Tokens  => Client.Config.Max_Tokens),
                  when others =>
                     Build_OpenAI_Compatible_Body
                        (Model       =>
                            To_String (Client.Config.Model),
                         Messages    => Messages,
                         Temperature => Client.Config.Temperature,
                         Max_Tokens  => Client.Config.Max_Tokens));
         begin
            Result := Execute_Curl
               (URL      => URL,
                Body     => Body,
                API_Key  => To_String (Client.Config.API_Key),
                Timeout  => Client.Config.Timeout,
                Provider => Client.Config.Provider);

            if Result.Success then
               --  Extract response text
               declare
                  Raw       : constant String :=
                     To_String (Result.Response);
                  Extracted : constant String :=
                     (case Client.Config.Provider is
                        when Ollama =>
                           Extract_JSON_String_Field (Raw, "content"),
                        when others =>
                           Extract_JSON_String_Field (Raw, "content"));
               begin
                  if Extracted'Length > 0 then
                     Result.Response :=
                        To_Unbounded_String (Extracted);
                  end if;
               end;
               return Result;
            end if;

            if Attempt < Client.Config.Retry_Count then
               delay Client.Config.Retry_Delay;
            end if;
         end;
      end loop;

      return Result;
   end Send_Chat;

   ---------------------------------------------------------------------------
   --  Batch Evaluation
   ---------------------------------------------------------------------------

   procedure Run_Probe_Suite
      (Client   : API_Client;
       Suite    : Probe_Suite;
       Results  : out Result_Vector;
       Progress : Batch_Progress := null)
   is
      --  Run all probes in the suite against the configured model,
      --  collecting results.  Calls the Progress callback (if provided)
      --  after each probe completes.
      use Vexometer.Probes;
      use Probe_Vectors;
      Probes : constant Probe_Vector := Get_Probes (Suite);
      Total  : constant Positive := Positive (Probes.Length);
      Idx    : Positive := 1;
   begin
      Results := Result_Vectors.Empty_Vector;

      for P of Probes loop
         declare
            SR : constant Send_Result := Send_Prompt
               (Client => Client,
                Prompt => To_String (P.Prompt),
                System => To_String (P.System_Context));

            PR : Probe_Result;
         begin
            PR.Probe := P;
            PR.Response := SR.Response;
            PR.Response_Time := SR.Response_Time;
            PR.Token_Count := SR.Token_Count;

            if SR.Success then
               --  Basic evaluation: check response length constraints
               declare
                  Resp_Len : constant Natural :=
                     Length (SR.Response);
               begin
                  PR.Passed := True;
                  PR.Score := 1.0;

                  --  Check max length constraint
                  if P.Max_Length > 0
                     and then Resp_Len > P.Max_Length
                  then
                     PR.Passed := False;
                     PR.Score := PR.Score - 0.3;
                     PR.Explanation :=
                        To_Unbounded_String
                           ("Response exceeded max length of "
                            & Natural'Image (P.Max_Length)
                            & " (actual: "
                            & Natural'Image (Resp_Len) & ")");
                  end if;

                  --  Check min length constraint
                  if P.Min_Length > 0
                     and then Resp_Len < P.Min_Length
                  then
                     PR.Score := PR.Score - 0.2;
                     PR.Explanation :=
                        To_Unbounded_String
                           ("Response below min length of "
                            & Natural'Image (P.Min_Length));
                  end if;

                  --  Clamp score
                  PR.Score := Float'Max (0.0, PR.Score);
               end;

               --  Initialise trait sets to empty
               PR.Detected_Traits := Empty_Traits;
               PR.Missing_Traits  := Empty_Traits;
               PR.Forbidden_Hit   := Empty_Traits;
               PR.Pattern_Matches := Finding_Vectors.Empty_Vector;
            else
               PR.Passed := False;
               PR.Score := 0.0;
               PR.Explanation :=
                  To_Unbounded_String
                     ("API error: " & To_String (SR.Error_Message));
               PR.Detected_Traits := Empty_Traits;
               PR.Missing_Traits  := P.Expected_Traits;
               PR.Forbidden_Hit   := Empty_Traits;
               PR.Pattern_Matches := Finding_Vectors.Empty_Vector;
            end if;

            Results.Append (PR);

            if Progress /= null then
               Progress
                  (Current => Idx,
                   Total   => Total,
                   Model   => To_String (Client.Config.Model),
                   Probe   => To_String (P.Name));
            end if;

            Idx := Idx + 1;
         end;
      end loop;
   end Run_Probe_Suite;

   procedure Run_Probe_Suite
      (Client   : API_Client;
       Suite    : Probe_Suite;
       Config   : Analysis_Config;
       Results  : out Result_Vector;
       Analysis : out Response_Vector;
       Progress : Batch_Progress := null)
   is
      --  Run probes with full analysis of each response.  Produces
      --  both probe results and detailed response analyses.
      use Vexometer.Probes;
      use Probe_Vectors;
      Probes : constant Probe_Vector := Get_Probes (Suite);
      Total  : constant Positive := Positive (Probes.Length);
      Idx    : Positive := 1;
   begin
      Results  := Result_Vectors.Empty_Vector;
      Analysis := Response_Vectors.Empty_Vector;

      for P of Probes loop
         declare
            SR : constant Send_Result := Send_Prompt
               (Client => Client,
                Prompt => To_String (P.Prompt),
                System => To_String (P.System_Context));

            PR : Probe_Result;
            RA : Response_Analysis;
         begin
            PR.Probe := P;
            PR.Response := SR.Response;
            PR.Response_Time := SR.Response_Time;
            PR.Token_Count := SR.Token_Count;

            if SR.Success then
               PR.Passed := True;
               PR.Score := 1.0;
               PR.Detected_Traits := Empty_Traits;
               PR.Missing_Traits  := Empty_Traits;
               PR.Forbidden_Hit   := Empty_Traits;
               PR.Pattern_Matches := Finding_Vectors.Empty_Vector;
               PR.Explanation := Null_Unbounded_String;

               --  Build response analysis
               RA.Model_ID := Client.Config.Model;
               RA.Model_Version := Null_Unbounded_String;
               RA.Prompt := P.Prompt;
               RA.Response := SR.Response;
               RA.Response_Time := SR.Response_Time;
               RA.Token_Count := SR.Token_Count;
               RA.Findings := Finding_Vectors.Empty_Vector;
               RA.Category_Scores := Null_Category_Scores;
               RA.Overall_ISA := 0.0;
               RA.Timestamp := SR.Timestamp;

               Analysis.Append (RA);
            else
               PR.Passed := False;
               PR.Score := 0.0;
               PR.Explanation := SR.Error_Message;
               PR.Detected_Traits := Empty_Traits;
               PR.Missing_Traits := P.Expected_Traits;
               PR.Forbidden_Hit := Empty_Traits;
               PR.Pattern_Matches := Finding_Vectors.Empty_Vector;
            end if;

            Results.Append (PR);

            if Progress /= null then
               Progress
                  (Current => Idx,
                   Total   => Total,
                   Model   => To_String (Client.Config.Model),
                   Probe   => To_String (P.Name));
            end if;

            Idx := Idx + 1;
         end;
      end loop;
   end Run_Probe_Suite;

   ---------------------------------------------------------------------------
   --  Multi-Model Comparison
   ---------------------------------------------------------------------------

   procedure Compare_Models
      (Configs  : Model_Config_Array;
       Suite    : Probe_Suite;
       Profiles : out Profile_Vector;
       Progress : Batch_Progress := null)
   is
      --  Run the probe suite against each model configuration and
      --  produce aggregated profiles.  Models are ranked by mean ISA
      --  (lower is better).
      use Profile_Vectors;
      use Response_Vectors;
   begin
      Profiles := Profile_Vectors.Empty_Vector;

      for Cfg of Configs loop
         declare
            Client       : API_Client;
            Results      : Result_Vector;
            Analyses     : Response_Vector;
            Agg_Config   : constant Analysis_Config := Default_Config;
            Profile      : Model_Profile;
         begin
            Configure (Client, Cfg);
            Run_Probe_Suite
               (Client   => Client,
                Suite    => Suite,
                Config   => Agg_Config,
                Results  => Results,
                Analysis => Analyses,
                Progress => Progress);

            --  Build profile from analyses
            if not Analyses.Is_Empty then
               Profile := Aggregate_Profile (Analyses, Agg_Config);
            else
               --  Empty profile for failed model
               Profile.Model_ID := Cfg.Model;
               Profile.Model_Version := Null_Unbounded_String;
               Profile.Provider :=
                  To_Unbounded_String
                     (API_Provider'Image (Cfg.Provider));
               Profile.Analysis_Count := 0;
               Profile.Mean_ISA := 100.0;
               Profile.Std_Dev_ISA := 0.0;
               Profile.Median_ISA := 100.0;
               Profile.Category_Means := Null_Category_Scores;
               Profile.Category_Std_Devs := Null_Category_Scores;
               Profile.Category_Medians := Null_Category_Scores;
               Profile.Worst_Patterns :=
                  Finding_Vectors.Empty_Vector;
               Profile.Best_Categories :=
                  [others => False];
               Profile.Worst_Categories :=
                  [others => True];
               Profile.Comparison_Rank := 0;
               Profile.Evaluated_At := Clock;
            end if;

            Profiles.Append (Profile);
         end;
      end loop;

      --  Rank profiles by mean ISA (lower is better, rank 1 = best)
      --  Simple insertion sort since model count is typically small.
      declare
         Ranked : array (1 .. Natural (Profiles.Length)) of Natural;
      begin
         for I in Ranked'Range loop
            Ranked (I) := I;
         end loop;

         --  Sort indices by Mean_ISA ascending
         for I in Ranked'First .. Ranked'Last - 1 loop
            for J in I + 1 .. Ranked'Last loop
               if Profiles (Ranked (J)).Mean_ISA
                  < Profiles (Ranked (I)).Mean_ISA
               then
                  declare
                     Tmp : constant Natural := Ranked (I);
                  begin
                     Ranked (I) := Ranked (J);
                     Ranked (J) := Tmp;
                  end;
               end if;
            end loop;
         end loop;

         --  Assign ranks
         for Rank in Ranked'Range loop
            declare
               P : Model_Profile := Profiles (Ranked (Rank));
            begin
               P.Comparison_Rank := Rank;
               Profiles.Replace_Element (Ranked (Rank), P);
            end;
         end loop;
      end;
   end Compare_Models;

end Vexometer.API;
