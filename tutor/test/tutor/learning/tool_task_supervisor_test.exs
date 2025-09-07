defmodule Tutor.Learning.ToolTaskSupervisorTest do
  use ExUnit.Case, async: true
  
  alias Tutor.Learning.ToolTaskSupervisor
  alias Tutor.Tools
  
  describe "ToolTaskSupervisor async execution" do
    test "executes tool function asynchronously with monitoring" do
      task = ToolTaskSupervisor.async_tool_call(
        Tools,
        :generate_question,
        [%{name: "Test Topic", id: 1}]
      )
      
      assert %Task{} = task
      assert is_pid(task.pid)
      
      # Await the result
      result = Task.await(task, 5000)
      
      assert is_map(result)
      assert result["text"] != nil
      assert result["correct_answer"] != nil
    end
    
    test "executes tool function without monitoring" do
      task = ToolTaskSupervisor.async_tool_call_nolink(
        Tools,
        :generate_question,
        [%{name: "Test Topic", id: 1}]
      )
      
      assert %Task{} = task
      assert is_pid(task.pid)
      
      # Should still be able to await even though it's not linked
      result = Task.await(task, 5000)
      assert is_map(result)
    end
    
    test "handles multiple concurrent tool calls" do
      tasks = for i <- 1..5 do
        ToolTaskSupervisor.async_tool_call(
          Tools,
          :generate_question,
          [%{name: "Topic #{i}", id: i}]
        )
      end
      
      results = Task.await_many(tasks, 5000)
      
      assert length(results) == 5
      for result <- results do
        assert is_map(result)
        assert result["text"] != nil
      end
    end
    
    test "start_tool_task sends result back to caller" do
      parent = self()
      
      {:ok, task_pid} = ToolTaskSupervisor.start_tool_task(
        parent,
        fn -> Tools.generate_question(%{name: "Test", id: 1}) end,
        []
      )
      
      assert is_pid(task_pid)
      
      # Should receive the result message
      assert_receive {:tool_result, ^task_pid, {:ok, result}}, 1000
      assert is_map(result)
      assert result["text"] != nil
    end
    
    test "start_tool_task handles errors gracefully" do
      parent = self()
      
      {:ok, task_pid} = ToolTaskSupervisor.start_tool_task(
        parent,
        fn -> raise "Test error" end,
        []
      )
      
      # Should receive error message
      assert_receive {:tool_result, ^task_pid, {:error, %RuntimeError{message: "Test error"}}}, 1000
    end
    
    test "handles different tool functions" do
      # Test check_answer
      question = %{"correct_answer" => "4"}
      task1 = ToolTaskSupervisor.async_tool_call(
        Tools,
        :check_answer,
        [question, "4"]
      )
      
      result1 = Task.await(task1, 5000)
      assert result1["is_correct"] == true
      
      # Test explain_concept  
      task2 = ToolTaskSupervisor.async_tool_call(
        Tools,
        :explain_concept,
        [nil, "What is addition?"]
      )
      
      result2 = Task.await(task2, 5000)
      assert is_binary(result2)
      assert String.contains?(result2, "What is addition?")
      
      # Test diagnose_error
      task3 = ToolTaskSupervisor.async_tool_call(
        Tools,
        :diagnose_error,
        [%{}, %{}]
      )
      
      result3 = Task.await(task3, 5000)
      assert result3["error_type"] != nil
      assert result3["misconception"] != nil
      
      # Test create_remediation
      task4 = ToolTaskSupervisor.async_tool_call(
        Tools,
        :create_remediation,
        [nil, %{"error_type" => "test"}]
      )
      
      result4 = Task.await(task4, 5000)
      assert is_binary(result4)
    end
  end
  
  describe "Task supervision" do
    test "supervised tasks are monitored by the supervisor" do
      # Start a long-running task
      task = ToolTaskSupervisor.async_tool_call(
        Kernel,
        :send,
        [self(), :test_message]
      )
      
      assert_receive :test_message, 1000
      
      # Task should complete
      Task.await(task, 1000)
    end
    
    test "handles task crashes without affecting supervisor" do
      # Start a task that will crash using start_tool_task which handles errors
      parent = self()
      
      {:ok, task_pid} = ToolTaskSupervisor.start_tool_task(
        parent,
        fn -> raise "Intentional crash" end,
        []
      )
      
      # Should receive error message without crashing
      assert_receive {:tool_result, ^task_pid, {:error, %RuntimeError{message: "Intentional crash"}}}, 1000
      
      # Supervisor should still be running
      # Try another task to verify
      task2 = ToolTaskSupervisor.async_tool_call(
        Tools,
        :generate_question,
        [%{name: "Test", id: 1}]
      )
      
      result = Task.await(task2, 5000)
      assert is_map(result)
    end
  end
end