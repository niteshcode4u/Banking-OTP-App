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

  @spec start_child(String.t()) :: DynamicSupervisor.on_start_child()
  def start_child(user) do
    child = {ExBanking.Managers.UserManager, user: user}

    DynamicSupervisor.start_child(__MODULE__, child)
  end
end
