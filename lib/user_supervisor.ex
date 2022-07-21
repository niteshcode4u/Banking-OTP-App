defmodule ExBanking.UserSupervisor do
  @moduledoc """
  Supervisor to start process for user to create.
  """

  use DynamicSupervisor

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_child(String.t()) :: :ok | :user_exist
  def start_child(user) do
    child = {ExBanking.Managers.UserManager, user: user}

    case DynamicSupervisor.start_child(__MODULE__, child) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :user_exist
    end
  end
end
