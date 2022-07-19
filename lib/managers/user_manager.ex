defmodule ExBanking.Managers.UserManager do
  @moduledoc """
  The `ExBanking.Managers.UserManager` server implementation
    A module which handles everything related to users and manages the user state
  """

  use GenServer, restart: :transient

  @registry_name Registry.UserRegistry

  ##############################################################################
  def start_link(opts) do
    name =
      opts
      |> Keyword.fetch!(:user)
      |> fetch_process_name()

    GenServer.start_link(__MODULE__, [], name: name)
  end

  @impl true
  def init(state), do: {:ok, state}

  ##### Public APIs ############################################################
  # @spec is_user_exist?(user)

  @spec get_user(String.t()) :: :empty | {:ok, map()}
  def get_user(user) do
    user
    |> fetch_process_name()
    |> GenServer.whereis()
    |> case do
      nil ->
        :empty

      _pid ->
        user = user |> fetch_process_name() |> GenServer.call({:get_user, user})
        {:ok, user}
    end
  end

  @spec create(String.t()) :: :ok | :user_exist
  def create(user) do
    user
    |> fetch_process_name()
    |> GenServer.call({:register_user, user})
  end

  @spec create(map()) :: :ok
  def update_balance(params) do
    params.user
    |> fetch_process_name()
    |> GenServer.call({:update_balance, params})
  end

  ##### Call handlers ##########################################################

  @impl true
  def handle_call({:get_user, _user}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:register_user, user}, _from, _state) do
    state = ExBanking.Core.User.new(user)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_balance, params}, _from, _state) do
    {:reply, :ok, params}
  end

  ##### Private functions #######################################################

  defp fetch_process_name(user), do: {:via, Registry, {@registry_name, user}}
end
