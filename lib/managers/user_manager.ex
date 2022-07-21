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

    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(state), do: {:ok, state}

  ##### Public APIs ############################################################
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

  @spec get_balance(String.t()) :: :empty | :max_request_reached | {:ok, map()}
  def get_balance(user) do
    user
    |> fetch_process_name()
    |> GenServer.whereis()
    |> case do
      nil ->
        :empty

      _pid ->
        user = user |> fetch_process_name() |> GenServer.call({:get_balance, user})
        if user == :max_request_reached, do: :max_request_reached, else: {:ok, user}
    end
  end

  @spec create(String.t()) :: :ok | :user_exist
  def create(user) do
    user
    |> fetch_process_name()
    |> GenServer.call({:register_user, user})
  end

  @spec update_balance(map()) :: map() | :max_request_reached
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
  def handle_call({:get_balance, _user}, _from, state) do
    case validate_number_of_prcesses(self()) do
      :ok ->
        {:reply, state, state}

      :max_request_reached ->
        {:reply, :max_request_reached, state}
    end
  end

  @impl true
  def handle_call({:register_user, user}, _from, _state) do
    new_state = ExBanking.Core.User.new(user)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update_balance, params}, _from, state) do
    case validate_number_of_prcesses(self()) do
      :ok ->
        {:reply, params, params}

      :max_request_reached ->
        {:reply, :max_request_reached, state}
    end
  end

  ##### Private functions #######################################################

  defp fetch_process_name(user), do: {:via, Registry, {@registry_name, user}}

  defp validate_number_of_prcesses(pid) do
    {_, num} = Process.info(pid, :message_queue_len)

    if num >= 10,
      do: :max_request_reached,
      else: :ok
  end
end
