defmodule ExBanking do
  @moduledoc """
  Documentation for `ExBanking`.
  """

  alias ExBanking.Core.User
  alias ExBanking.Managers.UserManager
  alias ExBanking.UserSupervisor

  @doc """
  Function creates new user in the system
  New user has zero balance of any currency

  ## Examples

      iex> ExBanking.create_user("nitesh")
      :ok

      iex> ExBanking.create_user("nitesh")
      {:error, :user_already_exists}

      iex> ExBanking.create_user(12345)
      {:error, :wrong_arguments}

  """
  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    user
    |> UserSupervisor.start_child()
    |> case do
      :ok -> UserManager.create(user)
      :user_exist -> {:error, :user_already_exists}
    end
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @doc """
  Increases user’s balance in given currency by amount value
  Returns new_balance of the user in given format

  ## Examples
      iex> ExBanking.deposit("nitesh", 1, "INR")
      {:ok, 1}

      iex> ExBanking.deposit("nitesh", 12, 123)
      {:error, :wrong_arguments}

      iex> ExBanking.deposit("Mishra", 1, "INR")
      {:error, :user_does_not_exist}

  """
  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
      when is_binary(user) and is_binary(currency) and is_number(amount) and amount > 0 do
    case UserManager.get_user(user) do
      :empty ->
        {:error, :user_does_not_exist}

      {:ok, user_details} ->
        params = %User{
          user: user_details.user,
          funds:
            Map.update(user_details.funds, currency, amount, fn currency_balance ->
              Float.floor((currency_balance + amount) / 1, 2)
            end)
        }

        case UserManager.update_balance(params) do
          :max_request_reached ->
            {:error, :too_many_requests_to_user}

          user_details ->
            {:ok, user_details.funds[currency]}
        end
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @doc """
  Decreases user’s balance in given currency by amount value
  Returns new_balance of the user in given format

  ## Examples

      iex> ExBanking.withdraw("nitesh", 1, "INR")
      {:ok, 1}

      iex> ExBanking.withdraw("nitesh", 1, 22)
      {:error, :wrong_arguments}

      iex> ExBanking.withdraw("nitesh", -12, "INR")
      {:error, :wrong_arguments}

      iex> ExBanking.withdraw("nitesh", "dummy", "INR")
      {:error, :wrong_arguments}

      iex> ExBanking.withdraw("Mishra", 1, "INR")
      {:error, :user_does_not_exist}

  """
  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency)
      when is_binary(user) and is_binary(currency) and is_number(amount) and amount > 0 do
    with {:ok, user_details} <- UserManager.get_user(user),
         true <- (user_details.funds[currency] || 0.0) > amount do
      params = %User{
        user: user_details.user,
        funds:
          Map.update(user_details.funds, currency, amount, fn currency_balance ->
            Float.floor((currency_balance - amount) / 1, 2)
          end)
      }

      case UserManager.update_balance(params) do
        :max_request_reached ->
          {:error, :too_many_requests_to_user}

        user_details ->
          {:ok, user_details.funds[currency]}
      end
    else
      :empty ->
        {:error, :user_does_not_exist}

      false ->
        {:error, :not_enough_money}
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @doc """
  Returns balance of the user in given format {:ok, balance}

  ## Examples

      iex> ExBanking.get_balance("nitesh", "INR")
      {:ok, 1}

      iex> ExBanking.get_balance("nitesh", 123)
      {:error, :wrong_arguments}

      iex> ExBanking.get_balance("Mishra", "INR")
      {:error, :user_does_not_exist}
  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}

  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    case UserManager.get_balance(user) do
      :empty ->
        {:error, :user_does_not_exist}

      :max_request_reached ->
        {:error, :too_many_requests_to_sender}

      {:ok, user_details} ->
        {:ok, user_details.funds[currency] || 0.0}
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @doc """
  Decreases from_user’s balance in given currency by amount value
  Increases to_user’s balance in given currency by amount value
  Returns balance of from_user and to_user in given format

  ## Examples

      iex> ExBanking.send("nitesh", "mishra", 10, "INR")
      :ok

      iex> ExBanking.send("nitesh", "mishra", 10, "INR")
      {:error, :receiver_does_not_exist}

      iex> ExBanking.send("niteshE", "mishra", 10, "INR")
      {:error, :sender_does_not_exist}

      iex> ExBanking.send("nitesh", "mishra", 10, "INR")
      {:error, :not_enough_money}

      iex> ExBanking.send("nitesh", "mishra", 10, "INR")
      {:error, :too_many_requests_to_sender}

      iex> ExBanking.send("nitesh", "mishra", 10, "INR")
      {:error, :too_many_requests_to_receiver}

  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_binary(currency) and
             is_number(amount) and amount > 0 do
    with {:from, {:ok, from_user_details}} <- {:from, UserManager.get_user(from_user)},
         {:to, {:ok, to_user_details}} <- {:to, UserManager.get_user(to_user)},
         true <- (from_user_details.funds[currency] || 0.0) >= amount do
      from_user_params = %User{
        user: from_user_details.user,
        funds:
          Map.update(from_user_details.funds, currency, amount, fn currency_balance ->
            Float.floor((currency_balance - amount) / 1, 2)
          end)
      }

      to_user_params = %User{
        user: to_user_details.user,
        funds:
          Map.update(to_user_details.funds, currency, amount, fn currency_balance ->
            Float.floor((currency_balance + amount) / 1, 2)
          end)
      }

      from_user_details = UserManager.update_balance(from_user_params)
      to_user_details = UserManager.update_balance(to_user_params)

      cond do
        from_user_details == :max_request_reached -> {:error, :too_many_requests_to_sender}
        to_user_details == :max_request_reached -> {:error, :too_many_requests_to_receiver}
        true -> {:ok, from_user_details.funds[currency]}
      end
    else
      {:from, :empty} ->
        {:error, :sender_does_not_exist}

      {:to, :empty} ->
        {:error, :receiver_does_not_exist}

      false ->
        {:error, :not_enough_money}
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}
end
