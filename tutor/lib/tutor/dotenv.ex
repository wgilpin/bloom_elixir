defmodule Tutor.DotEnv do
  @moduledoc """
  Loads environment variables from .env files.
  Supports multiple environments and follows priority order.
  """

  require Logger

  @doc """
  Loads environment variables from .env files based on the current environment.
  
  Files are loaded in the following order (later files override earlier ones):
  1. .env (shared settings)
  2. .env.local (local overrides, not committed to git)
  3. .env.{environment} (environment-specific settings, e.g., .env.dev)
  4. .env.{environment}.local (local environment-specific overrides)
  
  Environment variables that are already set in the system are NOT overridden.
  """
  def load! do
    env = Mix.env() |> to_string()
    
    files = [
      ".env",
      ".env.local",
      ".env.#{env}",
      ".env.#{env}.local"
    ]
    
    Enum.each(files, &load_file/1)
  end

  @doc """
  Loads a specific .env file if it exists.
  """
  def load_file(filename) do
    path = Path.join(File.cwd!(), filename)
    
    if File.exists?(path) do
      Logger.debug("Loading environment variables from #{filename}")
      
      case DotenvParser.parse_file(path) do
        {:ok, data} -> data
        {:error, reason} -> 
          Logger.warning("Failed to parse #{filename}: #{inspect(reason)}")
          []
      end
      |> Enum.each(fn {key, value} ->
        # Only set if not already set in system environment
        if System.get_env(key) == nil do
          System.put_env(key, value)
          Logger.debug("Set #{key} from #{filename}")
        end
      end)
    else
      Logger.debug("#{filename} not found, skipping")
    end
  rescue
    error ->
      Logger.warning("Failed to load #{filename}: #{inspect(error)}")
  end

  @doc """
  Validates that required environment variables are set.
  Returns {:ok, :valid} if all required vars are present, {:error, missing_vars} otherwise.
  """
  def validate_required(required_vars) do
    missing = Enum.filter(required_vars, fn var ->
      System.get_env(var) == nil
    end)
    
    case missing do
      [] -> 
        {:ok, :valid}
      vars -> 
        {:error, vars}
    end
  end

  @doc """
  Helper to check if an environment variable is set.
  """
  def has_env?(key) do
    System.get_env(key) != nil
  end

  @doc """
  Get environment variable with a default value if not set.
  """
  def get_env(key, default \\ nil) do
    System.get_env(key) || default
  end
end