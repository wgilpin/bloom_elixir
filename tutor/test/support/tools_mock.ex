defmodule Tutor.Tools.MockBehaviour do
  @moduledoc """
  Mock behaviour for Tools module to enable testing of LLM-dependent functions.
  """
  
  @callback generate_question(topic :: any()) :: {:ok, map()} | {:error, String.t()}
  @callback check_answer(question :: map(), student_answer :: String.t()) :: {:ok, map()} | {:error, String.t()}
  @callback diagnose_error(question :: map(), answer_data :: map()) :: {:ok, map()} | {:error, String.t()}
  @callback create_remediation(topic :: String.t(), diagnosis :: map()) :: {:ok, String.t()} | {:error, String.t()}
  @callback explain_concept(topic :: any(), student_message :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback provide_hint(question :: map(), context_or_prompt :: String.t()) :: {:ok, String.t()} | {:error, String.t()}
end

# Create the mock using Mox
Mox.defmock(Tutor.Tools.Mock, for: Tutor.Tools.MockBehaviour)