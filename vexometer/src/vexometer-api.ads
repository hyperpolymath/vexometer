--  Vexometer.API - LLM API clients
--
--  Clients for sending prompts to various LLM providers and collecting
--  responses for analysis. Prioritises local/open models.
--
--  Copyright (C) 2024 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0

pragma Ada_2022;

with Vexometer.Core;         use Vexometer.Core;
with Vexometer.Probes;       use Vexometer.Probes;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Calendar;

package Vexometer.API is

   ---------------------------------------------------------------------------
   --  API Providers
   --
   --  Local providers are preferred for privacy and reproducibility
   ---------------------------------------------------------------------------

   type API_Provider is (
      --  Local (preferred)
      Ollama,       --  https://ollama.ai - recommended
      LMStudio,     --  https://lmstudio.ai
      Llamacpp,     --  https://github.com/ggml-org/llama.cpp
      LocalAI,      --  https://localai.io
      Koboldcpp,    --  https://github.com/LostRuins/koboldcpp

      --  Remote open-weight
      HuggingFace,  --  Inference API
      Together,     --  https://together.ai
      Groq,         --  https://groq.com

      --  Remote proprietary (for comparison)
      OpenAI,
      Anthropic,
      Google,       --  Gemini
      Mistral,

      --  Custom endpoint
      Custom
   );

   function Is_Local (Provider : API_Provider) return Boolean is
      (Provider in Ollama | LMStudio | Llamacpp | LocalAI | Koboldcpp);

   function Default_Endpoint (Provider : API_Provider) return String is
      (case Provider is
         when Ollama    => "http://localhost:11434/api",
         when LMStudio  => "http://localhost:1234/v1",
         when Llamacpp  => "http://localhost:8080",
         when LocalAI   => "http://localhost:8080/v1",
         when Koboldcpp => "http://localhost:5001/api",
         when HuggingFace => "https://api-inference.huggingface.co",
         when Together  => "https://api.together.xyz/v1",
         when Groq      => "https://api.groq.com/openai/v1",
         when OpenAI    => "https://api.openai.com/v1",
         when Anthropic => "https://api.anthropic.com/v1",
         when Google    => "https://generativelanguage.googleapis.com/v1",
         when Mistral   => "https://api.mistral.ai/v1",
         when Custom    => "");

   ---------------------------------------------------------------------------
   --  API Client Configuration
   ---------------------------------------------------------------------------

   type Client_Config is record
      Provider       : API_Provider := Ollama;
      Endpoint       : Unbounded_String;
      API_Key        : Unbounded_String;  --  Empty for local
      Model          : Unbounded_String;
      Temperature    : Float := 0.0;      --  Deterministic for reproducibility
      Max_Tokens     : Natural := 2048;
      Timeout        : Duration := 60.0;
      Retry_Count    : Natural := 3;
      Retry_Delay    : Duration := 1.0;
   end record;

   Default_Ollama_Config : constant Client_Config := (
      Provider    => Ollama,
      Endpoint    => To_Unbounded_String ("http://localhost:11434/api"),
      API_Key     => Null_Unbounded_String,
      Model       => To_Unbounded_String ("llama3.2"),
      Temperature => 0.0,
      Max_Tokens  => 2048,
      Timeout     => 60.0,
      Retry_Count => 3,
      Retry_Delay => 1.0
   );

   ---------------------------------------------------------------------------
   --  API Client
   ---------------------------------------------------------------------------

   type API_Client is tagged private;

   procedure Configure
      (Client : in out API_Client;
       Config : Client_Config);

   procedure Configure
      (Client   : in out API_Client;
       Provider : API_Provider;
       Model    : String;
       Endpoint : String := "";
       API_Key  : String := "");

   function Is_Configured (Client : API_Client) return Boolean;

   function Test_Connection (Client : API_Client) return Boolean;
   --  Verify API is reachable

   function List_Models (Client : API_Client) return Unbounded_String;
   --  Get available models (provider-dependent)

   ---------------------------------------------------------------------------
   --  Sending Prompts
   ---------------------------------------------------------------------------

   type Send_Result is record
      Success       : Boolean;
      Response      : Unbounded_String;
      Response_Time : Duration;
      Token_Count   : Natural;       --  Estimated or exact
      Error_Message : Unbounded_String;
      Timestamp     : Ada.Calendar.Time;
   end record;

   function Send_Prompt
      (Client : API_Client;
       Prompt : String;
       System : String := "") return Send_Result;

   function Send_Chat
      (Client   : API_Client;
       Messages : Message_Array) return Send_Result;

   ---------------------------------------------------------------------------
   --  Batch Evaluation
   ---------------------------------------------------------------------------

   type Batch_Progress is access procedure
      (Current : Positive;
       Total   : Positive;
       Model   : String;
       Probe   : String);

   procedure Run_Probe_Suite
      (Client   : API_Client;
       Suite    : Probe_Suite;
       Results  : out Result_Vector;
       Progress : Batch_Progress := null);

   procedure Run_Probe_Suite
      (Client   : API_Client;
       Suite    : Probe_Suite;
       Config   : Analysis_Config;
       Results  : out Result_Vector;
       Analysis : out Response_Vector;
       Progress : Batch_Progress := null);

   ---------------------------------------------------------------------------
   --  Multi-Model Comparison
   ---------------------------------------------------------------------------

   type Model_Config_Array is array (Positive range <>) of Client_Config;

   procedure Compare_Models
      (Configs  : Model_Config_Array;
       Suite    : Probe_Suite;
       Profiles : out Profile_Vector;
       Progress : Batch_Progress := null);

   ---------------------------------------------------------------------------
   --  Message Types for Chat API
   ---------------------------------------------------------------------------

   type Message_Role is (System, User, Assistant);

   type Chat_Message is record
      Role    : Message_Role;
      Content : Unbounded_String;
   end record;

   type Message_Array is array (Positive range <>) of Chat_Message;

private

   type API_Client is tagged record
      Config      : Client_Config;
      Configured  : Boolean := False;
      Last_Error  : Unbounded_String;
   end record;

end Vexometer.API;
