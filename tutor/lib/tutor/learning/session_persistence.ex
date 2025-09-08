defmodule Tutor.Learning.SessionPersistence do
  @moduledoc """
  Handles persistence of session state and conversation history.
  
  Provides functions to save and restore SessionServer state to/from the database.
  """

  import Ecto.Query
  alias Tutor.Repo
  alias Tutor.Learning.{SessionHistory, UserProgress}

  @doc """
  Persists the current session state to the database.
  
  Creates or updates a SessionHistory record with:
  - Conversation history
  - Session metrics
  - Current pedagogical state
  - Topic progress
  """
  def persist_session(session_state) do
    session_data = %{
      user_id: session_state.user_id,
      session_id: session_state.session_id,
      current_state: session_state.current_state,
      current_topic_id: if(session_state.current_topic, do: session_state.current_topic.id),
      conversation_history: session_state.conversation_history,
      session_metrics: session_state.session_metrics,
      last_activity: session_state.last_activity,
      ended_at: nil  # Still active
    }

    case get_session_history(session_state.session_id) do
      nil ->
        %SessionHistory{}
        |> SessionHistory.changeset(session_data)
        |> Repo.insert()

      existing ->
        existing
        |> SessionHistory.changeset(session_data)
        |> Repo.update()
    end
  end

  @doc """
  Marks a session as ended and performs final persistence.
  """
  def end_session(session_state) do
    session_data = %{
      user_id: session_state.user_id,
      session_id: session_state.session_id,
      current_state: :ended,
      current_topic_id: if(session_state.current_topic, do: session_state.current_topic.id),
      conversation_history: session_state.conversation_history,
      session_metrics: session_state.session_metrics,
      last_activity: session_state.last_activity,
      ended_at: DateTime.utc_now()
    }

    case get_session_history(session_state.session_id) do
      nil ->
        %SessionHistory{}
        |> SessionHistory.changeset(session_data)
        |> Repo.insert()

      existing ->
        existing
        |> SessionHistory.changeset(session_data)
        |> Repo.update()
    end
    |> case do
      {:ok, session_history} ->
        # Update user progress based on session metrics
        update_user_progress(session_state)
        {:ok, session_history}

      error ->
        error
    end
  end

  @doc """
  Attempts to restore a session from the database.
  
  Returns the restored session state or nil if not found.
  """
  def restore_session(session_id) do
    case get_session_history(session_id) do
      nil ->
        nil

      session_history ->
        # Only restore if session was not ended
        if session_history.ended_at == nil do
          build_session_state_from_history(session_history)
        else
          nil
        end
    end
  end

  @doc """
  Gets recent sessions for a user.
  """
  def get_user_sessions(user_id, limit \\ 10) do
    SessionHistory
    |> where([sh], sh.user_id == ^user_id)
    |> order_by([sh], desc: sh.last_activity)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Calculates session statistics for analytics.
  """
  def get_session_stats(user_id, date_range \\ nil) do
    query = SessionHistory
    |> where([sh], sh.user_id == ^user_id)

    query = if date_range do
      where(query, [sh], sh.last_activity >= ^date_range.from and sh.last_activity <= ^date_range.to)
    else
      query
    end

    sessions = Repo.all(query)

    %{
      total_sessions: length(sessions),
      total_questions: Enum.sum(Enum.map(sessions, &get_in(&1.session_metrics, ["questions_attempted"]) || 0)),
      total_correct: Enum.sum(Enum.map(sessions, &get_in(&1.session_metrics, ["correct_answers"]) || 0)),
      average_session_length: calculate_average_session_length(sessions),
      topics_covered: get_unique_topics_covered(sessions)
    }
  end

  # Private functions

  defp get_session_history(session_id) do
    SessionHistory
    |> where([sh], sh.session_id == ^session_id)
    |> Repo.one()
  end

  defp build_session_state_from_history(session_history) do
    # This would reconstruct the SessionServer state from database
    # For now, return a basic structure
    %{
      user_id: session_history.user_id,
      session_id: session_history.session_id,
      current_state: String.to_atom(session_history.current_state),
      conversation_history: session_history.conversation_history,
      session_metrics: session_history.session_metrics,
      last_activity: session_history.last_activity
    }
  end

  defp update_user_progress(session_state) do
    # Update UserProgress records based on session performance
    if session_state.current_topic && session_state.session_metrics.questions_attempted > 0 do
      accuracy = session_state.session_metrics.correct_answers / session_state.session_metrics.questions_attempted

      # TODO: Implement UserProgress.update_progress/3 function
      # UserProgress.update_progress(
      #   session_state.user_id,
      #   session_state.current_topic.id,
      #   %{
      #     questions_attempted: session_state.session_metrics.questions_attempted,
      #     correct_answers: session_state.session_metrics.correct_answers,
      #     accuracy: accuracy,
      #     last_practiced: DateTime.utc_now()
      #   }
      # )
      :ok
    end
  end

  defp calculate_average_session_length(sessions) do
    durations = Enum.map(sessions, fn session ->
      if session.ended_at do
        DateTime.diff(session.ended_at, session.inserted_at, :minute)
      else
        DateTime.diff(session.last_activity, session.inserted_at, :minute)
      end
    end)

    if length(durations) > 0 do
      Enum.sum(durations) / length(durations)
    else
      0
    end
  end

  defp get_unique_topics_covered(sessions) do
    sessions
    |> Enum.map(& &1.current_topic_id)
    |> Enum.filter(& &1 != nil)
    |> Enum.uniq()
    |> length()
  end
end