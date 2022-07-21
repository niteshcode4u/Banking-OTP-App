defmodule ExBankingTest do
  use ExUnit.Case, async: false

  alias ExBanking.UserSupervisor

  @currency "INR"
  @username "Nitesh"

  describe "create_user/1 [user]" do
    setup [:clear_on_exit]

    test "Success: Creates user when correct data given" do
      assert :ok == ExBanking.create_user(@username)
      assert :ok == ExBanking.create_user("Mishra")
      assert :ok == ExBanking.create_user("Ravi")
    end

    test "Error: Already exist when trying to create user with same name" do
      assert :ok == ExBanking.create_user(@username)
      assert {:error, :user_already_exists} == ExBanking.create_user(@username)

      assert :ok == ExBanking.create_user("Mishra")
      assert {:error, :user_already_exists} == ExBanking.create_user("Mishra")
    end

    test "Error: When wrong argument provided" do
      assert {:error, :wrong_arguments} == ExBanking.create_user(:nitesh)
      assert {:error, :wrong_arguments} == ExBanking.create_user(123_456)
      assert {:error, :wrong_arguments} == ExBanking.create_user([])
    end
  end

  describe "deposit/3 [user, amount, currency]" do
    setup [:clear_on_exit]

    test "Success: Deposit money to provided user" do
      ExBanking.create_user(@username)

      assert {:ok, 11} == ExBanking.deposit(@username, 11, @currency)
      assert {:ok, 112} == ExBanking.deposit(@username, 101, @currency)
    end

    test "Error: when wrong argument given" do
      ExBanking.create_user(@username)

      assert {:error, :wrong_arguments} == ExBanking.deposit(@username, "11", @currency)
      assert {:error, :wrong_arguments} == ExBanking.deposit("Mishra", 11, 123)
      assert {:error, :wrong_arguments} == ExBanking.deposit(:nitesh, 11, @currency)
    end

    test "Error: when user doesn't exist" do
      assert {:error, :user_does_not_exist} == ExBanking.deposit(@username, 11, @currency)
      assert {:error, :user_does_not_exist} == ExBanking.deposit("Mishra", 11, @currency)
    end

    test "Error: when there are too many requests" do
      #set up
      ExBanking.create_user(@username)

      total_failures =
        1..51
        |> Enum.map(fn _request -> Task.async(fn -> ExBanking.deposit(@username, 11, @currency) end) end)
        |> Enum.map(&Task.await/1)
        |> Enum.count(fn result -> result == {:error, :too_many_requests_to_user}  end)

      assert total_failures > 0
    end
  end

  describe "withdraw/3 [user, amount, currency]" do
    setup [:clear_on_exit]

    test "Success: Withdraw money from user's account" do
      ExBanking.create_user(@username)
      ExBanking.deposit(@username, 101, @currency)

      assert {:ok, 90} == ExBanking.withdraw(@username, 11, @currency)
      assert {:ok, 51} == ExBanking.withdraw(@username, 39, @currency)
    end

    test "Error: when wrong argument given" do
      ExBanking.create_user(@username)

      assert {:error, :wrong_arguments} == ExBanking.withdraw(@username, "11", @currency)
      assert {:error, :wrong_arguments} == ExBanking.withdraw("Mishra", 11, 123)
      assert {:error, :wrong_arguments} == ExBanking.withdraw(:nitesh, 11, @currency)
    end

    test "Error: when user doesn't exist" do
      assert {:error, :user_does_not_exist} == ExBanking.withdraw(@username, 11, @currency)
      assert {:error, :user_does_not_exist} == ExBanking.withdraw("Mishra", 11, @currency)
    end

    test "Error: when requested amount exceeds available balance" do
      ExBanking.create_user(@username)

      assert {:error, :not_enough_money} == ExBanking.withdraw(@username, 11, @currency)
      assert {:error, :not_enough_money} == ExBanking.withdraw(@username, 21, "USD")
    end

    test "Error: when there are too many requests" do
      #set up
      ExBanking.create_user(@username)
      ExBanking.deposit(@username, 101, @currency)

      total_failures =
        1..51
        |> Enum.map(fn _request -> Task.async(fn -> ExBanking.withdraw(@username, 11, @currency) end) end)
        |> Enum.map(&Task.await/1)
        |> Enum.count(fn result -> result == {:error, :too_many_requests_to_user}  end)

      assert total_failures > 0
    end
  end

  describe "get_balance/2 [user, currency]" do
    setup [:clear_on_exit]

    test "Success: gives balance for the user" do
      ExBanking.create_user(@username)
      ExBanking.deposit(@username, 101, @currency)
      ExBanking.deposit(@username, 100, "EUR")

      assert {:ok, 101} == ExBanking.get_balance(@username, @currency)
      assert {:ok, 100} == ExBanking.get_balance(@username, "EUR")
      assert {:ok, 0.0} == ExBanking.get_balance(@username, "USD")
    end

    test "Error: when wrong argument given" do
      ExBanking.create_user(@username)

      assert {:error, :wrong_arguments} == ExBanking.get_balance(@username, :inr)
      assert {:error, :wrong_arguments} == ExBanking.get_balance(:nitesh, @currency)
    end

    test "Error: when user doesn't exist" do
      assert {:error, :user_does_not_exist} == ExBanking.get_balance(@username, @currency)
      assert {:error, :user_does_not_exist} == ExBanking.get_balance("Mishra", @currency)
    end
  end

  describe "send/4 [from_user, to_user, amount, currency]" do
    setup [:clear_on_exit]

    test "Success: send money to requested user" do
      ExBanking.create_user(@username)
      ExBanking.create_user("Mishra")
      ExBanking.deposit(@username, 101, @currency)

      assert {:ok, 90.0} == ExBanking.send(@username, "Mishra", 11, @currency)
      assert {:ok, 59.0} == ExBanking.send(@username, "Mishra", 31, @currency)

      # Doing reverse payment - just for fun
      assert {:ok, 11.0} == ExBanking.send("Mishra", @username, 31, @currency)
      assert {:ok, 6.0} == ExBanking.send("Mishra", @username, 5, @currency)
    end

    test "Error: when wrong argument given" do
      ExBanking.create_user(@username)

      assert {:error, :wrong_arguments} == ExBanking.send(:nitesh, :mishra, 11, @currency)
      assert {:error, :wrong_arguments} == ExBanking.send(@username, :mishra, 11, @currency)
      assert {:error, :wrong_arguments} == ExBanking.send(@username, :mishra, "11", @currency)
      assert {:error, :wrong_arguments} == ExBanking.send(@username, :mishra, 11, :eur)
    end

    test "Error: when not enoungh money to sender's account" do
      ExBanking.create_user(@username)
      ExBanking.create_user("Mishra")

      assert {:error, :not_enough_money} == ExBanking.send(@username, "Mishra", 11, @currency)
      assert {:error, :not_enough_money} == ExBanking.send("Mishra", @username, 31, @currency)
    end

    test "Error: when sender doesn't exist" do
      assert {:error, :sender_does_not_exist} == ExBanking.send(@username, "Mishra", 11, @currency)
      assert {:error, :sender_does_not_exist} == ExBanking.send("Mishra", @username, 31, @currency)
    end

    test "Error: when receiver doesn't exist" do
      ExBanking.create_user(@username)

      assert {:error, :receiver_does_not_exist} == ExBanking.send(@username, "Mishra", 11, @currency)
      assert {:error, :receiver_does_not_exist} == ExBanking.send(@username, "David", 101, @currency)
    end
  end

  defp clear_on_exit(_context) do
    UserSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {:undefined, pid, _type, _sup} ->
      DynamicSupervisor.terminate_child(UserSupervisor, pid)
    end)

    :ok
  end
end
